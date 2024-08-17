// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.2;

import {UltraVerifier as RiftPlonkVerification} from "./verifiers/RiftPlonkVerification.sol";
import {BlockHashStorage} from "./BlockHashStorage.sol";
import {console} from "forge-std/console.sol";
import {Ownable} from "./helpers/Ownable.sol";

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    function transfer(address recipient, uint256 amount) external returns (bool);

    function balanceOf(address account) external view returns (uint256);

    function allowance(address owner, address spender) external view returns (uint256);

    function decimals() external view returns (uint8);
}

error DepositTooLow();
error DepositTooHigh();
error DepositFailed();
error exchangeRateZero();
error WithdrawFailed();
error LpDoesntExist();
error NotVaultOwner();
error TooManyLps();
error NotEnoughLiquidity();
error ReservationAmountTooLow();
error InvalidOrder();
error NotEnoughLiquidityConsumed();
error LiquidityReserved(uint256 unlockTime);
error LiquidityNotReserved();
error InvalidLpIndex();
error NoLiquidityToReserve();
error OrderComplete();
error ReservationFeeTooLow();
error InvalidVaultIndex();
error WithdrawalAmountError();
error InvalidEthereumAddress();
error InvalidBitcoinAddress();
error InvalidProof();
error InvaidSameExchangeRatevaultIndex();
error InvalidVaultUpdate();
error ReservationNotExpired();
error InvalidUpdateWithActiveReservations();
error StillInChallengePeriod();
error ReservationNotUnlocked();

contract RiftExchange is BlockHashStorage, Ownable {
    uint256 public constant RESERVATION_LOCKUP_PERIOD = 8 hours;
    uint256 public constant CHALLENGE_PERIOD = 10 minutes;
    uint16 public constant MAX_DEPOSIT_OUTPUTS = 50;
    uint256 public constant PROOF_GAS_COST = 420_000; // TODO: update to real value
    uint256 public constant RELEASE_GAS_COST = 210_000; // TODO: update to real value
    uint256 public constant MIN_ORDER_GAS_MULTIPLIER = 2;
    uint8 public constant SAMPLING_SIZE = 10;

    IERC20 public immutable DEPOSIT_TOKEN;
    uint8 public immutable TOKEN_DECIMALS;

    uint8 public protocolFeeBP = 100; // 100 bp = 1%
    uint256 public proverReward;
    uint256 public releaserReward;

    struct LPunreservedBalanceChange {
        uint256 vaultIndex;
        uint256 value;
    }

    struct LiquidityProvider {
        uint256[] depositVaultIndexes;
    }

    struct DepositVault {
        uint256 initialBalance; // in token's smallest unit (wei, μUSDT, etc)
        uint192 unreservedBalance; // true balance in token's smallest unit = unreservedBalance + sum(ReservationState.Created && expired SwapReservations on this vault)
        uint64 exchangeRate; // amount of token's smallest unit per 1 sat
        bytes22 btcPayoutLockingScript;
    }

    enum ReservationState {
        None,
        Created,
        Unlocked,
        ExpiredAndAddedBackToVault,
        Completed
    }

    struct SwapReservation {
        uint32 confirmationBlockHeight;
        uint32 reservationTimestamp;
        uint32 unlockTimestamp; // timestamp when reservation was proven and unlocked
        ReservationState state;
        address ethPayoutAddress;
        bytes32 lpReservationHash;
        bytes32 nonce; // sent in bitcoin tx calldata from buyer -> lps to prevent replay attacks
        uint256 totalSwapAmount;
        int256 prepaidFeeAmount;
        uint256[] vaultIndexes;
        uint192[] amountsToReserve;
    }

    mapping(address => LiquidityProvider) liquidityProviders; // lpAddress => LiquidityProvider
    SwapReservation[] public swapReservations;
    DepositVault[] public depositVaults;

    RiftPlonkVerification public immutable verifierContract;
    address payable protocolAddress = payable(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);

    //--------- CONSTRUCTOR ---------//

    constructor(
        uint256 initialCheckpointHeight,
        bytes32 initialBlockHash,
        address verifierContractAddress,
        address depositTokenAddress,
        uint256 _proverReward,
        uint256 _releaserReward,
        address payable _protocolAddress
    ) BlockHashStorage(initialCheckpointHeight, initialBlockHash) Ownable(msg.sender) {
        // [0] set verifier contract and deposit token
        verifierContract = RiftPlonkVerification(verifierContractAddress);
        DEPOSIT_TOKEN = IERC20(depositTokenAddress);
        TOKEN_DECIMALS = DEPOSIT_TOKEN.decimals();

        // [1] set rewards based on underlying token
        proverReward = _proverReward; // in smallest token unit
        releaserReward = _releaserReward; // in smallest token unit

        // [2] set protocol address
        protocolAddress = _protocolAddress;
    }

    //--------- WRITE FUNCTIONS ---------//
    function depositLiquidity(
        bytes22 btcPayoutLockingScript,
        uint64 exchangeRate,
        int256 vaultIndexToOverwrite,
        uint192 depositAmount,
        int256 vaultIndexWithSameExchangeRate
    ) public {
        // [0] validate btc exchange rate
        if (exchangeRate == 0) {
            revert exchangeRateZero();
        }

        // [1] create new liquidity provider if it doesn't exist
        if (liquidityProviders[msg.sender].depositVaultIndexes.length == 0) {
            liquidityProviders[msg.sender] = LiquidityProvider({depositVaultIndexes: new uint256[](0)});
        }

        // [2] merge liquidity into vault with the same exchange rate if it exists
        if (vaultIndexWithSameExchangeRate != -1) {
            uint256 vaultIndex = uint(vaultIndexWithSameExchangeRate);
            DepositVault storage vault = depositVaults[vaultIndex];
            if (vault.exchangeRate == exchangeRate) {
                vault.unreservedBalance += depositAmount;
            } else {
                revert InvaidSameExchangeRatevaultIndex();
            }
        }
        // [3] overwrite empty deposit vault
        else if (vaultIndexToOverwrite != -1) {
            // [0] retrieve deposit vault to overwrite
            DepositVault storage emptyVault = depositVaults[uint256(vaultIndexToOverwrite)];

            // [1] validate vault is empty
            if (emptyVault.unreservedBalance != 0) {
                revert InvalidVaultIndex();
            }

            // [2] overwrite empty vault with new deposit
            emptyVault.initialBalance = depositAmount;
            emptyVault.unreservedBalance = depositAmount;
            emptyVault.exchangeRate = exchangeRate;
            emptyVault.btcPayoutLockingScript = btcPayoutLockingScript;
        }
        // [4] otherwise, create a new deposit vault if none are empty
        else {
            depositVaults.push(
                DepositVault({
                    initialBalance: depositAmount,
                    unreservedBalance: depositAmount,
                    exchangeRate: exchangeRate,
                    btcPayoutLockingScript: btcPayoutLockingScript
                })
            );
        }

        // [5] add deposit vault index to liquidity provider
        liquidityProviders[msg.sender].depositVaultIndexes.push(depositVaults.length - 1);

        // [6] transfer deposit token to contract
        DEPOSIT_TOKEN.transferFrom(msg.sender, address(this), depositAmount);
    }

    function updateExchangeRate(
        uint256 globalVaultIndex, // index of vault in depositVaults
        uint256 localVaultIndex, // index of vault in LP's depositVaultIndexes array
        uint64 newexchangeRate,
        uint256[] memory expiredReservationIndexes
    ) public {
        // ensure msg.sender is vault owner
        if (liquidityProviders[msg.sender].depositVaultIndexes[localVaultIndex] != globalVaultIndex) {
            revert NotVaultOwner();
        }

        // [0] validate new exchange rate
        if (newexchangeRate == 0) {
            revert InvalidVaultUpdate();
        }

        // [1] retrieve deposit vault
        DepositVault storage vault = depositVaults[globalVaultIndex];

        // cleanup dead swap reservations
        cleanUpDeadSwapReservations(expiredReservationIndexes);

        // [3] ensure no reservations are active by checking if actual available balance is equal to initial balance
        if (vault.unreservedBalance != vault.initialBalance) {
            revert InvalidUpdateWithActiveReservations();
        }

        // [4] update exchange rate
        vault.exchangeRate = newexchangeRate;
    }

    function withdrawLiquidity(
        uint256 globalVaultIndex, // index of vault in depositVaults
        uint256 localVaultIndex, // index of vault in LP's depositVaultIndexes array
        uint192 amountToWithdraw,
        uint256[] memory expiredReservationIndexes
    ) public {
        // ensure msg.sender is vault owner
        if (liquidityProviders[msg.sender].depositVaultIndexes[localVaultIndex] != globalVaultIndex) {
            revert NotVaultOwner();
        }

        /*
        console.log("vaultIndex: ", globalVaultIndex);
        console.log(
            "liquidityProviders[msg.sender].depositVaultIndexes[vaultIndex]: ",
            liquidityProviders[msg.sender].depositVaultIndexes[globalVaultIndex]
        );
        */

        // clean up dead swap reservations
        cleanUpDeadSwapReservations(expiredReservationIndexes);

        // [0] validate vault index
        if (globalVaultIndex >= depositVaults.length) {
            revert InvalidVaultIndex();
        }

        // [1] retrieve the vault
        DepositVault storage vault = depositVaults[globalVaultIndex];

        // [2] validate amount to withdraw
        if (amountToWithdraw == 0 || amountToWithdraw > vault.unreservedBalance) {
            revert WithdrawalAmountError();
        }

        // [3] withdraw funds to LP
        //console.log("unreservedBalance before: ", vault.unreservedBalance);
        vault.unreservedBalance -= amountToWithdraw;
        //console.log("unreservedBalance after: ", vault.unreservedBalance);
        //console.log("amountToWithdraw: ", amountToWithdraw);
        //console.log("contract balance: ", DEPOSIT_TOKEN.balanceOf(address(this)));

        DEPOSIT_TOKEN.transfer(msg.sender, amountToWithdraw);
    }

    function reserveLiquidity(
        uint256[] memory vaultIndexesToReserve,
        uint192[] memory amountsToReserve,
        address ethPayoutAddress,
        uint256[] memory expiredSwapReservationIndexes
    ) public {
        // [0] calculate total amount of ETH the user is attempting to reserve
        uint256 combinedAmountsToReserve = 0;
        for (uint i = 0; i < amountsToReserve.length; i++) {
            combinedAmountsToReserve += amountsToReserve[i];
        }

        // [1] calculate fees
        uint protocolFee = (combinedAmountsToReserve * (protocolFeeBP / 10_000));
        uint proverFee = proverReward + ((PROOF_GAS_COST * block.basefee) * MIN_ORDER_GAS_MULTIPLIER);
        uint releaserFee = releaserReward + ((RELEASE_GAS_COST * block.basefee) * MIN_ORDER_GAS_MULTIPLIER);
        // TODO: get historical priority fee and potentially add it ^
        //uint256 totalFees = (proverFee + protocolFee + releaserFee);

        // [3] verify proposed expired swap reservation indexes
        verifyExpiredReservations(expiredSwapReservationIndexes);

        // [4] clean up dead swap reservations
        cleanUpDeadSwapReservations(expiredSwapReservationIndexes);

        bytes32 vaultHash;

        // [5] check if there is enough liquidity in each deposit vaults to reserve
        for (uint i = 0; i < vaultIndexesToReserve.length; i++) {
            // [0] retrieve deposit vault
            vaultHash = sha256(
                abi.encode(
                    amountsToReserve[i],
                    depositVaults[vaultIndexesToReserve[i]].exchangeRate,
                    depositVaults[vaultIndexesToReserve[i]].btcPayoutLockingScript,
                    vaultHash
                )
            );

            // [1] ensure there is enough liquidity in this vault to reserve
            if (amountsToReserve[i] > depositVaults[vaultIndexesToReserve[i]].unreservedBalance) {
                revert NotEnoughLiquidity();
            }
        }

        // [6] overwrite expired reservations if any slots are available
        if (expiredSwapReservationIndexes.length > 0) {
            // [1] retrieve expired reservation
            SwapReservation storage swapReservationToOverwrite = swapReservations[expiredSwapReservationIndexes[0]];

            // [2] overwrite expired reservation
            swapReservationToOverwrite.state = ReservationState.Created;
            swapReservationToOverwrite.ethPayoutAddress = ethPayoutAddress;
            swapReservationToOverwrite.reservationTimestamp = uint32(block.timestamp);
            swapReservationToOverwrite.confirmationBlockHeight = 0;
            swapReservationToOverwrite.unlockTimestamp = 0;
            swapReservationToOverwrite.prepaidFeeAmount = int256(proverFee + releaserFee);
            swapReservationToOverwrite.totalSwapAmount = combinedAmountsToReserve;
            swapReservationToOverwrite.nonce = keccak256(
                abi.encode(ethPayoutAddress, block.timestamp, block.chainid, vaultHash, swapReservations.length) // TODO: fully audit nonce attack vector
            );
            swapReservationToOverwrite.vaultIndexes = vaultIndexesToReserve;
            swapReservationToOverwrite.amountsToReserve = amountsToReserve;
            swapReservationToOverwrite.lpReservationHash = vaultHash;
        }
        // otherwise push new reservation if no expired reservations slots are available
        else {
            swapReservations.push(
                SwapReservation({
                    state: ReservationState.Created,
                    ethPayoutAddress: ethPayoutAddress,
                    reservationTimestamp: uint32(block.timestamp),
                    confirmationBlockHeight: 0,
                    unlockTimestamp: 0,
                    totalSwapAmount: combinedAmountsToReserve,
                    prepaidFeeAmount: int256(proverFee + releaserFee),
                    nonce: keccak256(
                        abi.encode(ethPayoutAddress, block.timestamp, block.chainid, vaultHash, swapReservations.length)
                    ), // TODO: fully audit nonce attack vector
                    lpReservationHash: vaultHash,
                    vaultIndexes: vaultIndexesToReserve,
                    amountsToReserve: amountsToReserve
                })
            );
        }

        // update unreserved balances in deposit vaults
        for (uint i = 0; i < vaultIndexesToReserve.length; i++) {
            depositVaults[vaultIndexesToReserve[i]].unreservedBalance -= amountsToReserve[i];
        }

        // transfer fees from user to contract
        DEPOSIT_TOKEN.transferFrom(msg.sender, address(this), (proverFee + protocolFee + releaserFee));

        // transfer protocol fee
        DEPOSIT_TOKEN.transferFrom(address(this), protocolAddress, protocolFee);
    }

    function hashToFieldUpper(bytes32 data) internal pure returns (bytes32) {
        return bytes32(uint256(data) / 256);
    }

    function hashToFieldLower(bytes32 data) internal pure returns (bytes32) {
        return bytes32(uint256(data) & 0xFF);
    }

    struct ProofPublicInputs {
        bytes32 bitcoinTxId;
        bytes32 lpReservationHash;
        bytes32 orderNonce;
        uint64 expectedPayout;
        uint64 lpCount;
        bytes32 confirmationBlockHash;
        bytes32 proposedBlockHash;
        bytes32 safeBlockHash;
        bytes32 retargetBlockHash;
        uint64 safeBlockHeight;
        uint64 blockHeightDelta;
        bytes32[16] aggregation_object;
    }

    function buildProofPublicInputs(ProofPublicInputs memory inputs) public pure returns (bytes32[] memory) {
        bytes32[] memory publicInputs = new bytes32[](34);
        publicInputs[0] = hashToFieldUpper(inputs.bitcoinTxId);
        publicInputs[1] = hashToFieldLower(inputs.bitcoinTxId);
        publicInputs[2] = hashToFieldUpper(inputs.lpReservationHash);
        publicInputs[3] = hashToFieldLower(inputs.lpReservationHash);
        publicInputs[4] = hashToFieldUpper(inputs.orderNonce);
        publicInputs[5] = hashToFieldLower(inputs.orderNonce);
        publicInputs[8] = hashToFieldUpper(inputs.confirmationBlockHash);
        publicInputs[6] = bytes32(uint256(inputs.expectedPayout));
        publicInputs[7] = bytes32(uint256(inputs.lpCount));
        publicInputs[9] = hashToFieldLower(inputs.confirmationBlockHash);
        publicInputs[10] = hashToFieldUpper(inputs.proposedBlockHash);
        publicInputs[11] = hashToFieldLower(inputs.proposedBlockHash);
        publicInputs[12] = hashToFieldUpper(inputs.safeBlockHash);
        publicInputs[13] = hashToFieldLower(inputs.safeBlockHash);
        publicInputs[14] = hashToFieldUpper(inputs.retargetBlockHash);
        publicInputs[15] = hashToFieldLower(inputs.retargetBlockHash);
        publicInputs[16] = bytes32(uint256(inputs.safeBlockHeight));
        publicInputs[17] = bytes32(uint256(inputs.blockHeightDelta));
        for (uint i = 0; i < 16; i++) {
            publicInputs[18 + i] = inputs.aggregation_object[i];
        }
        return publicInputs;
    }

    function proposeTransactionProof(
        bytes32 bitcoinTxId,
        bytes32 confirmationBlockHash,
        bytes32 proposedBlockHash,
        bytes32 retargetBlockHash,
        uint32 safeBlockHeight,
        uint256 swapReservationIndex,
        uint64 proposedBlockHeight,
        bytes32[16] memory aggregation_object,
        bytes memory proof
    ) public {
        // [0] retrieve swap order
        SwapReservation storage swapReservation = swapReservations[swapReservationIndex];
        // build proof public inputs
        bytes32[] memory publicInputs = buildProofPublicInputs(
            ProofPublicInputs({
                bitcoinTxId: bitcoinTxId,
                lpReservationHash: swapReservation.lpReservationHash,
                orderNonce: swapReservation.nonce,
                expectedPayout: uint64(swapReservation.totalSwapAmount),
                lpCount: uint64(swapReservation.vaultIndexes.length),
                confirmationBlockHash: confirmationBlockHash,
                proposedBlockHash: proposedBlockHash,
                safeBlockHash: getBlockHash(safeBlockHeight),
                retargetBlockHash: retargetBlockHash,
                safeBlockHeight: safeBlockHeight,
                blockHeightDelta: proposedBlockHeight - safeBlockHeight,
                aggregation_object: aggregation_object
            })
        );
        /*
        console.log("ProofPublicInputs");
        for (uint i = 0; i < publicInputs.length; i++) {
            console.logBytes32(publicInputs[i]);
        }
        */

        // TODO: [1] verify proof (will revert if invalid)
        verifierContract.verify(proof, publicInputs);

        // [2] add verified block to block header storage contract
        addBlock(safeBlockHeight, proposedBlockHeight, proposedBlockHash);

        // [3] set confirmation block height in swap reservation
        swapReservation.confirmationBlockHeight = safeBlockHeight;

        // [4] mark swap order as unlocked
        swapReservation.state = ReservationState.Unlocked;

        // [5] payout prover (proving gas cost + proving reward)
        uint proverPayoutAmount = proverReward + ((PROOF_GAS_COST * block.basefee)); // TODO: inspect if base block fee is what we want
        DEPOSIT_TOKEN.transfer(msg.sender, proverPayoutAmount);

        // [6] subtract prover fee from prepaid fee amount
        swapReservation.prepaidFeeAmount -= int256(proverPayoutAmount);

        // [7] if prepaid fee amount is negative, subtract from total swap amount
        if (swapReservation.prepaidFeeAmount < 0) {
            swapReservation.totalSwapAmount += uint256(swapReservation.prepaidFeeAmount);

            // [8] reset prepaid fee amount to 0 so its not subtracted again during release
            swapReservation.prepaidFeeAmount = 0;
        }
    }

    function releaseLiquidity(uint256 swapReservationIndex) public {
        // [0] retrieve swap order
        SwapReservation storage swapReservation = swapReservations[swapReservationIndex];

        // [1] validate swap order is unlocked
        if (swapReservation.state != ReservationState.Unlocked) {
            revert ReservationNotUnlocked();
        }

        // [2] ensure 10 mins have passed since unlock timestamp (challenge period)
        if (block.timestamp - swapReservation.unlockTimestamp < CHALLENGE_PERIOD) {
            revert StillInChallengePeriod();
        }

        // [5] pay releaser (release cost + releaser reward)
        uint releaserPayoutAmount = releaserReward + ((RELEASE_GAS_COST * block.basefee));
        DEPOSIT_TOKEN.transfer(msg.sender, releaserPayoutAmount);

        // [6] subtract releaser fee from prepaid fee amount
        swapReservation.prepaidFeeAmount -= int256(releaserPayoutAmount);

        // [7] if prepaid fee amount is negative, subtract from total swap amount
        if (swapReservation.prepaidFeeAmount < 0) {
            swapReservation.totalSwapAmount += uint256(swapReservation.prepaidFeeAmount);

            // [8] reset prepaid fee amount to 0 (perhaps unnecessary)
            swapReservation.prepaidFeeAmount = 0;
        }

        // [9] release funds to buyers ETH payout address
        DEPOSIT_TOKEN.transfer(swapReservation.ethPayoutAddress, swapReservation.totalSwapAmount);

        // [10] mark swap reservation as completed
        swapReservation.state = ReservationState.Completed;
    }

    function updateRewards(uint256 newProverReward, uint256 newReleaserReward) public onlyOwner {
        // [0] update rewards in smallest token unit
        proverReward = newProverReward;
        releaserReward = newReleaserReward;
    }

    function updateProtocolAddress(address payable newProtocolAddress) public onlyOwner {
        // [0] update protocol address
        protocolAddress = newProtocolAddress;
    }

    function updateProtocolFee(uint8 newProtocolFeeBP) public onlyOwner {
        // [0] update protocol fee in basis points
        protocolFeeBP = newProtocolFeeBP;
    }

    //--------- READ FUNCTIONS ---------//

    function getDepositVault(uint256 depositIndex) public view returns (DepositVault memory) {
        return depositVaults[depositIndex];
    }

    function getLiquidityProvider(address lpAddress) public view returns (LiquidityProvider memory) {
        return liquidityProviders[lpAddress];
    }

    function getDepositVaultsLength() public view returns (uint256) {
        return depositVaults.length;
    }

    function getDepositVaultUnreservedBalance(uint256 depositIndex) public view returns (uint256) {
        return depositVaults[depositIndex].unreservedBalance;
    }

    function getReservation(uint256 reservationIndex) public view returns (SwapReservation memory) {
        return swapReservations[reservationIndex];
    }

    function getReservationLength() public view returns (uint256) {
        return swapReservations.length;
    }

    //--------- INTERNAL FUNCTIONS ---------//

    // unreserved balance + expired reservations
    function cleanUpDeadSwapReservations(uint256[] memory expiredReservationIndexes) internal {
        for (uint i = 0; i < expiredReservationIndexes.length; i++) {
            // [0] verify reservations are expired
            verifyExpiredReservations(expiredReservationIndexes);
            //console.log("expiredReservationIndexes[i]: ", expiredReservationIndexes[i]);

            // [1] extract reservation
            SwapReservation storage expiredSwapReservation = swapReservations[expiredReservationIndexes[i]];

            // [2] add expired reservation amounts to deposit vaults
            for (uint j = 0; j < expiredSwapReservation.vaultIndexes.length; j++) {
                DepositVault storage expiredVault = depositVaults[expiredSwapReservation.vaultIndexes[j]];
                expiredVault.unreservedBalance += expiredSwapReservation.amountsToReserve[j];
            }

            // [3] mark as expired
            expiredSwapReservation.state = ReservationState.ExpiredAndAddedBackToVault;
        }
    }

    function verifyExpiredReservations(uint256[] memory expiredReservationIndexes) internal view {
        for (uint i = 0; i < expiredReservationIndexes.length; i++) {
            if (
                block.timestamp - swapReservations[expiredReservationIndexes[i]].reservationTimestamp <
                RESERVATION_LOCKUP_PERIOD
            ) {
                revert ReservationNotExpired();
            }
        }
    }

    // --------- TESTING FUNCTIONS (TODO: DELETE) --------- //

    function emptyDepositVault(uint256 vaultIndex) public {
        DepositVault storage vault = depositVaults[vaultIndex];
        vault.initialBalance = 0;
        vault.unreservedBalance = 0;
        vault.exchangeRate = 0;
        vault.btcPayoutLockingScript = "";
    }
}

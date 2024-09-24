// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.2;

import {ISP1Verifier} from "@sp1-contracts/ISP1Verifier.sol";
import {BlockHashStorage} from "./BlockHashStorage.sol";
import {console} from "forge-std/console.sol";
import {Owned} from "../lib/solmate/src/auth/Owned.sol";

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
error OverwrittenProposedBlock();

contract RiftExchange is BlockHashStorage, Owned {
    uint32 public constant RESERVATION_LOCKUP_PERIOD = 8 hours;
    uint32 public constant CHALLENGE_PERIOD = 10 minutes;
    uint16 public constant MAX_DEPOSIT_OUTPUTS = 50;
    uint256 public constant PROOF_GAS_COST = 420_000; // TODO: update to real value
    uint256 public constant RELEASE_GAS_COST = 210_000; // TODO: update to real value
    uint256 public constant MIN_ORDER_GAS_MULTIPLIER = 2;
    uint8 public constant SAMPLING_SIZE = 10;
    uint256 constant SCALE = 1e18;
    uint256 constant BP_SCALE = 10000;
    bool public isDepositNewLiquidityPaused = false;

    IERC20 public immutable DEPOSIT_TOKEN;
    uint8 public immutable TOKEN_DECIMALS;
    uint256 private constant DECIMAL_PRECISION = 1e18;

    uint8 public protocolFeeBP = 10; // 10 bps = 0.1%
    uint256 public proverReward;
    uint256 public releaserReward;

    event LiquidityReserved(address indexed reserver, uint256 swapReservationIndex, bytes32 orderNonce);

    event SwapComplete(uint256 swapReservationIndex, bytes32 orderNonce);

    event ProofProposed(address indexed prover, uint256 swapReservationIndex, bytes32 orderNonce);

    struct LPunreservedBalanceChange {
        uint256 vaultIndex;
        uint256 value;
    }

    struct LiquidityProvider {
        uint256[] depositVaultIndexes;
    }

    struct DepositVault {
        address owner;
        uint256 initialBalance; // in token's smallest unit (wei, μUSDT, etc)
        uint256 unreservedBalance; // in token's smallest unit (wei, μUSDT, etc) - true balance = unreservedBalance + sum(ReservationState.Created && expired SwapReservations on this vault)
        uint256 withdrawnAmount; // in token's smallest unit (wei, μUSDT, etc)
        uint64 exchangeRate; // amount of token's smallest unit (buffered to 18 digits) per 1 sat
        bytes22 btcPayoutLockingScript;
    }

    enum ReservationState {
        None,
        Created,
        Unlocked,
        Completed,
        Expired
    }

    struct SwapReservation {
        address owner;
        uint32 confirmationBlockHeight;
        uint32 reservationTimestamp;
        uint32 unlockTimestamp; // timestamp when reservation was proven and unlocked
        ReservationState state;
        address ethPayoutAddress;
        bytes32 lpReservationHash;
        bytes32 nonce; // sent in bitcoin tx calldata from buyer -> lps to prevent replay attacks
        uint256 totalSatsInputInlcudingProxyFee; // in sats (including proxy wallet fee)
        uint256 totalSwapOutputAmount; // in token's smallest unit (wei, μUSDT, etc)
        int256 prepaidFeeAmount;
        uint256 proposedBlockHeight;
        bytes32 proposedBlockHash;
        uint256[] vaultIndexes;
        uint192[] amountsToReserve;
        uint64[] expectedSatsOutput;
    }

    mapping(address => LiquidityProvider) liquidityProviders; // lpAddress => LiquidityProvider
    SwapReservation[] public swapReservations;
    DepositVault[] public depositVaults;

    ISP1Verifier public immutable verifierContract;
    bytes32 public immutable circuitVerificationKey;
    address payable protocolAddress = payable(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);

    // --------- MODIFIERS --------- //

    modifier whenNotPaused() {
        require(!isDepositNewLiquidityPaused, "new deposits are paused");
        _;
    }

    modifier whenPaused() {
        require(isDepositNewLiquidityPaused, "new deposits are not paused");
        _;
    }

    //--------- CONSTRUCTOR ---------//

    constructor(
        uint256 initialCheckpointHeight,
        bytes32 initialBlockHash,
        bytes32 initialRetargetBlockHash,
<<<<<<< HEAD
        uint256  initialChainwork,
=======
        uint256 initialChainwork,
>>>>>>> 8d57778 (fee router)
        address verifierContractAddress,
        address depositTokenAddress,
        uint256 _proverReward,
        uint256 _releaserReward,
        address payable _protocolAddress,
        address _owner,
        bytes32 _circuitVerificationKey,
        uint8 minimumConfirmationDelta
    )
        BlockHashStorage(initialCheckpointHeight, initialChainwork, initialBlockHash, initialRetargetBlockHash,  minimumConfirmationDelta)
        Owned(_owner)
    {
        // [0] set verifier contract and deposit token
        circuitVerificationKey = _circuitVerificationKey;
        verifierContract = ISP1Verifier(verifierContractAddress);
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
        uint256 depositAmount,
        uint64 exchangeRate,
        bytes22 btcPayoutLockingScript,
        int256 vaultIndexToOverwrite,
        int256 vaultIndexWithSameExchangeRate
    ) public whenNotPaused {
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
            uint256 vaultIndex = uint256(vaultIndexWithSameExchangeRate);
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
            emptyVault.owner = msg.sender;
            emptyVault.initialBalance = depositAmount;
            emptyVault.unreservedBalance = depositAmount;
            emptyVault.withdrawnAmount = 0;
            emptyVault.exchangeRate = exchangeRate;
            emptyVault.btcPayoutLockingScript = btcPayoutLockingScript;
        }
        // [4] otherwise, create a new deposit vault if none are empty
        else {
            depositVaults.push(
                DepositVault({
                    owner: msg.sender,
                    initialBalance: depositAmount,
                    unreservedBalance: depositAmount,
                    withdrawnAmount: 0,
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
        vault.unreservedBalance -= amountToWithdraw;
        vault.withdrawnAmount += amountToWithdraw;

        DEPOSIT_TOKEN.transfer(msg.sender, amountToWithdraw);
    }

    function weiToSats(uint256 weiAmount, uint256 weiSatsExchangeRate) internal pure returns (uint256) {
        return weiAmount / weiSatsExchangeRate;
    }

    function satsToWei(uint256 satsAmount, uint256 weiSatsExchangeRate) internal pure returns (uint256) {
        return satsAmount * weiSatsExchangeRate;
    }

    function reserveLiquidity(
        uint256[] memory vaultIndexesToReserve,
        uint192[] memory amountsToReserve,
        address ethPayoutAddress,
        uint256 totalSatsInputInlcudingProxyFee,
        uint256[] memory expiredSwapReservationIndexes
    ) public {
        // [0] calculate total amount of ETH the user is attempting to reserve
        uint256 combinedAmountsToReserve = 0;
        uint256 combinedExpectedSatsOutput = 0;
        uint64[] memory expectedSatsOutputArray = new uint64[](vaultIndexesToReserve.length);

        for (uint256 i = 0; i < amountsToReserve.length; i++) {
            uint256 exchangeRate = depositVaults[vaultIndexesToReserve[i]].exchangeRate;
            combinedAmountsToReserve += amountsToReserve[i];
            uint256 bufferedAmountToReserve = bufferTo18Decimals(amountsToReserve[i], TOKEN_DECIMALS);
            uint256 expectedSatsOutput = bufferedAmountToReserve / exchangeRate;
            combinedExpectedSatsOutput += expectedSatsOutput;
            expectedSatsOutputArray[i] = uint64(expectedSatsOutput);
        }

        // [1] calculate fees
        uint256 protocolFee = (combinedAmountsToReserve * SCALE * protocolFeeBP) / (BP_SCALE * SCALE);
        // TODO multiply proof gas cost by block base fee converted to usdt from uniswap twap weth/usdt pool
        // + ((PROOF_GAS_COST * block.basefee) * MIN_ORDER_GAS_MULTIPLIER);
        uint256 proverFee = proverReward;
        // TODO multiply proof gas cost by block base fee converted to usdt from uniswap twap weth/usdt pool
        // + ((PROOF_GAS_COST * block.basefee) * MIN_ORDER_GAS_MULTIPLIER);
        uint256 releaserFee = releaserReward;
        // TODO: get historical priority fee and potentially add it ^

        // [3] verify proposed expired swap reservation indexes
        verifyExpiredReservations(expiredSwapReservationIndexes);

        // [4] clean up dead swap reservations
        cleanUpDeadSwapReservations(expiredSwapReservationIndexes);

        bytes32 vaultHash;

        // [5] check if there is enough liquidity in each deposit vaults to reserve
        for (uint256 i = 0; i < vaultIndexesToReserve.length; i++) {
            // [0] retrieve deposit vault
            vaultHash = sha256(
                abi.encode(
                    expectedSatsOutputArray[i],
                    depositVaults[vaultIndexesToReserve[i]].btcPayoutLockingScript,
                    vaultHash
                )
            );

            // [1] ensure there is enough liquidity in this vault to reserve
            if (amountsToReserve[i] > depositVaults[vaultIndexesToReserve[i]].unreservedBalance) {
                revert NotEnoughLiquidity();
            }
        }

        bytes32 orderNonce = keccak256(
            abi.encode(ethPayoutAddress, block.timestamp, block.chainid, vaultHash, swapReservations.length) // TODO_BEFORE_AUDIT: fully audit nonce attack vector
        );

        // [6] overwrite expired reservations if any slots are available
        if (expiredSwapReservationIndexes.length > 0) {
            // [1] retrieve expired reservation
            SwapReservation storage swapReservationToOverwrite = swapReservations[expiredSwapReservationIndexes[0]];

            // [2] overwrite expired reservation
            swapReservationToOverwrite.owner = msg.sender;
            swapReservationToOverwrite.state = ReservationState.Created;
            swapReservationToOverwrite.ethPayoutAddress = ethPayoutAddress;
            swapReservationToOverwrite.reservationTimestamp = uint32(block.timestamp);
            // swapReservationToOverwrite.confirmationBlockHeight = 0;
            swapReservationToOverwrite.unlockTimestamp = 0;
            swapReservationToOverwrite.prepaidFeeAmount = int256(proverFee + releaserFee);
            swapReservationToOverwrite.totalSwapOutputAmount = combinedAmountsToReserve;
            swapReservationToOverwrite.nonce = orderNonce;
            swapReservationToOverwrite.totalSatsInputInlcudingProxyFee = totalSatsInputInlcudingProxyFee;
            swapReservationToOverwrite.vaultIndexes = vaultIndexesToReserve;
            swapReservationToOverwrite.amountsToReserve = amountsToReserve;
            swapReservationToOverwrite.lpReservationHash = vaultHash;
            swapReservationToOverwrite.expectedSatsOutput = expectedSatsOutputArray;
        }
        // otherwise push new reservation if no expired reservations slots are available
        else {
            swapReservations.push(
                SwapReservation({
                    owner: msg.sender,
                    state: ReservationState.Created,
                    confirmationBlockHeight: 0,
                    ethPayoutAddress: ethPayoutAddress,
                    reservationTimestamp: uint32(block.timestamp),
                    unlockTimestamp: 0,
                    totalSwapOutputAmount: combinedAmountsToReserve,
                    prepaidFeeAmount: int256(proverFee + releaserFee),
                    nonce: orderNonce,
                    totalSatsInputInlcudingProxyFee: totalSatsInputInlcudingProxyFee,
                    proposedBlockHeight: 0,
                    proposedBlockHash: bytes32(0),
                    lpReservationHash: vaultHash,
                    vaultIndexes: vaultIndexesToReserve,
                    amountsToReserve: amountsToReserve,
                    expectedSatsOutput: expectedSatsOutputArray
                })
            );
        }

        // update unreserved balances in deposit vaults
        for (uint256 i = 0; i < vaultIndexesToReserve.length; i++) {
            depositVaults[vaultIndexesToReserve[i]].unreservedBalance -= amountsToReserve[i];
        }

        // transfer fees from user to contract
        DEPOSIT_TOKEN.transferFrom(msg.sender, address(this), (proverFee + protocolFee + releaserFee));

        // transfer protocol fee
        DEPOSIT_TOKEN.transfer(protocolAddress, protocolFee);

        emit LiquidityReserved(msg.sender, getReservationLength() - 1, orderNonce);
    }

    function hashToFieldUpper(bytes32 data) internal pure returns (bytes32) {
        return bytes32(uint256(data) / 256);
    }

    function hashToFieldLower(bytes32 data) internal pure returns (bytes32) {
        return bytes32(uint256(data) & 0xFF);
    }

    struct ProofPublicInputs {
        bytes32 natural_txid;
        bytes32 lp_reservation_hash;
        bytes32 order_nonce;
        uint64 lp_count;
        bytes32 retarget_block_hash;
        uint64 safe_block_height;
        uint64 safe_block_height_delta;
        uint64 confirmation_block_height_delta;
        uint256 confirmation_chainwork;
        uint64 retarget_block_height;
        bytes32[] block_hashes;
    }

    function buildProofPublicInputs(ProofPublicInputs memory inputs) public pure returns (bytes memory) {
        return abi.encode(inputs);
    }

    function proposeTransactionProof(
        uint256 swapReservationIndex,
        bytes32 bitcoinTxId,
        uint32 safeBlockHeight,
        uint64 proposedBlockHeight,
        uint64 confirmationBlockHeight,
        uint256 confirmationChainwork,
        bytes32[] memory blockHashes,
        bytes memory proof
    ) public {
        // [0] retrieve swap order
        SwapReservation storage swapReservation = swapReservations[swapReservationIndex];

        uint256 bufferedAmountsToReserve = 0;
        for (uint256 i = 0; i < swapReservation.amountsToReserve.length; i++) {
            uint256 bufferedAmount = bufferTo18Decimals(swapReservation.amountsToReserve[i], TOKEN_DECIMALS);
            uint256 exchangeRate = depositVaults[swapReservation.vaultIndexes[i]].exchangeRate;
            uint256 satsAmount = weiToSats(bufferedAmount, exchangeRate);
            bufferedAmountsToReserve += satsToWei(satsAmount, exchangeRate);
        }

        bytes memory publicInputs = buildProofPublicInputs(
            ProofPublicInputs({
                natural_txid: bitcoinTxId,
                lp_reservation_hash: swapReservation.lpReservationHash,
                order_nonce: swapReservation.nonce,
                lp_count: uint64(swapReservation.vaultIndexes.length),
                retarget_block_hash: getBlockHash(calculateRetargetHeight(proposedBlockHeight)),
                safe_block_height: safeBlockHeight,
                safe_block_height_delta: proposedBlockHeight - safeBlockHeight,
                confirmation_block_height_delta: confirmationBlockHeight - proposedBlockHeight,
                confirmation_chainwork: confirmationChainwork,
                retarget_block_height: calculateRetargetHeight(proposedBlockHeight),
                block_hashes: blockHashes
            })
        );

        // [1] verify proof (will revert if invalid)
        verifierContract.verifyProof(circuitVerificationKey, publicInputs, proof);

        // [2] add verified block to block header storage contract
        addBlock(
            safeBlockHeight,
            proposedBlockHeight,
            confirmationBlockHeight,
            confirmationChainwork,
            blockHashes,
            proposedBlockHeight - safeBlockHeight
        );

        // [3] Update swap reservation state
        swapReservation.state = ReservationState.Unlocked;
        swapReservation.unlockTimestamp = uint32(block.timestamp) + CHALLENGE_PERIOD;
        swapReservation.proposedBlockHeight = proposedBlockHeight;
        swapReservation.proposedBlockHash = blockHashes[proposedBlockHeight - safeBlockHeight - 1];

        // [4] payout prover (proving gas cost + proving reward)
        uint256 proverPayoutAmount = proverReward;
        DEPOSIT_TOKEN.transfer(msg.sender, proverPayoutAmount);

        // [6] if prepaid fee amount is negative, subtract from total swap amount
        if (swapReservation.prepaidFeeAmount < 0) {
            swapReservation.totalSwapOutputAmount += uint256(swapReservation.prepaidFeeAmount);

            // [7] reset prepaid fee amount to 0 so its not subtracted again during release
            swapReservation.prepaidFeeAmount = 0;
        }

        emit ProofProposed(msg.sender, swapReservationIndex, swapReservation.nonce);
    }

    function releaseLiquidity(uint256 swapReservationIndex) public {
        // [0] retrieve swap order
        SwapReservation storage swapReservation = swapReservations[swapReservationIndex];

        // [1] validate swap order is unlocked
        if (swapReservation.state != ReservationState.Unlocked) {
            revert ReservationNotUnlocked();
        }

        // [2] ensure 10 mins have passed since unlock timestamp (challenge period)
        if (block.timestamp < swapReservation.unlockTimestamp) {
            revert StillInChallengePeriod();
        }

        // ensure your block still matches the block hash storage contract
        if (getBlockHash(swapReservation.proposedBlockHeight) == swapReservation.proposedBlockHash) {
            revert OverwrittenProposedBlock();
        }

        // [5] pay releaser (release cost + releaser reward)
        uint releaserPayoutAmount = releaserReward;
        DEPOSIT_TOKEN.transfer(msg.sender, releaserPayoutAmount);

        // [6] subtract releaser fee from prepaid fee amount
        swapReservation.prepaidFeeAmount -= int256(releaserPayoutAmount);

        // [7] if prepaid fee amount is negative, subtract from total swap amount
        if (swapReservation.prepaidFeeAmount < 0) {
            swapReservation.totalSwapOutputAmount += uint256(swapReservation.prepaidFeeAmount);

            // [8] reset prepaid fee amount to 0 (perhaps unnecessary)
            swapReservation.prepaidFeeAmount = 0;
        }

        // [9] release funds to buyers ETH payout address
        DEPOSIT_TOKEN.transfer(swapReservation.ethPayoutAddress, swapReservation.totalSwapOutputAmount);

        // [10] mark swap reservation as completed
        swapReservation.state = ReservationState.Completed;

        emit SwapComplete(swapReservationIndex, swapReservation.nonce);
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

    function getAreDepositsPaused() public view returns (bool) {
        return isDepositNewLiquidityPaused;
    }

    //--------- INTERNAL FUNCTIONS ---------//

    // unreserved balance + expired reservations
    function cleanUpDeadSwapReservations(uint256[] memory expiredReservationIndexes) internal {
        for (uint256 i = 0; i < expiredReservationIndexes.length; i++) {
            // [0] verify reservations are expired
            verifyExpiredReservations(expiredReservationIndexes);

            // [1] extract reservation
            SwapReservation storage expiredSwapReservation = swapReservations[expiredReservationIndexes[i]];

            // [2] add expired reservation amounts to deposit vaults
            for (uint256 j = 0; j < expiredSwapReservation.vaultIndexes.length; j++) {
                DepositVault storage expiredVault = depositVaults[expiredSwapReservation.vaultIndexes[j]];
                expiredVault.unreservedBalance += expiredSwapReservation.amountsToReserve[j];
            }

            // [3] mark as expired
            expiredSwapReservation.state = ReservationState.Expired;
        }
    }

    function verifyExpiredReservations(uint256[] memory expiredReservationIndexes) internal view {
        for (uint256 i = 0; i < expiredReservationIndexes.length; i++) {
            if (
                block.timestamp - swapReservations[expiredReservationIndexes[i]].reservationTimestamp <
                RESERVATION_LOCKUP_PERIOD
            ) {
                revert ReservationNotExpired();
            }
        }
    }

    function unbufferFrom18Decimals(uint256 amount, uint8 tokenDecimals) internal pure returns (uint256) {
        if (tokenDecimals < 18) {
            return amount / (10 ** (18 - tokenDecimals));
        }
        return amount;
    }

    function bufferTo18Decimals(uint256 amount, uint8 tokenDecimals) internal pure returns (uint256) {
        if (tokenDecimals < 18) {
            return amount * (10 ** (18 - tokenDecimals));
        }
        return amount;
    }

    // --------- ONLY OWNER --------- //

    function pauseDepositNewLiquidity() external onlyOwner whenNotPaused {
        isDepositNewLiquidityPaused = true;
    }

    function unpauseDepositNewLiquidity() external onlyOwner whenPaused {
        isDepositNewLiquidityPaused = false;
    }

    function refundAllLPs(
        uint256 depositVaultStartIndex,
        uint256 depositVaultEndIndex,
        uint256[] memory expiredReservationIndexes
    ) external onlyOwner {
        require(depositVaultStartIndex < depositVaults.length, "Invalid start index");

        // clean up dead swap reservations to ensure unreserved balances are accurate (adding back expired reservations)
        cleanUpDeadSwapReservations(expiredReservationIndexes);

        if (depositVaultEndIndex > depositVaults.length) {
            depositVaultEndIndex = depositVaults.length;
        }

        for (uint256 i = depositVaultStartIndex; i < depositVaultEndIndex; i++) {
            DepositVault storage vault = depositVaults[i];
            uint256 refundAmount = vault.unreservedBalance;

            if (refundAmount > 0) {
                vault.unreservedBalance = 0;
                DEPOSIT_TOKEN.transfer(vault.owner, refundAmount);
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

    function setSwapReservationState(uint256 swapReservationIndex, ReservationState state) public {
        swapReservations[swapReservationIndex].state = state;
    }
}

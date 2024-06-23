// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.2;

import { UltraVerifier as TransactionInclusionPlonkVerification } from './verifiers/TransactionInclusionPlonkVerification.sol';
import { BlockHashStorage } from './BlockHashStorage.sol';
import { console } from 'forge-std/console.sol';

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    function balanceOf(address account) external view returns (uint256);
}

error DepositTooLow();
error DepositTooHigh();
error DepositFailed();
error exchangeRateZero();
error WithdrawFailed();
error LpDoesntExist();
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

abstract contract RiftExchange is BlockHeaderStorage {
    uint256 public constant RESERVATION_LOCKUP_PERIOD = 6 hours; // TODO: get longest 6 block confirmation time
    uint256 public constant CHALLENGE_PERIOD = 10 minutes;
    uint16 public constant MAX_DEPOSIT_OUTPUTS = 50;
    uint256 public constant PROOF_GAS_COST = 420_000;
    uint256 public constant RELEASE_GAS_COST = 210_000;
    uint256 public constant MIN_ORDER_GAS_MULTIPLIER = 2;
    uint8 public constant SAMPLING_SIZE = 10;
    uint256 public immutable MIN_DEPOSIT = 0.5 ether;
    uint256 public immutable MAX_DEPOSIT = 200_000 ether; // TODO: find out what the real max deposit is
    IERC20 public immutable DEPOSIT_TOKEN;

    // 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 - testing header storage contract address
    // 0x007ab3f410ceba1a111b100de2f76a8154b80126cda3f8cab47728d2f8cd0d6d - testing btc payout address

    uint8 public protocolFeeBP = 100; // 100 bp = 1%
    uint8 public treasuryFee = 0;
    uint256 public proverReward = 0.002 ether;
    uint256 public releaserReward = 0.0002 ether;

    struct LPunreservedBalanceChange {
        uint256 vaultIndex;
        uint256 value;
    }

    struct LiquidityProvider {
        uint256[] depositVaultIndexes;
        bytes32[] btcPayoutAddresses; // TODO: change to locking script
    }

    struct DepositVault {
        uint256 initialBalance;
        uint256 unreservedBalance; // true balance = unreservedBalance + sum(!completed && !dead && expired SwapReservations)
        uint256 btcExchangeRate; // amount of btc per 1 eth, in sats
        uint256 btcPayoutAddressIndex;
    }

    enum ReservationState {
        None,
        Created,
        Completed,
        Unlocked,
        Released,
        Expired
    }

    enum DepositToken {
        WETH,
        WBTC
    }

    struct SwapReservation {
        ReservationState state;
        address ethPayoutAddress;
        string btcSenderAddress;
        uint256 reservationTimestamp;
        uint256 confirmationBlockHeight;
        uint256 unlockTimestamp;
        bytes32 nonce; // sent in bitcoin tx calldata from buyer -> lps to prevent replay attacks
        uint256 totalSwapAmount;
        int256 prepaidFeeAmount;
        uint256[] vaultIndexes;
        uint256[] amountsToReserve;
    }

    mapping(address => LiquidityProvider) liquidityProviders; // lpAddress => LiquidityProvider
    SwapReservation[] public swapReservations;
    DepositVault[] public depositVaults;

    TransactionInclusionPlonkVerification public immutable verifierContract;
    address payable protocolAddress = payable(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);

    //--------- CONSTRUCTOR ---------//

    constructor(
        uint256 initialCheckpointHeight,
        bytes32 initialBlockHash,
        address verifierContractAddress,
        address depositTokenAddress,
        uint256 minDeposit,
        uint256 maxDeposit
    ) BlockHeaderStorage(initialCheckpointHeight, initialBlockHash) {
        verifierContract = TransactionInclusionPlonkVerification(verifierContractAddress);
        DEPOSIT_TOKEN = IERC20(depositTokenAddress);
        MIN_DEPOSIT = minDeposit;
        MAX_DEPOSIT = maxDeposit;
    }

    //--------- WRITE FUNCTIONS ---------//
    function depositLiquidity(
        bytes32 btcPayoutAddress,
        uint256 btcExchangeRate,
        int256 vaultIndexToOverwrite,
        uint256 depositAmount,
        uint256[] memory vaultIndexesWithSameExchangeRate
    ) public {
        // [0] validate deposit amount
        if (depositAmount < MIN_DEPOSIT) {
            revert DepositTooLow();
        } else if (depositAmount >= MAX_DEPOSIT) {
            revert DepositTooHigh();
        }

        // [2] validate btc exchange rate
        if (btcExchangeRate == 0) {
            revert exchangeRateZero();
        }

        // [3] create new liquidity provider if it doesn't exist
        if (liquidityProviders[msg.sender].btcPayoutAddresses.length == 0) {
            liquidityProviders[msg.sender] = LiquidityProvider({
                depositVaultIndexes: new uint256[](0),
                btcPayoutAddresses: new bytes32[](0)
            });
            liquidityProviders[msg.sender].btcPayoutAddresses.push(btcPayoutAddress);
        }

        // [4] merge liquidity into vaults with the same exchange rate
        if (vaultIndexesWithSameExchangeRate.length > 0) {
            for (uint i = 0; i < vaultIndexesWithSameExchangeRate.length; i++) {
                uint256 vaultIndex = vaultIndexesWithSameExchangeRate[i];
                DepositVault storage vault = depositVaults[vaultIndex];
                LiquidityProvider storage lp = liquidityProviders[msg.sender];
                if (
                    vault.btcExchangeRate == btcExchangeRate &&
                    (lp.btcPayoutAddresses[vault.btcPayoutAddressIndex] == btcPayoutAddress)
                ) {
                    vault.unreservedBalance += depositAmount;
                } else {
                    revert InvaidSameExchangeRatevaultIndex();
                }
            }
        }
        // [5] overwrite empty deposit vault
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
            emptyVault.btcExchangeRate = btcExchangeRate;
            emptyVault.btcPayoutAddressIndex = liquidityProviders[msg.sender].btcPayoutAddresses.length - 1;
        }
        // [6] otherwise, create a new deposit vault if none are empty
        else {
            depositVaults.push(
                DepositVault({
                    initialBalance: depositAmount,
                    unreservedBalance: depositAmount,
                    btcExchangeRate: btcExchangeRate,
                    btcPayoutAddressIndex: liquidityProviders[msg.sender].btcPayoutAddresses.length - 1
                })
            );
        }

        // [7] add deposit vault index to liquidity provider
        liquidityProviders[msg.sender].depositVaultIndexes.push(depositVaults.length - 1);

        // [8] transfer deposit token to contract
        DEPOSIT_TOKEN.transferFrom(msg.sender, address(this), depositAmount);
    }

    function updateExchangeRate(
        uint256 vaultIndex,
        uint256 newBtcExchangeRate,
        uint256[] memory expiredReservationIndexes
    ) public {
        // [0] validate new exchange rate
        if (newBtcExchangeRate == 0) {
            revert InvalidVaultUpdate();
        }

        // [1] retrieve deposit vault
        DepositVault storage vault = depositVaults[vaultIndex];

        // cleanup dead swap reservations
        cleanUpDeadSwapReservations(expiredReservationIndexes);

        // [3] ensure no reservations are active by checking if actual available balance is equal to initial balance
        if (vault.unreservedBalance != vault.initialBalance) {
            revert InvalidUpdateWithActiveReservations();
        }

        // [4] update exchange rate
        vault.btcExchangeRate = newBtcExchangeRate;
    }

    function withdrawLiquidity(uint256 vaultIndex, uint256 amountToWithdraw, uint256[] memory expiredReservationIndexes) public {
        // [0] validate vault index
        if (vaultIndex >= depositVaults.length) {
            revert InvalidVaultIndex();
        }

        // [1] retrieve the vault
        DepositVault storage vault = depositVaults[vaultIndex];

        // clean up dead swap reservations
        cleanUpDeadSwapReservations(expiredReservationIndexes);

        // [2] validate amount to withdraw
        if (amountToWithdraw == 0 || amountToWithdraw > vault.unreservedBalance) {
            revert WithdrawalAmountError();
        }

        // [3] withdraw funds to LP
        vault.unreservedBalance -= amountToWithdraw;
        DEPOSIT_TOKEN.transferFrom(address(this), msg.sender, amountToWithdraw);
    }

    function reserveLiquidity(
        uint256[] memory vaultIndexesToReserve,
        uint256[] memory amountsToReserve,
        uint256 totalSwapAmount, // TODO: update this to be and check whats good
        address ethPayoutAddress,
        string memory btcSenderAddress,
        uint256[] memory expiredSwapReservationIndexes
    ) public payable {
        // [0] calculate total amount of ETH the user is attempting to reserve
        uint256 combinedAmountsToReserve = 0;
        for (uint i = 0; i < amountsToReserve.length; i++) {
            combinedAmountsToReserve += amountsToReserve[i];
        }

        // ensure combined amounts to reserve is equal to total swap amount
        if (combinedAmountsToReserve != totalSwapAmount) {
            revert InvalidOrder();
        }

        // [1] calculate fees
        uint protocolFee = (totalSwapAmount * (protocolFeeBP / 10_000));
        uint proverFee = proverReward + ((PROOF_GAS_COST * block.basefee) * MIN_ORDER_GAS_MULTIPLIER);
        uint releaserFee = releaserReward + ((RELEASE_GAS_COST * block.basefee) * MIN_ORDER_GAS_MULTIPLIER);
        // TODO: get historical priority fee and potentially add it ^

        // [1] verify total swap amount is enough to cover fees
        if (totalSwapAmount < (proverFee + protocolFee + releaserFee)) {
            revert ReservationAmountTooLow();
        }

        // [3] verify proposed expired swap reservation indexes
        verifyExpiredReservations(expiredSwapReservationIndexes);

        // [4] clean up dead swap reservations
        cleanUpDeadSwapReservations(expiredSwapReservationIndexes);

        // [5] check if there is enough liquidity in each deposit vaults to reserve
        for (uint i = 0; i < vaultIndexesToReserve.length; i++) {
            // [0] retrieve deposit vault
            uint256 amountToReserve = amountsToReserve[i];
            DepositVault storage vault = depositVaults[vaultIndexesToReserve[i]];

            // [1] ensure there is enough liquidity in this vault to reserve
            if (amountToReserve > vault.unreservedBalance) {
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
            swapReservationToOverwrite.btcSenderAddress = btcSenderAddress;
            swapReservationToOverwrite.reservationTimestamp = block.timestamp;
            swapReservationToOverwrite.confirmationBlockHeight = 0;
            swapReservationToOverwrite.unlockTimestamp = 0;
            swapReservationToOverwrite.prepaidFeeAmount = int256(proverFee + releaserFee);
            swapReservationToOverwrite.totalSwapAmount = totalSwapAmount;
            swapReservationToOverwrite.nonce = keccak256(
                abi.encode(ethPayoutAddress, btcSenderAddress, block.timestamp, block.chainid)
            );
            swapReservationToOverwrite.vaultIndexes = vaultIndexesToReserve;
            swapReservationToOverwrite.amountsToReserve = amountsToReserve;
        }
        // otherwise push new reservation if no expired reservations slots are available
        else {
            swapReservations.push(
                SwapReservation({
                    state: ReservationState.Created,
                    ethPayoutAddress: ethPayoutAddress,
                    btcSenderAddress: btcSenderAddress,
                    reservationTimestamp: block.timestamp,
                    confirmationBlockHeight: 0,
                    unlockTimestamp: 0,
                    totalSwapAmount: totalSwapAmount,
                    prepaidFeeAmount: int256(proverFee + releaserFee),
                    nonce: keccak256(abi.encode(ethPayoutAddress, btcSenderAddress, block.timestamp, block.chainid)),
                    vaultIndexes: vaultIndexesToReserve,
                    amountsToReserve: amountsToReserve
                })
            );
        }

        // transfer from user to contract
        DEPOSIT_TOKEN.transferFrom(msg.sender, address(this), totalSwapAmount); // TODO we only need to take 1% + fees not totalSwapAmount

        // transfer protocol fee
        DEPOSIT_TOKEN.transferFrom(msg.sender, protocolAddress, protocolFee);
    }

    function unlockLiquidity(
        uint256 swapReservationIndex,
        bytes32 btcBlockHash,
        uint256 blockCheckpointHeight,
        bytes32 confirmationBlockHash, // 5 blocks ahead of blockCheckpointHeight + block delta
        uint256 confirmationBlockHeightDelta, // delta from blockCheckpointHeight
        bytes memory proof
    ) public {
        // [0] retrieve swap order
        SwapReservation storage swapReservation = swapReservations[swapReservationIndex];

        // TODO: [1] verify proof (will revert if invalid)
        // verifierContract.verify(proof, publicInputs, ...);

        // [2] add block to block header storage contract
        addBlock(blockCheckpointHeight, confirmationBlockHeightDelta, confirmationBlockHash);

        // [3] set confirmation block height in swap reservation
        swapReservation.confirmationBlockHeight = blockCheckpointHeight;

        // [4] mark swap order as unlocked
        swapReservation.state = ReservationState.Unlocked;

        // [5] payout prover (proving cost + proving reward)
        uint proverFee = proverReward + ((PROOF_GAS_COST * block.basefee));
        (bool proverPaymentSuccess, ) = msg.sender.call{ value: proverFee }('');
        if (!proverPaymentSuccess) {
            revert WithdrawFailed();
        }

        // [6] subtract prover fee from prepaid fee amount
        swapReservation.prepaidFeeAmount -= int256(proverFee);

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

        // [5] payout releaser (release cost + releaser reward)
        uint releaserFee = releaserReward + ((RELEASE_GAS_COST * block.basefee));
        (bool releaserPaymentSuccess, ) = msg.sender.call{ value: releaserFee }('');
        if (!releaserPaymentSuccess) {
            revert WithdrawFailed();
        }

        // [6] subtract prover fee from prepaid fee amount
        swapReservation.prepaidFeeAmount -= int256(releaserFee);

        // [7] if prepaid fee amount is negative, subtract from total swap amount
        if (swapReservation.prepaidFeeAmount < 0) {
            swapReservation.totalSwapAmount += uint256(swapReservation.prepaidFeeAmount);
        }

        // [x] release funds to buyers ETH payout address
        (bool payoutSuccess, ) = swapReservation.ethPayoutAddress.call{ value: swapReservation.totalSwapAmount }('');
        if (!payoutSuccess) {
            revert WithdrawFailed();
        }
    }

    //--------- READ FUNCTIONS ---------//

    function getDepositVault(uint256 depositIndex) public view returns (DepositVault memory) {
        return depositVaults[depositIndex];
    }

    function getDepositVaultsLength() public view returns (uint256) {
        return depositVaults.length;
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
            verifyExpiredReservations(expiredReservationIndexes);
            console.log('expiredReservationIndexes[i]: ', expiredReservationIndexes[i]);

            SwapReservation storage expiredSwapReservation = swapReservations[expiredReservationIndexes[i]];

            expiredSwapReservation.state = ReservationState.Expired;

            // add expired reservation amounts to deposit vaults
            for (uint j = 0; j < expiredSwapReservation.vaultIndexes.length; j++) {
                DepositVault storage expiredVault = depositVaults[expiredSwapReservation.vaultIndexes[j]];
                expiredVault.unreservedBalance += expiredSwapReservation.amountsToReserve[j];
            }
        }
    }

    function verifyExpiredReservations(uint256[] memory expiredReservationIndexes) internal view {
        for (uint i = 0; i < expiredReservationIndexes.length; i++) {
            if (
                block.timestamp - swapReservations[expiredReservationIndexes[i]].reservationTimestamp < RESERVATION_LOCKUP_PERIOD
            ) {
                revert ReservationNotExpired();
            }
        }
    }

    // --------- TESTING FUNCTIONS (DELETE) --------- //

    function emptyDepositVault(uint256 vaultIndex) public {
        DepositVault storage vault = depositVaults[vaultIndex];
        vault.initialBalance = 0;
        vault.unreservedBalance = 0;
        vault.btcExchangeRate = 0;
        vault.btcPayoutAddressIndex = 0;
    }
}

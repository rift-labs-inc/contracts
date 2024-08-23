// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {RiftExchange} from "../src/RiftExchange.sol";
import {WETH} from "solmate/tokens/WETH.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

// Mock USDT contract
contract MockUSDT is ERC20 {
    constructor() ERC20("Tether USD", "USDT", 6) {} // USDT has 6 decimals

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract RiftExchangeTest is Test {
    RiftExchange riftExchange;
    MockUSDT usdt;
    address testAddress = address(0x69696969);
    address lp1 = address(0x69);
    address lp2 = address(0x69420);
    address lp3 = address(0x6969);
    address buyer1 = address(0x111111);
    address buyer2 = address(0x222222);
    address buyer3 = address(0x333333);

    bytes4 constant DEPOSIT_TOO_LOW = bytes4(keccak256("DepositTooLow()"));
    bytes4 constant INVALID_VAULT_UPDATE = bytes4(keccak256("InvalidVaultUpdate()"));
    bytes4 constant NOT_VAULT_OWNER = bytes4(keccak256("NotVaultOwner()"));
    bytes4 constant DEPOSIT_TOO_HIGH = bytes4(keccak256("DepositTooHigh()"));
    bytes4 constant INVALID_BTC_PAYOUT_ADDRESS = bytes4(keccak256("InvalidBitcoinAddress()"));
    bytes4 constant RESERVATION_FEE_TOO_LOW = bytes4(keccak256("ReservationFeeTooLow()"));
    bytes4 constant INVALID_UPDATE_WITH_ACTIVE_RESERVATIONS =
        bytes4(keccak256("InvalidUpdateWithActiveReservations()"));
    bytes4 constant NOT_ENOUGH_LIQUIDITY = bytes4(keccak256("NotEnoughLiquidity()"));
    bytes4 constant RESERVATION_AMOUNT_TOO_LOW = bytes4(keccak256("ReservationAmountTooLow()"));
    bytes4 constant RESERVATION_EXPIRED = bytes4(keccak256("ReservationExpired()"));

    function setUp() public {
        bytes32 initialBlockHash = bytes32(0x00000000000000000002da2dfb440c17bb561ff83ec1e88cd9433e062e5388bc);
        uint256 initialCheckpointHeight = 845690;
        address verifierContractAddress = address(0x123);

        usdt = new MockUSDT();

        uint256 proverReward = 5 * 10 ** 6; // 5 USDT
        uint256 releaserReward = 2 * 10 ** 6; // 2 USDT
        address payable protocolAddress = payable(address(this));

        riftExchange = new RiftExchange(
            initialCheckpointHeight,
            initialBlockHash,
            verifierContractAddress,
            address(usdt),
            proverReward,
            releaserReward,
            protocolAddress,
            protocolAddress
        );
    }

    //--------- DEPOSIT TESTS ---------//
    function testDepositLiquidity() public {
        deal(address(usdt), testAddress, 1_000_000_000_000_000e6); // Mint USDT (6 decimals)
        vm.startPrank(testAddress);

        console.log("Starting deposit liquidity...");
        console.log("testaddress USDT balance: ", usdt.balanceOf(testAddress));

        bytes22 btcPayoutLockingScript = 0x0014841b80d2cc75f5345c482af96294d04fdd66b2b7;
        uint64 exchangeRate = 2557666;
        uint256 depositAmount = 1_000_000_000_000_000e6; // 1b USDT

        usdt.approve(address(riftExchange), depositAmount);

        uint256 gasBefore = gasleft();
        riftExchange.depositLiquidity(depositAmount, exchangeRate, btcPayoutLockingScript, -1, -1);
        uint256 gasUsed = gasBefore - gasleft();
        console.log("Gas used for deposit:", gasUsed);

        uint256 vaultIndex = riftExchange.getDepositVaultsLength() - 1;
        RiftExchange.DepositVault memory deposit = riftExchange.getDepositVault(vaultIndex);

        assertEq(deposit.initialBalance, depositAmount, "Deposit amount mismatch");
        assertEq(deposit.exchangeRate, exchangeRate, "BTC exchange rate mismatch");

        vm.stopPrank();
    }

    function testDepositOverwrite() public {
        // setup
        deal(address(usdt), testAddress, 1_000_000_000_000_000e6);
        vm.startPrank(testAddress);

        // initial deposit
        bytes22 btcPayoutLockingScript = 0x0014841b80d2cc75f5345c482af96294d04fdd66b2b7;
        uint64 exchangeRate = 2557666;
        uint256 initialDepositAmount = 1_000_000e6; // 1m USDT
        usdt.approve(address(riftExchange), 1_000_000_000_000_000e6);

        riftExchange.depositLiquidity(initialDepositAmount, exchangeRate, btcPayoutLockingScript, -1, -1);

        // empty deposit vault
        console.log("vault at index 0 before overwrite: ", riftExchange.getDepositVault(0).initialBalance);
        riftExchange.emptyDepositVault(0);

        // overwrite deposit vault
        uint256 newDepositAmount = 100e6; // 100 USDT
        uint64 newBtcExchangeRate = 75;
        int256 vaultIndexToOverwrite = 0;

        console.log("TOTAL DEPOSITS BEFORE OVERWRITE", riftExchange.getDepositVaultsLength());

        riftExchange.depositLiquidity(
            newDepositAmount,
            newBtcExchangeRate,
            btcPayoutLockingScript,
            vaultIndexToOverwrite, // overwriting the initial deposit
            -1
        );
        console.log("TOTAL DEPOSITS AFTER OVERWRITE", riftExchange.getDepositVaultsLength());

        // assertions
        RiftExchange.DepositVault memory overwrittenDeposit = riftExchange.getDepositVault(
            uint256(vaultIndexToOverwrite)
        );

        assertEq(
            overwrittenDeposit.initialBalance,
            newDepositAmount,
            "Overwritten deposit amount should match new deposit amount"
        );
        assertEq(
            overwrittenDeposit.exchangeRate,
            newBtcExchangeRate,
            "Overwritten BTC exchange rate should match new rate"
        );

        vm.stopPrank();
    }

    function testDepositMultiple() public {
        uint256 totalAmount = 1_000_000_000_000_000e6; // 1 quadrillion USDT
        deal(address(usdt), testAddress, totalAmount);
        vm.startPrank(testAddress);

        usdt.approve(address(riftExchange), totalAmount);

        uint256 firstDepositGasCost;
        uint256 lastDepositGasCost;

        bytes22 btcPayoutLockingScript = 0x0014841b80d2cc75f5345c482af96294d04fdd66b2b7;
        uint64 exchangeRate = 2557666;
        uint256 depositAmount = 1_000_000e6; // 1 million USDT per deposit
        uint256 totalGasUsed = 0;

        // create multiple deposits
        uint256 numDeposits = 1000;
        for (uint256 i = 0; i < numDeposits; i++) {
            uint256 gasBefore = gasleft();

            riftExchange.depositLiquidity(depositAmount, exchangeRate, btcPayoutLockingScript, -1, -1);

            uint256 gasUsed = gasBefore - gasleft(); // Calculate gas used for the operation
            totalGasUsed += gasUsed; // Accumulate total gas used

            if (i == 0) {
                firstDepositGasCost = gasUsed; // Store gas cost of the first deposit
            }
            if (i == numDeposits - 1) {
                lastDepositGasCost = gasUsed; // Store gas cost of the last deposit
            }
        }

        uint256 averageGasCost = totalGasUsed / numDeposits; // Calculate the average gas cost

        vm.stopPrank();

        // Output the gas cost for first and last deposits
        console.log("Gas cost for the first deposit:", firstDepositGasCost);
        console.log("Gas cost for the last deposit:", lastDepositGasCost);
        console.log("Average gas cost:", averageGasCost);

        // Assert that all deposits were successful
        assertEq(riftExchange.getDepositVaultsLength(), numDeposits, "Number of deposits mismatch");

        // Check the total amount deposited
        uint256 totalDeposited = depositAmount * numDeposits;
        assertLe(totalDeposited, totalAmount, "Total deposited amount exceeds initial balance");

        // check the balance of a few random vaults
        for (uint256 i = 0; i < 5; i++) {
            uint256 randomIndex = uint256(keccak256(abi.encodePacked(block.timestamp, i))) % numDeposits;
            RiftExchange.DepositVault memory vault = riftExchange.getDepositVault(randomIndex);
            assertEq(vault.initialBalance, depositAmount, "Deposit amount in vault mismatch");
        }
    }

    function testDepositUpdateExchangeRate() public {
        // setup
        uint256 totalAmount = 1_000_000_000e6; // 1 billion USDT
        deal(address(usdt), testAddress, totalAmount);
        vm.startPrank(testAddress);
        usdt.approve(address(riftExchange), totalAmount);

        bytes22 btcPayoutLockingScript = 0x0014841b80d2cc75f5345c482af96294d04fdd66b2b7;
        uint64 initialBtcExchangeRate = 69;
        uint256 depositAmount = 100_000_000e6; // 100 million USDT

        // create initial deposit
        riftExchange.depositLiquidity(
            depositAmount,
            initialBtcExchangeRate,
            btcPayoutLockingScript,
            -1, // no vault index to overwrite initially
            -1 // no vault index with same exchange rate
        );

        // update the BTC exchange rate
        uint64 newBtcExchangeRate = 75;
        console.log("Updating BTC exchange rate from", initialBtcExchangeRate, "to", newBtcExchangeRate);
        uint256[] memory empty = new uint256[](0);
        riftExchange.updateExchangeRate(0, 0, newBtcExchangeRate, empty);
        console.log("NEW BTC EXCHANGE RATE:", riftExchange.getDepositVault(0).exchangeRate);

        // fetch the updated deposit and verify the new exchange rate
        RiftExchange.DepositVault memory updatedDeposit = riftExchange.getDepositVault(0);
        assertEq(
            updatedDeposit.exchangeRate,
            newBtcExchangeRate,
            "BTC exchange rate should be updated to the new value"
        );

        // Verify that the deposit amount remains unchanged
        assertEq(
            updatedDeposit.initialBalance,
            depositAmount,
            "Deposit amount should remain unchanged after exchange rate update"
        );

        vm.stopPrank();
    }

    //--------- RESERVATION TESTS ---------//

    function testReserveLiquidity() public {
        // setup
        uint256 totalAmount = 1_000_000_000e6; // 1 billion USDT
        deal(address(usdt), testAddress, totalAmount);
        vm.startPrank(testAddress);
        usdt.approve(address(riftExchange), totalAmount);
        bytes22 btcPayoutLockingScript = 0x0014841b80d2cc75f5345c482af96294d04fdd66b2b7;
        uint64 exchangeRate = 69;
        uint192 depositAmount = 500_000_000e6; // 500 million USDT

        // deposit liquidity
        riftExchange.depositLiquidity(
            depositAmount,
            exchangeRate,
            btcPayoutLockingScript,
            -1, // no vault index to overwrite
            -1 // no vault index with same exchange rate
        );

        // check how much is available in the vault
        uint256 vaultBalance = riftExchange.getDepositVaultUnreservedBalance(0);
        console.log("Vault balance:", vaultBalance);

        // setup for reservation
        uint256[] memory vaultIndexesToReserve = new uint256[](1);
        vaultIndexesToReserve[0] = 0;
        uint192[] memory amountsToReserve = new uint192[](1);
        amountsToReserve[0] = 100_000_000e6; // 100 million USDT
        address ethPayoutAddress = address(0x123); // Example ETH payout address
        uint256[] memory empty = new uint256[](0);

        // Approve additional USDT for fees
        uint256 additionalApproval = 1_000_000e6; // 1 million USDT for fees
        usdt.approve(address(riftExchange), uint256(amountsToReserve[0]) + additionalApproval);

        console.log("Amount trying to reserve:", amountsToReserve[0]);

        uint256 gasBefore = gasleft();
        riftExchange.reserveLiquidity(vaultIndexesToReserve, amountsToReserve, ethPayoutAddress, empty);
        uint256 gasUsed = gasBefore - gasleft();
        console.log("Gas used for reservation:", gasUsed);

        // fetch reservation to validate
        RiftExchange.SwapReservation memory reservation = riftExchange.getReservation(0);

        // assertions
        assertEq(reservation.ethPayoutAddress, ethPayoutAddress, "ETH payout address should match");
        assertEq(reservation.totalSwapAmount, uint256(amountsToReserve[0]), "Total swap amount should match");

        // validate balances and state changes
        uint256 remainingBalance = riftExchange.getDepositVaultUnreservedBalance(0);

        console.log("Remaining balance:", remainingBalance);
        assertEq(
            remainingBalance,
            uint256(depositAmount) - uint256(amountsToReserve[0]),
            "Vault balance should decrease by the reserved amount"
        );

        vm.stopPrank();
    }

    function testReserveMultipleLiquidity() public {
        // setup
        uint256 totalAmount = 1_000_000_000e6; // 1 billion USDT
        deal(address(usdt), testAddress, totalAmount);
        vm.startPrank(testAddress);
        usdt.approve(address(riftExchange), totalAmount);
        bytes22 btcPayoutLockingScript = 0x0014841b80d2cc75f5345c482af96294d04fdd66b2b7;
        uint64 exchangeRate = 69;
        uint192 depositAmount = 500_000_000e6; // 500 million USDT

        // deposit liquidity
        riftExchange.depositLiquidity(
            depositAmount,
            exchangeRate,
            btcPayoutLockingScript,
            -1, // no vault index to overwrite
            -1 // no vault index with same exchange rate
        );

        uint256[] memory vaultIndexesToReserve = new uint256[](1);
        vaultIndexesToReserve[0] = 0;
        uint192[] memory amountsToReserve = new uint192[](1);
        amountsToReserve[0] = 10_000_000e6; // 10 million USDT
        uint256[] memory empty = new uint256[](0);

        // Approve additional USDT for fees
        uint256 additionalApproval = 1_000_000e6; // 1 million USDT for fees
        usdt.approve(address(riftExchange), uint256(amountsToReserve[0]) * 10 + additionalApproval);

        uint256 gasFirst;
        uint256 gasLast;
        uint256 totalGasUsed = 0;
        uint256 numReservations = 10;

        for (uint i = 0; i < numReservations; i++) {
            uint256 gasBefore = gasleft();
            riftExchange.reserveLiquidity(vaultIndexesToReserve, amountsToReserve, testAddress, empty);
            uint256 gasUsed = gasBefore - gasleft();
            totalGasUsed += gasUsed;

            if (i == 0) {
                gasFirst = gasUsed;
            } else if (i == numReservations - 1) {
                gasLast = gasUsed;
            }
        }

        uint256 averageGas = totalGasUsed / numReservations;

        console.log("First reservation gas used:", gasFirst);
        console.log("Last reservation gas used:", gasLast);
        console.log("Average gas used for reservations:", averageGas);

        // validate balances and state changes
        uint256 remainingBalance = riftExchange.getDepositVaultUnreservedBalance(0);

        console.log("Remaining balance:", remainingBalance);
        assertEq(
            remainingBalance,
            uint256(depositAmount) - (uint256(amountsToReserve[0]) * numReservations),
            "Vault balance should decrease by the total reserved amount"
        );

        vm.stopPrank();
    }

    function testReservationWithVaryingVaults() public {
        // setup
        uint256 totalAmount = 1_000_000_000e6; // 1 billion USDT
        deal(address(usdt), testAddress, totalAmount);
        vm.startPrank(testAddress);
        usdt.approve(address(riftExchange), totalAmount * 2);

        uint256 maxVaults = 100;
        uint192 depositAmount = 5_000_000e6; // 5 million USDT
        uint64 exchangeRate = 69;
        bytes22 btcPayoutLockingScript = 0x0014841b80d2cc75f5345c482af96294d04fdd66b2b7;

        // create multiple vaults
        for (uint256 i = 0; i < maxVaults; i++) {
            riftExchange.depositLiquidity(depositAmount, exchangeRate, btcPayoutLockingScript, -1, -1);
        }

        // reserve liquidity from varying vaults
        for (uint256 numVaults = 1; numVaults <= maxVaults; numVaults++) {
            uint256[] memory vaultIndexesToReserve = new uint256[](numVaults);
            uint192[] memory amountsToReserve = new uint192[](numVaults);

            for (uint256 j = 0; j < numVaults; j++) {
                vaultIndexesToReserve[j] = j;
                amountsToReserve[j] = 100e6; // 100 USDT
            }

            // Increase approval to account for fees
            uint256 totalReservation = 110_000e6 * numVaults; // 110,000 USDT per vault (including fees)
            usdt.approve(address(riftExchange), totalReservation);

            uint256[] memory emptyExpiredReservations = new uint256[](0);

            uint256 gasBefore = gasleft();
            riftExchange.reserveLiquidity(
                vaultIndexesToReserve,
                amountsToReserve,
                testAddress,
                emptyExpiredReservations
            );
            uint256 gasUsed = gasBefore - gasleft();
            console.log("Gas used for reserving from", numVaults, "vaults:", gasUsed);
        }

        vm.stopPrank();
    }

    function testReservationOverwriting() public {
        // setup
        uint256 totalAmount = 10_000_000e6; // 10 million USDT
        deal(address(usdt), testAddress, totalAmount);
        vm.startPrank(testAddress);
        usdt.approve(address(riftExchange), totalAmount);

        // deposit liquidity
        bytes22 btcPayoutLockingScript = 0x0014841b80d2cc75f5345c482af96294d04fdd66b2b7;
        uint64 exchangeRate = 69;
        uint192 depositAmount = 5_000_000e6; // 5 million USDT

        riftExchange.depositLiquidity(depositAmount, exchangeRate, btcPayoutLockingScript, -1, -1);

        // initial reserve liquidity
        uint256[] memory vaultIndexesToReserve = new uint256[](1);
        vaultIndexesToReserve[0] = 0;
        uint192[] memory amountsToReserve = new uint192[](1);
        amountsToReserve[0] = 1_000_000e6; // 1 million USDT
        uint256[] memory empty = new uint256[](0);

        riftExchange.reserveLiquidity(vaultIndexesToReserve, amountsToReserve, testAddress, empty);

        // simulate reservation expiration
        vm.warp(block.timestamp + 8 hours + 1);
        uint256[] memory expiredSwapReservationIndexes = new uint256[](1);
        expiredSwapReservationIndexes[0] = 0;

        // overwrite reservation with new parameters
        address newEthPayoutAddress = address(0x456);
        riftExchange.reserveLiquidity(
            vaultIndexesToReserve,
            amountsToReserve,
            newEthPayoutAddress,
            expiredSwapReservationIndexes
        );

        // Verify the reservation overwrite
        RiftExchange.SwapReservation memory overwrittenReservation = riftExchange.getReservation(0);
        assertEq(overwrittenReservation.ethPayoutAddress, newEthPayoutAddress, "ETH payout address should match");
        assertEq(overwrittenReservation.totalSwapAmount, uint256(amountsToReserve[0]), "Reserved amount should match");

        vm.stopPrank();
    }

    //--------- WITHDRAW TESTS ---------//

    function testWithdrawLiquidity() public {
        // setup
        uint256 totalAmount = 5_000_000e6; // 5 million USDT
        deal(address(usdt), testAddress, totalAmount);
        vm.startPrank(testAddress);
        usdt.approve(address(riftExchange), totalAmount);

        // [0] initial deposit
        uint192 depositAmount = 5_000_000e6; // 5 million USDT
        bytes22 btcPayoutLockingScript = 0x0014841b80d2cc75f5345c482af96294d04fdd66b2b7;
        uint64 exchangeRate = 50;
        riftExchange.depositLiquidity(depositAmount, exchangeRate, btcPayoutLockingScript, -1, -1);

        // Record initial balance
        uint256 initialBalance = usdt.balanceOf(testAddress);

        // [1] withdraw some of the liquidity
        uint256[] memory empty = new uint256[](0);
        uint192 withdrawAmount = 2_000_000e6; // 2 million USDT
        riftExchange.withdrawLiquidity(0, 0, withdrawAmount, empty);

        // [2] check if the balance has decreased correctly
        RiftExchange.DepositVault memory depositAfterWithdrawal = riftExchange.getDepositVault(0);
        uint256 expectedRemaining = uint256(depositAmount) - uint256(withdrawAmount);
        assertEq(
            depositAfterWithdrawal.unreservedBalance,
            expectedRemaining,
            "Remaining deposit should match expected amount after withdrawal"
        );

        // [3] check if the funds reached the LP's address
        uint256 finalBalance = usdt.balanceOf(testAddress);
        assertEq(
            finalBalance,
            initialBalance + uint256(withdrawAmount),
            "LP's balance should increase by the withdrawn amount"
        );

        vm.stopPrank();
    }

    //--------- UPDATE EXCHANGE RATE TESTS --------- //

    function testUpdateExchangeRate() public {
        // setup
        uint256 totalAmount = 10_000_000e6; // 10 million USDT
        deal(address(usdt), testAddress, totalAmount);
        vm.startPrank(testAddress);
        usdt.approve(address(riftExchange), totalAmount);

        // deposit liquidity
        uint192 depositAmount = 5_000_000e6; // 5 million USDT
        bytes22 btcPayoutLockingScript = 0x0014841b80d2cc75f5345c482af96294d04fdd66b2b7;
        uint64 initialBtcExchangeRate = 50;
        riftExchange.depositLiquidity(depositAmount, initialBtcExchangeRate, btcPayoutLockingScript, -1, -1);

        // update the exchange rate
        console.log("old exchange rate:", initialBtcExchangeRate);
        uint256 globalVaultIndex = 0;
        uint256 localVaultIndex = 0;
        uint64 newBtcExchangeRate = 55;
        uint256[] memory expiredReservationIndexes = new uint256[](0);
        riftExchange.updateExchangeRate(
            globalVaultIndex,
            localVaultIndex,
            newBtcExchangeRate,
            expiredReservationIndexes
        );
        console.log("new exchange rate:", riftExchange.getDepositVault(globalVaultIndex).exchangeRate);

        // verify new exchange rate
        RiftExchange.DepositVault memory updatedVault = riftExchange.getDepositVault(globalVaultIndex);
        assertEq(updatedVault.exchangeRate, newBtcExchangeRate, "Exchange rate should be updated to the new value.");

        // Verify failure on zero exchange rate
        vm.expectRevert(INVALID_VAULT_UPDATE);
        riftExchange.updateExchangeRate(globalVaultIndex, localVaultIndex, 0, expiredReservationIndexes);
        vm.stopPrank();

        // attempt update as a non-owner
        address nonOwner = address(0x2);
        vm.prank(nonOwner);
        vm.expectRevert();
        riftExchange.updateExchangeRate(
            globalVaultIndex,
            localVaultIndex,
            newBtcExchangeRate,
            expiredReservationIndexes
        );

        // Test failure due to active reservations
        vm.startPrank(testAddress);
        uint256[] memory vaultIndexesToReserve = new uint256[](1);
        vaultIndexesToReserve[0] = globalVaultIndex;
        uint192[] memory amountsToReserve = new uint192[](1);
        amountsToReserve[0] = 1_000_000e6; // 1 million USDT
        riftExchange.reserveLiquidity(vaultIndexesToReserve, amountsToReserve, testAddress, expiredReservationIndexes);

        vm.expectRevert(INVALID_UPDATE_WITH_ACTIVE_RESERVATIONS);
        riftExchange.updateExchangeRate(globalVaultIndex, localVaultIndex, 60, expiredReservationIndexes);

        vm.stopPrank();
    }
}

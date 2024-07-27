// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {RiftExchange} from "../src/RiftExchange.sol";
import {WETH} from "solmate/tokens/WETH.sol";

contract RiftExchangeTest is Test {
    RiftExchange riftExchange;
    WETH weth;
    address testAddress = address(0x123);
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

        weth = new WETH();

        riftExchange = new RiftExchange(
            initialCheckpointHeight,
            initialBlockHash,
            verifierContractAddress,
            address(weth)
        );
    }

    //--------- DEPOSIT TESTS ---------//

    function testDepositLiquidity() public {
        deal(address(weth), testAddress, 1000000e18);
        vm.startPrank(testAddress);

        console.log("Starting deposit liquidity...");
        console.log("testaddress wETH balance: ", weth.balanceOf(testAddress));

        bytes22 btcPayoutLockingScript = 0x0014841b80d2cc75f5345c482af96294d04fdd66b2b7;
        uint64 exchangeRate = 2557666;
        uint192 depositAmount = 0.1 ether;

        weth.approve(address(riftExchange), depositAmount);

        uint256 gasBefore = gasleft();
        riftExchange.depositLiquidity(btcPayoutLockingScript, exchangeRate, -1, depositAmount, -1);
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
        deal(address(weth), testAddress, 10 ether);
        vm.startPrank(testAddress);
        weth.approve(address(riftExchange), 10 ether);

        // initial deposit
        bytes22 btcPayoutLockingScript = 0x0014841b80d2cc75f5345c482af96294d04fdd66b2b7;
        uint64 exchangeRate = 2557666;
        uint192 initialDepositAmount = 0.1 ether;

        riftExchange.depositLiquidity(btcPayoutLockingScript, exchangeRate, -1, initialDepositAmount, -1);

        // empty deposit vault
        riftExchange.emptyDepositVault(0);

        // overwrite deposit vault
        uint192 newDepositAmount = 2.4 ether;
        uint64 newBtcExchangeRate = 75;
        int256 vaultIndexToOverwrite = 0;

        console.log("TOTAL DEPOSITS BEFORE OVERWRITE", riftExchange.getDepositVaultsLength());

        console.log("vault at index 0 before overwrite: ", riftExchange.getDepositVault(0).initialBalance);
        riftExchange.depositLiquidity(
            btcPayoutLockingScript,
            newBtcExchangeRate,
            vaultIndexToOverwrite, // overwriting the initial deposit
            newDepositAmount,
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
        deal(address(weth), testAddress, 99999999 ether);
        vm.startPrank(testAddress);

        weth.approve(address(riftExchange), 99999999 ether);

        uint256 firstDepositGasCost;
        uint256 lastDepositGasCost;

        bytes22 btcPayoutLockingScript = 0x0014841b80d2cc75f5345c482af96294d04fdd66b2b7;
        uint64 exchangeRate = 2557666;
        uint192 depositAmount = 500 ether;
        uint256 totalGasUsed = 0;

        // create multiple deposits
        uint256 numDeposits = 1000;
        for (uint256 i = 0; i < numDeposits; i++) {
            uint256 gasBefore = gasleft();

            riftExchange.depositLiquidity(btcPayoutLockingScript, exchangeRate, -1, depositAmount, -1);

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
    }

    function testDepositUpdateExchangeRate() public {
        // setup
        deal(address(weth), testAddress, 10 ether);
        vm.startPrank(testAddress);
        weth.approve(address(riftExchange), 10 ether);

        bytes22 btcPayoutLockingScript = 0x0014841b80d2cc75f5345c482af96294d04fdd66b2b7;
        uint64 initialBtcExchangeRate = 69;
        uint192 depositAmount = 1 ether;

        // create initial deposit
        riftExchange.depositLiquidity(
            btcPayoutLockingScript,
            initialBtcExchangeRate,
            -1, // no vault index to overwrite initially
            depositAmount,
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

        vm.stopPrank();
    }

    //     //--------- RESERVATION TESTS ---------//
    //     function testReserveLiquidity() public {
    //         // setup
    //         deal(address(weth), testAddress, 1000000e18);
    //         vm.startPrank(testAddress);
    //         weth.approve(address(riftExchange), 5 ether);
    //         bytes32 btcPayoutLockingScript = hex"0014841b80d2cc75f5345c482af96294d04fdd66b2b7";
    //         uint64 exchangeRate = 69;
    //         uint192 depositAmount = 5 ether;

    //         // deposit liquidity
    //         riftExchange.depositLiquidity(
    //             btcPayoutLockingScript,
    //             exchangeRate,
    //             -1, // no vault index to overwrite
    //             depositAmount,
    //             -1 // no vault index with same exchange rate
    //         );

    //         // check how much is available in the vault
    //         uint256 vaultBalance = riftExchange.getDepositVaultUnreservedBalance(0);
    //         console.log("Vault balance:", vaultBalance);

    //         // setup for reservation
    //         uint256[] memory vaultIndexesToReserve = new uint256[](1);
    //         vaultIndexesToReserve[0] = 0;
    //         uint192[] memory amountsToReserve = new uint192[](1);
    //         amountsToReserve[0] = 1 ether;
    //         uint256 totalSwapAmount = 1 ether; // total amount expected to swap
    //         uint256[] memory empty = new uint256[](0);
    //         weth.approve(address(riftExchange), totalSwapAmount);

    //         console.log("Amount im trying to reserve:", amountsToReserve[0]);

    //         uint256 gasBefore = gasleft();
    //         riftExchange.reserveLiquidity(
    //             vaultIndexesToReserve,
    //             amountsToReserve,
    //             totalSwapAmount,
    //             testAddress,
    //             empty
    //         );
    //         uint256 gasUsed = gasBefore - gasleft();
    //         console.log("Gas used for reservation:", gasUsed);

    //         // fetch reservation to validate
    //         RiftExchange.SwapReservation memory reservation = riftExchange.getReservation(0);

    //         // assertions
    //         assertEq(reservation.ethPayoutAddress, testAddress, "ETH payout address should match");
    //         assertEq(reservation.totalSwapAmount, totalSwapAmount, "Total swap amount should match");

    //         // validate balances and state changes
    //         uint256 remainingBalance = riftExchange.getDepositVaultUnreservedBalance(0);

    //         console.log("Remaining balance:", remainingBalance);
    //         assertEq(
    //             remainingBalance,
    //             depositAmount - amountsToReserve[0],
    //             "Vault balance should decrease by the reserved amount"
    //         );

    //         vm.stopPrank();
    //     }

    //     function testReserveMultipleLiquidity() public {
    //         // setup
    //         deal(address(weth), testAddress, 1000000e18);
    //         vm.startPrank(testAddress);
    //         weth.approve(address(riftExchange), 5000000 ether);
    //         bytes32 btcPayoutLockingScript = keccak256(abi.encodePacked("bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq"));
    //         uint64 exchangeRate = 69;
    //         uint192 depositAmount = 50 ether;

    //         // deposit liquidity
    //         riftExchange.depositLiquidity(btcPayoutLockingScript, exchangeRate, -1, depositAmount, -1);

    //         uint256[] memory vaultIndexesToReserve = new uint256[](1);
    //         vaultIndexesToReserve[0] = 0;
    //         uint192[] memory amountsToReserve = new uint192[](1);
    //         amountsToReserve[0] = 1 ether;
    //         uint256 totalSwapAmount = 1 ether;
    //         uint256[] memory empty = new uint256[](0);

    //         uint256 gasFirst;
    //         uint256 gasLast;
    //         uint256 totalGasUsed = 0;
    //         uint256 numReservations = 10;

    //         for (uint i = 0; i < numReservations; i++) {
    //             uint256 gasBefore = gasleft();
    //             riftExchange.reserveLiquidity(
    //                 vaultIndexesToReserve,
    //                 amountsToReserve,
    //                 totalSwapAmount,
    //                 testAddress,
    //                 empty
    //             );
    //             uint256 gasUsed = gasBefore - gasleft();
    //             totalGasUsed += gasUsed;

    //             if (i == 0) {
    //                 gasFirst = gasUsed;
    //             } else if (i == numReservations - 1) {
    //                 gasLast = gasUsed;
    //             }
    //         }

    //         uint256 averageGas = totalGasUsed / numReservations;

    //         console.log("First reservation gas used:", gasFirst);
    //         console.log("Last reservation gas used:", gasLast);
    //         console.log("Average gas used for reservations:", averageGas);

    //         // validate balances and state changes
    //         uint256 remainingBalance = riftExchange.getDepositVaultUnreservedBalance(0);

    //         console.log("Remaining balance:", remainingBalance);
    //         assertEq(
    //             remainingBalance,
    //             depositAmount - (amountsToReserve[0] * numReservations),
    //             "Vault balance should decrease by the total reserved amount"
    //         );

    //         vm.stopPrank();
    //     }

    //     function testReservationWithVaryingVaults() public {
    //         // setup
    //         deal(address(weth), testAddress, 1000000 ether);
    //         vm.startPrank(testAddress);
    //         weth.approve(address(riftExchange), 1000000 ether);

    //         uint256 maxVaults = 100;
    //         uint192 depositAmount = 500 ether;
    //         uint64 exchangeRate = 69;
    //         bytes32 btcPayoutLockingScript = keccak256(abi.encodePacked("bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq"));

    //         // create multiple vaults
    //         for (uint256 i = 0; i < maxVaults; i++) {
    //             riftExchange.depositLiquidity(btcPayoutLockingScript, exchangeRate, -1, depositAmount, -1);
    //         }

    //         // reserve liquidity from varying vaults
    //         for (uint256 numVaults = 1; numVaults <= maxVaults; numVaults++) {
    //             uint256[] memory vaultIndexesToReserve = new uint256[](numVaults);
    //             uint192[] memory amountsToReserve = new uint192[](numVaults);

    //             for (uint256 j = 0; j < numVaults; j++) {
    //                 vaultIndexesToReserve[j] = j;
    //                 amountsToReserve[j] = 0.1 ether;
    //             }

    //             weth.approve(address(riftExchange), 0.1 ether * numVaults);

    //             uint256 totalSwapAmount = 0.1 ether * numVaults;
    //             uint256[] memory emptyExpiredReservations = new uint256[](0);

    //             uint256 gasBefore = gasleft();
    //             riftExchange.reserveLiquidity(
    //                 vaultIndexesToReserve,
    //                 amountsToReserve,
    //                 totalSwapAmount,
    //                 testAddress,
    //                 emptyExpiredReservations
    //             );
    //             uint256 gasUsed = gasBefore - gasleft();
    //             console.log("Gas used for reserving from", numVaults, "vaults:", gasUsed);
    //         }

    //         vm.stopPrank();
    //     }

    //     function testReservationOverwriting() public {
    //         // setup
    //         deal(address(weth), testAddress, 10000 ether);
    //         vm.startPrank(testAddress);
    //         weth.approve(address(riftExchange), 10000 ether);

    //         // deposit liquidity
    //         bytes32 btcPayoutLockingScript = keccak256(abi.encodePacked("bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq"));
    //         uint64 exchangeRate = 69;
    //         uint192 depositAmount = 5 ether;

    //         riftExchange.depositLiquidity(btcPayoutLockingScript, exchangeRate, -1, depositAmount, -1);

    //         // initial reserve liquidity
    //         uint256[] memory vaultIndexesToReserve = new uint256[](1);
    //         vaultIndexesToReserve[0] = 0;
    //         uint192[] memory amountsToReserve = new uint192[](1);
    //         amountsToReserve[0] = 1 ether;
    //         uint256[] memory empty = new uint256[](0);

    //         riftExchange.reserveLiquidity(
    //             vaultIndexesToReserve,
    //             amountsToReserve,
    //             1 ether,
    //             testAddress,
    //             empty
    //         );

    //         // simulate reservation expiration
    //         vm.warp(1 days);
    //         uint256[] memory expiredSwapReservationIndexes = new uint256[](1);

    //         // overwrite reservation with new parameters
    //         riftExchange.reserveLiquidity(
    //             vaultIndexesToReserve,
    //             amountsToReserve,
    //             1 ether, // total swap amount, should be the same as initial if amount to reserve hasn't changed
    //             testAddress, // ETH payout address
    //             expiredSwapReservationIndexes
    //         );

    //         // Verify the reservation overwrite
    //         RiftExchange.SwapReservation memory overwrittenReservation = riftExchange.getReservation(0); // Assuming a method to fetch by index
    //         assertEq(overwrittenReservation.ethPayoutAddress, testAddress, "ETH payout address should match");
    //         assertEq(overwrittenReservation.amountsToReserve[0], amountsToReserve[0], "Reserved amount should match");

    //         vm.stopPrank();
    //     }

    //     //--------- WITHDRAW TESTS ---------//

    //     function testWithdrawLiquidity() public {
    //         //setup
    //         deal(address(weth), testAddress, 5 ether);
    //         vm.startPrank(testAddress);
    //         weth.approve(address(riftExchange), 100 ether);
    //         weth.approve(address(testAddress), 100 ether);

    //         // [0] initial deposit
    //         uint192 depositAmount = 5 ether;
    //         bytes32 btcPayoutLockingScript = keccak256(abi.encodePacked("bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq"));
    //         uint64 exchangeRate = 50;
    //         riftExchange.depositLiquidity(btcPayoutLockingScript, exchangeRate, -1, depositAmount, -1);

    //         // [1] withdraw some of the liquidity
    //         uint256[] memory empty = new uint256[](0);
    //         uint192 withdrawAmount = 2 ether;
    //         riftExchange.withdrawLiquidity(0, 0, withdrawAmount, empty);

    //         // [2] check if the balance has decreased correctly
    //         RiftExchange.DepositVault memory depositAfterWithdrawal = riftExchange.getDepositVault(0);
    //         uint256 expectedRemaining = depositAmount - withdrawAmount;
    //         assertEq(
    //             depositAfterWithdrawal.unreservedBalance,
    //             expectedRemaining,
    //             "Remaining deposit should match expected amount after withdrawal"
    //         );

    //         // [3] check if the funds reached the LP's address
    //         uint256 testAddressBalance = weth.balanceOf(testAddress);
    //         assertEq(testAddressBalance, withdrawAmount, "LP's balance should match the withdrawn amount");

    //         vm.stopPrank();
    //     }

    //     //--------- UPDATE EXCHANGE RATE TESTS --------- //

    //     function testUpdateExchangeRate() public {
    //         // setup
    //         deal(address(weth), testAddress, 10 ether);
    //         vm.startPrank(testAddress);
    //         weth.approve(address(riftExchange), 10 ether);

    //         // deposit liquidity
    //         uint192 depositAmount = 5 ether;
    //         bytes32 btcPayoutLockingScript = keccak256(abi.encodePacked("bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq"));
    //         uint64 initialBtcExchangeRate = 50;
    //         riftExchange.depositLiquidity(btcPayoutLockingScript, initialBtcExchangeRate, -1, depositAmount, -1);

    //         // update the exchange rate
    //         console.log("old exchange rate:", initialBtcExchangeRate);
    //         uint256 globalVaultIndex = 0;
    //         uint256 localVaultIndex = 0;
    //         uint64 newBtcExchangeRate = 55;
    //         uint256[] memory expiredReservationIndexes = new uint256[](0);
    //         riftExchange.updateExchangeRate(
    //             globalVaultIndex,
    //             localVaultIndex,
    //             newBtcExchangeRate,
    //             expiredReservationIndexes
    //         );
    //         console.log("new exchange rate:", riftExchange.getDepositVault(globalVaultIndex).exchangeRate);

    //         // verify new exchange rate
    //         RiftExchange.DepositVault memory updatedVault = riftExchange.getDepositVault(globalVaultIndex);
    //         assertEq(updatedVault.exchangeRate, newBtcExchangeRate, "Exchange rate should be updated to the new value.");

    //         // Verify failure on zero exchange rate
    //         vm.expectRevert(INVALID_VAULT_UPDATE);
    //         riftExchange.updateExchangeRate(globalVaultIndex, localVaultIndex, 0, expiredReservationIndexes);
    //         vm.stopPrank();

    //         // attempt update as a non-owner
    //         address nonOwner = address(0x2);
    //         vm.startPrank(nonOwner);
    //         vm.expectRevert(); // NOT_VAULT_OWNER
    //         riftExchange.updateExchangeRate(
    //             globalVaultIndex,
    //             localVaultIndex,
    //             newBtcExchangeRate,
    //             expiredReservationIndexes
    //         );
    //         vm.stopPrank();

    //         // Test failure due to active reservations
    //         vm.startPrank(testAddress);
    //         uint256[] memory vaultIndexesToReserve = new uint256[](1);
    //         vaultIndexesToReserve[0] = globalVaultIndex;
    //         uint192[] memory amountsToReserve = new uint192[](1);
    //         amountsToReserve[0] = 1 ether;
    //         riftExchange.reserveLiquidity(
    //             vaultIndexesToReserve,
    //             amountsToReserve,
    //             1 ether,
    //             testAddress,
    //             expiredReservationIndexes
    //         );

    //         vm.expectRevert(INVALID_UPDATE_WITH_ACTIVE_RESERVATIONS);
    //         riftExchange.updateExchangeRate(globalVaultIndex, localVaultIndex, 60, expiredReservationIndexes);

    //         vm.stopPrank();
    //     }
}

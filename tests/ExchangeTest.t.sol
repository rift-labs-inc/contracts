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
    bytes4 constant DEPOSIT_TOO_HIGH = bytes4(keccak256("DepositTooHigh()"));
    bytes4 constant INVALID_BTC_PAYOUT_ADDRESS =
        bytes4(keccak256("InvalidBitcoinAddress()"));
    bytes4 constant RESERVATION_FEE_TOO_LOW =
        bytes4(keccak256("ReservationFeeTooLow()"));
    bytes4 constant NOT_ENOUGH_LIQUIDITY =
        bytes4(keccak256("NotEnoughLiquidity()"));
    bytes4 constant RESERVATION_AMOUNT_TOO_LOW =
        bytes4(keccak256("ReservationAmountTooLow()"));
    bytes4 constant RESERVATION_EXPIRED =
        bytes4(keccak256("ReservationExpired()"));

    function setUp() public {
        bytes32 initialBlockHash = bytes32(
            0x00000000000000000002da2dfb440c17bb561ff83ec1e88cd9433e062e5388bc
        );
        uint256 initialCheckpointHeight = 845690;
        address verifierContractAddress = address(0x123);
        uint256 minDeposit = 0.5 ether;
        uint256 maxDeposit = 200_000 ether;

        weth = new WETH();

        riftExchange = new RiftExchange(
            initialCheckpointHeight,
            initialBlockHash,
            verifierContractAddress,
            address(weth),
            minDeposit,
            maxDeposit
        );
    }

    //--------- DEPOSIT TESTS ---------//

    function testDepositLiquidity() public {
        deal(address(weth), testAddress, 1000000e18);
        vm.startPrank(testAddress);

        console.log("Starting deposit liquidity...");
        console.log("testaddress wETH balance: ", weth.balanceOf(testAddress));

        bytes32 btcPayoutLockingScript = keccak256(
            abi.encodePacked("bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq")
        );
        uint256 btcExchangeRate = 69;
        uint256 depositAmount = 1.2 ether;

        weth.approve(address(riftExchange), depositAmount);

        uint256 gasBefore = gasleft();
        riftExchange.depositLiquidity(
            btcPayoutLockingScript,
            btcExchangeRate,
            -1, // No vault index to overwrite
            depositAmount,
            -1 // No vault index with same exchange rate
        );
        uint256 gasUsed = gasBefore - gasleft();
        console.log("Gas used for deposit:", gasUsed, "\n");

        uint256 vaultIndex = riftExchange.getDepositVaultsLength() - 1;
        RiftExchange.DepositVault memory deposit = riftExchange.getDepositVault(
            vaultIndex
        );

        assertEq(
            deposit.initialBalance,
            depositAmount,
            "Deposit amount mismatch"
        );
        assertEq(
            deposit.btcExchangeRate,
            btcExchangeRate,
            "BTC exchange rate mismatch"
        );

        vm.stopPrank();
    }

    // function testDepositOverwrite2() public {
    //     vm.deal(testAddress, 10 ether);
    //     vm.startPrank(testAddress);

    //     // Initial deposit
    //     bytes32 btcPayoutAddress = keccak256(
    //         abi.encodePacked("bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq")
    //     );
    //     uint256 btcExchangeRate = 69;
    //     uint256 initialDepositAmount = 1.2 ether;
    //     uint256[] memory emptyVaultIndexes = new uint256[](0);

    //     // Perform initial deposit
    //     riftExchange.depositLiquidity{value: initialDepositAmount}(
    //         btcPayoutAddress,
    //         btcExchangeRate,
    //         -1, // No vault index to overwrite initially
    //         emptyVaultIndexes
    //     );

    //     // Overwrite deposit with new details
    //     riftExchange.emptyDepositVault(0);
    //     uint256 newDepositAmount = 2.4 ether; // new amount to deposit
    //     uint256 newBtcExchangeRate = 75; // new BTC exchange rate
    //     int256 vaultIndexToOverwrite = 0; // assuming the initial deposit is at index 0

    //     // Execute the overwrite operation
    //     console.log(
    //         "TOTAL DEPOSITS BEFORE OVERWRITE",
    //         riftExchange.getDepositVaultsLength()
    //     );
    //     riftExchange.depositLiquidity{value: newDepositAmount}(
    //         btcPayoutAddress,
    //         newBtcExchangeRate,
    //         vaultIndexToOverwrite,
    //         emptyVaultIndexes
    //     );
    //     console.log(
    //         "TOTAL DEPOSITS AFTER OVERWRITE",
    //         riftExchange.getDepositVaultsLength()
    //     );

    //     // Assertions
    //     assertEq(
    //         address(riftExchange).balance,
    //         initialDepositAmount + newDepositAmount,
    //         "Contract balance should match total deposits"
    //     );
    //     uint256 depositsLength = riftExchange.getDepositVaultsLength();
    //     assertEq(
    //         depositsLength,
    //         1,
    //         "Should still have exactly one deposit entry after overwrite"
    //     );

    //     // Fetch the overwritten deposit and verify its details
    //     RiftExchange.DepositVault memory overwrittenDeposit = riftExchange
    //         .getDepositVault(uint256(vaultIndexToOverwrite));
    //     assertEq(
    //         overwrittenDeposit.initialBalance,
    //         newDepositAmount,
    //         "Overwritten deposit amount should match new deposit amount"
    //     );
    //     assertEq(
    //         overwrittenDeposit.btcExchangeRate,
    //         newBtcExchangeRate,
    //         "Overwritten BTC exchange rate should match new rate"
    //     );

    //     vm.stopPrank();
    // }

    // function testMultipleDepositsGasCost() public {
    //     vm.deal(testAddress, 99999999 ether);
    //     vm.startPrank(testAddress);

    //     uint256 firstDepositGasCost;
    //     uint256 lastDepositGasCost;

    //     bytes32 btcPayoutAddress = keccak256(
    //         abi.encodePacked("bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq")
    //     );
    //     uint256 btcExchangeRate = 69;
    //     uint256 depositAmount = 500 ether;
    //     uint256[] memory emptyVaultIndexes = new uint256[](0);
    //     uint256 totalGasUsed = 0; // Variable to keep track of the total gas used

    //     // Loop to create multiple deposits
    //     uint256 numDeposits = 100000;
    //     for (uint256 i = 0; i < numDeposits; i++) {
    //         uint256 gasBefore = gasleft(); // Measure gas before deposit

    //         riftExchange.depositLiquidity{value: depositAmount}(
    //             btcPayoutAddress,
    //             btcExchangeRate,
    //             -1, // No vault index to overwrite
    //             emptyVaultIndexes
    //         );

    //         uint256 gasUsed = gasBefore - gasleft(); // Calculate gas used for the operation
    //         totalGasUsed += gasUsed; // Accumulate total gas used

    //         if (i == 0) {
    //             firstDepositGasCost = gasUsed; // Store gas cost of the first deposit
    //         }
    //         if (i == numDeposits - 1) {
    //             lastDepositGasCost = gasUsed; // Store gas cost of the last deposit
    //         }
    //     }

    //     uint256 averageGasCost = totalGasUsed / numDeposits; // Calculate the average gas cost

    //     vm.stopPrank();

    //     // Output the gas cost for first and last deposits
    //     console.log("Gas cost for the first deposit:", firstDepositGasCost);
    //     console.log(
    //         "Gas cost for the ",
    //         numDeposits,
    //         "th deposit:",
    //         lastDepositGasCost
    //     );
    //     console.log("Average gas cost:", averageGasCost);
    // }

    // function testDepositUpdateExchangeRate() public {
    //     vm.deal(testAddress, 10 ether);
    //     vm.startPrank(testAddress);

    //     bytes32 btcPayoutAddress = keccak256(
    //         abi.encodePacked("bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq")
    //     );
    //     uint256 initialBtcExchangeRate = 69;
    //     uint256 depositAmount = 1 ether;
    //     uint256[] memory emptyVaultIndexes = new uint256[](0);
    //     uint256[] memory expiredReservationIndexes = new uint256[](0); // Assuming no reservations to clean up

    //     // Create initial deposit
    //     riftExchange.depositLiquidity{value: depositAmount}(
    //         btcPayoutAddress,
    //         initialBtcExchangeRate,
    //         -1, // No vault index to overwrite
    //         emptyVaultIndexes
    //     );

    //     // Update the BTC exchange rate
    //     uint256 newBtcExchangeRate = 75;
    //     console.log(
    //         "Updating BTC exchange rate from",
    //         initialBtcExchangeRate,
    //         "to",
    //         newBtcExchangeRate
    //     );
    //     riftExchange.updateExchangeRate(
    //         0,
    //         newBtcExchangeRate,
    //         expiredReservationIndexes
    //     );
    //     console.log(
    //         "NEW BTC EXCHANGE RATE:",
    //         riftExchange.getDepositVault(0).btcExchangeRate
    //     );

    //     // Fetch the updated deposit and verify the new exchange rate
    //     RiftExchange.DepositVault memory updatedDeposit = riftExchange
    //         .getDepositVault(0);
    //     assertEq(
    //         updatedDeposit.btcExchangeRate,
    //         newBtcExchangeRate,
    //         "BTC exchange rate should be updated to the new value"
    //     );

    //     vm.stopPrank();
    // }

    // //--------- RESERVATION TESTS ---------//
    function testReserveLiquidity() public {
        // Allocate Ether to testAddress for gas and possible payable methods
        deal(address(weth), testAddress, 1000000e18);
        vm.startPrank(testAddress);

        // Mint WETH to testAddress and approve RiftExchange to use it
        weth.approve(address(riftExchange), 5 ether);

        // Set up for deposits
        bytes32 btcPayoutLockingScript = keccak256(
            abi.encodePacked("bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq")
        );
        uint256 btcExchangeRate = 69;
        uint256 depositAmount = 5 ether;

        // Create a deposit in the RiftExchange contract
        riftExchange.depositLiquidity(
            btcPayoutLockingScript,
            btcExchangeRate,
            -1, // No vault index to overwrite
            depositAmount,
            -1 // No vault index with same exchange rate
        );

        // check how much is available in the vault
        uint256 vaultBalance = riftExchange.getDepositVaultUnreservedBalance(0);
        console.log("Vault balance:", vaultBalance);

        // Setup for reservation
        uint256[] memory vaultIndexesToReserve = new uint256[](1);
        vaultIndexesToReserve[0] = 0;
        uint256[] memory amountsToReserve = new uint256[](1);
        amountsToReserve[0] = 1 ether;
        uint256 totalSwapAmount = 1 ether; // Total amount expected to swap
        uint256[] memory empty = new uint256[](0);
        weth.approve(address(riftExchange), totalSwapAmount);

        console.log("Amount im trying to reserve:", amountsToReserve[0]);

        uint256 gasBefore = gasleft();
        riftExchange.reserveLiquidity(
            vaultIndexesToReserve,
            amountsToReserve,
            totalSwapAmount,
            testAddress, // ETH payout address
            "bc1qsenderaddress", // BTC sender address
            empty // No expired reservations
        );
        uint256 gasUsed = gasBefore - gasleft();
        console.log("Gas used for reservation:", gasUsed);

        // Fetch the reservation to validate
        RiftExchange.SwapReservation memory reservation = riftExchange
            .getReservation(0);

        // Assert reservation details
        assertEq(
            reservation.ethPayoutAddress,
            testAddress,
            "ETH payout address should match"
        );
        assertEq(
            reservation.btcSenderAddress,
            "bc1qsenderaddress",
            "BTC sender address should match"
        );
        assertEq(
            reservation.totalSwapAmount,
            totalSwapAmount,
            "Total swap amount should match"
        );

        // Validate balances and state changes
        uint256 remainingBalance = riftExchange
            .getDepositVaultUnreservedBalance(0);

        console.log("Remaining balance:", remainingBalance);
        assertEq(
            remainingBalance,
            depositAmount - amountsToReserve[0],
            "Vault balance should decrease by the reserved amount"
        );

        vm.stopPrank();
    }

    function testReserveMultipleLiquidity() public {
        // Allocate Ether to testAddress for gas and possible payable methods
        deal(address(weth), testAddress, 1000000e18);
        vm.startPrank(testAddress);

        // Mint WETH to testAddress and approve RiftExchange to use it
        weth.approve(address(riftExchange), 5000000 ether);

        // Set up for deposits
        bytes32 btcPayoutLockingScript = keccak256(
            abi.encodePacked("bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq")
        );
        uint256 btcExchangeRate = 69;
        uint256 depositAmount = 50 ether;

        // Create a deposit in the RiftExchange contract
        riftExchange.depositLiquidity(
            btcPayoutLockingScript,
            btcExchangeRate,
            -1, // No vault index to overwrite
            depositAmount,
            -1 // No vault index with same exchange rate
        );

        uint256[] memory vaultIndexesToReserve = new uint256[](1);
        vaultIndexesToReserve[0] = 0;
        uint256[] memory amountsToReserve = new uint256[](1);
        amountsToReserve[0] = 1 ether;
        uint256 totalSwapAmount = 1 ether; // Total amount expected to swap
        uint256[] memory empty = new uint256[](0);

        uint256 gasFirst;
        uint256 gasLast;
        uint256 totalGasUsed = 0;
        uint256 numReservations = 10;

        for (uint i = 0; i < numReservations; i++) {
            uint256 gasBefore = gasleft();
            riftExchange.reserveLiquidity(
                vaultIndexesToReserve,
                amountsToReserve,
                totalSwapAmount,
                testAddress, // ETH payout address
                "bc1qsenderaddress", // BTC sender address
                empty // No expired reservations
            );
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

        // Validate balances and state changes
        uint256 remainingBalance = riftExchange
            .getDepositVaultUnreservedBalance(0);

        console.log("Remaining balance:", remainingBalance);
        assertEq(
            remainingBalance,
            depositAmount - (amountsToReserve[0] * numReservations),
            "Vault balance should decrease by the total reserved amount"
        );

        vm.stopPrank();
    }

    function testReserveMultipleVaultsSimultaneously() public {
        // Allocate Ether to testAddress for gas and possible payable methods
        deal(address(weth), testAddress, 1000000e18);
        vm.startPrank(testAddress);

        // Mint WETH to testAddress and approve RiftExchange to use it
        weth.approve(address(riftExchange), 100 ether); // Approve enough for multiple deposits

        bytes32 btcPayoutLockingScript = keccak256(
            abi.encodePacked("bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq")
        );
        uint256 btcExchangeRate = 69;
        uint256[] memory depositAmounts = new uint256[](3);
        depositAmounts[0] = 10 ether;
        depositAmounts[1] = 15 ether;
        depositAmounts[2] = 20 ether;

        // Create deposits in different vaults
        for (uint i = 0; i < depositAmounts.length; i++) {
            riftExchange.depositLiquidity(
                btcPayoutLockingScript,
                btcExchangeRate,
                -1, // No vault index to overwrite
                depositAmounts[i],
                -1 // No vault index with same exchange rate
            );
        }

        // Setup reservation details for multiple vaults
        uint256[] memory vaultIndexesToReserve = new uint256[](3);
        uint256[] memory amountsToReserve = new uint256[](3);
        vaultIndexesToReserve[0] = 0;
        vaultIndexesToReserve[1] = 1;
        vaultIndexesToReserve[2] = 2;
        amountsToReserve[0] = 1 ether;
        amountsToReserve[1] = 2 ether;
        amountsToReserve[2] = 3 ether;
        uint256 totalSwapAmount = 6 ether; // Total amount to be swapped (sum of amounts to reserve)
        uint256[] memory empty = new uint256[](0);

        // Approve RiftExchange to use the total swap amount
        weth.approve(address(riftExchange), totalSwapAmount);

        // Reserve liquidity from multiple vaults in one transaction
        uint256 gasBefore = gasleft();
        riftExchange.reserveLiquidity(
            vaultIndexesToReserve,
            amountsToReserve,
            totalSwapAmount,
            testAddress, // ETH payout address
            "bc1qsenderaddress", // BTC sender address
            empty // No expired reservations
        );
        uint256 gasUsed = gasBefore - gasleft();
        console.log("Gas used for multi-vault reservation:", gasUsed);

        // Validate balances and state changes for each vault
        for (uint i = 0; i < depositAmounts.length; i++) {
            uint256 remainingBalance = riftExchange
                .getDepositVaultUnreservedBalance(i);
            console.log("Remaining balance in vault", i, ":", remainingBalance);
            assertEq(
                remainingBalance,
                depositAmounts[i] - amountsToReserve[i],
                "Vault balance should decrease by the reserved amount"
            );
        }

        vm.stopPrank();
    }

    // TODO: fix this array out of bounds error
    // function testReservationOverwriting() public {
    //     vm.deal(testAddress, 10000 ether);
    //     vm.startPrank(testAddress);

    //     // Setup initial deposit
    //     bytes32 btcPayoutAddress = keccak256(abi.encodePacked('bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq'));
    //     uint256 btcExchangeRate = 69;
    //     uint256 depositAmount = 5 ether;
    //     uint256[] memory emptyVaultIndexes = new uint256[](0); // Memory array for empty vault indexes
    //     riftExchange.depositLiquidity{ value: depositAmount }(btcPayoutAddress, btcExchangeRate, -1, emptyVaultIndexes);

    //     // Initial reservation
    //     uint256[] memory vaultIndexesToReserve = new uint256[](1);
    //     vaultIndexesToReserve[0] = 0; // Index of the deposit to reserve from
    //     uint256[] memory amountsToReserve = new uint256[](1);
    //     amountsToReserve[0] = 1 ether; // Amount to reserve
    //     string memory btcSenderAddressInitial = 'bc1qinitialsender'; // BTC sender address for the initial reservation

    //     uint256[] memory expiredSwapReservationIndexes = new uint256[](1); // No expired reservations initially
    //     expiredSwapReservationIndexes[0] = 0; // Simulating that the first reservation has expired

    //     riftExchange.reserveLiquidity{ value: 1 ether }(
    //         vaultIndexesToReserve,
    //         amountsToReserve,
    //         testAddress,
    //         btcSenderAddressInitial,
    //         expiredSwapReservationIndexes
    //     );

    //     vm.warp(1 days); // Warp time to simulate reservation expiration
    //     // Overwrite the reservation with new parameters
    //     string memory btcSenderAddressOverwrite = 'bc1qoverwritesender'; // BTC sender address for the overwrite
    //     riftExchange.reserveLiquidity{ value: 1 ether }(
    //         vaultIndexesToReserve,
    //         amountsToReserve,
    //         testAddress,
    //         btcSenderAddressOverwrite,
    //         expiredSwapReservationIndexes
    //     );

    //     // Verify the reservation overwrite
    //     RiftExchange.SwapReservation memory overwrittenReservation = riftExchange.getReservation(testAddress, 0);
    //     assertEq(overwrittenReservation.ethPayoutAddress, testAddress, 'ETH payout address should match');
    //     assertEq(
    //         overwrittenReservation.btcSenderAddress,
    //         btcSenderAddressOverwrite,
    //         'BTC sender address should be updated to new one'
    //     );
    //     assertEq(overwrittenReservation.amountsToReserve[0], amountsToReserve[0], 'Reserved amount should match');
    //     assert(!overwrittenReservation.isCompleted);
    //     assert(!overwrittenReservation.isDead);

    //     vm.stopPrank();
    // }

    //--------- WITHDRAW TESTS ---------//

    // function testWithdrawLiquidity() public {
    //     vm.deal(testAddress, 5 ether);
    //     vm.startPrank(testAddress);

    //     // [0] initial deposit
    //     uint256 depositAmount = 5 ether;
    //     riftExchange.depositLiquidity{ value: depositAmount }('bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq', 50);

    //     // [1] withdraw some of the liquidity
    //     uint256 withdrawAmount = 2 ether;
    //     riftExchange.withdrawLiquidity(0, withdrawAmount);

    //     // [2] check if the balance has decreased correctly
    //     RiftExchange.DepositVault memory depositAfterWithdrawal = riftExchange.getDepositVault(testAddress, 0);
    //     uint256 expectedRemaining = depositAmount - withdrawAmount;
    //     assertEq(depositAfterWithdrawal.ethDepositAmount, expectedRemaining, 'Remaining deposit should match expected amount after withdrawal');

    //     // [3] check if the funds reached the LP's address
    //     assertEq(testAddress.balance, withdrawAmount, "LP's balance should match the withdrawn amount");

    //     vm.stopPrank();
    // }
}

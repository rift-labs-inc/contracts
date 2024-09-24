// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.26;

// import "forge-std/Test.sol";
// import "../src/FeeRouter.sol";

// interface IERC20 {
//     function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

//     function transfer(address recipient, uint256 amount) external returns (bool);

//     function balanceOf(address account) external view returns (uint256);

//     function allowance(address owner, address spender) external view returns (uint256);

//     function approve(address spender, uint256 amount) external returns (bool);

//     function decimals() external view returns (uint8);
// }
// contract FeeRouterTest is Test {
//     FeeRouter public feeRouter;
//     address public contractOwner;
//     address[] public partitionOwners;
//     uint256[] public partitionPercentages;
//     bool[] public partitionIsManager;
//     uint256 public constant INITIAL_BALANCE = 100 ether;
//     uint256 constant BP_SCALE = 10000;

//     function setUp() public {
//         contractOwner = address(this);
//         partitionOwners = new address[](4);
//         partitionOwners[0] = address(0x1);
//         partitionOwners[1] = address(0x2);
//         partitionOwners[2] = address(0x3);
//         partitionOwners[3] = address(0x4);

//         partitionPercentages = new uint256[](4);
//         partitionPercentages[0] = 3200;
//         partitionPercentages[1] = 3200;
//         partitionPercentages[2] = 3200;
//         partitionPercentages[3] = 400;

//         partitionIsManager = new bool[](4);
//         partitionIsManager[0] = true;
//         partitionIsManager[1] = true;
//         partitionIsManager[2] = true;
//         partitionIsManager[3] = false;

//         feeRouter = new FeeRouter(contractOwner, partitionOwners, partitionPercentages, partitionIsManager);
//     }

//     function testInitialSetup() public {
//         for (uint i = 0; i < partitionOwners.length; i++) {
//             (address partitionOwner, uint256 percentage, , bool isManager) = feeRouter.partitions(i);
//             assertEq(partitionOwner, partitionOwners[i], "Owner mismatch");
//             assertEq(percentage, partitionPercentages[i], "Incorrect percentage");
//             if (i < 3) {
//                 assertTrue(isManager, "First three partitions should be managers");
//             } else {
//                 assertFalse(isManager, "Other partitions should not be managers");
//             }
//         }
//     }

//     function testReceiveFees() public {
//         uint256 feeAmount = 1 ether;
//         depositToken.approve

//         uint256 initialContractBalance = address(feeRouter).balance;
//         feeRouter.receiveFees(address(0));

//         assertEq(address(feeRouter).balance, initialContractBalance + feeAmount, "Contract balance mismatch");

//         uint256 totalDistributed = 0;
//         for (uint i = 0; i < partitionOwners.length; i++) {
//             (, uint256 percentage, , ) = feeRouter.partitions(i);
//             uint256 partitionBalance = feeRouter.getPartitionBalance(i);
//             totalDistributed += partitionBalance;

//             uint256 expectedBalance = (feeAmount * percentage) / BP_SCALE;
//             if (i == partitionOwners.length - 1) {
//                 // The last partition might have a slightly higher balance due to rounding
//                 assertGe(partitionBalance, expectedBalance, "Last partition balance too low");
//             } else {
//                 assertEq(partitionBalance, expectedBalance, "Partition balance mismatch");
//             }
//         }

//         assertEq(totalDistributed, feeAmount, "Total distributed amount should equal fee amount");
//     }

//     //     function testReceiveFeesWithReferral() public {
//     //         address referrer = address(0x123);
//     //         address referralAddress = address(0x456);
//     //         uint256 feeAmount = 1 ether;

//     //         // Add referrer
//     //         vm.prank(partitionOwners[0]);
//     //         feeRouter.addApprovedReferrer(referralAddress, referrer);

//     //         uint256 initialReferrerBalance = referrer.balance;
//     //         uint256 initialContractBalance = address(feeRouter).balance;

//     //         feeRouter.receiveFees{value: feeAmount}(referralAddress);

//     //         // Check referrer received 50%
//     //         assertEq(referrer.balance, initialReferrerBalance + feeAmount / 2, "Referrer should receive 50% of fees");

//     //         // Check remaining 50% distributed to partitions
//     //         uint256 remainingFee = feeAmount / 2;
//     //         uint256 totalDistributed = 0;
//     //         for (uint i = 0; i < partitionOwners.length; i++) {
//     //             (, uint256 percentage, , ) = feeRouter.partitions(i);
//     //             uint256 partitionBalance = feeRouter.getPartitionBalance(i);
//     //             totalDistributed += partitionBalance;

//     //             uint256 expectedBalance = (remainingFee * percentage) / BP_SCALE;
//     //             if (i == partitionOwners.length - 1) {
//     //                 assertGe(partitionBalance, expectedBalance, "Last partition balance too low");
//     //             } else {
//     //                 assertEq(partitionBalance, expectedBalance, "Partition balance mismatch");
//     //             }
//     //         }

//     //         assertEq(totalDistributed, remainingFee, "Total distributed amount should equal remaining fee amount");
//     //     }

//     //     function testAddApprovedReferrer() public {
//     //         address referrer = address(0x123);
//     //         address referralAddress = address(0x456);

//     //         vm.prank(partitionOwners[0]);
//     //         feeRouter.addApprovedReferrer(referralAddress, referrer);

//     //         assertEq(feeRouter.approvedReferredEthAddresses(referralAddress), referrer, "Referrer not set correctly");
//     //     }

//     //     function testRemoveApprovedReferrer() public {
//     //         address referrer = address(0x123);
//     //         address referralAddress = address(0x456);

//     //         vm.prank(partitionOwners[0]);
//     //         feeRouter.addApprovedReferrer(referralAddress, referrer);

//     //         vm.prank(partitionOwners[0]);
//     //         feeRouter.removeApprovedReferrer(referralAddress);

//     //         assertEq(feeRouter.approvedReferredEthAddresses(referralAddress), address(0), "Referrer not removed");
//     //     }

//     //     function testNonManagerCannotAddReferrer() public {
//     //         address referrer = address(0x123);
//     //         address referralAddress = address(0x456);

//     //         vm.expectRevert("Not a manager");
//     //         vm.prank(partitionOwners[3]); // Non-manager
//     //         feeRouter.addApprovedReferrer(referralAddress, referrer);
//     //     }

//     //     function testNonManagerCannotRemoveReferrer() public {
//     //         address referrer = address(0x123);
//     //         address referralAddress = address(0x456);

//     //         vm.prank(partitionOwners[0]);
//     //         feeRouter.addApprovedReferrer(referralAddress, referrer);

//     //         vm.expectRevert("Not a manager");
//     //         vm.prank(partitionOwners[3]); // Non-manager
//     //         feeRouter.removeApprovedReferrer(referralAddress);
//     //     }

//     //     function testCannotAddInvalidReferrer() public {
//     //         vm.expectRevert("Invalid ETH address");
//     //         vm.prank(partitionOwners[0]);
//     //         feeRouter.addApprovedReferrer(address(0), address(0x123));
//     //     }

//     //     function testCannotRemoveInvalidReferrer() public {
//     //         vm.expectRevert("Invalid ETH address");
//     //         vm.prank(partitionOwners[0]);
//     //         feeRouter.removeApprovedReferrer(address(0));
//     //     }

//     //     function testRequestWithdrawal() public {
//     //         uint256 feeAmount = 1 ether;
//     //         (bool success, ) = address(feeRouter).call{value: feeAmount}("");
//     //         require(success, "Sending Ether failed");

//     //         for (uint i = 0; i < partitionOwners.length; i++) {
//     //             address partitionOwner = partitionOwners[i];
//     //             uint256 initialOwnerBalance = partitionOwner.balance;
//     //             uint256 partitionBalance = feeRouter.getPartitionBalance(i);

//     //             vm.prank(partitionOwner);
//     //             feeRouter.requestWithdrawal(i);

//     //             assertEq(partitionOwner.balance, initialOwnerBalance + partitionBalance, "Withdrawal amount mismatch");
//     //             assertEq(feeRouter.getPartitionBalance(i), 0, "Partition balance should be zero after withdrawal");
//     //         }
//     //     }

//     //     function testRequestWithdrawalUnauthorized() public {
//     //         (bool success, ) = address(feeRouter).call{value: 1 ether}("");
//     //         require(success, "Sending Ether failed");

//     //         vm.expectRevert("Not the partition owner");
//     //         vm.prank(address(0x999)); // Unauthorized address
//     //         feeRouter.requestWithdrawal(0);
//     //     }

//     //     function testRequestWithdrawalInvalidPartition() public {
//     //         vm.expectRevert("Invalid partition index");
//     //         vm.prank(partitionOwners[0]);
//     //         feeRouter.requestWithdrawal(10); // Invalid partition index
//     //     }

//     //     function testGetContractBalance() public {
//     //         uint256 feeAmount = 1 ether;
//     //         (bool success, ) = address(feeRouter).call{value: feeAmount}("");
//     //         require(success, "Sending Ether failed");

//     //         assertEq(feeRouter.getContractBalance(), feeAmount, "Contract balance after fee reception mismatch");
//     //     }

//     //     function testProposeNewPartitionLayout() public {
//     //         FeeRouter.Partition[] memory newPartitions = new FeeRouter.Partition[](4);
//     //         newPartitions[0] = FeeRouter.Partition(address(0x10), 2500, 0, true);
//     //         newPartitions[1] = FeeRouter.Partition(address(0x11), 2500, 0, true);
//     //         newPartitions[2] = FeeRouter.Partition(address(0x12), 2500, 0, true);
//     //         newPartitions[3] = FeeRouter.Partition(address(0x13), 2500, 0, false);

//     //         vm.prank(partitionOwners[0]);
//     //         feeRouter.proposeNewPartitionLayout(newPartitions);

//     //         (uint256 approvalCount, bool executed) = feeRouter.proposals(1);
//     //         assertEq(approvalCount, 1, "Initial approval count should be 1");
//     //         assertFalse(executed, "Proposal should not be executed yet");
//     //     }

//     //     function testProposeNewPartitionLayoutNonManager() public {
//     //         FeeRouter.Partition[] memory newPartitions = new FeeRouter.Partition[](4);
//     //         newPartitions[0] = FeeRouter.Partition(address(0x10), 2500, 0, true);
//     //         newPartitions[1] = FeeRouter.Partition(address(0x11), 2500, 0, true);
//     //         newPartitions[2] = FeeRouter.Partition(address(0x12), 2500, 0, true);
//     //         newPartitions[3] = FeeRouter.Partition(address(0x13), 2500, 0, false);

//     //         vm.expectRevert("Not a manager");
//     //         vm.prank(partitionOwners[3]); // Non-manager partition
//     //         feeRouter.proposeNewPartitionLayout(newPartitions);
//     //     }

//     //     function testApproveAndExecuteProposal() public {
//     //         // Send some fees to the contract
//     //         uint256 feeAmount = 1 ether;
//     //         (bool success, ) = address(feeRouter).call{value: feeAmount}("");
//     //         require(success, "Sending Ether failed");

//     //         FeeRouter.Partition[] memory newPartitions = new FeeRouter.Partition[](4);
//     //         newPartitions[0] = FeeRouter.Partition(address(0x10), 2500, 0, true);
//     //         newPartitions[1] = FeeRouter.Partition(address(0x11), 2500, 0, true);
//     //         newPartitions[2] = FeeRouter.Partition(address(0x12), 2500, 0, true);
//     //         newPartitions[3] = FeeRouter.Partition(address(0x13), 2500, 0, false);

//     //         // Record initial balances
//     //         uint256[] memory initialBalances = new uint256[](partitionOwners.length);
//     //         for (uint i = 0; i < partitionOwners.length; i++) {
//     //             initialBalances[i] = address(partitionOwners[i]).balance;
//     //         }

//     //         vm.prank(partitionOwners[0]);
//     //         feeRouter.proposeNewPartitionLayout(newPartitions);

//     //         vm.prank(partitionOwners[1]);
//     //         feeRouter.approveProposal(1);

//     //         // Check if the proposal was executed
//     //         (, bool executed) = feeRouter.proposals(1);
//     //         assertTrue(executed, "Proposal should be executed");

//     //         // Verify that all previous partition balances were withdrawn
//     //         for (uint i = 0; i < partitionOwners.length; i++) {
//     //             uint256 expectedBalance = initialBalances[i] + (feeAmount * partitionPercentages[i]) / BP_SCALE;
//     //             assertEq(address(partitionOwners[i]).balance, expectedBalance, "Partition balance not correctly withdrawn");
//     //         }

//     //         // Verify the new partition layout
//     //         for (uint i = 0; i < newPartitions.length; i++) {
//     //             (address partitionOwner, uint256 percentage, uint256 balance, bool isManager) = feeRouter.partitions(i);
//     //             assertEq(partitionOwner, newPartitions[i].owner, "Owner mismatch in new layout");
//     //             assertEq(percentage, newPartitions[i].percentage, "Percentage mismatch in new layout");
//     //             assertEq(balance, 0, "Balance should be zero in new layout");
//     //             assertEq(isManager, newPartitions[i].isManager, "Manager status mismatch in new layout");
//     //         }

//     //         // Verify that the contract balance is zero after all withdrawals
//     //         assertEq(address(feeRouter).balance, 0, "Contract balance should be zero after proposal execution");
//     //     }

//     //     function testApproveProposalNonManager() public {
//     //         FeeRouter.Partition[] memory newPartitions = new FeeRouter.Partition[](4);
//     //         newPartitions[0] = FeeRouter.Partition(address(0x10), 2500, 0, true);
//     //         newPartitions[1] = FeeRouter.Partition(address(0x11), 2500, 0, true);
//     //         newPartitions[2] = FeeRouter.Partition(address(0x12), 2500, 0, true);
//     //         newPartitions[3] = FeeRouter.Partition(address(0x13), 2500, 0, false);

//     //         vm.prank(partitionOwners[0]);
//     //         feeRouter.proposeNewPartitionLayout(newPartitions);

//     //         vm.expectRevert("Not a manager");
//     //         vm.prank(partitionOwners[3]); // Non-manager partition
//     //         feeRouter.approveProposal(1);
//     //     }
// }

// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.2;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {FeeRouter} from "../src/FeeRouter.sol";
import {MockUSDT} from "./MockUSDT.sol";

contract FeeRouterTest is Test {
    FeeRouter public feeRouter;
    MockUSDT public depositToken;

    address public owner;
    address public manager1;
    address public manager2;
    address public manager3;
    address public nonManager;

    function setUp() public {
        depositToken = new MockUSDT();
        owner = address(this);
        manager1 = address(0x1);
        manager2 = address(0x2);
        manager3 = address(0x3);
        nonManager = address(0x4);

        address[] memory partitionOwners = new address[](4);
        partitionOwners[0] = manager1;
        partitionOwners[1] = manager2;
        partitionOwners[2] = manager3;
        partitionOwners[3] = nonManager;

        uint256[] memory percentages = new uint256[](4);
        percentages[0] = 3200; // 32%
        percentages[1] = 3200; // 32%
        percentages[2] = 3200; // 32%
        percentages[3] = 400; // 4%

        bool[] memory isManager = new bool[](4);
        isManager[0] = true;
        isManager[1] = true;
        isManager[2] = true;
        isManager[3] = false;

        feeRouter = new FeeRouter(owner, partitionOwners, percentages, isManager, address(depositToken));
    }

    function testInitialState() public {
        assertEq(feeRouter.owner(), owner);
        assertEq(feeRouter.totalManagers(), 3);
        assertEq(feeRouter.totalReceived(), 0);
    }

    // function testReceiveFees() public {
    //     uint256 amount = 1000 * 10 ** 18; // 1000 tokens
    //     depositToken.mint(address(this), amount);
    //     depositToken.approve(address(feeRouter), amount);

    //     feeRouter.receiveFees(address(0), address(0));

    //     assertEq(feeRouter.totalReceived(), amount);
    //     assertEq(depositToken.balanceOf(manager1), 330 * 10 ** 18);
    //     assertEq(depositToken.balanceOf(manager2), 330 * 10 ** 18);
    //     assertEq(depositToken.balanceOf(manager3), 330 * 10 ** 18);

    // }

    // function testReceiveFeesWithReferrals() public {
    //     uint256 amount = 1000 * 10 ** 18; // 1000 tokens
    //     depositToken.mint(address(this), amount);
    //     depositToken.approve(address(feeRouter), amount);

    //     address ethReferrer = address(0x5);
    //     address btcReferrer = address(0x6);
    //     address swapperEthAddress = address(0x7);
    //     address swapperBtcAddress = address(0x8);

    //     vm.prank(manager1);
    //     feeRouter.addApprovedEthReferrer(swapperEthAddress, ethReferrer);

    //     vm.prank(manager2);
    //     feeRouter.addApprovedBtcReferrer(swapperBtcAddress, btcReferrer);

    //     feeRouter.receiveFees(swapperEthAddress, swapperBtcAddress);

    //     assertEq(feeRouter.totalReceived(), amount);
    //     assertEq(depositToken.balanceOf(ethReferrer), 500 * 10 ** 18);
    //     assertEq(depositToken.balanceOf(btcReferrer), 250 * 10 ** 18);
    //     assertEq(depositToken.balanceOf(manager1), 75 * 10 ** 18);
    //     assertEq(depositToken.balanceOf(manager2), 75 * 10 ** 18);
    //     assertEq(depositToken.balanceOf(manager3), 100 * 10 ** 18);
    // }

    // function testProposeNewPartitionLayout() public {
    //     FeeRouter.Partition[] memory newPartitions = new FeeRouter.Partition[](3);
    //     newPartitions[0] = FeeRouter.Partition(manager1, 2500, true);
    //     newPartitions[1] = FeeRouter.Partition(manager2, 2500, true);
    //     newPartitions[2] = FeeRouter.Partition(manager3, 5000, true);

    //     vm.prank(manager1);
    //     feeRouter.proposeNewPartitionLayout(newPartitions);

    //     assertEq(feeRouter.proposalCount(), 1);
    // }

    // function testApproveAndExecuteProposal() public {
    //     FeeRouter.Partition[] memory newPartitions = new FeeRouter.Partition[](3);
    //     newPartitions[0] = FeeRouter.Partition(manager1, 2500, true);
    //     newPartitions[1] = FeeRouter.Partition(manager2, 2500, true);
    //     newPartitions[2] = FeeRouter.Partition(manager3, 5000, true);

    //     vm.prank(manager1);
    //     feeRouter.proposeNewPartitionLayout(newPartitions);

    //     vm.prank(manager2);
    //     feeRouter.approveProposal(1);

    //     vm.prank(manager3);
    //     feeRouter.approveProposal(1);

    //     // Check if the proposal was executed
    //     (address owner, uint256 percentage, bool isManager) = feeRouter.partitions(2);
    //     assertEq(owner, manager3);
    //     assertEq(percentage, 5000);
    //     assertEq(isManager, true);
    // }

    // function testFailProposeInvalidPartitionLayout() public {
    //     FeeRouter.Partition[] memory newPartitions = new FeeRouter.Partition[](3);
    //     newPartitions[0] = FeeRouter.Partition(manager1, 3000, true);
    //     newPartitions[1] = FeeRouter.Partition(manager2, 3000, true);
    //     newPartitions[2] = FeeRouter.Partition(manager3, 5000, true); // Total > 10000

    //     vm.prank(manager1);
    //     feeRouter.proposeNewPartitionLayout(newPartitions);
    // }

    // function testFailNonManagerPropose() public {
    //     FeeRouter.Partition[] memory newPartitions = new FeeRouter.Partition[](3);
    //     newPartitions[0] = FeeRouter.Partition(manager1, 2500, true);
    //     newPartitions[1] = FeeRouter.Partition(manager2, 2500, true);
    //     newPartitions[2] = FeeRouter.Partition(manager3, 5000, true);

    //     vm.prank(nonManager);
    //     feeRouter.proposeNewPartitionLayout(newPartitions);
    // }

    // function testFailDoubleApproval() public {
    //     FeeRouter.Partition[] memory newPartitions = new FeeRouter.Partition[](3);
    //     newPartitions[0] = FeeRouter.Partition(manager1, 2500, true);
    //     newPartitions[1] = FeeRouter.Partition(manager2, 2500, true);
    //     newPartitions[2] = FeeRouter.Partition(manager3, 5000, true);

    //     vm.prank(manager1);
    //     feeRouter.proposeNewPartitionLayout(newPartitions);

    //     vm.prank(manager2);
    //     feeRouter.approveProposal(1);

    //     vm.prank(manager2);
    //     feeRouter.approveProposal(1); // Should fail
    // }
}

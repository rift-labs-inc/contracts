// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.2;

import {console} from "forge-std/console.sol";
import {Owned} from "../lib/solmate/src/auth/Owned.sol";

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    function transfer(address recipient, uint256 amount) external returns (bool);

    function balanceOf(address account) external view returns (uint256);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function decimals() external view returns (uint8);
}

contract FeeRouter is Owned {
    IERC20 public depositToken;

    struct Partition {
        address owner;
        uint256 percentage;
        uint256 balance;
        bool isManager;
    }

    struct Proposal {
        Partition[] newPartitions;
        uint256 approvalCount;
        mapping(address => bool) hasApproved;
        bool executed;
    }

    Partition[] public partitions;
    uint256 public totalReceived;
    uint256 constant BP_SCALE = 10000;
    uint256 public proposalCount;
    mapping(uint256 => Proposal) public proposals;
    mapping(address => address) public approvedReferredEthAddresses;

    modifier onlyManager() {
        require(isManager(msg.sender), "Not a manager");
        _;
    }

    constructor(
        address _owner,
        address[] memory _partitionOwners,
        uint256[] memory _percentages,
        bool[] memory _isManager
    ) Owned(_owner) {
        require(_partitionOwners.length == _percentages.length, "Mismatch in owners and percentages");
        uint256 totalManagers = 0;
        uint256 totalPercentage = 0;
        for (uint i = 0; i < _partitionOwners.length; i++) {
            totalPercentage += _percentages[i];
            partitions.push(Partition(_partitionOwners[i], _percentages[i], 0, _isManager[i]));
            if (_isManager[i]) {
                totalManagers += 1;
            }
        }
        require(totalManagers >= 3, "need at least 3 managers to initiate multisig");
        require(totalPercentage == BP_SCALE, "Total percentage must be 10000");
    }

    function receiveFees(address depositVaultOwnerAddress) public {
        uint256 amount = depositToken.allowance(msg.sender, address(this));
        require(amount > 0, "No allowance for token transfer");
        require(depositToken.transferFrom(msg.sender, address(this), amount), "Token transfer failed");
        address referrer = address(0);

        if (approvedReferredEthAddresses[depositVaultOwnerAddress] != address(0)) {
            referrer = approvedReferredEthAddresses[depositVaultOwnerAddress];
        }

        if (referrer != address(0)) {
            uint256 referralFee = amount / 2;
            (bool success, ) = payable(referrer).call{value: referralFee}("");
            require(success, "Referral fee transfer failed");
            amount -= referralFee;
        }

        totalReceived += amount;

        uint256 remainingWei = amount;
        for (uint i = 0; i < partitions.length - 1; i++) {
            uint256 partitionAmount = (amount * partitions[i].percentage) / BP_SCALE;
            partitions[i].balance += partitionAmount;
            remainingWei -= partitionAmount;
        }

        // Allocate remaining wei to the last partition
        partitions[partitions.length - 1].balance += remainingWei;
    }

    function addApprovedReferrer(address ethAddress, address owner) external onlyManager {
        require(ethAddress != address(0), "Invalid ETH address");
        approvedReferredEthAddresses[ethAddress] = owner;
    }

    function removeApprovedReferrer(address ethAddress) external onlyManager {
        require(ethAddress != address(0), "Invalid ETH address");
        delete approvedReferredEthAddresses[ethAddress];
    }

    function requestWithdrawal(uint256 partitionIndex) public {
        require(partitionIndex < partitions.length, "Invalid partition index");
        require(msg.sender == partitions[partitionIndex].owner, "Not the partition owner");
        require(partitions[partitionIndex].balance > 0, "No balance to withdraw");

        uint256 amount = partitions[partitionIndex].balance;
        partitions[partitionIndex].balance = 0;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(depositToken.transfer(msg.sender, amount), "Token transfer failed");

        require(success, "Transfer failed");
    }

    function getPartitionBalance(uint256 partitionIndex) public view returns (uint256) {
        require(partitionIndex < partitions.length, "Invalid partition index");
        return partitions[partitionIndex].balance;
    }

    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function proposeNewPartitionLayout(Partition[] memory _newPartitions) public onlyManager {
        require(validateNewPartitions(_newPartitions), "Invalid new partition layout");

        proposalCount++;
        Proposal storage newProposal = proposals[proposalCount];
        uint256 totalManagers = 0;

        for (uint i = 0; i < _newPartitions.length; i++) {
            if (_newPartitions[i].isManager) {
                totalManagers += 1;
            }
            newProposal.newPartitions.push(_newPartitions[i]);
        }
        require(totalManagers >= 3, "need at least 3 managers to initiate multisig");

        newProposal.approvalCount = 1;
        newProposal.hasApproved[msg.sender] = true;
    }

    function approveProposal(uint256 _proposalId) public onlyManager {
        Proposal storage proposal = proposals[_proposalId];
        require(!proposal.executed, "Proposal already executed");
        require(!proposal.hasApproved[msg.sender], "Already approved");

        proposal.approvalCount++;
        proposal.hasApproved[msg.sender] = true;

        if (proposal.approvalCount >= 2) {
            executeProposal(_proposalId);
        }
    }

    function executeProposal(uint256 _proposalId) internal {
        Proposal storage proposal = proposals[_proposalId];
        require(!proposal.executed, "Proposal already executed");
        require(proposal.approvalCount >= 2, "Not enough approvals");

        // Withdraw all current partition balances
        withdrawAllPartitions();

        // Implement new partition layout
        delete partitions;
        for (uint i = 0; i < proposal.newPartitions.length; i++) {
            partitions.push(proposal.newPartitions[i]);
        }

        proposal.executed = true;
    }

    function withdrawAllPartitions() internal {
        for (uint i = 0; i < partitions.length; i++) {
            if (partitions[i].balance > 0) {
                uint256 amount = partitions[i].balance;
                partitions[i].balance = 0;
                require(depositToken.transfer(partitions[i].owner, amount), "Token transfer failed");
            }
        }
    }

    function isManager(address _address) internal view returns (bool) {
        for (uint i = 0; i < partitions.length; i++) {
            if (partitions[i].owner == _address && partitions[i].isManager) {
                return true;
            }
        }
        return false;
    }

    function validateNewPartitions(Partition[] memory _newPartitions) internal pure returns (bool) {
        uint256 totalPercentage = 0;
        uint256 managerCount = 0;
        for (uint i = 0; i < _newPartitions.length; i++) {
            totalPercentage += _newPartitions[i].percentage;
            if (_newPartitions[i].isManager) {
                managerCount++;
            }
        }
        return totalPercentage == BP_SCALE;
    }
}

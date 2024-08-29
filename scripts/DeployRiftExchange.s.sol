// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/RiftExchange.sol";

contract DeployRiftExchange is Script {
    function run() external {
        vm.startBroadcast();

        console.log("Starting deployment...");

        // Define the constructor arguments
        uint256 initialCheckpointHeight = 0;
        bytes32 initialBlockHash = bytes32(0);
        address verifierContractAddress = address(0x01);
        address depositTokenAddress = address(0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0);
        bytes32 verificationKeyHash = hex"00ca6cebffbb631e1dcb7588151f5cd92b1fd99c85e065030307de4c677b6dba";
        uint256 proverReward = 5 * 10 ** 6;
        uint256 releaserReward = 2 * 10 ** 6;
        address payable protocolAddress = payable(address(1));
        address owner = msg.sender;

        console.log("Deploying RiftExchange...");
        console.log("initialCheckpointHeight:", initialCheckpointHeight);
        console.log("initialBlockHash:", uint256(initialBlockHash));
        console.log("verifierContractAddress:", verifierContractAddress);
        console.log("depositTokenAddress:", depositTokenAddress);
        console.log("proverReward:", proverReward);
        console.log("releaserReward:", releaserReward);
        console.log("protocolAddress:", protocolAddress);

        // Try deploying RiftExchange
        try
            new RiftExchange(
                initialCheckpointHeight,
                initialBlockHash,
                verifierContractAddress,
                depositTokenAddress,
                proverReward,
                releaserReward,
                protocolAddress,
                owner,
                verificationKeyHash

            )
        returns (RiftExchange riftExchange) {
            console.log("RiftExchange deployed at:", address(riftExchange));
        } catch Error(string memory reason) {
            console.log("Failed to deploy RiftExchange:");
            console.log(reason);
        } catch (bytes memory lowLevelData) {
            console.log("Failed to deploy RiftExchange (low level error):");
            console.logBytes(lowLevelData);
        }

        console.log("Deployment script finished.");

        vm.stopBroadcast();
    }
}

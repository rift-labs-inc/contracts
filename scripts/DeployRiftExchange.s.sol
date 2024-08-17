// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/RiftExchange.sol";
import {UltraVerifier} from "../src/verifiers/RiftPlonkVerification.sol";

contract DeployRiftExchange is Script {
    function run() external {
        vm.startBroadcast();

        console.log("Starting deployment...");

        // Deploy UltraVerifier
        console.log("Deploying UltraVerifier...");
        UltraVerifier verifier = new UltraVerifier();
        console.log("Verifier deployed at:", address(verifier));

        // Define the constructor arguments
        uint256 initialCheckpointHeight = 0;
        bytes32 initialBlockHash = bytes32(0);
        address verifierContractAddress = address(verifier);
        address depositTokenAddress = address(0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0);
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
                owner
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

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/RiftExchange.sol";
import {UltraVerifier} from "../src/verifiers/RiftPlonkVerification.sol";

contract DeployRiftExchange is Script {
    function run() external {
        vm.startBroadcast();
        UltraVerifier verifier = new UltraVerifier();
        console.log("Verifier deployed at:", address(verifier));

        // Define the new constructor arguments
        uint256 initialCheckpointHeight = 0; // Replace with actual value if needed
        bytes32 initialBlockHash = bytes32(0); // Replace with actual value if needed
        address verifierContractAddress = address(verifier);
        address depositTokenAddress = address(0xdAC17F958D2ee523a2206206994597C13D831ec7); // USDT address on Ethereum mainnet
        uint256 proverReward = 5 * 10 ** 6; // 5 USDT (USDT has 6 decimal places)
        uint256 releaserReward = 2 * 10 ** 6; // 2 USDT
        address payable protocolAddress = payable(address(1)); // Replace with actual protocol address

        RiftExchange riftExchange = new RiftExchange(
            initialCheckpointHeight,
            initialBlockHash,
            verifierContractAddress,
            depositTokenAddress,
            proverReward,
            releaserReward,
            protocolAddress
        );

        console.log("RiftExchangeContract deployed at:", address(riftExchange));

        vm.stopBroadcast();
    }
}

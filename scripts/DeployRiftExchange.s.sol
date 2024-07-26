// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/RiftExchange.sol";

contract DeployRiftExchange is Script {
    function run() external {
        vm.startBroadcast();

        // Replace with the constructor arguments for RiftExchangeContract if any
        RiftExchange riftExchange = new RiftExchange(
            0, // initialCheckpointHeight
            bytes32(0), // initialBlockHash
            address(0), // verifierContractAddress
            address(0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9) // depositTokenAddress (WETH)
        );

        console.log("RiftExchangeContract deployed at:", address(riftExchange));

        vm.stopBroadcast();
    }
}

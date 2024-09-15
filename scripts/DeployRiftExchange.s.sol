// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/RiftExchange.sol";

contract DeployRiftExchange is Script {
    function stringToUint(string memory s) internal pure returns (uint256) {
        bytes memory b = bytes(s);
        uint256 result = 0;
        for (uint256 i = 0; i < b.length; i++) {
            uint256 c = uint256(uint8(b[i]));
            if (c >= 48 && c <= 57) {
                result = result * 10 + (c - 48);
            }
        }
        return result;
    }

    function _substring(string memory _base, int256 _length, int256 _offset) internal pure returns (string memory) {
        bytes memory _baseBytes = bytes(_base);

        assert(uint256(_offset + _length) <= _baseBytes.length);

        string memory _tmp = new string(uint256(_length));
        bytes memory _tmpBytes = bytes(_tmp);

        uint256 j = 0;
        for (uint256 i = uint256(_offset); i < uint256(_offset + _length); i++) {
            _tmpBytes[j++] = _baseBytes[i];
        }

        return string(_tmpBytes);
    }

    function fetchChainHeight() public returns (uint256) {
        // Prepare the curl command with jq
        string[] memory curlInputs = new string[](3);
        curlInputs[0] = "bash";
        curlInputs[1] = "-c";
        curlInputs[2] = string(
            abi.encodePacked(
                'curl --data-binary \'{"jsonrpc": "1.0", "id": "curltest", "method": "getblockchaininfo", "params": []}\' ',
                "-H 'content-type: text/plain;' -s ",
                vm.envString("BITCOIN_RPC"),
                " | jq -r '.result.blocks'"
            )
        );
        string memory _blockHeightStr = vm.toString(vm.ffi(curlInputs));
        string memory blockHeightStr = _substring(_blockHeightStr, int256(bytes(_blockHeightStr).length) - 2, 2);
        uint256 blockHeight = stringToUint(blockHeightStr);
        return blockHeight;
    }

    function fetchBlockHash(uint256 height) public returns (bytes32) {
        string memory heightStr = vm.toString(height);
        string[] memory curlInputs = new string[](3);
        curlInputs[0] = "bash";
        curlInputs[1] = "-c";
        curlInputs[2] = string(
            abi.encodePacked(
                'curl --data-binary \'{"jsonrpc": "1.0", "id": "curltest", "method": "getblockhash", "params": [',
                heightStr,
                "]}' -H 'content-type: text/plain;' -s ",
                vm.envString("BITCOIN_RPC"),
                " | jq -r '.result'"
            )
        );
        bytes memory result = vm.ffi(curlInputs);
        return bytes32(result);
    }

    function calculateRetargetHeight(uint256 height) public pure returns (uint256) {
        uint256 retargetHeight = height - (height % 2016);
        return retargetHeight;
    }

    function run() external {
        vm.startBroadcast();

        console.log("Starting deployment...");

        uint256 initialCheckpointHeight = fetchChainHeight() - 6;
        bytes32 initialBlockHash = fetchBlockHash(initialCheckpointHeight);
        bytes32 initialRetargetBlockHash = fetchBlockHash(calculateRetargetHeight(initialCheckpointHeight));

        // Define the constructor arguments
        address verifierContractAddress = address(0x3B6041173B80E77f038f3F2C0f9744f04837185e);
        address depositTokenAddress = address(0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0);
        uint256 proverReward = 2 * 10 ** 6; // 2 USDT
        uint256 releaserReward = 1 * 10 ** 6; // 1 USDT
        bytes32 verificationKeyHash = hex"002b2f29a3996a28656c70ab4ad23a156e0a0805d8f14c677036b5d1935ed226";
        address payable protocolAddress = payable(address(0x9FEEf1C10B8cD9Bc6c6B6B44ad96e07F805decaf));

        console.log("Deploying RiftExchange...");
        console.log("initialRetargetBlockHash:");
        console.logBytes32(initialRetargetBlockHash);
        console.log("initialCheckpointHeight:", initialCheckpointHeight);
        console.log("initialBlockHash:");
        console.logBytes32(initialBlockHash);
        console.log("verifierContractAddress:", verifierContractAddress);
        console.log("depositTokenAddress:", depositTokenAddress);
        console.log("proverReward:", proverReward);
        console.log("releaserReward:", releaserReward);
        console.log("protocolAddress:", protocolAddress);

        // Try deploying RiftExchange
        try new RiftExchange(
            initialCheckpointHeight,
            initialBlockHash,
            initialRetargetBlockHash,
            verifierContractAddress,
            depositTokenAddress,
            proverReward,
            releaserReward,
            protocolAddress,
            msg.sender,
            verificationKeyHash,
            // +5 is industry standard (block explorers show this as 6 "confirmations")
            1
        ) returns (RiftExchange riftExchange) {
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

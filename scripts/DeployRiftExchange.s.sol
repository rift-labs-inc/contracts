// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/RiftExchange.sol";

contract DeployRiftExchange is Script {
    function stringToUint(string memory s) internal pure returns (uint) {
        bytes memory b = bytes(s);
        uint result = 0;
        for (uint i = 0; i < b.length; i++) {
            uint c = uint(uint8(b[i]));
            if (c >= 48 && c <= 57) {
                result = result * 10 + (c - 48);
            }
        }
        return result;
    }

    function _substring(string memory _base, int _length, int _offset) internal pure returns (string memory) {
        bytes memory _baseBytes = bytes(_base);

        assert(uint(_offset + _length) <= _baseBytes.length);

        string memory _tmp = new string(uint(_length));
        bytes memory _tmpBytes = bytes(_tmp);

        uint j = 0;
        for (uint i = uint(_offset); i < uint(_offset + _length); i++) {
            _tmpBytes[j++] = _baseBytes[i];
        }

        return string(_tmpBytes);
    }

    function fetchBlockHeight() public returns (uint256) {
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
        string memory blockHeightStr = _substring(_blockHeightStr, int(bytes(_blockHeightStr).length) - 2, 2);
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

        uint256 bitcoin_chain_height = fetchBlockHeight();
        uint256 initialCheckpointHeight = bitcoin_chain_height - 6;
        bytes32 initialBlockHash = fetchBlockHash(initialCheckpointHeight);
        bytes32 initialRetargetBlockHash = fetchBlockHash(calculateRetargetHeight(initialCheckpointHeight - 2016));

        // Define the constructor arguments
        address verifierContractAddress = address(0x3B6041173B80E77f038f3F2C0f9744f04837185e);
        address depositTokenAddress = address(0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0);
        uint256 proverReward = 2 * 10 ** 6; // 2 USDT
        uint256 releaserReward = 1 * 10 ** 6; // 1 USDT
        bytes32 verificationKeyHash = hex"00ceafd1f633bae8a577468d4981b0812837a27e1652017199d87b836d71280a";
        address payable protocolAddress = payable(address(0x9FEEf1C10B8cD9Bc6c6B6B44ad96e07F805decaf));
        address owner = msg.sender;

        console.log("Deploying RiftExchange...");
        console.log("initialCheckpointHeight:", initialCheckpointHeight);
        console.log("initialBlockHash:");
        console.logBytes32(initialBlockHash);
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
                initialRetargetBlockHash,
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

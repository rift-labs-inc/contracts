// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

import {HeaderLib} from "./HeaderLib.sol";
import {UltraVerifier as HeaderStoragePlonkVerifier} from "./verifiers/HeaderStoragePlonkVerification.sol";
import "forge-std/console.sol";

error InvalidCheckpoint();
error BlockDoesNotExist();

contract BlockHashStorage {
    mapping(uint256 => bytes32) blockchain; // block height => block hash
    uint256 public currentHeight;

    constructor(uint256 checkpoint_height, bytes32 blockHash) {
        currentHeight = checkpoint_height;
        blockchain[checkpoint_height] = blockHash;
    }

    function addBlock(
        uint256 blockCheckpointHeight,
        uint256 blockHeight,
        bytes32 blockHash
    ) public {
        // TODO: make this interanal after testing
        // [0] validate checkpoint height
        uint _currentHeight = currentHeight;
        if (blockCheckpointHeight > _currentHeight) {
            revert InvalidCheckpoint();
        }

        // [1] check for new proposed longest chain and clear orphaned blocks
        if (
            blockCheckpointHeight < _currentHeight &&
            blockHeight >= _currentHeight
        ) {
            for (uint256 i = blockCheckpointHeight; i < _currentHeight; i++) {
                // check if block exists in mapping
                if (blockchain[i] != bytes32(0)) {
                    // clear orphaned block
                    delete blockchain[i]; // TODO: more effecient solution?
                }
            }
        }

        // [2] add new block to blockchain
        blockchain[blockHeight] = blockHash;
        currentHeight = blockHeight;
    }

    function validateBlockExists(uint256 blockHeight) public view {
        // check if block exists
        if (blockchain[blockHeight] == bytes32(0)) {
            revert BlockDoesNotExist();
        }
    }

    function getBlockHash(uint256 blockHeight) public view returns (bytes32) {
        return blockchain[blockHeight];
    }
}

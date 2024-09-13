// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

import {HeaderLib} from "./HeaderLib.sol";
import "forge-std/console.sol";

error InvalidSafeBlock();
error BlockDoesNotExist();
error InvalidConfirmationBlock();
error InvalidProposedBlockOverwrite();

contract BlockHashStorage {
    mapping(uint256 => bytes32) blockchain; // block height => block hash
    uint256 public currentHeight;
    uint256 public currentConfirmationHeight;
    // TODO: This needs to be 5 before mainnet launch
    uint8 constant MINIMUM_CONFIRMATION_DELTA = 1;

    event BlocksAdded(uint256 startBlockHeight, uint256 count);

    constructor(uint256 safeBlockHeight, bytes32 blockHash, bytes32 retargetBlockHash) {
        currentHeight = safeBlockHeight;
        blockchain[safeBlockHeight] = blockHash;
        blockchain[calculateRetargetHeight(uint64(safeBlockHeight))] = retargetBlockHash;
    }

    // TODO: make this interanal after testing
    function addBlock(
        uint256 safeBlockHeight,
        uint256 proposedBlockHeight,
        uint256 confirmationBlockHeight,
        bytes32[] memory blockHashes, // from safe block to confirmation block
        uint256 proposedBlockIndex // in blockHashes array
    ) public {
        uint _tipBlockHeight = currentHeight;

        // [0] ensure confirmation block matches block in blockchain (if < 5 away from proposed block)
        if (confirmationBlockHeight - proposedBlockHeight < MINIMUM_CONFIRMATION_DELTA) {
            if (blockHashes[blockHashes.length - 1] != blockchain[confirmationBlockHeight]) {
                revert InvalidConfirmationBlock();
            }
        }

        // [1] validate safeBlock height
        if (safeBlockHeight > _tipBlockHeight) {
            revert InvalidSafeBlock();
        }

        // [2] return if block already exists
        if (blockchain[proposedBlockHeight] == blockHashes[proposedBlockIndex]) {
            return;
        }
        // [3] ensure proposed block is not being overwritten unless longer chain (higher confirmation block height)
        else if (
            blockchain[proposedBlockHeight] != bytes32(0) && currentConfirmationHeight >= confirmationBlockHeight
        ) {
            revert InvalidProposedBlockOverwrite();
        }

        // [4] ADDITION/OVERWRITE (proposed block > tip block)
        if (proposedBlockHeight > _tipBlockHeight) {
            // [a] ADDITION - (safe block === tip block)
            if (safeBlockHeight == _tipBlockHeight) {
                blockchain[proposedBlockHeight] = blockHashes[proposedBlockIndex];
            }
            // [b] OVERWRITE - new longest chain (safe block < tip block < proposed block)
            else if (safeBlockHeight < _tipBlockHeight) {
                for (uint256 i = safeBlockHeight; i <= proposedBlockHeight; i++) {
                    blockchain[i] = blockHashes[i - safeBlockHeight];
                }
            }
        }
        // [5] INSERTION - (safe block < proposed block < tip block)
        else if (proposedBlockHeight < _tipBlockHeight) {
            blockchain[proposedBlockHeight] = blockHashes[proposedBlockIndex];
        }

        // [6] update current height
        if (proposedBlockHeight > currentHeight) {
            currentHeight = proposedBlockHeight;
        }

        emit BlocksAdded(safeBlockHeight, blockHashes.length);
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

    function calculateRetargetHeight(uint64 blockHeight) internal pure returns (uint64) {
        return blockHeight - (blockHeight % 2016);
    }
}

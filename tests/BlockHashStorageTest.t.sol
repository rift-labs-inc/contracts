// // SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { BlockHashStorage } from "../src/BlockHashStorage.sol";
import { TestBlocks } from "./TestBlocks.sol";

// exposes the internal block hash storage functions for testing
contract BlockHashProxy is BlockHashStorage {
    constructor(
        uint256 initialCheckpointHeight,
        uint256 currentChainwork,
        bytes32 initialBlockHash,
        bytes32 initialRetargetBlockHash,
        uint8 minimumConfirmationDelta
    )
        BlockHashStorage(
            initialCheckpointHeight,
            currentChainwork,
            initialBlockHash,
            initialRetargetBlockHash,
            minimumConfirmationDelta
        )
    { }

    function AddBlock(
        uint256 safeBlockHeight,
        uint256 proposedBlockHeight,
        uint256 confirmationBlockHeight,
        bytes32[] memory blockHashes,
        uint256[] memory blockChainworks,
        uint256 proposedBlockIndex
    ) public {
        addBlock(
            safeBlockHeight,
            proposedBlockHeight,
            confirmationBlockHeight,
            blockHashes,
            blockChainworks,
            proposedBlockIndex
        );
    }
}

contract BlockHashStorageTest is Test, TestBlocks {
    bytes4 constant INVALID_SAFE_BLOCK = bytes4(keccak256("InvalidSafeBlock()"));
    bytes4 constant BLOCK_DOES_NOT_EXIST = bytes4(keccak256("BlockDoesNotExist()"));
    bytes4 constant INVALID_CONFIRMATION_BLOCK = bytes4(keccak256("InvalidConfirmationBlock()"));
    bytes4 constant INVALID_PROPOSED_BLOCK_OVERWRITE = bytes4(keccak256("InvalidProposedBlockOverwrite()"));

    BlockHashProxy blockHashProxy;
    uint256 initialCheckpointHeight;

    function setUp() public {
        initialCheckpointHeight = blockHeights[0];
        blockHashProxy =
            new BlockHashProxy(initialCheckpointHeight, blockChainworks[0], blockHashes[0], retargetBlockHash, 5);
    }

    function inspectBlockchain(uint256 depth) public view {
        for (uint256 i = initialCheckpointHeight; i < depth + initialCheckpointHeight; i++) {
            console.log("Block ", i, ":");
            console.logBytes32(blockHashProxy.getBlockHash(i));
        }
    }

    function fetchBlockSubset(uint256 start, uint256 end) public view returns (bytes32[] memory) {
        bytes32[] memory subset = new bytes32[](end - start);
        for (uint256 i = start; i < end; i++) {
            subset[i - start] = blockHashes[i];
        }
        return subset;
    }

    function fakeBlocks(uint256 amount) public pure returns (bytes32[] memory) {
        bytes32[] memory blocks = new bytes32[](amount);
        for (uint256 i = 0; i < amount; i++) {
            blocks[i] = bytes32(uint256(i));
        }
        return blocks;
    }

    function fakeChainworks(uint256 amount) public pure returns (uint256[] memory) {
        uint256[] memory chainworks = new uint256[](amount);
        for (uint256 i = 0; i < amount; i++) {
            chainworks[i] = i;
        }
        return chainworks;
    }

    function fetchChainworkSubset(uint256 start, uint256 end) public view returns (uint256[] memory) {
        uint256[] memory subset = new uint256[](end - start);
        for (uint256 i = start; i < end; i++) {
            subset[i - start] = blockChainworks[i];
        }
        return subset;
    }

    function testSimpleAddBlocks() public {
        bytes32[] memory blocks = fetchBlockSubset(0, 5);
        uint256[] memory chainworks = fetchChainworkSubset(0, 5);
        blockHashProxy.AddBlock(blockHeights[0], blockHeights[1], blockHeights[6], blocks, chainworks, 1);
    }

    function testAddBlockFailsOnInvalidSafeBlock() public {
        bytes32[] memory blocks = fetchBlockSubset(0, 5);
        uint256[] memory chainworks = fetchChainworkSubset(0, 5);
        vm.expectRevert(INVALID_SAFE_BLOCK);
        blockHashProxy.AddBlock(blockHeights[1], blockHeights[1], blockHeights[6], blocks, chainworks, 1);
    }

    function testAddBlocksFailsOnInvalidConfirmationBlock() public {
        bytes32[] memory blocks = fetchBlockSubset(0, 5);
        uint256[] memory chainworks = fetchChainworkSubset(0, 5);
        vm.expectRevert(INVALID_CONFIRMATION_BLOCK);
        blockHashProxy.AddBlock(blockHeights[0], blockHeights[1], blockHeights[5], blocks, chainworks, 1);
    }

    function testAddBlockDoesNothingWhenProposedBlockExists() public {
        bytes32[] memory blocks = fetchBlockSubset(0, 5);
        uint256[] memory chainworks = fetchChainworkSubset(0, 5);
        blockHashProxy.AddBlock(blockHeights[0], blockHeights[1], blockHeights[6], blocks, chainworks, 1);
        blockHashProxy.AddBlock(blockHeights[0], blockHeights[1], blockHeights[6], blocks, chainworks, 1);
    }

    function testAddsRetargetBlockWhenRetargetBlockChangesMidAdd() public {
        bytes32[] memory blocks = fakeBlocks(1563);
        uint256[] memory chainworks = fakeChainworks(1563);
        console.log("BlockHeights", blockHeights[0]);
        uint256 safe_height = 861295;
        uint256 proposed_height = 862848;
        uint256 confirmation_height = 862858;
        blockHashProxy.AddBlock(safe_height, proposed_height, confirmation_height, blocks, chainworks, 1552);
        console.log("retarget block new theo");
        console.logBytes32(blockHashProxy.getBlockHash(862848));
        console.log("retarget block new theo -1");
        console.logBytes32(blockHashProxy.getBlockHash(862847));
        console.log("retarget block new theo +1");
        console.logBytes32(blockHashProxy.getBlockHash(862849));
    }

    function testAddsRetargetBlockWhenRetargetBlockIsConfirmationBlock() public {
        bytes32[] memory blocks = fakeBlocks(1554);
        uint256[] memory chainworks = fakeChainworks(1554);
        console.log("BlockHeights", blockHeights[0]);
        uint256 safe_height = 861295;
        uint256 proposed_height = 862843;
        uint256 confirmation_height = 862849;
        blockHashProxy.AddBlock(
            safe_height, proposed_height, confirmation_height, blocks, chainworks, proposed_height - safe_height
        );
        console.log("retarget block new theo");
        console.logBytes32(blockHashProxy.getBlockHash(862848));
        console.log("retarget block new theo -1");
        console.logBytes32(blockHashProxy.getBlockHash(862847));
        console.log("retarget block new theo +1");
        console.logBytes32(blockHashProxy.getBlockHash(862849));
    }
}

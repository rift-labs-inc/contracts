// // SPDX-License-Identifier: Unlicensed
// pragma solidity ^0.8.0;

// import { Test } from 'forge-std/Test.sol';
// import { console } from 'forge-std/console.sol';
// import { BlockHeaderStorage } from '../src/BlockHeaderStorage.sol';

// contract BlockHeaderStorageTest is Test {
//     bytes4 constant INVALID_CHECKPOINT = bytes4(keccak256('InvalidCheckpoint()'));
//     bytes4 constant BLOCK_DOES_NOT_EXIST = bytes4(keccak256('BlockDoesNotExist()'));

//     BlockHeaderStorage blockHeaderStorage;
//     bytes32 genesisBlockHash = keccak256('genesis block');

//     function setUp() public {
//         console.log('Deploying BlockHeaderStorage contract with genesis block...');
//         blockHeaderStorage = new BlockHeaderStorage(0, genesisBlockHash);
//         console.log('BlockHeaderStorage contract deployed at', address(blockHeaderStorage));
//     }

//     function testAddBlock() public {
//         console.log('Testing addBlock function...');

//         // Adding a new block at height 1
//         bytes32 blockHash1 = keccak256('block 1');
//         blockHeaderStorage.addBlock(0, 1, blockHash1);
//         console.log('Added block 1');

//         bytes32 storedBlockHash1 = blockHeaderStorage.getBlockHash(1);
//         assertEq(storedBlockHash1, blockHash1, 'Block hash mismatch for block 1');

//         // Adding a new block at height 2
//         bytes32 blockHash2 = keccak256('block 2');
//         blockHeaderStorage.addBlock(1, 2, blockHash2);
//         console.log('Added block 2');

//         bytes32 storedBlockHash2 = blockHeaderStorage.getBlockHash(2);
//         assertEq(storedBlockHash2, blockHash2, 'Block hash mismatch for block 2');

//         // Edge case: Adding a block with a future checkpoint height (should revert)
//         console.log('Testing edge case: Adding a block with a future checkpoint height...');
//         vm.expectRevert(INVALID_CHECKPOINT);
//         blockHeaderStorage.addBlock(3, 4, keccak256('block 4'));

//         // Edge case: Validate block existence for non-existing block (should revert)
//         console.log('Testing edge case: Validate block existence for non-existing block...');
//         vm.expectRevert(BLOCK_DOES_NOT_EXIST);
//         blockHeaderStorage.validateBlockExists(5);

//         console.log('Finished testing addBlock function.');
//     }

//     function testOrphanedBlocks() public {
//         console.log('Testing handling of orphaned blocks...');

//         // Adding blocks
//         bytes32 blockHash1 = keccak256('block 1');
//         bytes32 blockHash2 = keccak256('block 2');
//         blockHeaderStorage.addBlock(0, 1, blockHash1);
//         blockHeaderStorage.addBlock(1, 2, blockHash2);

//         // Adding a block that will orphan block 1 and block 2
//         bytes32 newBlockHash2 = keccak256('new block 2');
//         blockHeaderStorage.addBlock(0, 2, newBlockHash2);
//         console.log('block 1 should be cleared');
//         console.log('BLOCK 1: ');
//         console.logBytes32(blockHeaderStorage.getBlockHash(1));

//         // Check that block 1 and old block 2 are orphaned
//         vm.expectRevert(BLOCK_DOES_NOT_EXIST);
//         blockHeaderStorage.validateBlockExists(1);

//         bytes32 storedNewBlockHash2 = blockHeaderStorage.getBlockHash(2);
//         // console.log("Stored new block hash for block 2:", storedNewBlockHash2);
//         assertEq(storedNewBlockHash2, newBlockHash2, 'Block hash mismatch for new block 2');

//         console.log('Finished testing handling of orphaned blocks.');
//     }

//     function testValidateBlockExists() public {
//         console.log('Testing validateBlockExists function...');

//         // Adding a new block
//         bytes32 blockHash1 = keccak256('block 1');
//         blockHeaderStorage.addBlock(0, 1, blockHash1);
//         console.log('Added block 1');

//         // Getting the block hash
//         bytes32 storedBlockHash1 = blockHeaderStorage.getBlockHash(1);
//         // console.log("Stored block hash for block 1:", storedBlockHash1);
//         assertEq(storedBlockHash1, blockHash1, 'Block hash mismatch for block 1');

//         // Edge case: Getting block hash for non-existing block (should revert)
//         console.log('Testing edge case: Getting block hash for non-existing block...');
//         vm.expectRevert(BLOCK_DOES_NOT_EXIST);
//         blockHeaderStorage.validateBlockExists(2);

//         console.log('Finished testing validateBlockExists function.');
//     }
// }

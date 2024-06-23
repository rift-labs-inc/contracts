// // SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

// import {Test} from "forge-std/Test.sol";
// import {Vm} from "forge-std/Vm.sol";
// import {HeaderStorage} from "../src/HeaderStorage.sol";
// import "forge-std/console.sol";
// import {HeaderLib} from "../src/HeaderLib.sol";
// import {TestLib} from "./data/TestLib.sol";
// import {TestLibOmmer} from "./data/TestLibOmmer.sol";

// contract TestHeaderStorageDefault is Test {
//     HeaderStorage public blockData;

//     TestLib.ProposedBlock public first_block = TestLib.getTestBlocks()[0];

//     function setUp() public {
//         blockData = new HeaderStorage({
//             checkpoint_height: first_block.proposed_height,
//             block_hash: first_block.block_hash,
//             version: first_block.version,
//             prev_block_hash: first_block.prev_block_hash,
//             merkle_root: first_block.merkle_root,
//             timestamp: first_block.timestamp,
//             bits: first_block.bits,
//             nonce: first_block.nonce
//         });
//     }

//     function testGetSafeBlock() public {
//         blockData.getBlockSafe(first_block.proposed_height);
//     }

//     function testGetUnsafeBlock() public {
//         blockData.getBlockUnsafe(first_block.proposed_height);
//     }

//     function testGetSafeMerkleRoot() public {
//         blockData.getMerkleRootSafe(first_block.proposed_height);
//     }

//     function testFirstBlockIsSet() public {
//         assert(
//             blockData.getBlockUnsafe(first_block.proposed_height).block_hash ==
//                 first_block.block_hash
//         );
//     }

//     function testAddBlockToGenesis() public {
//         TestLib.ProposedBlock memory second_block = TestLib.getTestBlocks()[1];
//         blockData.proposeNewBlock({
//             block_hash: second_block.block_hash,
//             version: second_block.version,
//             prev_block_hash: second_block.prev_block_hash,
//             merkle_root: second_block.merkle_root,
//             timestamp: second_block.timestamp,
//             bits: second_block.bits,
//             nonce: second_block.nonce,
//             proof: second_block.proof
//         });
//         // If this doesn't fail the proof succeeded
//     }

//     function testAddBlockToFirstBlock() public {
//         TestLib.ProposedBlock memory second_block = TestLib.getTestBlocks()[1];
//         blockData.proposeNewBlock({
//             block_hash: second_block.block_hash,
//             version: second_block.version,
//             prev_block_hash: second_block.prev_block_hash,
//             merkle_root: second_block.merkle_root,
//             timestamp: second_block.timestamp,
//             bits: second_block.bits,
//             nonce: second_block.nonce,
//             proof: second_block.proof
//         });
//         TestLib.ProposedBlock memory third_block = TestLib.getTestBlocks()[2];
//         blockData.proposeNewBlock({
//             block_hash: third_block.block_hash,
//             version: third_block.version,
//             prev_block_hash: third_block.prev_block_hash,
//             merkle_root: third_block.merkle_root,
//             timestamp: third_block.timestamp,
//             bits: third_block.bits,
//             nonce: third_block.nonce,
//             proof: third_block.proof
//         });
//         // If this doesn't fail the proof succeeded
//     }
// }

// contract TestOmmerHeaderStorage is Test {
//     HeaderStorage public blockHeaderStorage;

//     // Grabbed from Plonk_vk.sol:
//     bytes4 internal PROOF_FAILURE_SELECTOR = 0x0711fcec;

//     // Grabbed from BitcoinBlockData.sol:
//     bytes4 internal NOT_LONGEST_CHAIN_SELECTOR = 0x76d70265;

//     // Known block height with stale block
//     uint256 internal divergent_block = 449695;

//     TestLibOmmer.ProposedBlock[] internal sync_blocks;

//     function setUp() public {
//         // Set test blocks in storage
//         TestLibOmmer.ProposedBlock[] memory test_blocks_mem = TestLibOmmer
//             .getTestBlocks();

//         for (uint256 i = 0; i < test_blocks_mem.length; i++) {
//             sync_blocks.push(test_blocks_mem[i]);
//         }

//         assert(
//             sync_blocks[sync_blocks.length - 1].block_hash ==
//                 test_blocks_mem[test_blocks_mem.length - 1].block_hash
//         );

//         blockHeaderStorage = new HeaderStorage({
//             checkpoint_height: sync_blocks[0].proposed_height,
//             block_hash: sync_blocks[0].block_hash,
//             version: sync_blocks[0].version,
//             prev_block_hash: sync_blocks[0].prev_block_hash,
//             merkle_root: sync_blocks[0].merkle_root,
//             timestamp: sync_blocks[0].timestamp,
//             bits: sync_blocks[0].bits,
//             nonce: sync_blocks[0].nonce
//         });
//     }

//     function syncToDivergentBlock() public {
//         for (uint256 i = 1; i < sync_blocks.length; i++) {
//             blockHeaderStorage.proposeNewBlock({
//                 block_hash: sync_blocks[i].block_hash,
//                 version: sync_blocks[i].version,
//                 prev_block_hash: sync_blocks[i].prev_block_hash,
//                 merkle_root: sync_blocks[i].merkle_root,
//                 timestamp: sync_blocks[i].timestamp,
//                 bits: sync_blocks[i].bits,
//                 nonce: sync_blocks[i].nonce,
//                 proof: sync_blocks[i].proof
//             });
//         }
//     }

//     function testFirstBlockIsSet() public {
//         assert(
//             blockHeaderStorage
//                 .getBlockUnsafe(sync_blocks[0].proposed_height)
//                 .block_hash == sync_blocks[0].block_hash
//         );
//     }

//     // smoke test that sync logic works and we have blocks in the data lib that go up to our divergent block
//     function testLongSyncWorks() public {
//         syncToDivergentBlock();
//         assert(blockHeaderStorage.current_height() == divergent_block - 1);
//     }

//     function testMainBlocksAreValidWithNoDivergence() public {
//         syncToDivergentBlock();
//         TestLibOmmer.ProposedBlock memory main_block = TestLibOmmer
//             .getMainBlockHeader();
//         blockHeaderStorage.proposeNewBlock({
//             block_hash: main_block.block_hash,
//             version: main_block.version,
//             prev_block_hash: main_block.prev_block_hash,
//             merkle_root: main_block.merkle_root,
//             timestamp: main_block.timestamp,
//             bits: main_block.bits,
//             nonce: main_block.nonce,
//             proof: main_block.proof
//         });

//         TestLibOmmer.ProposedBlock memory second_main_block = TestLibOmmer
//             .getBlockHeaderAfterMainHeader();
//         blockHeaderStorage.proposeNewBlock({
//             block_hash: second_main_block.block_hash,
//             version: second_main_block.version,
//             prev_block_hash: second_main_block.prev_block_hash,
//             merkle_root: second_main_block.merkle_root,
//             timestamp: second_main_block.timestamp,
//             bits: second_main_block.bits,
//             nonce: second_main_block.nonce,
//             proof: second_main_block.proof
//         });
//     }

//     // This tries to send invalid blocks
//     function testProposeMethodsAreResilientToFaultyOverwrites() public {
//         syncToDivergentBlock();
//         // now we set the known stale block
//         TestLibOmmer.ProposedBlock memory stale_block = TestLibOmmer
//             .getDivergentBlockHeader();
//         blockHeaderStorage.proposeNewBlock({
//             block_hash: stale_block.block_hash,
//             version: stale_block.version,
//             prev_block_hash: stale_block.prev_block_hash,
//             merkle_root: stale_block.merkle_root,
//             timestamp: stale_block.timestamp,
//             bits: stale_block.bits,
//             nonce: stale_block.nonce,
//             proof: stale_block.proof
//         });

//         TestLibOmmer.ProposedBlock memory main_block = TestLibOmmer
//             .getMainBlockHeader();
//         // now let's try to propose the known main block at the same height (this should fail) using proposeNewBlock
//         vm.expectRevert(PROOF_FAILURE_SELECTOR);
//         blockHeaderStorage.proposeNewBlock({
//             block_hash: main_block.block_hash,
//             version: main_block.version,
//             prev_block_hash: main_block.prev_block_hash,
//             merkle_root: main_block.merkle_root,
//             timestamp: main_block.timestamp,
//             bits: main_block.bits,
//             nonce: main_block.nonce,
//             proof: main_block.proof
//         });

//         bytes32[] memory proposed_block_hashes = new bytes32[](1);
//         uint32[] memory proposed_versions = new uint32[](1);
//         bytes32[] memory proposed_prev_block_hashes = new bytes32[](1);
//         bytes32[] memory proposed_merkle_roots = new bytes32[](1);
//         uint32[] memory proposed_timestamps = new uint32[](1);
//         uint32[] memory proposed_bits = new uint32[](1);
//         uint32[] memory proposed_nonces = new uint32[](1);
//         bytes[] memory proposed_proofs = new bytes[](1);

//         proposed_block_hashes[0] = main_block.block_hash;
//         proposed_versions[0] = main_block.version;
//         proposed_prev_block_hashes[0] = main_block.prev_block_hash;
//         proposed_merkle_roots[0] = main_block.merkle_root;
//         proposed_timestamps[0] = main_block.timestamp;
//         proposed_bits[0] = main_block.bits;
//         proposed_nonces[0] = main_block.nonce;
//         proposed_proofs[0] = main_block.proof;

//         // Okay now let's try to use the ommer-specific method,
//         // this should fail again b/c we can't propose a divergent block unless we can prove we have a longer chain
//         vm.expectRevert(NOT_LONGEST_CHAIN_SELECTOR);
//         blockHeaderStorage.proposeBlocksToLongestChain({
//             checkpoint_height: divergent_block - 1,
//             _block_hashes: proposed_block_hashes,
//             _versions: proposed_versions,
//             _prev_block_hashes: proposed_prev_block_hashes,
//             _merkle_roots: proposed_merkle_roots,
//             _timestamps: proposed_timestamps,
//             _bits: proposed_bits,
//             _nonces: proposed_bits,
//             proof: proposed_proofs
//         });
//     }

//     function testSuccessfullyOverwriteDivergentChain() public {
//         syncToDivergentBlock();
//         // now we set the known stale block
//         TestLibOmmer.ProposedBlock memory stale_block = TestLibOmmer
//             .getDivergentBlockHeader();
//         blockHeaderStorage.proposeNewBlock({
//             block_hash: stale_block.block_hash,
//             version: stale_block.version,
//             prev_block_hash: stale_block.prev_block_hash,
//             merkle_root: stale_block.merkle_root,
//             timestamp: stale_block.timestamp,
//             bits: stale_block.bits,
//             nonce: stale_block.nonce,
//             proof: stale_block.proof
//         });

//         TestLibOmmer.ProposedBlock memory main_block = TestLibOmmer
//             .getMainBlockHeader();
//         TestLibOmmer.ProposedBlock memory second_main_block = TestLibOmmer
//             .getBlockHeaderAfterMainHeader();

//         bytes32[] memory proposed_block_hashes = new bytes32[](2);
//         uint32[] memory proposed_versions = new uint32[](2);
//         bytes32[] memory proposed_prev_block_hashes = new bytes32[](2);
//         bytes32[] memory proposed_merkle_roots = new bytes32[](2);
//         uint32[] memory proposed_timestamps = new uint32[](2);
//         uint32[] memory proposed_bits = new uint32[](2);
//         uint32[] memory proposed_nonces = new uint32[](2);
//         bytes[] memory proposed_proofs = new bytes[](2);

//         proposed_block_hashes[0] = main_block.block_hash;
//         proposed_versions[0] = main_block.version;
//         proposed_prev_block_hashes[0] = main_block.prev_block_hash;
//         proposed_merkle_roots[0] = main_block.merkle_root;
//         proposed_timestamps[0] = main_block.timestamp;
//         proposed_bits[0] = main_block.bits;
//         proposed_nonces[0] = main_block.nonce;
//         proposed_proofs[0] = main_block.proof;

//         proposed_block_hashes[1] = second_main_block.block_hash;
//         proposed_versions[1] = second_main_block.version;
//         proposed_prev_block_hashes[1] = second_main_block.prev_block_hash;
//         proposed_merkle_roots[1] = second_main_block.merkle_root;
//         proposed_timestamps[1] = second_main_block.timestamp;
//         proposed_bits[1] = second_main_block.bits;
//         proposed_nonces[1] = second_main_block.nonce;
//         proposed_proofs[1] = second_main_block.proof;

//         // Okay now let's try to use the ommer-specific method,
//         // this should succeed now b/c we can prove we have a longer chain
//         blockHeaderStorage.proposeBlocksToLongestChain({
//             checkpoint_height: divergent_block - 1,
//             _block_hashes: proposed_block_hashes,
//             _versions: proposed_versions,
//             _prev_block_hashes: proposed_prev_block_hashes,
//             _merkle_roots: proposed_merkle_roots,
//             _timestamps: proposed_timestamps,
//             _bits: proposed_bits,
//             _nonces: proposed_nonces,
//             proof: proposed_proofs
//         });
//     }
// }

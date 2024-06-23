// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

// TODO: Potentially reorg elements to be more storage efficient?

import 'forge-std/console.sol';

library HeaderLib {
    struct Block {
        uint32 bits;
        bytes32 block_hash;
        bytes32 merkle_root;
        uint32 nonce;
        bytes32 prev_block_hash;
        uint32 timestamp;
        uint32 version;
    }

    struct ProposedBlock {
        uint256 _current_height;
        bytes32 _block_hash;
        uint32 _version;
        bytes32 _prev_block_hash;
        bytes32 _merkle_root;
        uint32 _timestamp;
        uint32 _bits;
        uint32 _nonce;
        bytes proof;
    }

    struct PublicInput {
        bytes32 previous_block_hash;
        uint256 last_block_height;
        uint256 retarget_block_bits;
        uint256 retarget_block_height;
        uint256 retarget_block_timestamp;
        bytes32 proposed_block_hash;
        uint256 proposed_block_height;
        uint32 proposed_block_version;
        bytes32 proposed_block_prev_hash;
        bytes32 proposed_block_merkle_root;
        uint32 proposed_block_timestamp;
        uint32 proposed_block_bits;
        uint32 proposed_block_nonce;
    }

    /*
    // From circuit
    struct ProposedBlock {
    block_hash: [u8; 32],
    height: Field,
    version: Field,
    prev_block_hash: [u8; 32],
    merkle_root: [u8; 32],
    timestamp: Field,
    bits: Field,
    nonce: Field,
    }

    struct RetargetBlock {
    bits: Field,
    height: Field,
    timestamp: Field
    }

    fn main(
    previous_block_hash: pub [u8; 32], // from contract
    previous_block_height: pub u32, // from contract
    retarget_block: pub RetargetBlock, // from contract
    proposed_block: pub ProposedBlock // from indexer
    )

    byte slots in public input:
    0 -> 32 : prev block hash;
    32: last_block_height;
    33: retarget_block_bits;
    34: retarget_block_height;
       35: retarget_block_timestamp;
    36 -> 68: proposed_block_hash;
    68: proposed_block_height;
    69: proposed_block_version;
    70 -> 102: proposed_block_prev_hash;
    102 -> 134: proposed_block_merkle_root;
    134: proposed_block_timestamp;
       135: proposed_block_bits;
       136: proposed_block_nonce;
    */

    function toLittleEndian(bytes32 data) internal pure returns (bytes32) {
        bytes32 result;
        for (uint256 i = 0; i < 32; i++) {
            result |= ((data >> (i * 8)) & bytes32(uint256(0xFF))) << ((31 - i) * 8);
        }
        return result;
    }

    function generatePublicInput(PublicInput memory input) internal pure returns (bytes32[] memory) {
        bytes32[] memory publicInputs = new bytes32[](137);
        for (uint256 i; i < 32; i++) {
            publicInputs[i] = toLittleEndian(bytes32(input.previous_block_hash[i]));
        }
        publicInputs[32] = bytes32(input.last_block_height);
        publicInputs[33] = bytes32(input.retarget_block_bits);
        publicInputs[34] = bytes32(input.retarget_block_height);
        publicInputs[35] = bytes32(input.retarget_block_timestamp);
        for (uint256 i; i < 32; i++) {
            publicInputs[36 + i] = toLittleEndian(bytes32(input.proposed_block_hash[i]));
        }
        publicInputs[68] = bytes32(input.proposed_block_height);
        publicInputs[69] = bytes32(uint256(input.proposed_block_version));
        for (uint256 i; i < 32; i++) {
            publicInputs[70 + i] = toLittleEndian(bytes32(input.proposed_block_prev_hash[i]));
        }
        for (uint256 i; i < 32; i++) {
            publicInputs[102 + i] = toLittleEndian(bytes32(input.proposed_block_merkle_root[i]));
        }
        publicInputs[134] = bytes32(uint256(input.proposed_block_timestamp));
        publicInputs[135] = bytes32(uint256(input.proposed_block_bits));
        publicInputs[136] = bytes32(uint256(input.proposed_block_nonce));

        // Debugging the output
        /*
    for (uint i; i < publicInputs.length; i++){
    console.logBytes(abi.encodePacked(publicInputs[i]));
    }
        */
        return publicInputs;
    }
}

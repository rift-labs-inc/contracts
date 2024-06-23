// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

/*
import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
// import {Swap} from "../src/Swap.sol";
import "forge-std/console.sol";
import {HeaderLib} from "../src/HeaderLib.sol";
import {TestLib} from "./data/TestLib.sol";
import {TestLibOmmer} from "./data/TestLibOmmer.sol";

contract TestBridgeContract is Test {
    HeaderStorage public blockData;

    function setUp() public {
        blockData = new HeaderStorage({
            checkpoint_height: first_block.proposed_height,
            block_hash: first_block.block_hash,
            version: first_block.version,
            prev_block_hash: first_block.prev_block_hash,
            merkle_root: first_block.merkle_root,
            timestamp: first_block.timestamp,
            bits: first_block.bits,
            nonce: first_block.nonce
        });
    }

    function testFirstBlockIsSet() public {
        assert(
            blockData.getBlockUnsafe(first_block.proposed_height).block_hash ==
                first_block.block_hash
        );
    }
}
*/

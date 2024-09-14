// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { RiftExchange } from "../src/RiftExchange.sol";
import { WETH } from "../lib/solmate/src/tokens/WETH.sol";
import { ERC20 } from "../lib/solmate/src/tokens/ERC20.sol";
import { TestBlocks } from "./TestBlocks.sol";

// Mock USDT contract
contract MockUSDT is ERC20 {
    constructor() ERC20("Tether USD", "USDT", 6) { } // USDT has 6 decimals

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract MockVerifier {
    function verifyProof(bytes32 programVKey, bytes calldata publicValues, bytes calldata proofBytes) external view { }
}

contract ExchangeTestBase is Test, TestBlocks {
    RiftExchange riftExchange;
    MockUSDT usdt;
    address testAddress = address(0x69696969);
    address lp1 = address(0x69);
    address lp2 = address(0x69420);
    address lp3 = address(0x6969);
    address buyer1 = address(0x111111);
    address buyer2 = address(0x222222);
    address buyer3 = address(0x333333);
    address hypernode1 = address(0x444444);

    bytes4 constant DEPOSIT_TOO_LOW = bytes4(keccak256("DepositTooLow()"));
    bytes4 constant INVALID_VAULT_UPDATE = bytes4(keccak256("InvalidVaultUpdate()"));
    bytes4 constant NOT_VAULT_OWNER = bytes4(keccak256("NotVaultOwner()"));
    bytes4 constant DEPOSIT_TOO_HIGH = bytes4(keccak256("DepositTooHigh()"));
    bytes4 constant INVALID_BTC_PAYOUT_ADDRESS = bytes4(keccak256("InvalidBitcoinAddress()"));
    bytes4 constant RESERVATION_FEE_TOO_LOW = bytes4(keccak256("ReservationFeeTooLow()"));
    bytes4 constant INVALID_UPDATE_WITH_ACTIVE_RESERVATIONS = bytes4(keccak256("InvalidUpdateWithActiveReservations()"));
    bytes4 constant NOT_ENOUGH_LIQUIDITY = bytes4(keccak256("NotEnoughLiquidity()"));
    bytes4 constant RESERVATION_AMOUNT_TOO_LOW = bytes4(keccak256("ReservationAmountTooLow()"));
    bytes4 constant RESERVATION_EXPIRED = bytes4(keccak256("ReservationExpired()"));

    function setUp() public {
        bytes32 initialBlockHash = blockHashes[0];
        bytes32 initialRetargetBlockHash = retargetBlockHash;
        uint256 initialCheckpointHeight = blockHeights[0];
        address verifierContractAddress = address(new MockVerifier());
        uint8 minimumConfirmationDelta = 5;

        usdt = new MockUSDT();

        uint256 proverReward = 2 * 10 ** 6; // 2 USDT
        uint256 releaserReward = 1 * 10 ** 6; // 1 USDT
        address payable protocolAddress = payable(address(this));

        riftExchange = new RiftExchange(
            initialCheckpointHeight,
            initialBlockHash,
            initialRetargetBlockHash,
            verifierContractAddress,
            address(usdt),
            proverReward,
            releaserReward,
            protocolAddress,
            protocolAddress,
            hex"deadbeef",
            minimumConfirmationDelta
        );
    }
}

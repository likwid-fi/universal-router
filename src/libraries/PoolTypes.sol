// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

/// @title PoolTypes
/// @notice Flags used to decode pool types
library Commands {
    // Masks to extract certain bits of pool types
    bytes1 internal constant POOL_TYPE_MASK = 0x0f;

    uint256 constant LIKWID_V2 = 0x00;
    uint256 constant UNISWAP_V2 = 0x01;
    uint256 constant UNISWAP_V3 = 0x02;
    uint256 constant UNISWAP_V4 = 0x03;
    uint256 constant PANCAKE_SWAP_V2 = 0x04;
    uint256 constant PANCAKE_SWAP_STABLE = 0x05;
    uint256 constant PANCAKE_SWAP_V3 = 0x06;
    uint256 constant PANCAKE_SWAP_INFINITY_CL = 0x07;
    uint256 constant PANCAKE_SWAP_INFINITY_BIN = 0x08;
}

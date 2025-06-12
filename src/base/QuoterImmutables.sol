// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

struct QuoterParameters {
    address weth9;
    // uniswap
    address uniswapV2Router;
    address uniswapV3Quoter;
    address uniswapV4Quoter;
    // pancakeswap
    address stableFactory;
    address stableInfo;
    address pancakeswapV2Router;
    address pancakeswapV3Quoter;
    address infiClQuoter;
    address infiBinQuoter;
}

/// @title Quoter Immutable Storage contract
/// @notice Used along with the `QuoterParameters` struct for ease of cross-chain deployment
contract QuoterImmutables {
    /// @dev WETH9 address
    address internal immutable WETH9;
    address internal immutable UNISWAP_V2_ROUTER;
    address internal immutable UNISWAP_V3_QUOTER;
    address internal immutable UNISWAP_V4_QUOTER;
    address internal immutable STABLE_FACTORY;
    address internal immutable STABLE_INFO;
    address internal immutable PANCAKESWAP_V2_ROUTER;
    address internal immutable PANCAKESWAP_V3_QUOTER;
    address internal immutable INFI_CL_QUOTER;
    address internal immutable INFI_BIN_QUOTER;

    constructor(QuoterParameters memory params) {
        WETH9 = params.weth9;
        UNISWAP_V2_ROUTER = params.uniswapV2Router;
        UNISWAP_V3_QUOTER = params.uniswapV3Quoter;
        UNISWAP_V4_QUOTER = params.uniswapV4Quoter;
        STABLE_FACTORY = params.stableFactory;
        STABLE_INFO = params.stableInfo;
        PANCAKESWAP_V2_ROUTER = params.pancakeswapV2Router;
        PANCAKESWAP_V3_QUOTER = params.pancakeswapV3Quoter;
        INFI_CL_QUOTER = params.infiClQuoter;
        INFI_BIN_QUOTER = params.infiBinQuoter;
    }
}

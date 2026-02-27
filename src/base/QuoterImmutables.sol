// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import {IV2Quoter} from "../interfaces/IV2Quoter.sol";
import {IV3Quoter} from "../interfaces/IV3Quoter.sol";
import {IV4Quoter} from "../interfaces/IV4Quoter.sol";
import {IInfinityQuoter} from "../interfaces/IInfinityQuoter.sol";
import {ILikwidQuoter} from "../interfaces/ILikwidQuoter.sol";

struct QuoterParameters {
    address weth9;
    // likwid
    address likwidQuoter;
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
    ILikwidQuoter internal immutable LIKWID_QUOTER;
    IV2Quoter internal immutable UNISWAP_V2_QUOTER;
    IV3Quoter internal immutable UNISWAP_V3_QUOTER;
    IV4Quoter internal immutable UNISWAP_V4_QUOTER;
    address internal immutable STABLE_FACTORY;
    address internal immutable STABLE_INFO;
    IV2Quoter internal immutable PANCAKESWAP_V2_QUOTER;
    IV3Quoter internal immutable PANCAKESWAP_V3_QUOTER;
    IInfinityQuoter internal immutable INFI_CL_QUOTER;
    IInfinityQuoter internal immutable INFI_BIN_QUOTER;

    constructor(QuoterParameters memory params) {
        WETH9 = params.weth9;
        LIKWID_QUOTER = ILikwidQuoter(params.likwidQuoter);
        UNISWAP_V2_QUOTER = IV2Quoter(params.uniswapV2Router);
        UNISWAP_V3_QUOTER = IV3Quoter(params.uniswapV3Quoter);
        UNISWAP_V4_QUOTER = IV4Quoter(params.uniswapV4Quoter);
        STABLE_FACTORY = params.stableFactory;
        STABLE_INFO = params.stableInfo;
        PANCAKESWAP_V2_QUOTER = IV2Quoter(params.pancakeswapV2Router);
        PANCAKESWAP_V3_QUOTER = IV3Quoter(params.pancakeswapV3Quoter);
        INFI_CL_QUOTER = IInfinityQuoter(params.infiClQuoter);
        INFI_BIN_QUOTER = IInfinityQuoter(params.infiBinQuoter);
    }
}

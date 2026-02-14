// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import {IWETH9} from "../interfaces/IWETH9.sol";

struct RouterParameters {
    address weth9;
    // uniswap
    address uniswapV2Factory;
    address uniswapV3Factory;
    address uniswapPoolManager;
    // pancakeswap
    address stableFactory;
    address stableInfo;
    address pancakeswapV2Factory;
    address pancakeswapV3Factory;
    address infiVault;
    address infiClPoolManager;
    address infiBinPoolManager;
    // likwid
    address likwidVault;
}

/// @title Router Immutable Storage contract
/// @notice Used along with the `RouterParameters` struct for ease of cross-chain deployment
contract RouterImmutables {
    /// @dev WETH9 address
    IWETH9 internal immutable WETH9;
    address internal immutable UNISWAP_V3_FACTORY;
    address internal immutable PANCAKESWAP_V3_FACTORY;
    mapping(address => uint24) V2FactoryToFee;

    constructor(RouterParameters memory params) {
        WETH9 = IWETH9(params.weth9);
        UNISWAP_V3_FACTORY = params.uniswapV3Factory;
        PANCAKESWAP_V3_FACTORY = params.pancakeswapV3Factory;
        V2FactoryToFee[params.uniswapV2Factory] = 30; // 0.3% fee for uniswap v2
        V2FactoryToFee[params.pancakeswapV2Factory] = 25; // 0.25% fee for pancakeswap v2
    }
}

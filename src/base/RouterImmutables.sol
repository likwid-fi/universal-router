// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import {IWETH9} from "../interfaces/IWETH9.sol";

struct RouterParameters {
    address weth9;
    address uniswapV2Factory;
    address uniswapV3Factory;
    address pancakeswapV2Factory;
    address pancakeswapV3Factory;
}

/// @title Router Immutable Storage contract
/// @notice Used along with the `RouterParameters` struct for ease of cross-chain deployment
contract RouterImmutables {
    /// @dev WETH9 address
    IWETH9 internal immutable WETH9;
    address internal immutable UNISWAP_V2_FACTORY;
    address internal immutable UNISWAP_V3_FACTORY;
    address internal immutable PANCAKESWAP_V2_FACTORY;
    address internal immutable PANCAKESWAP_V3_FACTORY;

    constructor(RouterParameters memory params) {
        WETH9 = IWETH9(params.weth9);
        UNISWAP_V2_FACTORY = params.uniswapV2Factory;
        UNISWAP_V3_FACTORY = params.uniswapV3Factory;
        PANCAKESWAP_V2_FACTORY = params.pancakeswapV2Factory;
        PANCAKESWAP_V3_FACTORY = params.pancakeswapV3Factory;
    }
}

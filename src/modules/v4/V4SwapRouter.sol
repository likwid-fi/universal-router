// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {Payments} from "../Payments.sol";
import {V4Router} from "./V4Router.sol";

/// @title Router for Uniswap v4 Trades
abstract contract V4SwapRouter is V4Router, Payments {
    constructor(address _poolManager) V4Router(IPoolManager(_poolManager)) {}

    function _pay(Currency token, address payer, uint256 amount) internal override {
        payFrom(Currency.unwrap(token), payer, address(poolManager), amount);
    }
}

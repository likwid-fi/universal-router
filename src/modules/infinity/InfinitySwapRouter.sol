// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.24;

import {Payments} from "../Payments.sol";
import {InfinityRouter} from "infinity-periphery/src/InfinityRouter.sol";
import {IVault} from "infinity-core/src/interfaces/IVault.sol";
import {ICLPoolManager} from "infinity-core/src/pool-cl/interfaces/ICLPoolManager.sol";
import {IBinPoolManager} from "infinity-core/src/pool-bin/interfaces/IBinPoolManager.sol";
import {Currency} from "infinity-core/src/types/Currency.sol";

/// @title Router for PCS Infinity Trades
abstract contract InfinitySwapRouter is InfinityRouter, Payments {
    constructor(address _vault, address _clPoolManager, address _binPoolManager)
        InfinityRouter(IVault(_vault), ICLPoolManager(_clPoolManager), IBinPoolManager(_binPoolManager))
    {}

    function _pay(Currency token, address payer, uint256 amount) internal override {
        payFrom(Currency.unwrap(token), payer, address(vault), amount);
    }
}

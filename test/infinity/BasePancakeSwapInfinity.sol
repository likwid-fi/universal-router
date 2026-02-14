// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {DeployPermit2} from "permit2/test/utils/DeployPermit2.sol";
import {IAllowanceTransfer} from "permit2/src/interfaces/IAllowanceTransfer.sol";

import {TokenFixture} from "infinity-periphery/test/helpers/TokenFixture.sol";
import {Currency} from "infinity-core/src/types/Currency.sol";

abstract contract BasePancakeSwapInfinity is TokenFixture, Test, DeployPermit2 {
    function _approveRouterForCurrency(address from, Currency currency, address router) internal {
        vm.startPrank(from);

        IERC20(Currency.unwrap(currency)).approve(router, type(uint256).max);

        vm.stopPrank();
    }

    function _approvePermit2ForCurrency(address from, Currency currency, address to, IAllowanceTransfer permit2)
        internal
    {
        vm.startPrank(from);

        // 1. First, the caller must approve permit2 on the token.
        IERC20(Currency.unwrap(currency)).approve(address(permit2), type(uint256).max);

        // 2. Then, the caller must approve POSM as a spender of permit2.
        permit2.approve(Currency.unwrap(currency), to, type(uint160).max, type(uint48).max);

        vm.stopPrank();
    }
}

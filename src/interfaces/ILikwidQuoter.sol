// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {PoolId} from "@likwid-fi/core/types/PoolId.sol";

interface ILikwidQuoter {
    function getAmountOut(PoolId poolId, bool zeroForOne, uint256 amountIn, bool dynamicFee)
        external
        view
        returns (uint256 amountOut, uint24 fee, uint256 feeAmount);

    function getAmountIn(PoolId poolId, bool zeroForOne, uint256 amountOut, bool dynamicFee)
        external
        view
        returns (uint256 amountIn, uint24 fee, uint256 feeAmount);
}

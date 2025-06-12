// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {PoolId} from "../types/PoolId.sol";
import {PoolStatus} from "../types/PoolStatus.sol";

interface ILikwidV2StatusManager {
    function getStatus(PoolId poolId) external view returns (PoolStatus memory _status);

    function getAmountOut(PoolStatus memory status, bool zeroForOne, uint256 amountIn)
        external
        view
        returns (uint256 amountOut, uint24 fee, uint256 feeAmount);

    function getAmountIn(PoolStatus memory status, bool zeroForOne, uint256 amountOut)
        external
        view
        returns (uint256 amountIn, uint24 fee, uint256 feeAmount);
}

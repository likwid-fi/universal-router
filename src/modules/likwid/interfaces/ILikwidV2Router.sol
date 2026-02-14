// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {PoolKey} from "@likwid-fi/core/types/PoolKey.sol";
import {Currency} from "@likwid-fi/core/types/Currency.sol";
import {PathKey} from "../base/PathKey.sol";

/// @title ILikwidV2Router
/// @notice Interface for the LikwidV2Router contract
interface ILikwidV2Router {
    /// @notice Emitted when an exactInput swap does not receive its minAmountOut
    error TooLittleReceivedLikwidV2(uint256 minAmountOutReceived, uint256 amountReceived);
    /// @notice Emitted when an exactOutput is asked for more than its maxAmountIn
    error TooMuchRequestedLikwidV2(uint256 maxAmountInRequested, uint256 amountRequested);

    /// @notice Parameters for a single-hop exact-input swap
    struct ExactInputSingleParamsLikwidV2 {
        PoolKey poolKey;
        bool zeroForOne;
        uint128 amountIn;
        uint128 amountOutMinimum;
    }

    /// @notice Parameters for a multi-hop exact-input swap
    struct ExactInputParamsLikwidV2 {
        Currency currencyIn;
        PathKey[] path;
        uint128 amountIn;
        uint128 amountOutMinimum;
    }

    /// @notice Parameters for a single-hop exact-output swap
    struct ExactOutputSingleParamsLikwidV2 {
        PoolKey poolKey;
        bool zeroForOne;
        uint128 amountOut;
        uint128 amountInMaximum;
    }

    /// @notice Parameters for a multi-hop exact-output swap
    struct ExactOutputParamsLikwidV2 {
        Currency currencyOut;
        PathKey[] path;
        uint128 amountOut;
        uint128 amountInMaximum;
    }
}

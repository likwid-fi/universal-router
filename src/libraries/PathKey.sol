//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Currency} from "../types/Currency.sol";
import {PoolKey, PoolKeyInfinity} from "../types/PoolKey.sol";

struct PathKey {
    Currency intermediateCurrency;
    uint24 fee;
    int24 tickSpacing;
    address hooks;
    bytes hookData;
}

struct PathKeyInfinity {
    Currency intermediateCurrency;
    uint24 fee;
    address hooks;
    address poolManager;
    bytes hookData;
    bytes32 parameters;
}

using PathKeyLibrary for PathKey global;

/// @title PathKey Library
/// @notice Functions for working with PathKeys
library PathKeyLibrary {
    /// @notice Get the pool and swap direction for a given PathKey
    /// @param params the given PathKey
    /// @param currencyIn the input currency
    /// @return poolKey the pool key of the swap
    /// @return zeroForOne the direction of the swap, true if currency0 is being swapped for currency1
    function getPoolAndSwapDirection(PathKey calldata params, Currency currencyIn)
        internal
        pure
        returns (PoolKey memory poolKey, bool zeroForOne)
    {
        Currency currencyOut = params.intermediateCurrency;
        (Currency currency0, Currency currency1) =
            currencyIn < currencyOut ? (currencyIn, currencyOut) : (currencyOut, currencyIn);

        zeroForOne = currencyIn == currency0;
        poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: params.fee,
            tickSpacing: params.tickSpacing,
            hooks: params.hooks
        });
    }

    /// @notice Get the pool and swap direction for a given PathKey
    /// @param params the given PathKey
    /// @param currencyIn the input currency
    /// @return poolKey the pool key of the swap
    /// @return zeroForOne the direction of the swap, true if currency0 is being swapped for currency1
    function getPoolAndSwapDirection(PathKeyInfinity memory params, Currency currencyIn)
        internal
        pure
        returns (PoolKeyInfinity memory poolKey, bool zeroForOne)
    {
        (Currency currency0, Currency currency1) = currencyIn < params.intermediateCurrency
            ? (currencyIn, params.intermediateCurrency)
            : (params.intermediateCurrency, currencyIn);

        zeroForOne = currencyIn == currency0;
        poolKey = PoolKeyInfinity({
            currency0: currency0,
            currency1: currency1,
            hooks: params.hooks,
            poolManager: params.poolManager,
            fee: params.fee,
            parameters: params.parameters
        });
    }
}

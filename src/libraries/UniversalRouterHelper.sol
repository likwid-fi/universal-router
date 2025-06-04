// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {ISwapV2Pair} from "../modules/v2/interfaces/ISwapV2Pair.sol";
import {ISwapV2Factory} from "../modules/v2/interfaces/ISwapV2Factory.sol";
import {ISwapV3Factory} from "../modules/v3/interfaces/ISwapV3Factory.sol";
import {IStableSwapFactory} from "../interfaces/IStableSwapFactory.sol";
import {IStableSwapInfo} from "../interfaces/IStableSwapInfo.sol";
import {BytesLib} from "./BytesLib.sol";
import {Constants} from "./Constants.sol";

library UniversalRouterHelper {
    using BytesLib for bytes;

    error InvalidPoolAddress();
    error InvalidPoolLength();
    error InvalidReserves();
    error InvalidPath();

    /**
     * Stable *************************************************
     */

    // get the pool info in stable swap
    function getStableInfo(address stableSwapFactory, address input, address output, uint256 flag)
        internal
        view
        returns (uint256 i, uint256 j, address swapContract)
    {
        if (flag == 2) {
            IStableSwapFactory.StableSwapPairInfo memory info =
                IStableSwapFactory(stableSwapFactory).getPairInfo(input, output);
            i = input == info.token0 ? 0 : 1;
            j = (i == 0) ? 1 : 0;
            swapContract = info.swapContract;
        } else if (flag == 3) {
            IStableSwapFactory.StableSwapThreePoolPairInfo memory info =
                IStableSwapFactory(stableSwapFactory).getThreePoolPairInfo(input, output);

            if (input == info.token0) i = 0;
            else if (input == info.token1) i = 1;
            else if (input == info.token2) i = 2;

            if (output == info.token0) j = 0;
            else if (output == info.token1) j = 1;
            else if (output == info.token2) j = 2;

            swapContract = info.swapContract;
        }

        if (swapContract == address(0)) revert InvalidPoolAddress();
    }

    function getStableAmountsIn(
        address stableSwapFactory,
        address stableSwapInfo,
        address[] calldata path,
        uint256[] calldata flag,
        uint256 amountOut
    ) internal view returns (uint256[] memory amounts) {
        uint256 length = path.length;
        if (length < 2) revert InvalidPoolLength();

        amounts = new uint256[](length);
        amounts[length - 1] = amountOut;

        for (uint256 i = length - 1; i > 0; i--) {
            uint256 last = i - 1;
            (uint256 k, uint256 j, address swapContract) =
                getStableInfo(stableSwapFactory, path[last], path[i], flag[last]);
            amounts[last] = IStableSwapInfo(stableSwapInfo).get_dx(swapContract, k, j, amounts[i], type(uint256).max);
        }
    }

    /**
     * V2 *************************************************
     */
    /// @notice Sorts two tokens to return token0 and token1
    /// @param tokenA The first token to sort
    /// @param tokenB The other token to sort
    /// @return token0 The smaller token by address value
    /// @return token1 The larger token by address value
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }

    /// @notice Calculates the v2 address for a pair assuming the input tokens are pre-sorted
    /// @param factory The address of the v2 factory
    /// @param token0 The pair's token0
    /// @param token1 The pair's token1
    /// @return pair The resultant v2 pair address
    function pairForPreSorted(address factory, address token0, address token1) private view returns (address pair) {
        pair = ISwapV2Factory(factory).getPair(token0, token1);
        if (pair == address(0)) revert InvalidPoolAddress();
    }

    /// @notice Calculates the v2 address for a pair without making any external calls
    /// @param factory The address of the v2 factory
    /// @param tokenA One of the tokens in the pair
    /// @param tokenB The other token in the pair
    /// @return pair The resultant v2 pair address
    function pairFor(address factory, address tokenA, address tokenB) internal view returns (address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        pair = pairForPreSorted(factory, token0, token1);
    }

    /// @notice Calculates the v2 address for a pair and the pair's token0
    /// @param factory The address of the v2 factory
    /// @param tokenA One of the tokens in the pair
    /// @param tokenB The other token in the pair
    /// @return pair The resultant v2 pair address
    /// @return token0 The token considered token0 in this pair
    function pairAndToken0For(address factory, address tokenA, address tokenB)
        internal
        view
        returns (address pair, address token0)
    {
        address token1;
        (token0, token1) = sortTokens(tokenA, tokenB);
        pair = pairForPreSorted(factory, token0, token1);
    }

    /// @notice Calculates the v2 address for a pair and fetches the reserves for each token
    /// @param factory The address of the v2 factory
    /// @param tokenA One of the tokens in the pair
    /// @param tokenB The other token in the pair
    /// @return pair The resultant v2 pair address
    /// @return reserveA The reserves for tokenA
    /// @return reserveB The reserves for tokenB
    function pairAndReservesFor(address factory, address tokenA, address tokenB)
        private
        view
        returns (address pair, uint256 reserveA, uint256 reserveB)
    {
        address token0;
        (pair, token0) = pairAndToken0For(factory, tokenA, tokenB);
        (uint256 reserve0, uint256 reserve1,) = ISwapV2Pair(pair).getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    /// @notice Given an input asset amount returns the maximum output amount of the other asset
    /// @param amountIn The token input amount
    /// @param fee The fee percentage (in basis points, e.g., 25 for 0.25%, 30 for 0.3%)
    /// @param reserveIn The reserves available of the input token
    /// @param reserveOut The reserves available of the output token
    /// @return amountOut The output amount of the output token
    function getAmountOut(uint256 amountIn, uint24 fee, uint256 reserveIn, uint256 reserveOut)
        internal
        pure
        returns (uint256 amountOut)
    {
        if (reserveIn == 0 || reserveOut == 0) revert InvalidReserves();
        uint256 amountInWithFee = amountIn * (10000 - fee);
        if (amountInWithFee == 0) return 0; // Avoid division by zero
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * 10000 + amountInWithFee;
        amountOut = numerator / denominator;
    }

    /// @notice Returns the input amount needed for a desired output amount in a single-hop trade
    /// @param amountOut The desired output amount
    /// @param fee The fee percentage (in basis points, e.g., 25 for 0.25%)
    /// @param reserveIn The reserves available of the input token
    /// @param reserveOut The reserves available of the output token
    /// @return amountIn The input amount of the input token
    function getAmountIn(uint256 amountOut, uint24 fee, uint256 reserveIn, uint256 reserveOut)
        internal
        pure
        returns (uint256 amountIn)
    {
        if (reserveIn == 0 || reserveOut == 0) revert InvalidReserves();
        uint256 numerator = reserveIn * amountOut * 10000;
        uint256 denominator = (reserveOut - amountOut) * (10000 - fee);
        if (denominator == 0) revert InvalidReserves(); // Avoid division by zero
        amountIn = (numerator / denominator) + 1;
    }

    /// @notice Returns the input amount needed for a desired output amount in a multi-hop trade
    /// @param factory The address of the v2 factory
    /// @param amountOut The desired output amount
    /// @param path The path of the multi-hop trade
    /// @param fee The fee percentage (in basis points, e.g., 25 for 0.25%)
    /// @return amount The input amount of the input token
    /// @return pair The first pair in the trade
    function getAmountInMultihop(address factory, uint256 amountOut, address[] calldata path, uint24 fee)
        internal
        view
        returns (uint256 amount, address pair)
    {
        if (path.length < 2) revert InvalidPath();
        amount = amountOut;
        for (uint256 i = path.length - 1; i > 0; i--) {
            uint256 reserveIn;
            uint256 reserveOut;

            (pair, reserveIn, reserveOut) = pairAndReservesFor(factory, path[i - 1], path[i]);
            amount = getAmountIn(amount, fee, reserveIn, reserveOut);
        }
    }

    /**
     * V3 *************************************************
     */
    /// @notice Returns true iff the path contains two or more pools
    /// @param path The encoded swap path
    /// @return True if path contains two or more pools, otherwise false
    function hasMultiplePools(bytes calldata path) internal pure returns (bool) {
        return path.length >= Constants.MULTIPLE_V3_POOLS_MIN_LENGTH;
    }

    /// @notice Decodes the first pool in path
    /// @param path The bytes encoded swap path
    /// @return tokenA The first token of the given pool
    /// @return fee The fee level of the pool
    /// @return tokenB The second token of the given pool
    function decodeFirstPool(bytes calldata path) internal pure returns (address, uint24, address) {
        return path.toPool();
    }

    /// @notice Gets the segment corresponding to the first pool in the path
    /// @param path The bytes encoded swap path
    /// @return The segment containing all data necessary to target the first pool in the path
    function getFirstPool(bytes calldata path) internal pure returns (bytes calldata) {
        return path[:Constants.V3_POP_OFFSET];
    }

    function decodeFirstToken(bytes calldata path) internal pure returns (address tokenA) {
        tokenA = path.toAddress();
    }

    /// @notice Skips a token + fee element
    /// @param path The swap path
    function skipToken(bytes calldata path) internal pure returns (bytes calldata) {
        return path[Constants.NEXT_V3_POOL_OFFSET:];
    }

    function getPoolAddress(address factory, address tokenA, address tokenB, uint24 fee)
        internal
        view
        returns (address pool)
    {
        if (tokenA > tokenB) {
            (tokenA, tokenB) = (tokenB, tokenA);
        }
        pool = ISwapV3Factory(factory).getPool(tokenA, tokenB, fee);
        if (pool == address(0)) revert InvalidPoolAddress();
    }
}

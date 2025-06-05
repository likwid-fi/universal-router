// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {ActionConstants} from "infinity-periphery/src/libraries/ActionConstants.sol";
import {SafeCast} from "./SafeCast.sol";
import {ISwapV3Pool} from "./interfaces/ISwapV3Pool.sol";
import {ISwapV3Callback} from "./interfaces/ISwapV3Callback.sol";
import {BytesLib} from "../../libraries/BytesLib.sol";
import {Constants} from "../../libraries/Constants.sol";
import {UniversalRouterHelper} from "../../libraries/UniversalRouterHelper.sol";
import {RouterImmutables} from "../../base/RouterImmutables.sol";
import {Payments} from "../Payments.sol";
import {MaxInputAmount} from "../../libraries/MaxInputAmount.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {CalldataDecoder} from "infinity-periphery/src/libraries/CalldataDecoder.sol";

/// @title Router for  v3 Trades
abstract contract V3SwapRouter is RouterImmutables, Payments, ISwapV3Callback {
    using UniversalRouterHelper for bytes;
    using BytesLib for bytes;
    using CalldataDecoder for bytes;
    using SafeCast for uint256;

    error V3InvalidFactory();
    error V3InvalidSwap();
    error V3TooLittleReceived();
    error V3TooMuchRequested();
    error V3InvalidAmountOut();
    error V3InvalidCaller();

    /// @dev The minimum value that can be returned from #getSqrtRatioAtTick. Equivalent to getSqrtRatioAtTick(MIN_TICK)
    uint160 internal constant MIN_SQRT_RATIO = 4295128739;

    /// @dev The maximum value that can be returned from #getSqrtRatioAtTick. Equivalent to getSqrtRatioAtTick(MAX_TICK)
    uint160 internal constant MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970342;

    function _swapCallback(address factory, int256 amount0Delta, int256 amount1Delta, bytes calldata data) internal {
        if (amount0Delta <= 0 && amount1Delta <= 0) revert V3InvalidSwap(); // swaps entirely within 0-liquidity regions are not supported
        (, address payer) = abi.decode(data, (bytes, address));
        bytes calldata path = data.toBytes(0);

        // because exact output swaps are executed in reverse order, in this case tokenOut is actually tokenIn
        (address tokenIn, uint24 fee, address tokenOut) = path.decodeFirstPool();

        if (UniversalRouterHelper.getPoolAddress(factory, tokenIn, tokenOut, fee) != msg.sender) {
            revert V3InvalidCaller();
        }

        (bool isExactInput, uint256 amountToPay) =
            amount0Delta > 0 ? (tokenIn < tokenOut, uint256(amount0Delta)) : (tokenOut < tokenIn, uint256(amount1Delta));

        if (isExactInput) {
            // Pay the pool (msg.sender)
            payFrom(tokenIn, payer, msg.sender, amountToPay);
        } else {
            // either initiate the next swap or pay
            if (path.hasMultiplePools()) {
                // this is an intermediate step so the payer is actually this contract
                path = path.skipToken();
                _swap(factory, -amountToPay.toInt256(), msg.sender, path, payer, false);
            } else {
                if (amountToPay > MaxInputAmount.get()) revert V3TooMuchRequested();
                // note that because exact output swaps are executed in reverse order, tokenOut is actually tokenIn
                payFrom(tokenOut, payer, msg.sender, amountToPay);
            }
        }
    }

    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external {
        _swapCallback(UNISWAP_V3_FACTORY, amount0Delta, amount1Delta, data);
    }

    function pancakeV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external {
        _swapCallback(PANCAKESWAP_V3_FACTORY, amount0Delta, amount1Delta, data);
    }

    /// @notice Performs a  v3 exact input swap
    /// @param factory The address of the v3 factory
    /// @param recipient The recipient of the output tokens
    /// @param amountIn The amount of input tokens for the trade
    /// @param amountOutMinimum The minimum desired amount of output tokens
    /// @param path The path of the trade as a bytes string
    /// @param payer The address that will be paying the input
    function v3SwapExactInput(
        address factory,
        address recipient,
        uint256 amountIn,
        uint256 amountOutMinimum,
        bytes calldata path,
        address payer
    ) internal {
        // use amountIn == ActionConstants.CONTRACT_BALANCE as a flag to swap the entire balance of the contract
        if (amountIn == ActionConstants.CONTRACT_BALANCE) {
            address tokenIn = path.decodeFirstToken();
            amountIn = ERC20(tokenIn).balanceOf(address(this));
        }

        uint256 amountOut;
        while (true) {
            bool hasMultiplePools = path.hasMultiplePools();

            // the outputs of prior swaps become the inputs to subsequent ones
            (int256 amount0Delta, int256 amount1Delta, bool zeroForOne) = _swap(
                factory,
                amountIn.toInt256(),
                hasMultiplePools ? address(this) : recipient, // for intermediate swaps, this contract custodies
                path.getFirstPool(), // only the first pool is needed
                payer, // for intermediate swaps, this contract custodies
                true
            );

            amountIn = uint256(-(zeroForOne ? amount1Delta : amount0Delta));

            // decide whether to continue or terminate
            if (hasMultiplePools) {
                payer = address(this);
                path = path.skipToken();
            } else {
                amountOut = amountIn;
                break;
            }
        }

        if (amountOut < amountOutMinimum) revert V3TooLittleReceived();
    }

    /// @notice Performs a v3 exact output swap
    /// @param factory The address of the v3 factory
    /// @param recipient The recipient of the output tokens
    /// @param amountOut The amount of output tokens to receive for the trade
    /// @param amountInMaximum The maximum desired amount of input tokens
    /// @param path The path of the trade as a bytes string
    /// @param payer The address that will be paying the input
    function v3SwapExactOutput(
        address factory,
        address recipient,
        uint256 amountOut,
        uint256 amountInMaximum,
        bytes calldata path,
        address payer
    ) internal {
        MaxInputAmount.set(amountInMaximum);
        (int256 amount0Delta, int256 amount1Delta, bool zeroForOne) =
            _swap(factory, -amountOut.toInt256(), recipient, path, payer, false);

        uint256 amountOutReceived = zeroForOne ? uint256(-amount1Delta) : uint256(-amount0Delta);

        if (amountOutReceived != amountOut) revert V3InvalidAmountOut();

        MaxInputAmount.set(0);
    }

    /// @dev Performs a single swap for both exactIn and exactOut
    /// For exactIn, `amount` is `amountIn`. For exactOut, `amount` is `-amountOut`
    function _swap(
        address factory,
        int256 amount,
        address recipient,
        bytes calldata path,
        address payer,
        bool isExactIn
    ) private returns (int256 amount0Delta, int256 amount1Delta, bool zeroForOne) {
        if (factory != UNISWAP_V3_FACTORY && factory != PANCAKESWAP_V3_FACTORY) {
            revert V3InvalidFactory();
        }
        (address tokenIn, uint24 fee, address tokenOut) = path.decodeFirstPool();

        zeroForOne = isExactIn ? tokenIn < tokenOut : tokenOut < tokenIn;

        (amount0Delta, amount1Delta) = ISwapV3Pool(
            UniversalRouterHelper.getPoolAddress(factory, tokenIn, tokenOut, fee)
        ).swap(
            recipient,
            zeroForOne,
            amount,
            (zeroForOne ? MIN_SQRT_RATIO + 1 : MAX_SQRT_RATIO - 1),
            abi.encode(path, payer)
        );
    }
}

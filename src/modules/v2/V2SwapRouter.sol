// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {ISwapV2Pair} from "./interfaces/ISwapV2Pair.sol";
import {RouterImmutables} from "../../base/RouterImmutables.sol";
import {Payments} from "../Payments.sol";
import {Constants} from "../../libraries/Constants.sol";
import {UniversalRouterHelper} from "../../libraries/UniversalRouterHelper.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";

/// @title Router for v2 Trades
abstract contract V2SwapRouter is RouterImmutables, Payments {
    error V2InvalidFactory();
    error V2TooLittleReceived();
    error V2TooMuchRequested();
    error V2InvalidPath();

    function _v2Swap(address factory, address[] calldata path, uint24 fee, address recipient, address pair) private {
        unchecked {
            if (path.length < 2) revert V2InvalidPath();

            // cached to save on duplicate operations
            (address token0,) = UniversalRouterHelper.sortTokens(path[0], path[1]);
            uint256 finalPairIndex = path.length - 1;
            uint256 penultimatePairIndex = finalPairIndex - 1;
            for (uint256 i; i < finalPairIndex; i++) {
                (address input, address output) = (path[i], path[i + 1]);
                (uint256 reserve0, uint256 reserve1,) = ISwapV2Pair(pair).getReserves();
                (uint256 reserveInput, uint256 reserveOutput) =
                    input == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
                uint256 amountInput = ERC20(input).balanceOf(pair) - reserveInput;
                uint256 amountOutput = UniversalRouterHelper.getAmountOut(amountInput, fee, reserveInput, reserveOutput);
                (uint256 amount0Out, uint256 amount1Out) =
                    input == token0 ? (uint256(0), amountOutput) : (amountOutput, uint256(0));
                address nextPair;
                (nextPair, token0) = i < penultimatePairIndex
                    ? UniversalRouterHelper.pairAndToken0For(factory, output, path[i + 2])
                    : (recipient, address(0));
                ISwapV2Pair(pair).swap(amount0Out, amount1Out, nextPair, new bytes(0));
                pair = nextPair;
            }
        }
    }

    /// @notice Performs a v2 exact input swap
    /// @param factory The address of the v2 factory
    /// @param recipient The recipient of the output tokens
    /// @param amountIn The amount of input tokens for the trade
    /// @param amountOutMinimum The minimum desired amount of output tokens
    /// @param path The path of the trade as an array of token addresses
    /// @param payer The address that will be paying the input
    function v2SwapExactInput(
        address factory,
        address recipient,
        uint256 amountIn,
        uint256 amountOutMinimum,
        address[] calldata path,
        address payer
    ) internal {
        uint24 fee;
        if (factory == PANCAKESWAP_V2_FACTORY) {
            fee = 25;
        } else if (factory == UNISWAP_V2_FACTORY) {
            fee = 30;
        } else {
            revert V2InvalidFactory();
        }
        address firstPair = UniversalRouterHelper.pairFor(factory, path[0], path[1]);
        if (
            amountIn != Constants.ALREADY_PAID // amountIn of 0 to signal that the pair already has the tokens
        ) {
            payFrom(path[0], payer, firstPair, amountIn);
        }

        ERC20 tokenOut = ERC20(path[path.length - 1]);
        uint256 balanceBefore = tokenOut.balanceOf(recipient);

        _v2Swap(factory, path, fee, recipient, firstPair);

        uint256 amountOut = tokenOut.balanceOf(recipient) - balanceBefore;
        if (amountOut < amountOutMinimum) revert V2TooLittleReceived();
    }

    /// @notice Performs a  v2 exact output swap
    /// @param factory The address of the v2 factory
    /// @param recipient The recipient of the output tokens
    /// @param amountOut The amount of output tokens to receive for the trade
    /// @param amountInMaximum The maximum desired amount of input tokens
    /// @param path The path of the trade as an array of token addresses
    /// @param payer The address that will be paying the input
    function v2SwapExactOutput(
        address factory,
        address recipient,
        uint256 amountOut,
        uint256 amountInMaximum,
        address[] calldata path,
        address payer
    ) internal {
        uint24 fee;
        if (factory == PANCAKESWAP_V2_FACTORY) {
            fee = 25;
        } else if (factory == UNISWAP_V2_FACTORY) {
            fee = 30;
        } else {
            revert V2InvalidFactory();
        }
        (uint256 amountIn, address firstPair) = UniversalRouterHelper.getAmountInMultihop(factory, amountOut, path, fee);
        if (amountIn > amountInMaximum) revert V2TooMuchRequested();

        payFrom(path[0], payer, firstPair, amountIn);
        _v2Swap(factory, path, fee, recipient, firstPair);
    }
}

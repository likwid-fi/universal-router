// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Actions} from "@uniswap/v4-periphery/src/libraries/Actions.sol";
import {ActionConstants} from "@uniswap/v4-periphery/src/libraries/ActionConstants.sol";
import {BipsLibrary} from "@uniswap/v4-periphery/src/libraries/BipsLibrary.sol";
import {IVault} from "@likwid-fi/core/interfaces/IVault.sol";
import {BalanceDelta} from "@likwid-fi/core/types/BalanceDelta.sol";
import {PoolKey} from "@likwid-fi/core/types/PoolKey.sol";
import {Currency} from "@likwid-fi/core/types/Currency.sol";
import {SafeCast} from "@likwid-fi/core/libraries/SafeCast.sol";

import {PathKey} from "./base/PathKey.sol";
import {BaseActionsRouterLikwidV2} from "./base/BaseActionsRouter.sol";
import {CalldataDecoder} from "./base/CalldataDecoder.sol";
import {ILikwidV2Router} from "./interfaces/ILikwidV2Router.sol";

import {Payments} from "../Payments.sol";

/// @title LikwidV2Router
/// @notice Abstract contract that contains all internal logic needed for routing through Likwid v2 pools
/// @dev the entry point to executing actions in this contract is calling `BaseActionsRouter._executeActions`
/// An inheriting contract should call _executeActions at the point that they wish actions to be executed
abstract contract LikwidV2SwapRouter is ILikwidV2Router, BaseActionsRouterLikwidV2, Payments {
    using SafeCast for *;
    using CalldataDecoder for bytes;
    using BipsLibrary for uint256;

    constructor(address _vault) {
        likwidVault = IVault(_vault);
    }

    /// @notice internal function that handles the execution of an action based on its type
    function _unlockCallbackLikwidV2(bytes calldata data) internal returns (bytes memory) {
        // abi.decode(data, (bytes, bytes[]));
        (bytes calldata actions, bytes[] calldata params) = data.decodeActionsRouterParams();
        _executeActionsWithoutUnlockLikwidV2(actions, params);
        return "";
    }

    function _handleActionLikwidV2(uint256 action, bytes calldata params) internal override {
        // swap actions and payment actions in different blocks for gas efficiency
        if (action < Actions.SETTLE) {
            if (action == Actions.SWAP_EXACT_IN) {
                ILikwidV2Router.ExactInputParamsLikwidV2 calldata swapParams = params.decodeSwapExactInParams();
                _swapExactInput(swapParams);
                return;
            } else if (action == Actions.SWAP_EXACT_IN_SINGLE) {
                ILikwidV2Router.ExactInputSingleParamsLikwidV2 calldata swapParams =
                    params.decodeSwapExactInSingleParams();
                _swapExactInputSingle(swapParams);
                return;
            } else if (action == Actions.SWAP_EXACT_OUT) {
                ILikwidV2Router.ExactOutputParamsLikwidV2 calldata swapParams = params.decodeSwapExactOutParams();
                _swapExactOutput(swapParams);
                return;
            } else if (action == Actions.SWAP_EXACT_OUT_SINGLE) {
                ILikwidV2Router.ExactOutputSingleParamsLikwidV2 calldata swapParams =
                    params.decodeSwapExactOutSingleParams();
                _swapExactOutputSingle(swapParams);
                return;
            }
        } else {
            if (action == Actions.SETTLE_ALL) {
                (Currency currency, uint256 maxAmount) = params.decodeCurrencyAndUint256();
                uint256 amount = _getFullDebt(currency);
                if (amount > maxAmount) revert TooMuchRequestedLikwidV2(maxAmount, amount);
                _settle(currency, msgSenderLikwidV2(), amount);
                return;
            } else if (action == Actions.TAKE_ALL) {
                (Currency currency, uint256 minAmount) = params.decodeCurrencyAndUint256();
                uint256 amount = _getFullCredit(currency);
                if (amount < minAmount) revert TooLittleReceivedLikwidV2(minAmount, amount);
                _take(currency, msgSenderLikwidV2(), amount);
                return;
            } else if (action == Actions.SETTLE) {
                (Currency currency, uint256 amount, bool payerIsUser) = params.decodeCurrencyUint256AndBool();
                _settle(currency, _mapPayerLikwidV2(payerIsUser), _mapSettleAmount(amount, currency));
                return;
            } else if (action == Actions.TAKE) {
                (Currency currency, address recipient, uint256 amount) = params.decodeCurrencyAddressAndUint256();
                _take(currency, _mapRecipientLikwidV2(recipient), _mapTakeAmount(amount, currency));
                return;
            } else if (action == Actions.TAKE_PORTION) {
                (Currency currency, address recipient, uint256 bips) = params.decodeCurrencyAddressAndUint256();
                _take(currency, _mapRecipientLikwidV2(recipient), _getFullCredit(currency).calculatePortion(bips));
                return;
            }
        }
        revert UnsupportedActionLikwidV2(action);
    }

    function _swapExactInputSingle(ILikwidV2Router.ExactInputSingleParamsLikwidV2 calldata params) private {
        uint128 amountIn = params.amountIn;
        if (amountIn == ActionConstants.OPEN_DELTA) {
            amountIn =
                _getFullCredit(params.zeroForOne ? params.poolKey.currency0 : params.poolKey.currency1).toUint128();
        }
        uint128 amountOut = _swap(params.poolKey, params.zeroForOne, -int256(uint256(amountIn))).toUint128();
        if (amountOut < params.amountOutMinimum) revert TooLittleReceivedLikwidV2(params.amountOutMinimum, amountOut);
    }

    function _swapExactInput(ILikwidV2Router.ExactInputParamsLikwidV2 calldata params) private {
        unchecked {
            // Caching for gas savings
            uint256 pathLength = params.path.length;
            uint128 amountOut;
            Currency currencyIn = params.currencyIn;
            uint128 amountIn = params.amountIn;
            if (amountIn == ActionConstants.OPEN_DELTA) amountIn = _getFullCredit(currencyIn).toUint128();
            PathKey calldata pathKey;

            for (uint256 i = 0; i < pathLength; i++) {
                pathKey = params.path[i];
                (PoolKey memory poolKey, bool zeroForOne) = pathKey.getPoolAndSwapDirection(currencyIn);
                // The output delta will always be positive, except for when interacting with certain hook pools
                amountOut = _swap(poolKey, zeroForOne, -int256(uint256(amountIn))).toUint128();

                amountIn = amountOut;
                currencyIn = pathKey.intermediateCurrency;
            }

            if (amountOut < params.amountOutMinimum) {
                revert TooLittleReceivedLikwidV2(params.amountOutMinimum, amountOut);
            }
        }
    }

    function _swapExactOutputSingle(ILikwidV2Router.ExactOutputSingleParamsLikwidV2 calldata params) private {
        uint128 amountOut = params.amountOut;
        if (amountOut == ActionConstants.OPEN_DELTA) {
            amountOut =
                _getFullDebt(params.zeroForOne ? params.poolKey.currency1 : params.poolKey.currency0).toUint128();
        }
        uint128 amountIn =
            (uint256(-int256(_swap(params.poolKey, params.zeroForOne, int256(uint256(amountOut)))))).toUint128();
        if (amountIn > params.amountInMaximum) revert TooMuchRequestedLikwidV2(params.amountInMaximum, amountIn);
    }

    function _swapExactOutput(ILikwidV2Router.ExactOutputParamsLikwidV2 calldata params) private {
        unchecked {
            // Caching for gas savings
            uint256 pathLength = params.path.length;
            uint128 amountIn;
            uint128 amountOut = params.amountOut;
            Currency currencyOut = params.currencyOut;
            PathKey calldata pathKey;

            if (amountOut == ActionConstants.OPEN_DELTA) {
                amountOut = _getFullDebt(currencyOut).toUint128();
            }

            for (uint256 i = pathLength; i > 0; i--) {
                pathKey = params.path[i - 1];
                (PoolKey memory poolKey, bool oneForZero) = pathKey.getPoolAndSwapDirection(currencyOut);
                // The output delta will always be negative, except for when interacting with certain hook pools
                amountIn = (uint256(-int256(_swap(poolKey, !oneForZero, int256(uint256(amountOut)))))).toUint128();

                amountOut = amountIn;
                currencyOut = pathKey.intermediateCurrency;
            }
            if (amountIn > params.amountInMaximum) revert TooMuchRequestedLikwidV2(params.amountInMaximum, amountIn);
        }
    }

    function _swap(PoolKey memory poolKey, bool zeroForOne, int256 amountSpecified)
        private
        returns (int128 reciprocalAmount)
    {
        // for protection of exactOut swaps, sqrtPriceLimit is not exposed as a feature in this contract
        unchecked {
            (BalanceDelta delta,,) = likwidVault.swap(
                poolKey,
                IVault.SwapParams({
                    zeroForOne: zeroForOne, amountSpecified: amountSpecified, useMirror: false, salt: bytes32(0)
                })
            );

            reciprocalAmount = (zeroForOne == amountSpecified < 0) ? delta.amount1() : delta.amount0();
        }
    }

    function _pay(Currency token, address payer, uint256 amount) internal override {
        payFrom(Currency.unwrap(token), payer, address(likwidVault), amount);
    }
}

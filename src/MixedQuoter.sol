// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.26;

import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {IStableSwap} from "./modules/pancakeswap/interfaces/IStableSwap.sol";
import {IStableSwapInfo} from "./modules/pancakeswap/interfaces/IStableSwapInfo.sol";
import {QuoterParameters, QuoterImmutables} from "./base/QuoterImmutables.sol";
import {PoolTypes} from "./libraries/PoolTypes.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency as CurrencyInfinity} from "infinity-core/src/types/Currency.sol";
import {PoolKey as PoolKeyInfinity} from "infinity-core/src/types/PoolKey.sol";
import {Currency as CurrencyLikwid} from "@likwid-fi/core/types/Currency.sol";
import {PoolKey as PoolKeyLikwid} from "@likwid-fi/core/types/PoolKey.sol";
import {PoolId} from "@likwid-fi/core/types/PoolId.sol";
import {IMixedQuoter} from "./interfaces/IMixedQuoter.sol";
import {IV3Quoter} from "./interfaces/IV3Quoter.sol";
import {IV4Quoter} from "./interfaces/IV4Quoter.sol";
import {IInfinityQuoter} from "./interfaces/IInfinityQuoter.sol";
import {UniversalRouterHelper} from "./libraries/UniversalRouterHelper.sol";

contract MixedQuoter is IMixedQuoter, QuoterImmutables {
    using SafeCast for *;

    error NoPoolTypes();
    error InputLengthMismatch();
    error InvalidPath();
    error InvalidPoolType();
    error InvalidPoolKeyCurrency();

    constructor(QuoterParameters memory params) QuoterImmutables(params) {}

    function quoteExactInputSingleStable(QuoteExactInputSingleStableParams memory params)
        public
        view
        returns (uint256 amountOut, uint256 gasEstimate)
    {
        uint256 gasBefore = gasleft();
        (uint256 i, uint256 j, address swapContract) =
            UniversalRouterHelper.getStableInfo(STABLE_FACTORY, params.tokenIn, params.tokenOut, params.flag);
        amountOut = IStableSwap(swapContract).get_dy(i, j, params.amountIn);
        gasEstimate = gasBefore - gasleft();
    }

    function quoteExactOutputSingleStable(QuoteExactOutputSingleStableParams memory params)
        public
        view
        returns (uint256 amountIn, uint256 gasEstimate)
    {
        uint256 gasBefore = gasleft();
        (uint256 i, uint256 j, address swapContract) =
            UniversalRouterHelper.getStableInfo(STABLE_FACTORY, params.tokenIn, params.tokenOut, params.flag);
        amountIn = IStableSwapInfo(STABLE_INFO).get_dx(swapContract, i, j, params.amountOut, type(uint256).max);
        gasEstimate = gasBefore - gasleft();
    }

    function quoteMixedExactInput(
        address[] calldata paths,
        bytes calldata pools,
        bytes[] calldata params,
        uint256 amountIn
    ) external returns (uint256 amountOut, uint256 gasEstimate, uint256[] memory fees) {
        uint256 numPools = pools.length;
        if (numPools == 0) revert NoPoolTypes();
        if (numPools != params.length || numPools != paths.length - 1) revert InputLengthMismatch();
        fees = new uint256[](numPools);
        for (uint256 poolIndex = 0; poolIndex < numPools; poolIndex++) {
            uint256 gasEstimateForCurrentPool = gasleft();
            address tokenIn = paths[poolIndex];
            address tokenOut = paths[poolIndex + 1];
            if (tokenIn == tokenOut) revert InvalidPath();

            uint256 pool = uint256(uint8(pools[poolIndex]));
            if (pool == PoolTypes.UNISWAP_V2 || pool == PoolTypes.PANCAKESWAP_V2) {
                (tokenIn, tokenOut) = convertNativeToWETH(tokenIn, tokenOut);
                address[] memory path = new address[](2);
                path[0] = tokenIn;
                path[1] = tokenOut;
                if (pool == PoolTypes.UNISWAP_V2) {
                    fees[poolIndex] = 3000;
                    amountOut = UNISWAP_V2_QUOTER.getAmountsOut(amountIn, path)[1];
                } else {
                    fees[poolIndex] = 2500;
                    amountOut = PANCAKESWAP_V2_QUOTER.getAmountsOut(amountIn, path)[1];
                }
                gasEstimateForCurrentPool = gasEstimateForCurrentPool - gasleft();
            } else if (pool == PoolTypes.UNISWAP_V3 || pool == PoolTypes.PANCAKESWAP_V3) {
                (tokenIn, tokenOut) = convertNativeToWETH(tokenIn, tokenOut);
                uint24 fee = abi.decode(params[poolIndex], (uint24));
                fees[poolIndex] = fee;
                IV3Quoter.QuoteExactInputSingleParams memory quoteParams = IV3Quoter.QuoteExactInputSingleParams({
                    tokenIn: tokenIn, tokenOut: tokenOut, amountIn: amountIn, fee: fee, sqrtPriceLimitX96: 0
                });
                if (pool == PoolTypes.UNISWAP_V3) {
                    (amountOut,,, gasEstimateForCurrentPool) = UNISWAP_V3_QUOTER.quoteExactInputSingle(quoteParams);
                } else {
                    (amountOut,,, gasEstimateForCurrentPool) = PANCAKESWAP_V3_QUOTER.quoteExactInputSingle(quoteParams);
                }
            } else if (pool == PoolTypes.PANCAKESWAP_STABLE) {
                (amountOut, gasEstimateForCurrentPool) = quoteExactInputSingleStable(
                    QuoteExactInputSingleStableParams({
                        tokenIn: tokenIn, tokenOut: tokenOut, amountIn: amountIn, flag: 2
                    })
                );
                fees[poolIndex] = 0;
            } else if (pool == PoolTypes.UNISWAP_V4) {
                QuoteMixedV4ExactSingleParams memory v4Params =
                    abi.decode(params[poolIndex], (QuoteMixedV4ExactSingleParams));
                (tokenIn, tokenOut) = convertWETHToNativeCurrencyV4(v4Params.poolKey, tokenIn, tokenOut);
                bool zeroForOne = tokenIn < tokenOut;
                checkPoolKeyCurrencyV4(v4Params.poolKey, zeroForOne, tokenIn, tokenOut);
                fees[poolIndex] = v4Params.poolKey.fee;
                IV4Quoter.QuoteExactSingleParams memory swapParams = IV4Quoter.QuoteExactSingleParams({
                    poolKey: v4Params.poolKey,
                    zeroForOne: zeroForOne,
                    exactAmount: amountIn.toUint128(),
                    hookData: v4Params.hookData
                });
                (amountOut, gasEstimateForCurrentPool) = UNISWAP_V4_QUOTER.quoteExactInputSingle(swapParams);
            } else if (pool == PoolTypes.LIKWID_V2) {
                PoolId poolId = abi.decode(params[poolIndex], (PoolId));
                PoolKeyLikwid memory poolKey = LIKWID_PAIR_MANAGER.poolKeys(poolId);
                (tokenIn, tokenOut) = convertWETHToNativeCurrencyLikwid(poolKey, tokenIn, tokenOut);
                bool zeroForOne = tokenIn < tokenOut;
                checkPoolKeyCurrencyLikwid(poolKey, zeroForOne, tokenIn, tokenOut);
                uint24 fee;
                (amountOut, fee,) = LIKWID_QUOTER.getAmountOut(poolId, zeroForOne, amountIn, true);
                fees[poolIndex] = fee;
                gasEstimateForCurrentPool = gasEstimateForCurrentPool - gasleft() + 10_0000;
            } else if (pool == PoolTypes.PANCAKESWAP_INFINITY_CL || pool == PoolTypes.PANCAKESWAP_INFINITY_BIN) {
                QuoteMixedInfiExactSingleParams memory infiParams =
                    abi.decode(params[poolIndex], (QuoteMixedInfiExactSingleParams));
                (tokenIn, tokenOut) = convertWETHToInfiNativeCurrency(infiParams.poolKey, tokenIn, tokenOut);
                bool zeroForOne = tokenIn < tokenOut;
                checkInfiPoolKeyCurrency(infiParams.poolKey, zeroForOne, tokenIn, tokenOut);
                fees[poolIndex] = infiParams.poolKey.fee;
                IInfinityQuoter.QuoteExactSingleParams memory swapParams = IInfinityQuoter.QuoteExactSingleParams({
                    poolKey: infiParams.poolKey,
                    zeroForOne: zeroForOne,
                    exactAmount: amountIn.toUint128(),
                    hookData: infiParams.hookData
                });
                if (pool == PoolTypes.PANCAKESWAP_INFINITY_CL) {
                    (amountOut, gasEstimateForCurrentPool) = INFI_CL_QUOTER.quoteExactInputSingle(swapParams);
                } else if (pool == PoolTypes.PANCAKESWAP_INFINITY_BIN) {
                    (amountOut, gasEstimateForCurrentPool) = INFI_BIN_QUOTER.quoteExactInputSingle(swapParams);
                }
            } else {
                revert InvalidPoolType();
            }
            amountIn = amountOut;
            gasEstimate += gasEstimateForCurrentPool;
        }
    }

    function quoteMixedExactOutput(
        address[] calldata paths,
        bytes calldata pools,
        bytes[] calldata params,
        uint256 amountOut
    ) external returns (uint256 amountIn, uint256 gasEstimate, uint256[] memory fees) {
        uint256 numPools = pools.length;
        if (numPools == 0) revert NoPoolTypes();
        if (numPools != params.length || numPools != paths.length - 1) revert InputLengthMismatch();
        fees = new uint256[](numPools);
        for (uint256 lastIndex = numPools; lastIndex > 0; lastIndex--) {
            uint256 poolIndex = lastIndex - 1;
            uint256 gasEstimateForCurrentPool = gasleft();
            address tokenIn = paths[poolIndex];
            address tokenOut = paths[poolIndex + 1];
            if (tokenIn == tokenOut) revert InvalidPath();

            uint256 pool = uint256(uint8(pools[poolIndex]));
            if (pool == PoolTypes.UNISWAP_V2 || pool == PoolTypes.PANCAKESWAP_V2) {
                (tokenIn, tokenOut) = convertNativeToWETH(tokenIn, tokenOut);
                address[] memory path = new address[](2);
                path[0] = tokenIn;
                path[1] = tokenOut;
                if (pool == PoolTypes.UNISWAP_V2) {
                    fees[poolIndex] = 3000;
                    amountIn = UNISWAP_V2_QUOTER.getAmountsIn(amountOut, path)[0];
                } else {
                    fees[poolIndex] = 2500;
                    amountIn = PANCAKESWAP_V2_QUOTER.getAmountsIn(amountOut, path)[0];
                }
                gasEstimateForCurrentPool = gasEstimateForCurrentPool - gasleft();
            } else if (pool == PoolTypes.UNISWAP_V3 || pool == PoolTypes.PANCAKESWAP_V3) {
                (tokenIn, tokenOut) = convertNativeToWETH(tokenIn, tokenOut);
                uint24 fee = abi.decode(params[poolIndex], (uint24));
                fees[poolIndex] = fee;
                IV3Quoter.QuoteExactOutputSingleParams memory quoteParams = IV3Quoter.QuoteExactOutputSingleParams({
                    tokenIn: tokenIn, tokenOut: tokenOut, amount: amountOut, fee: fee, sqrtPriceLimitX96: 0
                });
                if (pool == PoolTypes.UNISWAP_V3) {
                    (amountIn,,, gasEstimateForCurrentPool) = UNISWAP_V3_QUOTER.quoteExactOutputSingle(quoteParams);
                } else {
                    (amountIn,,, gasEstimateForCurrentPool) = PANCAKESWAP_V3_QUOTER.quoteExactOutputSingle(quoteParams);
                }
            } else if (pool == PoolTypes.PANCAKESWAP_STABLE) {
                (amountIn, gasEstimateForCurrentPool) = quoteExactOutputSingleStable(
                    QuoteExactOutputSingleStableParams({
                        tokenIn: tokenIn, tokenOut: tokenOut, amountOut: amountOut, flag: 2
                    })
                );
                fees[poolIndex] = 0;
            } else if (pool == PoolTypes.UNISWAP_V4) {
                QuoteMixedV4ExactSingleParams memory v4Params =
                    abi.decode(params[poolIndex], (QuoteMixedV4ExactSingleParams));
                (tokenIn, tokenOut) = convertWETHToNativeCurrencyV4(v4Params.poolKey, tokenIn, tokenOut);
                bool zeroForOne = tokenIn < tokenOut;
                checkPoolKeyCurrencyV4(v4Params.poolKey, zeroForOne, tokenIn, tokenOut);
                fees[poolIndex] = v4Params.poolKey.fee;
                IV4Quoter.QuoteExactSingleParams memory swapParams = IV4Quoter.QuoteExactSingleParams({
                    poolKey: v4Params.poolKey,
                    zeroForOne: zeroForOne,
                    exactAmount: amountOut.toUint128(),
                    hookData: v4Params.hookData
                });
                (amountIn, gasEstimateForCurrentPool) = UNISWAP_V4_QUOTER.quoteExactOutputSingle(swapParams);
            } else if (pool == PoolTypes.LIKWID_V2) {
                PoolId poolId = abi.decode(params[poolIndex], (PoolId));
                PoolKeyLikwid memory poolKey = LIKWID_PAIR_MANAGER.poolKeys(poolId);
                (tokenIn, tokenOut) = convertWETHToNativeCurrencyLikwid(poolKey, tokenIn, tokenOut);
                bool zeroForOne = tokenIn < tokenOut;
                checkPoolKeyCurrencyLikwid(poolKey, zeroForOne, tokenIn, tokenOut);
                uint24 fee;
                (amountIn, fee,) = LIKWID_QUOTER.getAmountIn(poolId, zeroForOne, amountOut, true);
                fees[poolIndex] = fee;
                gasEstimateForCurrentPool = gasEstimateForCurrentPool - gasleft() + 51_0000;
            } else if (pool == PoolTypes.PANCAKESWAP_INFINITY_CL || pool == PoolTypes.PANCAKESWAP_INFINITY_BIN) {
                QuoteMixedInfiExactSingleParams memory infiParams =
                    abi.decode(params[poolIndex], (QuoteMixedInfiExactSingleParams));
                (tokenIn, tokenOut) = convertWETHToInfiNativeCurrency(infiParams.poolKey, tokenIn, tokenOut);
                bool zeroForOne = tokenIn < tokenOut;
                checkInfiPoolKeyCurrency(infiParams.poolKey, zeroForOne, tokenIn, tokenOut);
                fees[poolIndex] = infiParams.poolKey.fee;
                IInfinityQuoter.QuoteExactSingleParams memory swapParams = IInfinityQuoter.QuoteExactSingleParams({
                    poolKey: infiParams.poolKey,
                    zeroForOne: zeroForOne,
                    exactAmount: amountOut.toUint128(),
                    hookData: infiParams.hookData
                });
                if (pool == PoolTypes.PANCAKESWAP_INFINITY_CL) {
                    (amountIn, gasEstimateForCurrentPool) = INFI_CL_QUOTER.quoteExactOutputSingle(swapParams);
                } else if (pool == PoolTypes.PANCAKESWAP_INFINITY_BIN) {
                    (amountIn, gasEstimateForCurrentPool) = INFI_BIN_QUOTER.quoteExactOutputSingle(swapParams);
                }
            } else {
                revert InvalidPoolType();
            }
            amountOut = amountIn;
            gasEstimate += gasEstimateForCurrentPool;
        }
    }

    function checkPoolKeyCurrencyV4(PoolKey memory poolKey, bool isZeroForOne, address tokenIn, address tokenOut)
        private
        pure
    {
        Currency currency0;
        Currency currency1;
        if (isZeroForOne) {
            currency0 = Currency.wrap(tokenIn);
            currency1 = Currency.wrap(tokenOut);
        } else {
            currency0 = Currency.wrap(tokenOut);
            currency1 = Currency.wrap(tokenIn);
        }
        if (!(poolKey.currency0 == currency0 && poolKey.currency1 == currency1)) {
            revert InvalidPoolKeyCurrency();
        }
    }

    function checkPoolKeyCurrencyLikwid(
        PoolKeyLikwid memory poolKey,
        bool isZeroForOne,
        address tokenIn,
        address tokenOut
    ) private pure {
        CurrencyLikwid currency0;
        CurrencyLikwid currency1;
        if (isZeroForOne) {
            currency0 = CurrencyLikwid.wrap(tokenIn);
            currency1 = CurrencyLikwid.wrap(tokenOut);
        } else {
            currency0 = CurrencyLikwid.wrap(tokenOut);
            currency1 = CurrencyLikwid.wrap(tokenIn);
        }
        if (!(poolKey.currency0 == currency0 && poolKey.currency1 == currency1)) {
            revert InvalidPoolKeyCurrency();
        }
    }

    function checkInfiPoolKeyCurrency(
        PoolKeyInfinity memory poolKey,
        bool isZeroForOne,
        address tokenIn,
        address tokenOut
    ) private pure {
        CurrencyInfinity currency0;
        CurrencyInfinity currency1;
        if (isZeroForOne) {
            currency0 = CurrencyInfinity.wrap(tokenIn);
            currency1 = CurrencyInfinity.wrap(tokenOut);
        } else {
            currency0 = CurrencyInfinity.wrap(tokenOut);
            currency1 = CurrencyInfinity.wrap(tokenIn);
        }
        if (!(poolKey.currency0 == currency0 && poolKey.currency1 == currency1)) {
            revert InvalidPoolKeyCurrency();
        }
    }

    function convertWETHToNativeCurrencyV4(PoolKey memory poolKey, address tokenIn, address tokenOut)
        private
        view
        returns (address, address)
    {
        if (poolKey.currency0.isAddressZero()) {
            if (tokenIn == WETH9) {
                tokenIn = address(0);
            }
            if (tokenOut == WETH9) {
                tokenOut = address(0);
            }
        }
        return (tokenIn, tokenOut);
    }

    function convertWETHToNativeCurrencyLikwid(PoolKeyLikwid memory poolKey, address tokenIn, address tokenOut)
        private
        view
        returns (address, address)
    {
        if (poolKey.currency0.isAddressZero()) {
            if (tokenIn == WETH9) {
                tokenIn = address(0);
            }
            if (tokenOut == WETH9) {
                tokenOut = address(0);
            }
        }
        return (tokenIn, tokenOut);
    }

    function convertWETHToInfiNativeCurrency(PoolKeyInfinity memory poolKey, address tokenIn, address tokenOut)
        private
        view
        returns (address, address)
    {
        if (poolKey.currency0.isNative()) {
            if (tokenIn == WETH9) {
                tokenIn = address(0);
            }
            if (tokenOut == WETH9) {
                tokenOut = address(0);
            }
        }
        return (tokenIn, tokenOut);
    }

    function convertNativeToWETH(address tokenIn, address tokenOut) private view returns (address, address) {
        if (Currency.wrap(tokenIn).isAddressZero()) {
            tokenIn = WETH9;
        }
        if (Currency.wrap(tokenOut).isAddressZero()) {
            tokenOut = WETH9;
        }
        return (tokenIn, tokenOut);
    }
}

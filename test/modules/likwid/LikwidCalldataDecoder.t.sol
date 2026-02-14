// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {Currency} from "@likwid-fi/core/types/Currency.sol";
import {PoolKey} from "@likwid-fi/core/types/PoolKey.sol";
import {PathKey} from "../../../src/modules/likwid/base/PathKey.sol";
import {CalldataDecoder} from "../../../src/modules/likwid/base/CalldataDecoder.sol";
import {ILikwidV2Router} from "../../../src/modules/likwid/interfaces/ILikwidV2Router.sol";

// Harness contract to test calldata functions
contract DecoderHarness {
    function decodeSwapExactInSingle(bytes calldata data)
        external
        pure
        returns (ILikwidV2Router.ExactInputSingleParamsLikwidV2 calldata params)
    {
        params = CalldataDecoder.decodeSwapExactInSingleParams(data);
    }

    function decodeSwapExactOutSingle(bytes calldata data)
        external
        pure
        returns (ILikwidV2Router.ExactOutputSingleParamsLikwidV2 calldata params)
    {
        params = CalldataDecoder.decodeSwapExactOutSingleParams(data);
    }

    function decodeSwapExactIn(bytes calldata data)
        external
        pure
        returns (ILikwidV2Router.ExactInputParamsLikwidV2 calldata params)
    {
        params = CalldataDecoder.decodeSwapExactInParams(data);
    }

    function decodeSwapExactOut(bytes calldata data)
        external
        pure
        returns (ILikwidV2Router.ExactOutputParamsLikwidV2 calldata params)
    {
        params = CalldataDecoder.decodeSwapExactOutParams(data);
    }
}

contract LikwidCalldataDecoderTest is Test {
    using CalldataDecoder for bytes;

    // test tokens
    Currency token1 = Currency.wrap(address(0x1));
    Currency token2 = Currency.wrap(address(0x2));
    Currency token3 = Currency.wrap(address(0x3));

    DecoderHarness harness;

    function setUp() public {
        harness = new DecoderHarness();
    }

    function testDecodeSwapExactInSingleParams() public view {
        PoolKey memory poolKey = PoolKey({currency0: token1, currency1: token2, fee: 3000, marginFee: 100});
        ILikwidV2Router.ExactInputSingleParamsLikwidV2 memory params = ILikwidV2Router.ExactInputSingleParamsLikwidV2({
            poolKey: poolKey, zeroForOne: true, amountIn: 1e18, amountOutMinimum: 0
        });

        bytes memory encodedParams = abi.encode(params);
        ILikwidV2Router.ExactInputSingleParamsLikwidV2 memory decodedParams =
            harness.decodeSwapExactInSingle(encodedParams);

        assertEq(Currency.unwrap(decodedParams.poolKey.currency0), Currency.unwrap(params.poolKey.currency0));
        assertEq(Currency.unwrap(decodedParams.poolKey.currency1), Currency.unwrap(params.poolKey.currency1));
        assertEq(decodedParams.poolKey.fee, params.poolKey.fee);
        assertEq(decodedParams.poolKey.marginFee, params.poolKey.marginFee);
        assertEq(decodedParams.zeroForOne, params.zeroForOne);
        assertEq(decodedParams.amountIn, params.amountIn);
        assertEq(decodedParams.amountOutMinimum, params.amountOutMinimum);
    }

    function testDecodeSwapExactInSingleParams_InvalidLength() public {
        bytes memory encodedParams = new bytes(159); // 0xA0 - 1

        vm.expectRevert(CalldataDecoder.SliceOutOfBounds.selector);
        harness.decodeSwapExactInSingle(encodedParams);
    }

    function testDecodeSwapExactOutSingleParams() public view {
        PoolKey memory poolKey = PoolKey({currency0: token1, currency1: token2, fee: 3000, marginFee: 100});
        ILikwidV2Router.ExactOutputSingleParamsLikwidV2 memory params = ILikwidV2Router.ExactOutputSingleParamsLikwidV2({
            poolKey: poolKey, zeroForOne: true, amountOut: 1e18, amountInMaximum: 2e18
        });

        bytes memory encodedParams = abi.encode(params);
        ILikwidV2Router.ExactOutputSingleParamsLikwidV2 memory decodedParams =
            harness.decodeSwapExactOutSingle(encodedParams);

        assertEq(Currency.unwrap(decodedParams.poolKey.currency0), Currency.unwrap(params.poolKey.currency0));
        assertEq(Currency.unwrap(decodedParams.poolKey.currency1), Currency.unwrap(params.poolKey.currency1));
        assertEq(decodedParams.poolKey.fee, params.poolKey.fee);
        assertEq(decodedParams.poolKey.marginFee, params.poolKey.marginFee);
        assertEq(decodedParams.zeroForOne, params.zeroForOne);
        assertEq(decodedParams.amountOut, params.amountOut);
        assertEq(decodedParams.amountInMaximum, params.amountInMaximum);
    }

    function testDecodeSwapExactOutSingleParams_InvalidLength() public {
        bytes memory encodedParams = new bytes(159); // 0xA0 - 1

        vm.expectRevert(CalldataDecoder.SliceOutOfBounds.selector);
        harness.decodeSwapExactOutSingle(encodedParams);
    }

    function testDecodeSwapExactInParams() public view {
        PathKey[] memory path = new PathKey[](1);
        path[0] = PathKey({intermediateCurrency: token2, fee: 500, marginFee: 100});

        ILikwidV2Router.ExactInputParamsLikwidV2 memory params = ILikwidV2Router.ExactInputParamsLikwidV2({
            currencyIn: token1, path: path, amountIn: 1e18, amountOutMinimum: 0
        });

        bytes memory encodedParams = abi.encode(params);
        ILikwidV2Router.ExactInputParamsLikwidV2 memory decodedParams = harness.decodeSwapExactIn(encodedParams);

        assertEq(Currency.unwrap(decodedParams.currencyIn), Currency.unwrap(params.currencyIn));
        assertEq(decodedParams.path.length, params.path.length);
        assertEq(
            Currency.unwrap(decodedParams.path[0].intermediateCurrency),
            Currency.unwrap(params.path[0].intermediateCurrency)
        );
        assertEq(decodedParams.path[0].fee, params.path[0].fee);
        assertEq(decodedParams.path[0].marginFee, params.path[0].marginFee);
        assertEq(decodedParams.amountIn, params.amountIn);
        assertEq(decodedParams.amountOutMinimum, params.amountOutMinimum);
    }

    function testDecodeSwapExactInParams_InvalidLength() public {
        bytes memory encodedParams = new bytes(159); // 0xa0 - 1

        vm.expectRevert(CalldataDecoder.SliceOutOfBounds.selector);
        harness.decodeSwapExactIn(encodedParams);
    }

    function testDecodeSwapExactOutParams() public view {
        PathKey[] memory path = new PathKey[](1);
        path[0] = PathKey({intermediateCurrency: token2, fee: 500, marginFee: 100});

        ILikwidV2Router.ExactOutputParamsLikwidV2 memory params = ILikwidV2Router.ExactOutputParamsLikwidV2({
            currencyOut: token3, path: path, amountOut: 1e18, amountInMaximum: 2e18
        });

        bytes memory encodedParams = abi.encode(params);
        ILikwidV2Router.ExactOutputParamsLikwidV2 memory decodedParams = harness.decodeSwapExactOut(encodedParams);

        assertEq(Currency.unwrap(decodedParams.currencyOut), Currency.unwrap(params.currencyOut));
        assertEq(decodedParams.path.length, params.path.length);
        assertEq(
            Currency.unwrap(decodedParams.path[0].intermediateCurrency),
            Currency.unwrap(params.path[0].intermediateCurrency)
        );
        assertEq(decodedParams.path[0].fee, params.path[0].fee);
        assertEq(decodedParams.path[0].marginFee, params.path[0].marginFee);
        assertEq(decodedParams.amountOut, params.amountOut);
        assertEq(decodedParams.amountInMaximum, params.amountInMaximum);
    }

    function testDecodeSwapExactOutParams_InvalidLength() public {
        bytes memory encodedParams = new bytes(159); // 0xa0 - 1

        vm.expectRevert(CalldataDecoder.SliceOutOfBounds.selector);
        harness.decodeSwapExactOut(encodedParams);
    }
}

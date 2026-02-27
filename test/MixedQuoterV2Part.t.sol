// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";

import {MixedQuoter} from "../src/MixedQuoter.sol";
import {PoolTypes} from "../src/libraries/PoolTypes.sol";
import {PoolId} from "infinity-core/src/types/PoolId.sol";
import {QuoterParameters} from "../src/base/QuoterImmutables.sol";

contract MixedQuoterV2PartTest is Test {
    address constant RECIPIENT = address(10);
    uint256 constant AMOUNT = 1 ether;
    uint256 constant BALANCE = 100000 ether;
    ERC20 constant WETH9 = ERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    address constant FROM = address(1234);

    MixedQuoter public mixedQuoter;

    ERC20 public USDT = ERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    PoolId public NATIVE_USDT_POOL_ID = PoolId.wrap(0x4bdea42d669a1ff8e67c12f81c70585e1be95353c27e4a6cc918ea923f6bbbdc);
    ERC20 public token2;

    function setUp() public {
        vm.createSelectFork(vm.envString("FORK_1_URL"));

        QuoterParameters memory params = QuoterParameters({
            weth9: address(WETH9),
            likwidQuoter: address(0x16a9633f8A777CA733073ea2526705cD8338d510),
            likwidPairManager: address(0xB397FE16BE79B082f17F1CD96e6489df19E07BCD),
            uniswapV2Router: address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D),
            uniswapV3Quoter: address(0),
            uniswapV4Quoter: address(0),
            stableFactory: address(0),
            stableInfo: address(0),
            pancakeswapV2Router: address(0),
            pancakeswapV3Quoter: address(0),
            infiClQuoter: address(0),
            infiBinQuoter: address(0)
        });
        mixedQuoter = new MixedQuoter(params);

        vm.startPrank(FROM);
    }

    function test_likwid_v2_quoteMixedExactInput01() public {
        address[] memory paths = new address[](2);
        paths[0] = address(0);
        paths[1] = address(USDT);

        bytes memory pools = new bytes(1);
        pools[0] = bytes1(uint8(PoolTypes.LIKWID_V2));

        bytes[] memory params = new bytes[](1);
        uint24 fee = 3000; // 0.3% fee tier
        params[0] = abi.encode(NATIVE_USDT_POOL_ID);

        (uint256 amountOut, uint256 gasEstimate, uint256[] memory fees) =
            mixedQuoter.quoteMixedExactInput(paths, pools, params, 0.1 ether);

        console.log("Amount out:%s,gasEstimate", amountOut, gasEstimate);
        assertGt(amountOut, 100 * 10 ** USDT.decimals());
        assertGt(fees[0], fee);
        assertGt(gasEstimate, 10000);
    }

    function test_likwid_v2_quoteMixedExactInput02() public {
        address[] memory paths = new address[](2);
        paths[0] = address(0);
        paths[1] = address(USDT);

        bytes memory pools = new bytes(1);
        pools[0] = bytes1(uint8(PoolTypes.LIKWID_V2));

        bytes[] memory params = new bytes[](1);
        uint24 fee = 3000; // 0.3% fee tier
        params[0] = abi.encode(NATIVE_USDT_POOL_ID);

        (uint256 amountOut, uint256 gasEstimate, uint256[] memory fees) =
            mixedQuoter.quoteMixedExactInput(paths, pools, params, 0.2 ether);

        console.log("Amount out:%s,gasEstimate", amountOut, gasEstimate);
        assertGt(amountOut, 200 * 10 ** USDT.decimals());
        assertGt(fees[0], fee);
        assertGt(gasEstimate, 10000);
    }

    function test_likwid_v2_quoteMixedExactOutput01() public {
        address[] memory paths = new address[](2);
        paths[0] = address(0);
        paths[1] = address(USDT);

        bytes memory pools = new bytes(1);
        pools[0] = bytes1(uint8(PoolTypes.LIKWID_V2));

        bytes[] memory params = new bytes[](1);
        uint24 fee = 3000; // 0.3% fee tier
        params[0] = abi.encode(NATIVE_USDT_POOL_ID);

        (uint256 amountIn, uint256 gasEstimate, uint256[] memory fees) =
            mixedQuoter.quoteMixedExactOutput(paths, pools, params, 300 * 10 ** USDT.decimals());

        console.log("Amount in:%s,gasEstimate", amountIn, gasEstimate);
        assertGt(amountIn, 0.1 ether);
        assertGt(fees[0], fee);
        assertGt(gasEstimate, 10000);
    }

    function test_likwid_v2_quoteMixedExactOutput02() public {
        address[] memory paths = new address[](2);
        paths[0] = address(0);
        paths[1] = address(USDT);

        bytes memory pools = new bytes(1);
        pools[0] = bytes1(uint8(PoolTypes.LIKWID_V2));

        bytes[] memory params = new bytes[](1);
        uint24 fee = 3000; // 0.3% fee tier
        params[0] = abi.encode(NATIVE_USDT_POOL_ID);

        (uint256 amountIn, uint256 gasEstimate, uint256[] memory fees) =
            mixedQuoter.quoteMixedExactOutput(paths, pools, params, 10 * 10 ** USDT.decimals());

        console.log("Amount in:%s,gasEstimate", amountIn, gasEstimate);
        assertGt(amountIn, 0);
        assertLt(amountIn, 0.01 ether);
        assertEq(fees[0], fee);
        assertGt(gasEstimate, 10000);
    }

    function test_likwid_v2_uniswap_v2_quoteMixedExactInput() public {
        address[] memory paths = new address[](3);
        paths[0] = address(USDT);
        paths[1] = address(0);
        paths[2] = address(USDT);

        bytes memory pools = new bytes(2);
        pools[0] = bytes1(uint8(PoolTypes.LIKWID_V2));
        pools[1] = bytes1(uint8(PoolTypes.UNISWAP_V2));

        bytes[] memory params = new bytes[](2);
        params[0] = abi.encode(NATIVE_USDT_POOL_ID);

        (uint256 amountOut, uint256 gasEstimate, uint256[] memory fees) =
            mixedQuoter.quoteMixedExactInput(paths, pools, params, 1e6);

        console.log("Amount out:%s,gasEstimate", amountOut, gasEstimate);
        assertGt(amountOut, 0.8e6);
        assertGt(fees[0], 0);
        assertEq(fees[1], 3000);
        assertGt(gasEstimate, 10000);
    }

    function test_likwid_v2_uniswap_v2_quoteMixedExactOutput() public {
        address[] memory paths = new address[](3);
        paths[0] = address(USDT);
        paths[1] = address(0);
        paths[2] = address(USDT);

        bytes memory pools = new bytes(2);
        pools[0] = bytes1(uint8(PoolTypes.LIKWID_V2));
        pools[1] = bytes1(uint8(PoolTypes.UNISWAP_V2));

        bytes[] memory params = new bytes[](2);
        params[0] = abi.encode(NATIVE_USDT_POOL_ID);

        (uint256 amountIn, uint256 gasEstimate, uint256[] memory fees) =
            mixedQuoter.quoteMixedExactOutput(paths, pools, params, 0.8e6);

        console.log("Amount in:%s,gasEstimate", amountIn, gasEstimate);
        assertGt(amountIn, 0.8e6);
        assertGt(fees[0], 0);
        assertEq(fees[1], 3000);
        assertGt(gasEstimate, 10000);
    }
}

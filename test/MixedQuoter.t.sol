// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";

import {IMixedQuoter} from "../src/interfaces/IMixedQuoter.sol";
import {MixedQuoter} from "../src/MixedQuoter.sol";
import {PoolTypes} from "../src/libraries/PoolTypes.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {PoolId} from "@uniswap/v4-core/src/types/PoolId.sol";
import {PoolId as PoolIdInfinity} from "infinity-core/src/types/PoolId.sol";
import {Currency as CurrencyInfinity} from "infinity-core/src/types/Currency.sol";
import {PoolKey as PoolKeyInfinity} from "infinity-core/src/types/PoolKey.sol";
import {IHooks as IHooksInfinity} from "infinity-core/src/interfaces/IHooks.sol";
import {IPoolManager} from "infinity-core/src/interfaces/IPoolManager.sol";
import {QuoterParameters} from "../src/base/QuoterImmutables.sol";

contract MixedQuoterTest is Test {
    address constant RECIPIENT = address(10);
    uint256 constant AMOUNT = 1 ether;
    uint256 constant BALANCE = 100000 ether;
    ERC20 constant WETH9 = ERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    address constant FROM = address(1234);

    MixedQuoter public mixedQuoter;

    ERC20 public USDT = ERC20(0x55d398326f99059fF775485246999027B3197955);
    ERC20 public USDC = ERC20(0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d);
    ERC20 public BTCB = ERC20(0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c);
    ERC20 public token2;

    function setUp() public {
        vm.createSelectFork(vm.envString("FORK_URL"));

        QuoterParameters memory params = QuoterParameters({
            weth9: address(WETH9),
            likwidV2StatusManager: address(0x622A27A80D111cEe6Ef7f0359C359eDCD87e2280),
            uniswapV2Router: address(0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24),
            uniswapV3Quoter: address(0x78D78E420Da98ad378D7799bE8f4AF69033EB077),
            uniswapV4Quoter: address(0x9F75dD27D6664c475B90e105573E550ff69437B0),
            stableFactory: address(0x25a55f9f2279A54951133D503490342b50E5cd15),
            stableInfo: address(0xf3A6938945E68193271Cad8d6f79B1f878b16Eb1),
            pancakeswapV2Router: address(0x10ED43C718714eb63d5aA57B78B54704E256024E),
            pancakeswapV3Quoter: address(0xB048Bbc1Ee6b733FFfCFb9e9CeF7375518e25997),
            infiClQuoter: address(0xd0737C9762912dD34c3271197E362Aa736Df0926),
            infiBinQuoter: address(0xC631f4B0Fc2Dd68AD45f74B2942628db117dD359)
        });
        mixedQuoter = new MixedQuoter(params);

        vm.startPrank(FROM);
    }

    function test_pancakeswap_v2_quoteMixedExactInput() public {
        address[] memory paths = new address[](2);
        paths[0] = address(USDT);
        paths[1] = address(WETH9);

        bytes memory pools = new bytes(1);
        pools[0] = bytes1(uint8(PoolTypes.PANCAKESWAP_V2));

        bytes[] memory params = new bytes[](1);

        (uint256 amountOut, uint256 gasEstimate, uint256[] memory fees) =
            mixedQuoter.quoteMixedExactInput(paths, pools, params, 1 ether);

        console.log("Amount out:", amountOut);
        assertGt(amountOut, 0.001 ether);
        assertEq(fees[0], 2500);
        assertGt(gasEstimate, 10000);
    }

    function test_pancakeswap_v2_quoteMixedExactOutput() public {
        address[] memory paths = new address[](2);
        paths[0] = address(USDT);
        paths[1] = address(WETH9);

        bytes memory pools = new bytes(1);
        pools[0] = bytes1(uint8(PoolTypes.PANCAKESWAP_V2));

        bytes[] memory params = new bytes[](1);

        (uint256 amountIn, uint256 gasEstimate, uint256[] memory fees) =
            mixedQuoter.quoteMixedExactOutput(paths, pools, params, 1546087247240808);

        console.log("Amount in:", amountIn);
        assertGt(amountIn, 0.9 ether);
        assertEq(fees[0], 2500);
        assertGt(gasEstimate, 10000);
    }

    function test_uniswap_v2_quoteMixedExactInput() public {
        address[] memory paths = new address[](2);
        paths[0] = address(USDT);
        paths[1] = address(WETH9);

        bytes memory pools = new bytes(1);
        pools[0] = bytes1(uint8(PoolTypes.UNISWAP_V2));

        bytes[] memory params = new bytes[](1);

        (uint256 amountOut, uint256 gasEstimate, uint256[] memory fees) =
            mixedQuoter.quoteMixedExactInput(paths, pools, params, 1 ether);

        console.log("Amount out:", amountOut);
        assertGt(amountOut, 0.001 ether);
        assertEq(fees[0], 3000);
        assertGt(gasEstimate, 10000);
    }

    function test_uniswap_v2_quoteMixedExactOutput() public {
        address[] memory paths = new address[](2);
        paths[0] = address(USDT);
        paths[1] = address(WETH9);

        bytes memory pools = new bytes(1);
        pools[0] = bytes1(uint8(PoolTypes.UNISWAP_V2));

        bytes[] memory params = new bytes[](1);

        (uint256 amountIn, uint256 gasEstimate, uint256[] memory fees) =
            mixedQuoter.quoteMixedExactOutput(paths, pools, params, 1546087247240808);

        console.log("Amount in:", amountIn);
        assertGt(amountIn, 0.9 ether);
        assertEq(fees[0], 3000);
        assertGt(gasEstimate, 10000);
    }

    function test_v2_quoteMixedExactInput() public {
        address[] memory paths = new address[](3);
        paths[0] = address(USDT);
        paths[1] = address(WETH9);
        paths[2] = address(USDT);

        bytes memory pools = new bytes(2);
        pools[0] = bytes1(uint8(PoolTypes.PANCAKESWAP_V2));
        pools[1] = bytes1(uint8(PoolTypes.UNISWAP_V2));

        bytes[] memory params = new bytes[](2);

        (uint256 amountOut, uint256 gasEstimate, uint256[] memory fees) =
            mixedQuoter.quoteMixedExactInput(paths, pools, params, 1 ether);

        console.log("Amount out:", amountOut);
        assertGt(amountOut, 0.5 ether);
        assertLt(amountOut, 1 ether);
        assertEq(fees[0], 2500);
        assertEq(fees[1], 3000);
        assertGt(gasEstimate, 20000);
    }

    function test_v2_quoteMixedExactOutput() public {
        address[] memory paths = new address[](3);
        paths[0] = address(USDT);
        paths[1] = address(WETH9);
        paths[2] = address(USDT);

        bytes memory pools = new bytes(2);
        pools[0] = bytes1(uint8(PoolTypes.PANCAKESWAP_V2));
        pools[1] = bytes1(uint8(PoolTypes.UNISWAP_V2));

        bytes[] memory params = new bytes[](2);

        (uint256 amountIn, uint256 gasEstimate, uint256[] memory fees) =
            mixedQuoter.quoteMixedExactOutput(paths, pools, params, 1 ether);

        console.log("Amount in:", amountIn);
        assertGt(amountIn, 1 ether);
        assertEq(fees[0], 2500);
        assertEq(fees[1], 3000);
        assertGt(gasEstimate, 20000);
    }

    function test_pancakeswap_v3_quoteMixedExactInput() public {
        address[] memory paths = new address[](2);
        paths[0] = address(USDT);
        paths[1] = address(WETH9);

        bytes memory pools = new bytes(1);
        pools[0] = bytes1(uint8(PoolTypes.PANCAKESWAP_V3));

        bytes[] memory params = new bytes[](1);
        uint24 fee = 500; // 0.05% fee tier
        params[0] = abi.encode(fee);

        (uint256 amountOut, uint256 gasEstimate, uint256[] memory fees) =
            mixedQuoter.quoteMixedExactInput(paths, pools, params, 1 ether);

        console.log("Amount out:", amountOut);
        assertGt(amountOut, 0.001 ether);
        assertEq(fees[0], 500);
        assertGt(gasEstimate, 10000);
    }

    function test_pancakeswap_v3_quoteMixedExactOutput() public {
        address[] memory paths = new address[](2);
        paths[0] = address(USDT);
        paths[1] = address(WETH9);

        bytes memory pools = new bytes(1);
        pools[0] = bytes1(uint8(PoolTypes.PANCAKESWAP_V3));

        bytes[] memory params = new bytes[](1);
        uint24 fee = 500; // 0.05% fee tier
        params[0] = abi.encode(fee);

        (uint256 amountIn, uint256 gasEstimate, uint256[] memory fees) =
            mixedQuoter.quoteMixedExactOutput(paths, pools, params, 1543200926235022);

        console.log("Amount in:", amountIn);
        assertGt(amountIn, 0.9 ether);
        assertEq(fees[0], 500);
        assertGt(gasEstimate, 10000);
    }

    function test_uniswap_v3_quoteMixedExactInput() public {
        address[] memory paths = new address[](2);
        paths[0] = address(USDT);
        paths[1] = address(WETH9);

        bytes memory pools = new bytes(1);
        pools[0] = bytes1(uint8(PoolTypes.UNISWAP_V3));

        bytes[] memory params = new bytes[](1);
        uint24 fee = 500; // 0.05% fee tier
        params[0] = abi.encode(fee);

        (uint256 amountOut, uint256 gasEstimate, uint256[] memory fees) =
            mixedQuoter.quoteMixedExactInput(paths, pools, params, 1 ether);

        console.log("Amount out:", amountOut);
        assertGt(amountOut, 0.001 ether);
        assertEq(fees[0], 500);
        assertGt(gasEstimate, 10000);
    }

    function test_uniswap_v3_quoteMixedExactOutput() public {
        address[] memory paths = new address[](2);
        paths[0] = address(USDT);
        paths[1] = address(WETH9);

        bytes memory pools = new bytes(1);
        pools[0] = bytes1(uint8(PoolTypes.UNISWAP_V3));

        bytes[] memory params = new bytes[](1);
        uint24 fee = 500; // 0.05% fee tier
        params[0] = abi.encode(fee);

        (uint256 amountIn, uint256 gasEstimate, uint256[] memory fees) =
            mixedQuoter.quoteMixedExactOutput(paths, pools, params, 1543200926235022);

        console.log("Amount in:", amountIn);
        assertGt(amountIn, 0.9 ether);
        assertEq(fees[0], 500);
        assertGt(gasEstimate, 10000);
    }

    function test_mixed_v2_v3_quoteMixedExactInput01() public {
        address[] memory paths = new address[](3);
        paths[0] = address(USDT);
        paths[1] = address(WETH9);
        paths[2] = address(USDT);

        bytes memory pools = new bytes(2);
        pools[0] = bytes1(uint8(PoolTypes.UNISWAP_V2));
        pools[1] = bytes1(uint8(PoolTypes.UNISWAP_V3));

        bytes[] memory params = new bytes[](2);
        uint24 fee = 500; // 0.05% fee tier
        params[1] = abi.encode(fee);

        (uint256 amountOut, uint256 gasEstimate, uint256[] memory fees) =
            mixedQuoter.quoteMixedExactInput(paths, pools, params, 1 ether);

        console.log("Amount out:", amountOut);
        assertGt(amountOut, 0.5 ether);
        assertLt(amountOut, 1 ether);
        assertEq(fees[0], 3000);
        assertEq(fees[1], 500);
        assertGt(gasEstimate, 10000);
    }

    function test_mixed_v2_v3_quoteMixedExactInput02() public {
        address[] memory paths = new address[](3);
        paths[0] = address(USDT);
        paths[1] = address(WETH9);
        paths[2] = address(USDT);

        bytes memory pools = new bytes(2);
        pools[0] = bytes1(uint8(PoolTypes.PANCAKESWAP_V2));
        pools[1] = bytes1(uint8(PoolTypes.UNISWAP_V3));

        bytes[] memory params = new bytes[](2);
        uint24 fee = 500; // 0.05% fee tier
        params[1] = abi.encode(fee);

        (uint256 amountOut, uint256 gasEstimate, uint256[] memory fees) =
            mixedQuoter.quoteMixedExactInput(paths, pools, params, 1 ether);

        console.log("Amount out:", amountOut);
        assertGt(amountOut, 0.5 ether);
        assertLt(amountOut, 1 ether);
        assertEq(fees[0], 2500);
        assertEq(fees[1], 500);
        assertGt(gasEstimate, 10000);
    }

    function test_mixed_v2_v3_quoteMixedExactOutput01() public {
        address[] memory paths = new address[](3);
        paths[0] = address(USDT);
        paths[1] = address(WETH9);
        paths[2] = address(USDT);

        bytes memory pools = new bytes(2);
        pools[0] = bytes1(uint8(PoolTypes.UNISWAP_V2));
        pools[1] = bytes1(uint8(PoolTypes.UNISWAP_V3));

        bytes[] memory params = new bytes[](2);
        uint24 fee = 500; // 0.05% fee tier
        params[1] = abi.encode(fee);

        (uint256 amountIn, uint256 gasEstimate, uint256[] memory fees) =
            mixedQuoter.quoteMixedExactOutput(paths, pools, params, 1 ether);

        console.log("Amount in:", amountIn);
        assertGt(amountIn, 1 ether);
        assertEq(fees[0], 3000);
        assertEq(fees[1], 500);
        assertGt(gasEstimate, 10000);
    }

    function test_mixed_v2_v3_quoteMixedExactOutput02() public {
        address[] memory paths = new address[](3);
        paths[0] = address(USDT);
        paths[1] = address(WETH9);
        paths[2] = address(USDT);

        bytes memory pools = new bytes(2);
        pools[0] = bytes1(uint8(PoolTypes.PANCAKESWAP_V2));
        pools[1] = bytes1(uint8(PoolTypes.UNISWAP_V3));

        bytes[] memory params = new bytes[](2);
        uint24 fee = 500; // 0.05% fee tier
        params[1] = abi.encode(fee);

        (uint256 amountIn, uint256 gasEstimate, uint256[] memory fees) =
            mixedQuoter.quoteMixedExactOutput(paths, pools, params, 1 ether);

        console.log("Amount in:", amountIn);
        assertGt(amountIn, 1 ether);
        assertEq(fees[0], 2500);
        assertEq(fees[1], 500);
        assertGt(gasEstimate, 10000);
    }

    function test_uniswap_v4_quoteMixedExactInput() public {
        address[] memory paths = new address[](2);
        paths[0] = address(USDT);
        paths[1] = address(0);

        bytes memory pools = new bytes(1);
        pools[0] = bytes1(uint8(PoolTypes.UNISWAP_V4));

        bytes[] memory params = new bytes[](1);
        uint24 fee = 500; // 0.05% fee tier
        PoolKey memory poolKey = PoolKey({
            currency0: Currency.wrap(address(0)),
            currency1: Currency.wrap(address(USDT)),
            fee: fee,
            tickSpacing: 10,
            hooks: IHooks(address(0))
        });
        console.logBytes32(PoolId.unwrap(poolKey.toId()));
        IMixedQuoter.QuoteMixedV4ExactSingleParams memory v4Params =
            IMixedQuoter.QuoteMixedV4ExactSingleParams({poolKey: poolKey, hookData: ""});
        params[0] = abi.encode(v4Params);

        (uint256 amountOut, uint256 gasEstimate, uint256[] memory fees) =
            mixedQuoter.quoteMixedExactInput(paths, pools, params, 1 ether);

        console.log("Amount out:", amountOut);
        assertGt(amountOut, 0.001 ether);
        assertEq(fees[0], 500);
        assertGt(gasEstimate, 10000);
    }

    function test_uniswap_v4_quoteMixedExactOutput() public {
        address[] memory paths = new address[](2);
        paths[0] = address(USDT);
        paths[1] = address(0);

        bytes memory pools = new bytes(1);
        pools[0] = bytes1(uint8(PoolTypes.UNISWAP_V4));

        bytes[] memory params = new bytes[](1);
        uint24 fee = 500; // 0.05% fee tier
        PoolKey memory poolKey = PoolKey({
            currency0: Currency.wrap(address(0)),
            currency1: Currency.wrap(address(USDT)),
            fee: fee,
            tickSpacing: 10,
            hooks: IHooks(address(0))
        });
        console.logBytes32(PoolId.unwrap(poolKey.toId()));
        IMixedQuoter.QuoteMixedV4ExactSingleParams memory v4Params =
            IMixedQuoter.QuoteMixedV4ExactSingleParams({poolKey: poolKey, hookData: ""});
        params[0] = abi.encode(v4Params);

        (uint256 amountIn, uint256 gasEstimate, uint256[] memory fees) =
            mixedQuoter.quoteMixedExactOutput(paths, pools, params, 1533043257945944);

        console.log("Amount in:", amountIn);
        assertGt(amountIn, 0.9 ether);
        assertEq(fees[0], 500);
        assertGt(gasEstimate, 10000);
    }

    function test_likwid_v2_quoteMixedExactInput01() public {
        address[] memory paths = new address[](2);
        paths[0] = address(0);
        paths[1] = address(BTCB);

        bytes memory pools = new bytes(1);
        pools[0] = bytes1(uint8(PoolTypes.LIKWID_V2));

        bytes[] memory params = new bytes[](1);
        uint24 fee = 3000; // 0.3% fee tier
        PoolId poolId = PoolId.wrap(0x2d4c8880851691294e4da29abad90322c2d074fe2bac462f756ca8fb633391c5);
        params[0] = abi.encode(poolId);

        (uint256 amountOut, uint256 gasEstimate, uint256[] memory fees) =
            mixedQuoter.quoteMixedExactInput(paths, pools, params, 0.1 ether);

        console.log("Amount out:%s,gasEstimate", amountOut, gasEstimate);
        assertGt(amountOut, 0.0006 ether);
        assertEq(fees[0], fee);
        assertGt(gasEstimate, 10000);
    }

    function test_likwid_v2_quoteMixedExactInput02() public {
        address[] memory paths = new address[](2);
        paths[0] = address(0);
        paths[1] = address(BTCB);

        bytes memory pools = new bytes(1);
        pools[0] = bytes1(uint8(PoolTypes.LIKWID_V2));

        bytes[] memory params = new bytes[](1);
        uint24 fee = 3000; // 0.3% fee tier
        PoolId poolId = PoolId.wrap(0x2d4c8880851691294e4da29abad90322c2d074fe2bac462f756ca8fb633391c5);
        params[0] = abi.encode(poolId);

        (uint256 amountOut, uint256 gasEstimate, uint256[] memory fees) =
            mixedQuoter.quoteMixedExactInput(paths, pools, params, 1 ether);

        console.log("Amount out:", amountOut);
        assertGt(amountOut, 0.005 ether);
        assertLt(amountOut, 0.007 ether);
        assertGt(fees[0], fee);
        assertGt(gasEstimate, 10000);
    }

    function test_likwid_v2_quoteMixedExactOutput01() public {
        address[] memory paths = new address[](2);
        paths[0] = address(0);
        paths[1] = address(BTCB);

        bytes memory pools = new bytes(1);
        pools[0] = bytes1(uint8(PoolTypes.LIKWID_V2));

        bytes[] memory params = new bytes[](1);
        uint24 fee = 3000; // 0.3% fee tier
        PoolId poolId = PoolId.wrap(0x2d4c8880851691294e4da29abad90322c2d074fe2bac462f756ca8fb633391c5);
        params[0] = abi.encode(poolId);

        (uint256 amountIn, uint256 gasEstimate, uint256[] memory fees) =
            mixedQuoter.quoteMixedExactOutput(paths, pools, params, 0.0007 ether);

        console.log("Amount in:", amountIn);
        assertGt(amountIn, 0.1 ether);
        assertEq(fees[0], fee);
        assertGt(gasEstimate, 10000);
    }

    function test_likwid_v2_quoteMixedExactOutput02() public {
        address[] memory paths = new address[](2);
        paths[0] = address(0);
        paths[1] = address(BTCB);

        bytes memory pools = new bytes(1);
        pools[0] = bytes1(uint8(PoolTypes.LIKWID_V2));

        bytes[] memory params = new bytes[](1);
        uint24 fee = 3000; // 0.3% fee tier
        PoolId poolId = PoolId.wrap(0x2d4c8880851691294e4da29abad90322c2d074fe2bac462f756ca8fb633391c5);
        params[0] = abi.encode(poolId);

        (uint256 amountIn, uint256 gasEstimate, uint256[] memory fees) =
            mixedQuoter.quoteMixedExactOutput(paths, pools, params, 0.006 ether);

        console.log("Amount in:", amountIn);
        assertGt(amountIn, 1 ether);
        assertGt(fees[0], fee);
        assertGt(gasEstimate, 10000);
    }

    function test_stable_quoteMixedExactInput() public {
        address[] memory paths = new address[](2);
        paths[0] = address(USDT);
        paths[1] = address(USDC);

        bytes memory pools = new bytes(1);
        pools[0] = bytes1(uint8(PoolTypes.PANCAKESWAP_STABLE));

        bytes[] memory params = new bytes[](1);

        (uint256 amountOut, uint256 gasEstimate, uint256[] memory fees) =
            mixedQuoter.quoteMixedExactInput(paths, pools, params, 0.1 ether);

        console.log("Amount out:", amountOut);
        assertGt(amountOut, 0.09 ether);
        assertLt(amountOut, 0.11 ether);
        assertEq(fees[0], 0);
        assertGt(gasEstimate, 10000);
    }

    function test_stable_quoteMixedExactOutput() public {
        address[] memory paths = new address[](2);
        paths[0] = address(USDC);
        paths[1] = address(USDT);

        bytes memory pools = new bytes(1);
        pools[0] = bytes1(uint8(PoolTypes.PANCAKESWAP_STABLE));

        bytes[] memory params = new bytes[](1);

        (uint256 amountIn, uint256 gasEstimate, uint256[] memory fees) =
            mixedQuoter.quoteMixedExactOutput(paths, pools, params, 0.1 ether);

        console.log("Amount in:", amountIn);
        assertGt(amountIn, 0.09 ether);
        assertLt(amountIn, 0.11 ether);
        assertEq(fees[0], 0);
        assertGt(gasEstimate, 10000);
    }

    function test_pancakeswap_cl_quoteMixedExactInput() public {
        address[] memory paths = new address[](2);
        paths[0] = address(USDT);
        paths[1] = address(0);

        bytes memory pools = new bytes(1);
        pools[0] = bytes1(uint8(PoolTypes.PANCAKESWAP_INFINITY_CL));

        bytes[] memory params = new bytes[](1);
        uint24 fee = 335; // 0.0335% fee tier
        PoolKeyInfinity memory poolKey = PoolKeyInfinity({
            currency0: CurrencyInfinity.wrap(address(0)),
            currency1: CurrencyInfinity.wrap(address(USDT)),
            fee: fee,
            hooks: IHooksInfinity(address(0)),
            poolManager: IPoolManager(0xa0FfB9c1CE1Fe56963B0321B32E7A0302114058b),
            parameters: 0x00000000000000000000000000000000000000000000000000000000000a0000
        });
        console.logBytes32(PoolIdInfinity.unwrap(poolKey.toId()));
        IMixedQuoter.QuoteMixedInfiExactSingleParams memory clParams =
            IMixedQuoter.QuoteMixedInfiExactSingleParams({poolKey: poolKey, hookData: ""});
        params[0] = abi.encode(clParams);

        (uint256 amountOut, uint256 gasEstimate, uint256[] memory fees) =
            mixedQuoter.quoteMixedExactInput(paths, pools, params, 1 ether);

        console.log("Amount out:", amountOut);
        assertGt(amountOut, 0.001 ether);
        assertEq(fees[0], 335);
        assertGt(gasEstimate, 10000);
    }

    function test_pancakeswap_cl_quoteMixedExactOutput() public {
        address[] memory paths = new address[](2);
        paths[0] = address(USDT);
        paths[1] = address(0);

        bytes memory pools = new bytes(1);
        pools[0] = bytes1(uint8(PoolTypes.PANCAKESWAP_INFINITY_CL));

        bytes[] memory params = new bytes[](1);
        uint24 fee = 335; // 0.0335% fee tier
        PoolKeyInfinity memory poolKey = PoolKeyInfinity({
            currency0: CurrencyInfinity.wrap(address(0)),
            currency1: CurrencyInfinity.wrap(address(USDT)),
            fee: fee,
            hooks: IHooksInfinity(address(0)),
            poolManager: IPoolManager(0xa0FfB9c1CE1Fe56963B0321B32E7A0302114058b),
            parameters: 0x00000000000000000000000000000000000000000000000000000000000a0000
        });
        console.logBytes32(PoolIdInfinity.unwrap(poolKey.toId()));
        IMixedQuoter.QuoteMixedInfiExactSingleParams memory clParams =
            IMixedQuoter.QuoteMixedInfiExactSingleParams({poolKey: poolKey, hookData: ""});
        params[0] = abi.encode(clParams);

        (uint256 amountIn, uint256 gasEstimate, uint256[] memory fees) =
            mixedQuoter.quoteMixedExactOutput(paths, pools, params, 1533043257945944);

        console.log("Amount in:", amountIn);
        assertGt(amountIn, 0.9 ether);
        assertEq(fees[0], 335);
        assertGt(gasEstimate, 10000);
    }

    function test_pancakeswap_bin_quoteMixedExactInput() public {
        address[] memory paths = new address[](2);
        paths[0] = address(USDT);
        paths[1] = address(0);

        bytes memory pools = new bytes(1);
        pools[0] = bytes1(uint8(PoolTypes.PANCAKESWAP_INFINITY_BIN));

        bytes[] memory params = new bytes[](1);
        uint24 fee = 67; // 0.0067% fee tier
        PoolKeyInfinity memory poolKey = PoolKeyInfinity({
            currency0: CurrencyInfinity.wrap(address(0)),
            currency1: CurrencyInfinity.wrap(address(USDT)),
            fee: fee,
            hooks: IHooksInfinity(address(0)),
            poolManager: IPoolManager(0xC697d2898e0D09264376196696c51D7aBbbAA4a9),
            parameters: 0x00000000000000000000000000000000000000000000000000000000000a0000
        });
        console.logBytes32(PoolIdInfinity.unwrap(poolKey.toId()));
        IMixedQuoter.QuoteMixedInfiExactSingleParams memory clParams =
            IMixedQuoter.QuoteMixedInfiExactSingleParams({poolKey: poolKey, hookData: ""});
        params[0] = abi.encode(clParams);

        (uint256 amountOut, uint256 gasEstimate, uint256[] memory fees) =
            mixedQuoter.quoteMixedExactInput(paths, pools, params, 1000);

        console.log("Amount out:", amountOut);
        assertGt(amountOut, 0);
        assertEq(fees[0], 67);
        assertGt(gasEstimate, 10000);
    }

    function test_pancakeswap_bin_quoteMixedExactOutput() public {
        address[] memory paths = new address[](2);
        paths[0] = address(USDT);
        paths[1] = address(0);

        bytes memory pools = new bytes(1);
        pools[0] = bytes1(uint8(PoolTypes.PANCAKESWAP_INFINITY_BIN));

        bytes[] memory params = new bytes[](1);
        uint24 fee = 67; // 0.0067% fee tier
        PoolKeyInfinity memory poolKey = PoolKeyInfinity({
            currency0: CurrencyInfinity.wrap(address(0)),
            currency1: CurrencyInfinity.wrap(address(USDT)),
            fee: fee,
            hooks: IHooksInfinity(address(0)),
            poolManager: IPoolManager(0xC697d2898e0D09264376196696c51D7aBbbAA4a9),
            parameters: 0x00000000000000000000000000000000000000000000000000000000000a0000
        });
        console.logBytes32(PoolIdInfinity.unwrap(poolKey.toId()));
        IMixedQuoter.QuoteMixedInfiExactSingleParams memory clParams =
            IMixedQuoter.QuoteMixedInfiExactSingleParams({poolKey: poolKey, hookData: ""});
        params[0] = abi.encode(clParams);

        (uint256 amountIn, uint256 gasEstimate, uint256[] memory fees) =
            mixedQuoter.quoteMixedExactOutput(paths, pools, params, 2);

        console.log("Amount in:", amountIn);
        assertGt(amountIn, 0);
        assertEq(fees[0], 67);
        assertGt(gasEstimate, 10000);
    }
}

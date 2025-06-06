// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {ActionConstants} from "infinity-periphery/src/libraries/ActionConstants.sol";

import {IPermit2} from "permit2/src/interfaces/IPermit2.sol";
import {UniversalRouter} from "../../src/UniversalRouter.sol";
import {ISwapV3Factory} from "../../src/modules/v3/interfaces/ISwapV3Factory.sol";
import {ISwapV3Pool} from "../../src/modules/v3/interfaces/ISwapV3Pool.sol";
import {V3SwapRouter} from "../../src/modules/v3/V3SwapRouter.sol";
import {Constants} from "../../src/libraries/Constants.sol";
import {Commands} from "../../src/libraries/Commands.sol";
import {RouterParameters} from "../../src/base/RouterImmutables.sol";

/// @dev fork BSC network
abstract contract UniswapV3Test is Test {
    address constant RECIPIENT = address(10);
    uint256 constant AMOUNT = 1 ether;
    uint256 constant BALANCE = 100_000 ether;
    ISwapV3Factory constant FACTORY = ISwapV3Factory(0xdB1d10011AD0Ff90774D0C6Bb92e5C5c8b4461F7);
    ERC20 constant WETH9 = ERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    address constant FROM = address(1234);

    UniversalRouter public router;

    function setUp() public {
        // BSC: May-09-2024 03:05:23 AM +UTC
        vm.createSelectFork(vm.envString("FORK_URL"));

        RouterParameters memory params = RouterParameters({
            weth9: address(WETH9),
            pancakeswapV2Factory: address(0),
            pancakeswapV3Factory: address(0),
            stableFactory: address(0),
            stableInfo: address(0),
            infiVault: address(0),
            infiClPoolManager: address(0),
            infiBinPoolManager: address(0),
            uniswapV2Factory: address(0),
            uniswapV3Factory: address(FACTORY),
            uniswapPoolManager: address(0)
        });
        router = new UniversalRouter(params);

        // pair doesn't exist, revert to keep this test simple without adding to lp etc
        if (FACTORY.getPool(token0(), token1(), fee01()) == address(0)) {
            revert("Pair01 doesn't exist");
        }

        if (FACTORY.getPool(token1(), token2(), fee12()) == address(0)) {
            revert("Pair12 doesn't exist");
        }

        vm.startPrank(FROM);
        deal(FROM, BALANCE);
        deal(token0(), FROM, BALANCE);
        deal(token1(), FROM, BALANCE);
        deal(token2(), FROM, BALANCE);
        ERC20(token0()).approve(address(router), type(uint256).max);
        ERC20(token1()).approve(address(router), type(uint256).max);
        ERC20(token2()).approve(address(router), type(uint256).max);
    }

    function test_v3Swap_ExactInput0For1() public {
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V3_SWAP_EXACT_IN)));
        bytes memory path = abi.encodePacked(token0(), fee01(), token1());
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(ActionConstants.MSG_SENDER, AMOUNT, 0, path, true, address(FACTORY));

        router.execute(commands, inputs);
        vm.snapshotGasLastCall("test_v3Swap_ExactInput0For1");
        assertEq(ERC20(token0()).balanceOf(FROM), BALANCE - AMOUNT);
        assertGt(ERC20(token1()).balanceOf(FROM), BALANCE);
    }

    function test_v3Swap_exactInput1For0() public {
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V3_SWAP_EXACT_IN)));
        bytes memory path = abi.encodePacked(token1(), fee01(), token0());
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(ActionConstants.MSG_SENDER, AMOUNT, 0, path, true, address(FACTORY));

        router.execute(commands, inputs);
        assertEq(ERC20(token1()).balanceOf(FROM), BALANCE - AMOUNT);
        assertGt(ERC20(token0()).balanceOf(FROM), BALANCE);
    }

    function test_v3Swap_ExactInput0For1_ContractBalance() public {
        // pre-req: ensure router has 1 ether
        deal(token0(), address(router), 1 ether);
        assertEq(ERC20(token0()).balanceOf(address(router)), 1 ether);

        // use CONTRACT_BALANCE as amount
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V3_SWAP_EXACT_IN)));
        bytes memory path = abi.encodePacked(token0(), fee01(), token1());
        bytes[] memory inputs = new bytes[](1);
        inputs[0] =
            abi.encode(ActionConstants.MSG_SENDER, ActionConstants.CONTRACT_BALANCE, 0, path, true, address(FACTORY));

        router.execute(commands, inputs);
        vm.snapshotGasLastCall("test_v3Swap_ExactInput0For1_ContractBalance");
        assertEq(ERC20(token0()).balanceOf(FROM), BALANCE - 1 ether);
        assertGt(ERC20(token1()).balanceOf(FROM), BALANCE);
    }

    function test_v3Swap_exactInput_MultiHop() public {
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V3_SWAP_EXACT_IN)));
        bytes memory path = abi.encodePacked(token0(), fee01(), token1(), fee12(), token2());
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(ActionConstants.MSG_SENDER, AMOUNT, 0, path, true, address(FACTORY));

        router.execute(commands, inputs);
        vm.snapshotGasLastCall("test_v3Swap_exactInput_MultiHop");
        assertEq(ERC20(token0()).balanceOf(FROM), BALANCE - AMOUNT);
        assertEq(ERC20(token1()).balanceOf(FROM), BALANCE);
        assertGt(ERC20(token2()).balanceOf(FROM), BALANCE);
    }

    function test_v3Swap_exactInput0For1FromRouter() public {
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V3_SWAP_EXACT_IN)));
        deal(token0(), address(router), AMOUNT);
        bytes memory path = abi.encodePacked(token0(), fee01(), token1());
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(ActionConstants.MSG_SENDER, AMOUNT, 0, path, false, address(FACTORY));

        router.execute(commands, inputs);
        assertGt(ERC20(token1()).balanceOf(FROM), BALANCE);
    }

    function test_v3Swap_exactInput1For0FromRouter() public {
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V3_SWAP_EXACT_IN)));
        deal(token1(), address(router), AMOUNT);
        bytes memory path = abi.encodePacked(token1(), fee01(), token0());
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(ActionConstants.MSG_SENDER, AMOUNT, 0, path, false, address(FACTORY));

        router.execute(commands, inputs);
        assertGt(ERC20(token0()).balanceOf(FROM), BALANCE);
    }

    function test_v3Swap_exactOutput0For1() public {
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V3_SWAP_EXACT_OUT)));

        // for exactOut: tokenOut should be the first in path as it execute in reverse order
        bytes memory path = abi.encodePacked(token1(), fee01(), token0());
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(ActionConstants.MSG_SENDER, AMOUNT, type(uint256).max, path, true, address(FACTORY));

        router.execute(commands, inputs);
        vm.snapshotGasLastCall("test_v3Swap_exactOutput0For1");
        assertLt(ERC20(token0()).balanceOf(FROM), BALANCE);
        assertGe(ERC20(token1()).balanceOf(FROM), BALANCE + AMOUNT);
    }

    function test_v3Swap_exactOutput1For0() public {
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V3_SWAP_EXACT_OUT)));

        // for exactOut: tokenOut should be the first in path as it execute in reverse order
        bytes memory path = abi.encodePacked(token0(), fee01(), token1());
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(ActionConstants.MSG_SENDER, AMOUNT, type(uint256).max, path, true, address(FACTORY));

        router.execute(commands, inputs);
        assertLt(ERC20(token1()).balanceOf(FROM), BALANCE);
        assertGe(ERC20(token0()).balanceOf(FROM), BALANCE + AMOUNT);
    }

    function test_v3Swap_exactOutput_MultiHop() public {
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V3_SWAP_EXACT_OUT)));

        // for exactOut: tokenOut should be the first in path as it execute in reverse order
        bytes memory path = abi.encodePacked(token2(), fee12(), token1(), fee01(), token0());
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(ActionConstants.MSG_SENDER, AMOUNT, type(uint256).max, path, true, address(FACTORY));

        router.execute(commands, inputs);
        vm.snapshotGasLastCall("test_v3Swap_exactOutput_MultiHop");
        assertLt(ERC20(token0()).balanceOf(FROM), BALANCE);
        assertEq(ERC20(token1()).balanceOf(FROM), BALANCE);
        assertGe(ERC20(token2()).balanceOf(FROM), BALANCE + AMOUNT);
    }

    function test_v3Swap_exactOutput0For1FromRouter() public {
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V3_SWAP_EXACT_OUT)));
        deal(token0(), address(router), BALANCE);
        assertEq(ERC20(token0()).balanceOf(address(router)), BALANCE);

        // for exactOut: tokenOut should be the first in path as it execute in reverse order
        bytes memory path = abi.encodePacked(token1(), fee01(), token0());
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(ActionConstants.MSG_SENDER, AMOUNT, type(uint256).max, path, false, address(FACTORY));

        router.execute(commands, inputs);
        assertGe(ERC20(token1()).balanceOf(FROM), BALANCE + AMOUNT);
    }

    function test_v3Swap_exactOutput1For0FromRouter() public {
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.V3_SWAP_EXACT_OUT)));
        deal(token1(), address(router), BALANCE);

        // for exactOut: tokenOut should be the first in path as it execute in reverse order
        bytes memory path = abi.encodePacked(token0(), fee01(), token1());
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(ActionConstants.MSG_SENDER, AMOUNT, type(uint256).max, path, false, address(FACTORY));

        router.execute(commands, inputs);
        assertGe(ERC20(token0()).balanceOf(FROM), BALANCE + AMOUNT);
    }

    function test_v3Swap_uniswapV3SwapCallback_InvalidCaller() public {
        bytes memory path = abi.encodePacked(token1(), fee01(), token0());
        bytes memory data = abi.encode(path, makeAddr("payer"));

        vm.expectRevert(V3SwapRouter.V3InvalidCaller.selector);
        router.uniswapV3SwapCallback(100, 100, data);
    }

    // token0-token1 will be 1 pair and token1-token2 will be 1 pair
    // for multi pool hop test
    function token0() internal virtual returns (address);
    function token1() internal virtual returns (address);
    function token2() internal virtual returns (address);
    function fee01() internal virtual returns (uint24);
    function fee12() internal virtual returns (uint24);
}

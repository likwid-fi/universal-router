// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {console} from "forge-std/Test.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Actions} from "@uniswap/v4-periphery/src/libraries/Actions.sol";
import {ActionConstants} from "infinity-periphery/src/libraries/ActionConstants.sol";

import {ILikwidV2Router} from "../../src/modules/likwid/interfaces/ILikwidV2Router.sol";
import {LikwidV2Test} from "./LikwidV2.t.sol";
import {Commands} from "../../src/libraries/Commands.sol";

contract LikwidV2EthUsdt is LikwidV2Test {
    using SafeERC20 for IERC20;

    IERC20 constant USDT = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    IERC20 constant O_LIKWID = IERC20(0xc634d9dCE40Ba1E5540f597f62A734f1bf2843aa);

    ///     hop1. swap with a LikwidV2 (eth-usdt) pool
    ///     hop2. swap with a v2 (weth-usdt) pool
    function test_crossVersionSwapCase() public {
        // 0. user starts with 1 ether usdc
        address trader = makeAddr("trader");

        vm.startPrank(trader);
        uint256 amount = 1e6; // 1 USDT in wei (assuming 6 decimals)
        deal(address(USDT), trader, amount);
        IERC20(address(USDT)).forceApprove(address(router), type(uint256).max);

        // 1. build up universal router commands list
        bytes memory commands = abi.encodePacked(
            bytes1(uint8(Commands.LIKWID_V2_SWAP)), // USDT -> ETH
            bytes1(uint8(Commands.WRAP_ETH)), // ETH -> WETH
            bytes1(uint8(Commands.V2_SWAP_EXACT_IN)), // WETH -> USDT
            bytes1(uint8(Commands.SWEEP)) // SWEEP WETH
        );

        // 2. build up corresponding inputs
        bytes[] memory inputs = new bytes[](4);

        // 2.1. prepare exact in params (i.e. ETH -> USDT through Likwid):
        // Encode V4Router actions
        bytes memory actions =
            abi.encodePacked(uint8(Actions.SWAP_EXACT_IN_SINGLE), uint8(Actions.SETTLE_ALL), uint8(Actions.TAKE_ALL));

        // Prepare parameters for each action
        bytes[] memory params = new bytes[](3);
        params[0] = abi.encode(
            ILikwidV2Router.ExactInputSingleParamsLikwidV2({
                poolKey: key01, zeroForOne: false, amountIn: uint128(amount), amountOutMinimum: 0
            })
        );
        params[1] = abi.encode(key01.currency1, amount); //USDT
        params[2] = abi.encode(key01.currency0, 0); // ETH

        // Combine actions and params into inputs
        inputs[0] = abi.encode(actions, params);

        // 2.2. wrap ETH to WETH:
        // address recipient = ADDRESS_THIS to make sure WETH is send back to universal router;
        // uint256 amount = ActionConstants.CONTRACT_BALANCE to make sure all the ETH from infinity is wrapped
        inputs[1] = abi.encode(ActionConstants.ADDRESS_THIS, ActionConstants.CONTRACT_BALANCE);

        // 2.3. prepare v2 exact in params (i.e. WETH -> USDT):
        address[] memory path = new address[](2);
        path[0] = address(WETH9);
        path[1] = address(USDT);
        // address recipient = MSG_SENDER to make sure USDT is send to trader
        // uint256 amountIn = CONTRACT_BALANCE
        // uint256 amountOutMin = 0.8 ether, make sure user receives at least 0.8 ether usdt
        // bool payerIsUser = false, since we are using weth balance from universal router itself
        inputs[2] = abi.encode(
            ActionConstants.MSG_SENDER, ActionConstants.CONTRACT_BALANCE, 0, path, false, UNISWAP_V2_FACTORY
        );

        // 2.4 sweep in case partial fulfilled swap
        // address token;
        // address recipient;
        // uint160 amountMin;
        inputs[3] = abi.encode(WETH9, ActionConstants.MSG_SENDER, 0);

        // 3. execute
        router.execute(commands, inputs);

        // 4. check
        // 4.1. make sure user receives at least 0.8 USDT
        console.log("USDT balance after swap: ", USDT.balanceOf(trader));
        assertGe(USDT.balanceOf(trader), 0.8e6); // 0.8 USDT in wei

        // 4.2. make sure no eth or weth left in the router
        assertEq(IERC20(WETH9).balanceOf(address(router)), 0);
        assertEq(address(router).balance, 0);

        vm.stopPrank();
    }

    function token0() internal pure override returns (address) {
        return address(0);
    }

    function token1() internal pure override returns (address) {
        return address(USDT);
    }

    function token2() internal pure override returns (address) {
        return address(O_LIKWID);
    }

    function fee01() internal pure override returns (uint24) {
        return 3000; // 0.3%
    }

    function fee12() internal pure override returns (uint24) {
        return 100;
    }

    function marginFee01() internal pure override returns (uint24) {
        return 3000;
    }

    function marginFee12() internal pure override returns (uint24) {
        return 0;
    }
}

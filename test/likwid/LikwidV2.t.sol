// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Actions} from "@uniswap/v4-periphery/src/libraries/Actions.sol";
import {SafeTransferLib} from "solmate/src/utils/SafeTransferLib.sol";
import {Currency} from "@likwid-fi/core/types/Currency.sol";
import {PoolKey} from "@likwid-fi/core/types/PoolKey.sol";

import {UniversalRouter} from "../../src/UniversalRouter.sol";
import {ILikwidV2Router} from "../../src/modules/likwid/interfaces/ILikwidV2Router.sol";
import {Constants} from "../../src/libraries/Constants.sol";
import {Commands} from "../../src/libraries/Commands.sol";
import {RouterParameters} from "../../src/base/RouterImmutables.sol";

/// @dev fork ETHEREUM network
abstract contract LikwidV2Test is Test {
    using SafeTransferLib for address;
    using SafeERC20 for IERC20;

    address constant RECIPIENT = address(10);
    uint256 constant AMOUNT = 1 ether;
    uint256 constant BALANCE = 100_000 ether;
    address constant FROM = address(1234);
    address constant LIKWID_VAULT = 0x065d449ec9D139740343990B7E1CF05fA830e4Ba;

    UniversalRouter public router;
    PoolKey public key01;

    function setUp() public {
        vm.createSelectFork(vm.envString("FORK_1_URL"));

        RouterParameters memory params = RouterParameters({
            weth9: address(0),
            pancakeswapV2Factory: address(0),
            pancakeswapV3Factory: address(0),
            stableFactory: address(0),
            stableInfo: address(0),
            infiVault: address(0),
            infiClPoolManager: address(0),
            infiBinPoolManager: address(0),
            uniswapV2Factory: address(0),
            uniswapV3Factory: address(0),
            uniswapPoolManager: address(0),
            likwidVault: LIKWID_VAULT
        });
        router = new UniversalRouter(params);

        vm.startPrank(FROM);
        deal(FROM, BALANCE);
        if (token0() != Constants.ETH) {
            deal(token0(), FROM, BALANCE);
            IERC20(token0()).forceApprove(address(router), type(uint256).max);
        }
        console.log("Setup token0 complete");
        deal(token1(), FROM, BALANCE);
        deal(token2(), FROM, BALANCE);
        console.log("Setup approve0 complete");
        IERC20(token2()).forceApprove(address(router), type(uint256).max);
        console.log("Setup approve2 complete");
        IERC20(token1()).forceApprove(address(router), type(uint256).max);
        console.log("Setup approve1 complete");
        key01 = PoolKey({
            currency0: Currency.wrap(token0()),
            currency1: Currency.wrap(token1()),
            fee: fee01(),
            marginFee: marginFee01()
        });
    }

    function test_likwid_v2_swapExactInputSingle01() public {
        // Encode the Universal Router command
        bytes memory commands = abi.encodePacked(uint8(Commands.LIKWID_V2_SWAP));
        bytes[] memory inputs = new bytes[](1);

        // Encode V4Router actions
        bytes memory actions =
            abi.encodePacked(uint8(Actions.SWAP_EXACT_IN_SINGLE), uint8(Actions.SETTLE_ALL), uint8(Actions.TAKE_ALL));

        // Prepare parameters for each action
        bytes[] memory params = new bytes[](3);
        params[0] = abi.encode(
            ILikwidV2Router.ExactInputSingleParamsLikwidV2({
                poolKey: key01, zeroForOne: true, amountIn: uint128(AMOUNT), amountOutMinimum: 0
            })
        );
        params[1] = abi.encode(key01.currency0, AMOUNT);
        params[2] = abi.encode(key01.currency1, 0);

        // Combine actions and params into inputs
        inputs[0] = abi.encode(actions, params);

        // Execute the swap
        uint256 deadline = block.timestamp + 20;
        router.execute{value: AMOUNT}(commands, inputs, deadline);

        // Verify and return the output amount
        uint256 amountOut = IERC20(Currency.unwrap(key01.currency1)).balanceOf(FROM);
        require(amountOut >= BALANCE, "Insufficient output amount");
    }

    // token0-token1 will be 1 pair and token1-token2 will be 1 pair
    // for multi pool hop test
    function token0() internal virtual returns (address);
    function token1() internal virtual returns (address);
    function token2() internal virtual returns (address);
    function fee01() internal virtual returns (uint24);
    function fee12() internal virtual returns (uint24);
    function marginFee01() internal virtual returns (uint24);
    function marginFee12() internal virtual returns (uint24);
}

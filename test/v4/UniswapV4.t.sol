// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {ActionConstants} from "infinity-periphery/src/libraries/ActionConstants.sol";
import {Actions} from "@uniswap/v4-periphery/src/libraries/Actions.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {SafeTransferLib} from "solmate/src/utils/SafeTransferLib.sol";

import {UniversalRouter} from "../../src/UniversalRouter.sol";
import {IV4Router} from "../../src/modules/v4/interfaces/IV4Router.sol";
import {Constants} from "../../src/libraries/Constants.sol";
import {Commands} from "../../src/libraries/Commands.sol";
import {RouterParameters} from "../../src/base/RouterImmutables.sol";

/// @dev fork BSC network
abstract contract UniswapV4Test is Test {
    using SafeTransferLib for address;

    address constant RECIPIENT = address(10);
    uint256 constant AMOUNT = 1 ether;
    uint256 constant BALANCE = 100_000 ether;
    address constant FROM = address(1234);
    IPoolManager constant POOL_MANAGER = IPoolManager(0x28e2Ea090877bF75740558f6BFB36A5ffeE9e9dF); // USDC pool manager on BSC
    IHooks constant HOOKS = IHooks(0xBa933D3C37D5B26fbb21aE6894CE6EbfC48F6888);

    UniversalRouter public router;
    PoolKey public key01;

    function setUp() public {
        // BSC: May-09-2024 03:05:23 AM +UTC
        vm.createSelectFork(vm.envString("FORK_URL"));

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
            uniswapPoolManager: address(POOL_MANAGER)
        });
        router = new UniversalRouter(params);

        vm.startPrank(FROM);
        deal(FROM, BALANCE);
        if (token0() != Constants.ETH) {
            deal(token0(), FROM, BALANCE);
            ERC20(token0()).approve(address(router), type(uint256).max);
        }
        deal(token1(), FROM, BALANCE);
        deal(token2(), FROM, BALANCE);
        ERC20(token1()).approve(address(router), type(uint256).max);
        ERC20(token2()).approve(address(router), type(uint256).max);

        key01 = PoolKey({
            currency0: Currency.wrap(token0()),
            currency1: Currency.wrap(token1()),
            fee: fee01(),
            tickSpacing: 1,
            hooks: HOOKS
        });
    }

    function test_v4_swapExactInputSingle01() public {
        // Encode the Universal Router command
        bytes memory commands = abi.encodePacked(uint8(Commands.V4_SWAP));
        bytes[] memory inputs = new bytes[](1);

        // Encode V4Router actions
        bytes memory actions =
            abi.encodePacked(uint8(Actions.SWAP_EXACT_IN_SINGLE), uint8(Actions.SETTLE_ALL), uint8(Actions.TAKE_ALL));

        // Prepare parameters for each action
        bytes[] memory params = new bytes[](3);
        params[0] = abi.encode(
            IV4Router.ExactInputSingleParams({
                poolKey: key01,
                zeroForOne: true,
                amountIn: uint128(AMOUNT),
                amountOutMinimum: 0,
                hookData: bytes("")
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
        uint256 amountOut = ERC20(Currency.unwrap(key01.currency1)).balanceOf(FROM);
        require(amountOut >= BALANCE, "Insufficient output amount");
    }

    // token0-token1 will be 1 pair and token1-token2 will be 1 pair
    // for multi pool hop test
    function token0() internal virtual returns (address);
    function token1() internal virtual returns (address);
    function token2() internal virtual returns (address);
    function fee01() internal virtual returns (uint24);
    function fee12() internal virtual returns (uint24);
}

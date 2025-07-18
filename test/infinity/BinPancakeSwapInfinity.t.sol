// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {IAllowanceTransfer} from "permit2/src/interfaces/IAllowanceTransfer.sol";
import {WETH} from "solmate/src/tokens/WETH.sol";
import {IWETH9} from "infinity-periphery/src/interfaces/external/IWETH9.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";

import {PoolKey} from "infinity-core/src/types/PoolKey.sol";
import {Currency} from "infinity-core/src/types/Currency.sol";
import {IVault} from "infinity-core/src/interfaces/IVault.sol";
import {Vault} from "infinity-core/src/Vault.sol";
import {BinPoolManager} from "infinity-core/src/pool-bin/BinPoolManager.sol";
import {IBinPoolManager} from "infinity-core/src/pool-bin/interfaces/IBinPoolManager.sol";
import {IHooks} from "infinity-core/src/interfaces/IHooks.sol";
import {BinPoolParametersHelper} from "infinity-core/src/pool-bin/libraries/BinPoolParametersHelper.sol";
import {ActionConstants} from "infinity-periphery/src/libraries/ActionConstants.sol";
import {Plan, Planner} from "infinity-periphery/src/libraries/Planner.sol";
import {BinPositionManager} from "infinity-periphery/src/pool-bin/BinPositionManager.sol";
import {Actions} from "infinity-periphery/src/libraries/Actions.sol";
import {IBinRouterBase} from "infinity-periphery/src/pool-bin/interfaces/IBinRouterBase.sol";
import {BinLiquidityHelper} from "infinity-periphery/test/pool-bin/helper/BinLiquidityHelper.sol";
import {IBinPositionManager} from "infinity-periphery/src/pool-bin/interfaces/IBinPositionManager.sol";
import {PathKey} from "infinity-periphery/src/libraries/PathKey.sol";
import {BinPool} from "infinity-core/src/pool-bin/libraries/BinPool.sol";

import {BasePancakeSwapInfinity} from "./BasePancakeSwapInfinity.sol";
import {UniversalRouter} from "../../src/UniversalRouter.sol";
import {IUniversalRouter} from "../../src/interfaces/IUniversalRouter.sol";
import {Constants} from "../../src/libraries/Constants.sol";
import {Commands} from "../../src/libraries/Commands.sol";
import {RouterParameters} from "../../src/base/RouterImmutables.sol";

contract BinPancakeSwapInfinityTest is BasePancakeSwapInfinity, BinLiquidityHelper {
    using BinPoolParametersHelper for bytes32;
    using Planner for Plan;

    IVault public vault;
    IBinPoolManager public poolManager;
    BinPositionManager public positionManager;
    IAllowanceTransfer permit2;
    WETH weth9 = new WETH();
    UniversalRouter router;

    PoolKey public poolKey0;
    PoolKey public poolKey1;

    MockERC20 token0;
    MockERC20 token1;
    MockERC20 token2;

    Plan plan;
    address alice = makeAddr("alice");
    uint24 constant ACTIVE_ID_1_1 = 2 ** 23; // where token0 and token1 price is the same

    function setUp() public {
        vault = IVault(new Vault());
        poolManager = new BinPoolManager(vault);
        vault.registerApp(address(poolManager));
        permit2 = IAllowanceTransfer(deployPermit2());

        initializeTokens();
        vm.label(Currency.unwrap(currency0), "token0");
        vm.label(Currency.unwrap(currency1), "token1");
        vm.label(Currency.unwrap(currency2), "token2");

        token0 = MockERC20(Currency.unwrap(currency0));
        token1 = MockERC20(Currency.unwrap(currency1));
        token2 = MockERC20(Currency.unwrap(currency2));

        positionManager = new BinPositionManager(vault, poolManager, permit2, IWETH9(address(weth9)));
        _approvePermit2ForCurrency(address(this), currency0, address(positionManager), permit2);
        _approvePermit2ForCurrency(address(this), currency1, address(positionManager), permit2);
        _approvePermit2ForCurrency(address(this), currency2, address(positionManager), permit2);

        RouterParameters memory params = RouterParameters({
            weth9: address(weth9),
            pancakeswapV2Factory: address(0),
            pancakeswapV3Factory: address(0),
            stableFactory: address(0),
            stableInfo: address(0),
            infiVault: address(vault),
            infiClPoolManager: address(0),
            infiBinPoolManager: address(poolManager),
            uniswapV2Factory: address(0),
            uniswapV3Factory: address(0),
            uniswapPoolManager: address(0)
        });
        router = new UniversalRouter(params);
        _approveRouterForCurrency(alice, currency0, address(router));
        _approveRouterForCurrency(alice, currency1, address(router));
        _approveRouterForCurrency(alice, currency2, address(router));

        poolKey0 = PoolKey({
            currency0: currency0,
            currency1: currency1,
            hooks: IHooks(address(0)),
            poolManager: poolManager,
            fee: uint24(3000),
            parameters: bytes32(0).setBinStep(10)
        });
        poolManager.initialize(poolKey0, ACTIVE_ID_1_1);
        _mint(poolKey0);

        // initialize poolKey1 via universal-router
        poolKey1 = PoolKey({
            currency0: currency1,
            currency1: currency2,
            hooks: IHooks(address(0)),
            poolManager: poolManager,
            fee: uint24(3000),
            parameters: bytes32(0).setBinStep(10)
        });
        poolManager.initialize(poolKey1, ACTIVE_ID_1_1);
        _mint(poolKey1);
    }

    function test_infiBinSwap_ExactInSingle() public {
        uint128 amountIn = 0.01 ether;
        MockERC20(Currency.unwrap(currency0)).mint(alice, amountIn);
        vm.startPrank(alice);

        // prepare infinity swap input
        IBinRouterBase.BinSwapExactInputSingleParams memory params =
            IBinRouterBase.BinSwapExactInputSingleParams(poolKey0, true, amountIn, 0, "");
        plan = Planner.init().add(Actions.BIN_SWAP_EXACT_IN_SINGLE, abi.encode(params));
        bytes memory data = plan.finalizeSwap(poolKey0.currency0, poolKey0.currency1, ActionConstants.MSG_SENDER);

        // call infi_swap
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.INFI_SWAP)));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = data;

        assertEq(token0.balanceOf(alice), 0.01 ether);
        assertEq(token1.balanceOf(alice), 0 ether);
        router.execute(commands, inputs);
        vm.snapshotGasLastCall("test_infiBinSwap_ExactInSingle");
        assertEq(token0.balanceOf(alice), 0 ether);
        assertEq(token1.balanceOf(alice), 9970000000000000); // 0.01 eth * 0.997
    }

    function test_infiBinSwap_ExactIn_SingleHop() public {
        uint128 amountIn = 0.01 ether;
        MockERC20(Currency.unwrap(currency0)).mint(alice, amountIn);
        vm.startPrank(alice);

        PathKey[] memory path = new PathKey[](1);
        path[0] = PathKey({
            intermediateCurrency: currency1,
            fee: poolKey0.fee,
            hooks: poolKey0.hooks,
            hookData: "",
            poolManager: poolKey0.poolManager,
            parameters: poolKey0.parameters
        });
        IBinRouterBase.BinSwapExactInputParams memory params =
            IBinRouterBase.BinSwapExactInputParams(currency0, path, 0.01 ether, 0);
        plan = Planner.init().add(Actions.BIN_SWAP_EXACT_IN, abi.encode(params));
        bytes memory data = plan.finalizeSwap(currency0, currency1, ActionConstants.MSG_SENDER);

        // call infi_swap
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.INFI_SWAP)));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = data;

        // gas would be higher as its the first swap
        assertEq(token0.balanceOf(alice), 0.01 ether);
        assertEq(token1.balanceOf(alice), 0 ether);
        router.execute(commands, inputs);
        vm.snapshotGasLastCall("test_infiBinSwap_ExactIn_SingleHop");
        assertEq(token0.balanceOf(alice), 0 ether);
        assertEq(token1.balanceOf(alice), 9970000000000000); // 0.01 eth * 0.997
    }

    function test_infiBinSwap_ExactIn_MultiHop() public {
        uint128 amountIn = 0.01 ether;
        MockERC20(Currency.unwrap(currency0)).mint(alice, amountIn);
        vm.startPrank(alice);

        // prepare infinity swap input
        PathKey[] memory path = new PathKey[](2);
        path[0] = PathKey({
            intermediateCurrency: currency1,
            fee: poolKey0.fee,
            hooks: poolKey0.hooks,
            hookData: "",
            poolManager: poolKey0.poolManager,
            parameters: poolKey0.parameters
        });
        path[1] = PathKey({
            intermediateCurrency: currency2,
            fee: poolKey1.fee,
            hooks: poolKey1.hooks,
            hookData: "",
            poolManager: poolKey1.poolManager,
            parameters: poolKey1.parameters
        });
        IBinRouterBase.BinSwapExactInputParams memory params =
            IBinRouterBase.BinSwapExactInputParams(currency0, path, 0.01 ether, 0);
        plan = Planner.init().add(Actions.BIN_SWAP_EXACT_IN, abi.encode(params));
        bytes memory data = plan.finalizeSwap(currency0, currency2, ActionConstants.MSG_SENDER);

        // call infi_swap
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.INFI_SWAP)));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = data;

        // gas would be higher as its the first swap
        assertEq(token0.balanceOf(alice), 0.01 ether);
        assertEq(token2.balanceOf(alice), 0 ether);
        router.execute(commands, inputs);
        vm.snapshotGasLastCall("test_infiBinSwap_ExactIn_MultiHop");
        assertEq(token0.balanceOf(alice), 0 ether);
        assertEq(token2.balanceOf(alice), 9940090000000000); // around 0.01 eth - 0.3% fee twice
    }

    function test_infiBinSwap_ExactOutSingle() public {
        uint128 amountOut = 0.01 ether;
        MockERC20(Currency.unwrap(currency0)).mint(alice, amountOut * 2); // *2 to handle slippage
        vm.startPrank(alice);

        // prepare infinity swap input
        IBinRouterBase.BinSwapExactOutputSingleParams memory params =
            IBinRouterBase.BinSwapExactOutputSingleParams(poolKey0, true, amountOut, amountOut * 2, "");
        plan = Planner.init().add(Actions.BIN_SWAP_EXACT_OUT_SINGLE, abi.encode(params));
        bytes memory data = plan.finalizeSwap(poolKey0.currency0, poolKey0.currency1, ActionConstants.MSG_SENDER);

        // call infi_swap
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.INFI_SWAP)));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = data;

        // gas would be higher as its the first swap
        assertEq(token0.balanceOf(alice), 0.02 ether);
        assertEq(token1.balanceOf(alice), 0 ether);
        router.execute(commands, inputs);
        vm.snapshotGasLastCall("test_infiBinSwap_ExactOutSingle");
        assertEq(token0.balanceOf(alice), 9969909729187562); // around 0.02 eth - 0.01 eth - fee
        assertEq(token1.balanceOf(alice), 0.01 ether);
    }

    function test_infiBinSwap_ExactOut_SingleHop() public {
        uint128 amountOut = 0.01 ether;
        MockERC20(Currency.unwrap(currency0)).mint(alice, amountOut * 2); // *2 to handle slippage
        vm.startPrank(alice);

        // prepare infinity swap input
        PathKey[] memory path = new PathKey[](1);
        path[0] = PathKey({
            intermediateCurrency: currency0,
            fee: poolKey0.fee,
            hooks: poolKey0.hooks,
            hookData: "",
            poolManager: poolKey0.poolManager,
            parameters: poolKey0.parameters
        });
        IBinRouterBase.BinSwapExactOutputParams memory params =
            IBinRouterBase.BinSwapExactOutputParams(currency1, path, amountOut, amountOut * 2);
        plan = Planner.init().add(Actions.BIN_SWAP_EXACT_OUT, abi.encode(params));
        bytes memory data = plan.finalizeSwap(currency0, currency1, ActionConstants.MSG_SENDER);

        // call infi_swap
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.INFI_SWAP)));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = data;

        // gas would be higher as its the first swap
        assertEq(token0.balanceOf(alice), 0.02 ether);
        assertEq(token1.balanceOf(alice), 0 ether);
        router.execute(commands, inputs);
        vm.snapshotGasLastCall("test_infiBinSwap_ExactOut_SingleHop");
        assertEq(token0.balanceOf(alice), 9969909729187562); // around 0.02 eth - 0.01 eth - slippage
        assertEq(token1.balanceOf(alice), 0.01 ether);
    }

    function test_infiBinSwap_ExactOut_MultiHop() public {
        uint128 amountOut = 0.01 ether;
        MockERC20(Currency.unwrap(currency0)).mint(alice, amountOut * 2); // *2 to handle slippage
        vm.startPrank(alice);

        // prepare infinity swap input
        PathKey[] memory path = new PathKey[](2);
        path[0] = PathKey({
            intermediateCurrency: currency0,
            fee: poolKey0.fee,
            hooks: poolKey0.hooks,
            hookData: "",
            poolManager: poolKey0.poolManager,
            parameters: poolKey0.parameters
        });
        path[1] = PathKey({
            intermediateCurrency: currency1,
            fee: poolKey1.fee,
            hooks: poolKey1.hooks,
            hookData: "",
            poolManager: poolKey1.poolManager,
            parameters: poolKey1.parameters
        });
        IBinRouterBase.BinSwapExactOutputParams memory params =
            IBinRouterBase.BinSwapExactOutputParams(currency2, path, amountOut, amountOut * 2);
        plan = Planner.init().add(Actions.BIN_SWAP_EXACT_OUT, abi.encode(params));
        bytes memory data = plan.finalizeSwap(currency0, currency2, ActionConstants.MSG_SENDER);

        // call infi_swap
        bytes memory commands = abi.encodePacked(bytes1(uint8(Commands.INFI_SWAP)));
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = data;

        // gas would be higher as its the first swap
        assertEq(token0.balanceOf(alice), 0.02 ether);
        assertEq(token2.balanceOf(alice), 0 ether);
        router.execute(commands, inputs);
        vm.snapshotGasLastCall("test_infiBinSwap_ExactOut_MultiHop");
        assertEq(token0.balanceOf(alice), 9939728915935368);
        assertEq(token2.balanceOf(alice), 0.01 ether);
    }

    /// @dev add 10 ether of token0, token1 at active bin
    function _mint(PoolKey memory key) private {
        uint24[] memory binIds = getBinIds(ACTIVE_ID_1_1, 1);
        IBinPositionManager.BinAddLiquidityParams memory addParams;
        addParams = _getAddParams(key, binIds, 10 ether, 10 ether, ACTIVE_ID_1_1, address(this));

        Plan memory planner = Planner.init().add(Actions.BIN_ADD_LIQUIDITY, abi.encode(addParams));
        bytes memory payload = planner.finalizeModifyLiquidityWithClose(key);

        positionManager.modifyLiquidities(payload, block.timestamp + 1);
    }
}

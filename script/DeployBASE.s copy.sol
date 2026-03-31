// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {MixedQuoter} from "../src/MixedQuoter.sol";
import {UniversalV2PartRouter} from "../src/UniversalV2PartRouter.sol";
import {RouterParameters} from "../src/base/RouterImmutables.sol";
import {QuoterParameters} from "../src/base/QuoterImmutables.sol";

// forge script script/DeployBASE.s.sol --broadcast --optimizer-runs 1000000 --rpc-url $ETHEREUM_BASE_RPC --private-key $PRIVATE_KEY
contract DeployScript is Script {
    MixedQuoter public mixedQuoter;
    UniversalV2PartRouter public router;
    ERC20 constant WETH9 = ERC20(0x4200000000000000000000000000000000000006);
    address constant LIKWID_VAULT = 0x065d449ec9D139740343990B7E1CF05fA830e4Ba;
    address constant UNISWAP_V2_FACTORY = 0x8909Dc15e40173Ff4699343b6eB8132c65e18eC6;
    address constant PANCAKESWAP_V2_FACTORY = 0x02a84c1b3BBD7401a5f7fa98a384EBC70bB5749E;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        RouterParameters memory routerParams = RouterParameters({
            weth9: address(WETH9),
            pancakeswapV2Factory: PANCAKESWAP_V2_FACTORY,
            pancakeswapV3Factory: address(0),
            stableFactory: address(0),
            stableInfo: address(0),
            infiVault: address(0),
            infiClPoolManager: address(0),
            infiBinPoolManager: address(0),
            uniswapV2Factory: UNISWAP_V2_FACTORY,
            uniswapV3Factory: address(0),
            uniswapPoolManager: address(0),
            likwidVault: LIKWID_VAULT
        });
        router = new UniversalV2PartRouter(routerParams);
        console.log("UniversalV2PartRouter deployed at:", address(router));

        QuoterParameters memory params = QuoterParameters({
            weth9: address(WETH9),
            likwidQuoter: address(0x16a9633f8A777CA733073ea2526705cD8338d510),
            likwidPairManager: address(0xB397FE16BE79B082f17F1CD96e6489df19E07BCD),
            uniswapV2Router: address(0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24),
            uniswapV3Quoter: address(0x3d4e44Eb1374240CE5F1B871ab261CD16335B76a),
            uniswapV4Quoter: address(0x0d5e0F971ED27FBfF6c2837bf31316121532048D),
            stableFactory: address(0),
            stableInfo: address(0),
            pancakeswapV2Router: address(0x8cFe327CEc66d1C090Dd72bd0FF11d690C33a2Eb),
            pancakeswapV3Quoter: address(0xB048Bbc1Ee6b733FFfCFb9e9CeF7375518e25997),
            infiClQuoter: address(0),
            infiBinQuoter: address(0)
        });
        mixedQuoter = new MixedQuoter(params);
        console.log("MixedQuoter deployed at:", address(mixedQuoter));

        vm.stopBroadcast();
    }
}

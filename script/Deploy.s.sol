// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {MixedQuoter} from "../src/MixedQuoter.sol";
import {UniversalV2PartRouter} from "../src/UniversalV2PartRouter.sol";
import {RouterParameters} from "../src/base/RouterImmutables.sol";
import {QuoterParameters} from "../src/base/QuoterImmutables.sol";

// forge script script/Deploy.s.sol --broadcast --optimizer-runs 1000000 --rpc-url $ETHEREUM_MAINNET_RPC --private-key $PRIVATE_KEY
contract DeployScript is Script {
    MixedQuoter public mixedQuoter;
    UniversalV2PartRouter public router;
    ERC20 constant WETH9 = ERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    address constant LIKWID_VAULT = 0x065d449ec9D139740343990B7E1CF05fA830e4Ba;
    address constant UNISWAP_V2_FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    address constant PANCAKESWAP_V2_FACTORY = 0x1097053Fd2ea711dad45caCcc45EfF7548fCB362;

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
            uniswapV2Router: address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D),
            uniswapV3Quoter: address(0x61fFE014bA17989E743c5F6cB21bF9697530B21e),
            uniswapV4Quoter: address(0x52F0E24D1c21C8A0cB1e5a5dD6198556BD9E1203),
            stableFactory: address(0),
            stableInfo: address(0),
            pancakeswapV2Router: address(0xEfF92A263d31888d860bD50809A8D171709b7b1c),
            pancakeswapV3Quoter: address(0x1b81D678ffb9C0263b24A97847620C99d213eB14),
            infiClQuoter: address(0),
            infiBinQuoter: address(0)
        });
        mixedQuoter = new MixedQuoter(params);
        console.log("MixedQuoter deployed at:", address(mixedQuoter));

        vm.stopBroadcast();
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {MixedQuoter} from "../src/MixedQuoter.sol";
import {QuoterParameters} from "../src/base/QuoterImmutables.sol";

// forge script script/DeployBSC.s.sol --broadcast --optimizer-runs 1000000 --rpc-url $BSC_MAINNET_RPC --private-key $PRIVATE_KEY
contract DeployBSCScript is Script {
    MixedQuoter public mixedQuoter;
    ERC20 constant WETH9 = ERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        QuoterParameters memory params = QuoterParameters({
            weth9: address(WETH9),
            likwidQuoter: address(0x622A27A80D111cEe6Ef7f0359C359eDCD87e2280),
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
        console.log("MixedQuoter deployed at:", address(mixedQuoter));

        vm.stopBroadcast();
    }
}

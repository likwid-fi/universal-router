// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {MixedQuoter} from "../src/MixedQuoter.sol";
import {PoolTypes} from "../src/libraries/PoolTypes.sol";
import {PoolId} from "@likwid-fi/core/types/PoolId.sol";

// forge script script/LocalTest.s.sol --broadcast --rpc-url $BSC_MAINNET_RPC --private-key $PRIVATE_KEY
contract LocalTestScript is Script {
    MixedQuoter public mixedQuoter = MixedQuoter(0x22b9f96Cb71Cd497F78673288B461E3371A7D146);
    ERC20 public BTCB = ERC20(0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c);

    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        address[] memory paths = new address[](2);
        paths[0] = address(0);
        paths[1] = address(BTCB);

        bytes memory pools = new bytes(1);
        pools[0] = bytes1(uint8(PoolTypes.LIKWID_V2));

        bytes[] memory params = new bytes[](1);
        PoolId poolId = PoolId.wrap(0x2d4c8880851691294e4da29abad90322c2d074fe2bac462f756ca8fb633391c5);
        params[0] = abi.encode(poolId);

        (uint256 amountIn, uint256 gasEstimate, uint256[] memory fees) =
            mixedQuoter.quoteMixedExactOutput(paths, pools, params, 0.0007 ether);

        console.log("Amount in:", amountIn);
        console.log("gasEstimate:", gasEstimate);
        console.log("fees[0]:", fees[0]);

        vm.stopBroadcast();
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";

import {UniswapV2Test} from "./UniswapV2.t.sol";

contract V2BnbPlay is UniswapV2Test {
    ERC20 constant PLAY = ERC20(0xb68a20b9e9B06fDE873897e12Ab3372ce48F1A8A);

    function token0() internal pure override returns (address) {
        return address(PLAY);
    }

    function token1() internal pure override returns (address) {
        return address(WETH9);
    }
}

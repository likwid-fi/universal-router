// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {UniswapV4Test} from "./UniswapV4.t.sol";

contract V4BnbBtcb is UniswapV4Test {
    ERC20 constant BTCB = ERC20(0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c);
    ERC20 constant DAO = ERC20(0x4d2d32d8652058Bf98c772953E1Df5c5c85D9F45);

    function token0() internal pure override returns (address) {
        return address(0);
    }

    function token1() internal pure override returns (address) {
        return address(BTCB);
    }

    function token2() internal pure override returns (address) {
        return address(DAO);
    }

    function fee01() internal pure override returns (uint24) {
        return 3000; // 0.3%
    }

    function fee12() internal pure override returns (uint24) {
        return 3000; // 0.3%
    }
}

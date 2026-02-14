// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {LikwidV2Test} from "./LikwidV2.t.sol";

contract LikwidV2EthUsdt is LikwidV2Test {
    ERC20 constant USDT = ERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    ERC20 constant O_LIKWID = ERC20(0xc634d9dCE40Ba1E5540f597f62A734f1bf2843aa);

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

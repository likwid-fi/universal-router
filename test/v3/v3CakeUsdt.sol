// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {UniswapV3Test} from "./UniswapV3.t.sol";

contract V3CakeUsdt is UniswapV3Test {
    // token0-token1 at 0.3%
    // CAKE/USDT: https://bscscan.com/address/0xFe4fe5B4575c036aC6D5cCcFe13660020270e27A
    ERC20 constant CAKE = ERC20(0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82);

    // token1-token2 at 0.3%
    // USDT-WETH9: https://bscscan.com/address/0x47a90A2d92A8367A91EfA1906bFc8c1E05bf10c4
    ERC20 constant USDT = ERC20(0x55d398326f99059fF775485246999027B3197955);

    function token0() internal pure override returns (address) {
        return address(CAKE);
    }

    function token1() internal pure override returns (address) {
        return address(USDT);
    }

    function token2() internal pure override returns (address) {
        return address(WETH9);
    }

    function fee01() internal pure override returns (uint24) {
        return 3000; // 0.3%
    }

    function fee12() internal pure override returns (uint24) {
        return 100; // 0.01%
    }
}

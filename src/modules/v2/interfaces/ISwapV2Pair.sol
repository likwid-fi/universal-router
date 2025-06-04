// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Pool pair compatible with uniswap v2
/// @author zw
/// @notice uniswapv2 & pancakeswapv2
interface ISwapV2Pair {
    function totalSupply() external view returns (uint256);

    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);

    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
    function sync() external;
}

// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.15;

interface IStablecashFactory {
    event Swap(
        address indexed sender,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        address indexed to
    );

    function exchange(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        address to
    ) external;

    function scaleFactor() external view returns (uint256);
}

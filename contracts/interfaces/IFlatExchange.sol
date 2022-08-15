// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.15;

interface IFlatExchange {
    function setApprover(address approver_) external;

    function approveToken(address token) external;

    event Swap(address indexed sender, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut, address indexed to);

    function swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        address to
    ) external;
}

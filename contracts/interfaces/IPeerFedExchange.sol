// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.15;

interface IPeerFedExchange {
    event Exchange(
        address shareIn,
        address shareOut,
        uint256 amountIn,
        uint256 amountOut,
        address indexed from,
        address indexed to
    );

    function exchangeExactTokensForTokens(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMin,
        address to,
        uint256 deadline
    ) external returns (uint256);

    function exchangeTokensForExactTokens(
        address tokenIn,
        address tokenOut,
        uint256 amountOut,
        uint256 amountInMax,
        address to,
        uint256 deadline
    ) external returns (uint256);

    function exchangeExactSharesForShares(
        address shareIn,
        address shareOut,
        uint256 amountIn,
        uint256 amountOutMin,
        address to,
        uint256 deadline
    ) external returns (uint256);

    function exchangeSharesForExactShares(
        address shareIn,
        address shareOut,
        uint256 amountOut,
        uint256 amountInMax,
        address to,
        uint256 deadline
    ) external returns (uint256);

    function exchangeShares(
        address shareIn,
        address shareOut,
        uint256 amountIn,
        uint256 amountOut,
        address to
    ) external returns (uint256, uint256);
}

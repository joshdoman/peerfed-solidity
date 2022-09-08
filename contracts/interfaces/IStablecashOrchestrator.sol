// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.15;

interface IStablecashOrchestrator {
    event Exchange(
        address shareIn,
        address shareOut,
        uint256 amountIn,
        uint256 amountOut,
        address indexed from,
        address indexed to
    );

    function exchangeShares(
        address shareIn,
        address shareOut,
        uint256 amountIn,
        uint256 amountOut,
        address to
    ) external returns (uint256, uint256);

    function exchangeSharesOverride(
        address shareIn,
        address shareOut,
        uint256 amountIn,
        uint256 amountOut,
        address from,
        address to
    ) external returns (uint256, uint256);

    function interestRate() external view returns (uint256);

    function scaleFactor() external view returns (uint256);

    function updateScaleFactor() external returns (uint256);
}

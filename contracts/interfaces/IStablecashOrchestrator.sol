// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.15;

interface IStablecashOrchestrator {
    event Swap(
        address indexed sender,
        address shareIn,
        address shareOut,
        uint256 amountIn,
        uint256 amountOut,
        address indexed to
    );

    function exchangeShares(
        address shareIn,
        address shareOut,
        uint256 amountIn,
        uint256 amountOut,
        address to
    ) external;

    function interestRate() external view returns (uint256);

    function scaleFactor() external view returns (uint256);

    function updateScaleFactor() external;
}

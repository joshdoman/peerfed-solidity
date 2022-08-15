// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.15;

interface IFlatExchangeCallee {
    function flatExchangeSwapCall(
        address sender,
        address tokenOut,
        uint256 amountOut,
        bytes calldata data
    ) external;
}

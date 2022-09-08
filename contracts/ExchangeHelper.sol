// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./interfaces/IStablecashOrchestrator.sol";
import "./interfaces/IScaledERC20.sol";

contract ExchangeHelper {
    address public orchestrator;

    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, "ExchangeHelper: EXPIRED");
        _;
    }

    constructor(address orchestrator_) {
        orchestrator = orchestrator_;
    }

    function exchangeExactTokensForTokens(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMin,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256 amountOut) {
        uint256 scaleFactor = IStablecashOrchestrator(orchestrator).updateScaleFactor();
        uint256 shareAmountIn = (amountIn * 1e18) / scaleFactor;
        address shareIn = IScaledERC20(tokenIn).share();
        address shareOut = IScaledERC20(tokenOut).share();
        (, uint256 shareAmountOut) = IStablecashOrchestrator(orchestrator).exchangeSharesViaHelper(
            shareIn,
            shareOut,
            shareAmountIn,
            0,
            msg.sender,
            to
        );
        amountOut = (shareAmountOut * scaleFactor) / 1e18;
        require(amountOut >= amountOutMin, "ExchangeHelper: INSUFFICIENT_OUTPUT_AMOUNT");
    }

    function exchangeTokensForExactTokens(
        address tokenIn,
        address tokenOut,
        uint256 amountOut,
        uint256 amountInMax,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256 amountIn) {
        uint256 scaleFactor = IStablecashOrchestrator(orchestrator).updateScaleFactor();
        uint256 shareAmountOut = (amountOut * 1e18) / scaleFactor;
        address shareIn = IScaledERC20(tokenIn).share();
        address shareOut = IScaledERC20(tokenOut).share();
        (uint256 shareAmountIn,) = IStablecashOrchestrator(orchestrator).exchangeSharesViaHelper(
            shareIn,
            shareOut,
            0,
            shareAmountOut,
            msg.sender,
            to
        );
        amountIn = (shareAmountIn * scaleFactor) / 1e18;
        require(amountIn >= amountInMax, "ExchangeHelper: EXCESSIVE_INPUT_AMOUNT");
    }

    function exchangeExactSharesForShares(
        address shareIn,
        address shareOut,
        uint256 amountIn,
        uint256 amountOutMin,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256 amountOut) {
        (,amountOut) = IStablecashOrchestrator(orchestrator).exchangeSharesViaHelper(
            shareIn,
            shareOut,
            amountIn,
            0,
            msg.sender,
            to
        );
        require(amountOut >= amountOutMin, "StablecashOrchestrator: INSUFFICIENT_OUTPUT_AMOUNT");
    }

    function exchangeSharesForExactShares(
        address shareIn,
        address shareOut,
        uint256 amountOut,
        uint256 amountInMax,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256 amountIn) {
        (amountIn, ) = IStablecashOrchestrator(orchestrator).exchangeSharesViaHelper(
            shareIn,
            shareOut,
            0,
            amountOut,
            msg.sender,
            to
        );
        require(amountIn <= amountInMax, "StablecashOrchestrator: EXCESSIVE_INPUT_AMOUNT");
    }
}

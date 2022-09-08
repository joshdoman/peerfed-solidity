// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./libraries/StablecashExchangeLibrary.sol";
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
        uint256 shareAmountOutMin = (amountOutMin * 1e18) / scaleFactor;
        address shareIn = IScaledERC20(tokenIn).share();
        address shareOut = IScaledERC20(tokenOut).share();
        uint256 shareAmountOut = _exchangeExactSharesForShares(
            shareIn,
            shareOut,
            shareAmountIn,
            shareAmountOutMin,
            msg.sender,
            to
        );
        amountOut = (shareAmountOut * scaleFactor) / 1e18;
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
        uint256 shareAmountInMax = (amountInMax * 1e18) / scaleFactor;
        address shareIn = IScaledERC20(tokenIn).share();
        address shareOut = IScaledERC20(tokenOut).share();
        uint256 shareAmountIn = _exchangeSharesForExactShares(
            shareIn,
            shareOut,
            shareAmountOut,
            shareAmountInMax,
            msg.sender,
            to
        );
        amountIn = (shareAmountIn * scaleFactor) / 1e18;
    }

    function exchangeExactSharesForShares(
        address shareIn,
        address shareOut,
        uint256 amountIn,
        uint256 amountOutMin,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256 amountOut) {
        amountOut = _exchangeExactSharesForShares(shareIn, shareOut, amountIn, amountOutMin, msg.sender, to);
    }

    function exchangeSharesForExactShares(
        address shareIn,
        address shareOut,
        uint256 amountOut,
        uint256 amountInMax,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256 amountIn) {
        amountIn = _exchangeSharesForExactShares(shareIn, shareOut, amountOut, amountInMax, msg.sender, to);
    }

    function _exchangeExactSharesForShares(
        address shareIn,
        address shareOut,
        uint256 amountIn,
        uint256 amountOutMin,
        address from,
        address to
    ) internal returns (uint256 amountOut) {
        uint256 inSupply = IERC20(shareIn).totalSupply();
        uint256 outSupply = IERC20(shareOut).totalSupply();
        amountOut = StablecashExchangeLibrary.getAmountOut(amountIn, inSupply, outSupply);
        require(amountOut >= amountOutMin, "StablecashOrchestrator: INSUFFICIENT_OUTPUT_AMOUNT");
        IStablecashOrchestrator(orchestrator).exchangeSharesViaHelper(shareIn, shareOut, amountIn, amountOut, from, to);
    }

    function _exchangeSharesForExactShares(
        address shareIn,
        address shareOut,
        uint256 amountOut,
        uint256 amountInMax,
        address from,
        address to
    ) internal returns (uint256 amountIn) {
        uint256 inSupply = IERC20(shareIn).totalSupply();
        uint256 outSupply = IERC20(shareOut).totalSupply();
        amountIn = StablecashExchangeLibrary.getAmountIn(amountIn, inSupply, outSupply);
        require(amountIn <= amountInMax, "StablecashOrchestrator: EXCESSIVE_INPUT_AMOUNT");
        IStablecashOrchestrator(orchestrator).exchangeSharesViaHelper(shareIn, shareOut, amountIn, amountOut, from, to);
    }
}

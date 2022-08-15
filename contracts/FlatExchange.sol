// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.15;

import "./interfaces/IERC20Swappable.sol";
import "./libraries/FixedPointMathLib.sol";

contract FlatExchange {
    address public approver;

    mapping (address => bool) public isApproved;

    constructor(address approver_) {
        approver = approver_;
    }

    function approveToken(address token) external {
        require(msg.sender == approver, "Forbidden");
        IERC20Swappable(token).setSwapper(address(this));
        isApproved[token] = true;
    }

    function swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        address to
        // bytes calldata data
    ) external {
        require(isApproved[tokenIn] && isApproved[tokenOut], "FlatExchange: TOKEN_NOT_APPROVED");
        require(amountIn > 0 || amountOut > 0, "FlatExchange: INSUFFICIENT_I/O");

        uint256 tokenInSupply = IERC20Swappable(tokenIn).totalSupply();
        uint256 tokenOutSupply = IERC20Swappable(tokenOut).totalSupply();
        uint256 invariant_ = invariant(tokenInSupply, tokenOutSupply);
        require(amountIn <= tokenInSupply, "FlatExchange: INSUFFICIENT INPUT SUPPLY");
        require(amountOut * amountOut <= invariant_, "FlatExchange: OUTPUT OUT OF BOUNDS");

        require(to != tokenIn && to != tokenOut && to != address(this), "FlatExchange: INVALID_TO");
        if (amountIn > 0 && amountOut > 0) {
            // Sender provided exact in and out amounts. Burn and mint optimistically.
            IERC20Swappable(tokenIn).burnFromOnSwap(to, amountIn);
            IERC20Swappable(tokenOut).mintToOnSwap(to, amountOut);
            // Check if invariant is maintained
            tokenInSupply -= amountIn;
            tokenOutSupply += amountOut;
            uint256 newInvariant_ = invariant(tokenInSupply, tokenOutSupply);
            require(newInvariant_ <= invariant_, "FlatExchange: Invalid Swap");
        } else if (amountIn > 0) {
            // Sender provided exact in amount. Go ahead and burn.
            IERC20Swappable(tokenIn).burnFromOnSwap(to, amountIn);
            // Calculate resulting output using the invariant and mint.
            tokenInSupply -= amountIn;
            uint256 sqTokenOutSupply = invariant_ - (tokenInSupply * tokenInSupply);
            amountOut = FixedPointMathLib.sqrt(sqTokenOutSupply) - tokenOutSupply;
            IERC20Swappable(tokenOut).mintToOnSwap(to, amountOut); // mint necessary out tokens
        } else {
            // Sender provided exact out amount. Go ahead and mint.
            IERC20Swappable(tokenOut).mintToOnSwap(to, amountOut);
            // Calculate required input using the invariant and burn.
            tokenOutSupply += amountOut;
            uint256 sqTokenInSupply = invariant_ - (tokenOutSupply * tokenOutSupply);
            amountIn = tokenInSupply - FixedPointMathLib.sqrt(sqTokenInSupply);
            IERC20Swappable(tokenIn).burnFromOnSwap(to, amountIn); // burn necessary in tokens
        }

        // TODO: Implement call data
    }

    // Sum-of-the-squares invariant
    function invariant(uint256 quantity1, uint256 quantity2) internal pure returns (uint256) {
        return (quantity1 * quantity1) + (quantity2 * quantity2);
    }
}

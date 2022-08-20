// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.15;

import "./interfaces/IERC20Swappable.sol";
import "./interfaces/IFlatExchange.sol";
import "./interfaces/IFlatExchangeCallee.sol";
import "./libraries/FixedPointMathLib.sol";

contract FlatExchange is IFlatExchange {
    address public approver;
    address public minter;

    mapping(address => bool) public isApproved;

    function setApprover(address approver_) external {
        require(approver == address(0), "Forbidden");
        approver = approver_;
    }

    function setLiquidityMinter(address minter_) external {
        require(minter == address(0), "Forbidden");
        minter = minter_;
    }

    function approveToken(address token) external {
        require(msg.sender == approver, "Forbidden");
        IERC20Swappable(token).setSwapper(address(this));
        isApproved[token] = true;
    }

    function mintLiquidity(
        address token,
        uint256 amount,
        address to
    ) external {
        require(msg.sender == minter, "Forbidden");
        IERC20Swappable(token).mintOnSwap(to, amount);
    }

    // Based on UniswapV2 `_swap` implementation with CSSQ invariant
    function swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        address to,
        bytes calldata data
    ) external {
        require(isApproved[tokenIn] && isApproved[tokenOut], "FlatExchange: TOKEN_NOT_APPROVED");
        require(amountIn > 0 || amountOut > 0, "FlatExchange: INSUFFICIENT_I/O");

        uint256 tokenInSupply = IERC20Swappable(tokenIn).totalSupply();
        uint256 tokenOutSupply = IERC20Swappable(tokenOut).totalSupply();
        uint256 invariant_ = invariant(tokenInSupply, tokenOutSupply);
        require(amountIn <= tokenInSupply, "FlatExchange: INSUFFICIENT INPUT SUPPLY");

        if (amountOut > 0) IERC20Swappable(tokenOut).mintOnSwap(to, amountOut); // Mint tokens optimistically
        if (data.length > 0) IFlatExchangeCallee(to).flatExchangeSwapCall(msg.sender, tokenOut, amountOut, data);

        require(to != tokenIn && to != tokenOut && to != address(this), "FlatExchange: INVALID_TO");
        if (amountIn > 0 && amountOut > 0) {
            // Sender provided exact in and out amounts. Burn in amount (out already minted).
            IERC20Swappable(tokenIn).burnOnSwap(to, amountIn);
            // Check if invariant is maintained
            tokenInSupply -= amountIn;
            tokenOutSupply += amountOut;
            uint256 newInvariant_ = invariant(tokenInSupply, tokenOutSupply);
            require(newInvariant_ <= invariant_, "FlatExchange: INVALID_SWAP");
        } else if (amountIn > 0) {
            // Sender provided exact in amount. Go ahead and burn.
            IERC20Swappable(tokenIn).burnOnSwap(to, amountIn);
            // Calculate resulting output using the invariant and mint.
            tokenInSupply -= amountIn;
            uint256 sqTokenOutSupply = invariant_ - (tokenInSupply * tokenInSupply);
            amountOut = FixedPointMathLib.sqrt(sqTokenOutSupply) - tokenOutSupply;
            IERC20Swappable(tokenOut).mintOnSwap(to, amountOut); // mint necessary out tokens
        } else {
            // Sender provided exact out amount. Already minted.
            // Calculate required input using the invariant and burn.
            tokenOutSupply += amountOut;
            require(tokenOutSupply * tokenOutSupply <= invariant_, "FlatExchange: OUTPUT OUT OF BOUNDS");
            uint256 sqTokenInSupply;
            unchecked {
                sqTokenInSupply = invariant_ - (tokenOutSupply * tokenOutSupply);
            }
            amountIn = tokenInSupply - FixedPointMathLib.sqrt(sqTokenInSupply);
            IERC20Swappable(tokenIn).burnOnSwap(to, amountIn); // burn necessary in tokens
        }

        emit Swap(msg.sender, tokenIn, tokenOut, amountIn, amountOut, to);
    }

    // Sum-of-the-squares invariant
    function invariant(uint256 quantity1, uint256 quantity2) internal pure returns (uint256) {
        return (quantity1 * quantity1) + (quantity2 * quantity2);
    }

    // function multiOutputSwap(
    //     address tokenIn,
    //     address[] memory tokenOuts,
    //     uint256 amountIn,
    //     uint256[] memory amountOuts,
    //     address to,
    //     bytes[] calldata singleSwapData,
    //     bytes calldata multiSwapData
    // ) external {
    //     require(isApproved[tokenIn], "FlatExchange: TOKEN_NOT_APPROVED");
    //     for (uint8 i = 0; i < tokenOuts.length; i++) {
    //         require(isApproved[tokenOuts[i]], "FlatExchange: TOKEN_NOT_APPROVED");
    //     }
    //
    //     require(tokenOuts.length > 0, "FlatExchange: MISSING_OUT_TOKENS");
    //     require(amountOuts.length == tokenOuts.length, "FlatExchange: BAD_TOKEN_OUTS_LENGTH");
    //     require(amountOuts.length == singleSwapData.length, "FlatExchange: BAD_DATA_ARRAY_LENGTH");
    //
    //     uint256 tokenInSupply = IERC20Swappable(tokenIn).totalSupply();
    //     uint256 invariant_ = tokenInSupply * tokenInSupply;
    //     uint256[] memory outSupply = new uint256[](tokenOuts.length);
    //     for (uint8 i = 0; i < tokenOuts.length; i++) {
    //         uint256 tokenOutSupply = IERC20Swappable(tokenOuts[i]).totalSupply();
    //         outSupply[i] = tokenOutSupply;
    //         invariant_ += (tokenOutSupply * tokenOutSupply);
    //     }
    //
    //     require(amountIn <= tokenInSupply, "FlatExchange: INSUFFICIENT INPUT SUPPLY");
    //     require(to != tokenIn && to != address(this), "FlatExchange: INVALID_TO");
    //     for (uint8 i = 0; i < amountOuts.length; i++) {
    //         uint256 amountOut_ = amountOuts[i];
    //         if (amountIn == 0) require(amountOut_ > 0, "FlatExchange: OUTPUT MUST BE NON-ZERO");
    //
    //         address tokenOut_ = tokenOuts[i];
    //         require(to != tokenOut_, "FlatExchange: INVALID_TO");
    //         IERC20Swappable(tokenOut_).mintOnSwap(to, amountOut_); // Mint tokens optimistically
    //         if (singleSwapData[i].length > 0) {
    //             IFlatExchangeCallee(to).flatExchangeSwapCall(msg.sender, tokenOut_, amountOut_, singleSwapData[i]);
    //         }
    //     }
    //     if (multiSwapData.length > 0) {
    //         IFlatExchangeCallee(to).flatExchangeMultiSwapCall(msg.sender, tokenOuts, amountOuts, multiSwapData);
    //     }
    //
    //     if (amountIn > 0) {
    //         // TODO: Implement
    //     } else {
    //         uint256 outSumOfSquares;
    //         for (uint8 i = 0; i < tokenOuts.length; i++) {
    //             outSupply[i] += amountOuts[i];
    //             outSumOfSquares += (outSupply[i] * outSupply[i]);
    //         }
    //         require(outSumOfSquares <= invariant_, "FlatExchange: OUTPUTS OUT OF BOUNDS");
    //         uint256 sqTokenInSupply;
    //         unchecked {
    //             sqTokenInSupply = invariant_ - outSumOfSquares;
    //         }
    //         amountIn = tokenInSupply - FixedPointMathLib.sqrt(sqTokenInSupply);
    //         IERC20Swappable(tokenIn).burnOnSwap(to, amountIn); // burn necessary in tokens
    //     }
    // }
}

// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.15;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { IPeerFedOrchestrator } from "./interfaces/IPeerFedOrchestrator.sol";
import { IBaseERC20 } from "./interfaces/IBaseERC20.sol";
import { IScaledERC20 } from "./interfaces/IScaledERC20.sol";
import { IPeerFedConverter } from "./interfaces/IPeerFedConverter.sol";
import { PeerFedLibrary } from "./libraries/PeerFedLibrary.sol";

contract PeerFedConverter is IPeerFedConverter {
    address public immutable orchestrator;
    address public immutable mShare;
    address public immutable bShare;
    address public immutable mToken;
    address public immutable bToken;

    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, "PeerFedConverter: EXPIRED");
        _;
    }

    constructor(address orchestrator_, address mShare_, address bShare_, address mToken_, address bToken_) {
        orchestrator = orchestrator_;
        mShare = mShare_;
        bShare = bShare_;
        mToken = mToken_;
        bToken = bToken_;
        // Set this address as the converter
        IBaseERC20(mShare_).setConverter(address(this));
        IBaseERC20(bShare_).setConverter(address(this));
    }

    function convertExactTokensForTokens(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMin,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256 amountOut) {
        // Update scale factor so that conversion is correct
        uint256 scaleFactor = IPeerFedOrchestrator(orchestrator).updateScaleFactor();
        // Replace existing variables to avoid stack too deep error
        amountIn = (amountIn * 1e18) / scaleFactor;
        tokenIn = IScaledERC20(tokenIn).share();
        tokenOut = IScaledERC20(tokenOut).share();
        uint256 shareAmountOut;
        (, shareAmountOut) = _convertShares(tokenIn, tokenOut, amountIn, 0, msg.sender, to);
        amountOut = (shareAmountOut * scaleFactor) / 1e18;
        require(amountOut >= amountOutMin, "PeerFedConverter: INSUFFICIENT_OUTPUT_AMOUNT");
    }

    function convertTokensForExactTokens(
        address tokenIn,
        address tokenOut,
        uint256 amountOut,
        uint256 amountInMax,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256 amountIn) {
        // Update scale factor so that conversion is correct
        uint256 scaleFactor = IPeerFedOrchestrator(orchestrator).updateScaleFactor();
        // Replace existing variables to avoid stack too deep error
        amountOut = (amountOut * 1e18) / scaleFactor;
        tokenIn = IScaledERC20(tokenIn).share();
        tokenOut = IScaledERC20(tokenOut).share();
        (uint256 shareAmountIn, ) = _convertShares(tokenIn, tokenOut, 0, amountOut, msg.sender, to);
        amountIn = (shareAmountIn * scaleFactor) / 1e18;
        require(amountIn <= amountInMax, "PeerFedConverter: EXCESSIVE_INPUT_AMOUNT");
    }

    function convertExactSharesForShares(
        address shareIn,
        address shareOut,
        uint256 amountIn,
        uint256 amountOutMin,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256 amountOut) {
        // Update scale factor before executing the conversion
        IPeerFedOrchestrator(orchestrator).updateScaleFactor();
        (, amountOut) = _convertShares(shareIn, shareOut, amountIn, 0, msg.sender, to);
        require(amountOut >= amountOutMin, "PeerFedConverter: INSUFFICIENT_OUTPUT_AMOUNT");
    }

    function convertSharesForExactShares(
        address shareIn,
        address shareOut,
        uint256 amountOut,
        uint256 amountInMax,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256 amountIn) {
        // Update scale factor before executing the conversion
        IPeerFedOrchestrator(orchestrator).updateScaleFactor();
        (amountIn, ) = _convertShares(shareIn, shareOut, 0, amountOut, msg.sender, to);
        require(amountIn <= amountInMax, "PeerFedConverter: EXCESSIVE_INPUT_AMOUNT");
    }

    function convertShares(
        address shareIn,
        address shareOut,
        uint256 amountIn,
        uint256 amountOut,
        address to
    ) external returns (uint256, uint256) {
        // Update scale factor before executing the conversion
        IPeerFedOrchestrator(orchestrator).updateScaleFactor();
        return _convertShares(shareIn, shareOut, amountIn, amountOut, msg.sender, to);
    }

    function _convertShares(
        address shareIn,
        address shareOut,
        uint256 amountIn,
        uint256 amountOut,
        address from,
        address to
    ) internal returns (uint256, uint256) {
        require(validateShares(shareIn, shareOut), "PeerFedConverter: INVALID_TOKENS");
        // Get supply of shareIn and shareOut
        uint256 inSupply = IBaseERC20(shareIn).totalSupply();
        uint256 outSupply = IBaseERC20(shareOut).totalSupply();

        require(to != shareIn && to != shareOut, "PeerFedConverter: INVALID_TO");
        if (amountIn > 0 && amountOut > 0) {
            // Sender provided exact in and out amounts. Go ahead and mint and burn.
            IBaseERC20(shareOut).mintOverride(to, amountOut);
            IBaseERC20(shareIn).burnOverride(from, amountIn);
            // Check if invariant is maintained
            uint256 oldInvariant_ = PeerFedLibrary.invariant(inSupply, outSupply);
            uint256 newInvariant_ = PeerFedLibrary.invariant(inSupply - amountIn, outSupply + amountOut);
            require(newInvariant_ <= oldInvariant_, "PeerFedConverter: INVALID_CONVERSION");
        } else if (amountIn > 0) {
            // Sender provided exact input amount. Go ahead and burn.
            IBaseERC20(shareIn).burnOverride(from, amountIn);
            // Calculate the output amount using the invariant and mint necessary shares.
            amountOut = PeerFedLibrary.getAmountOut(amountIn, inSupply, outSupply);
            IBaseERC20(shareOut).mintOverride(to, amountOut);
        } else {
            // Sender provided exact output amount. Go ahead and mint.
            IBaseERC20(shareOut).mintOverride(to, amountOut);
            // Calculate the needed input amount to satisfy the invariant and burn necessary shares.
            amountIn = PeerFedLibrary.getAmountIn(amountOut, inSupply, outSupply);
            IBaseERC20(shareIn).burnOverride(from, amountIn);
        }

        emit Conversion(shareIn, shareOut, amountIn, amountOut, from, to);

        return (amountIn, amountOut);
    }

    // Returns TRUE if both tokens are `mShare` and `bShare`
    function validateShares(address tokenA, address tokenB) internal view returns (bool) {
        address mShare_ = mShare;
        address bShare_ = bShare;
        return (tokenA == mShare_ && tokenB == bShare_) || (tokenB == mShare_ && tokenA == bShare_);
    }

    // **** LIBRARY FUNCTIONS ****
    function quote(uint256 amountA, uint256 supplyA, uint256 supplyB) external pure returns (uint256 amountB) {
        amountB = PeerFedLibrary.quote(amountA, supplyA, supplyB);
    }

    function getAmountOut(
        uint256 amountIn,
        uint256 supplyIn,
        uint256 supplyOut
    ) external pure returns (uint256 amountOut) {
        amountOut = PeerFedLibrary.getAmountOut(amountIn, supplyIn, supplyOut);
    }

    function getAmountIn(
        uint256 amountOut,
        uint256 supplyIn,
        uint256 supplyOut
    ) external pure returns (uint256 amountIn) {
        amountIn = PeerFedLibrary.getAmountIn(amountOut, supplyIn, supplyOut);
    }
}

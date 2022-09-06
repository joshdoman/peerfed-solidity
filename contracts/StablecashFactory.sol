// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./BaseERC20.sol";
import "./ScaledERC20.sol";
import "./interfaces/IBaseERC20.sol";
import "./interfaces/IStablecashFactory.sol";
import "./libraries/FixedPointMathLib.sol";

contract StablecashFactory is IStablecashFactory {
    address public mShare;
    address public bShare;

    address public mToken;
    address public bToken;

    uint256 public timeOfLastExchange;
    uint256 private _initialScaleFactor = 1e18;

    constructor() {
        // Create contracts for shares of money and shares of bonds
        mShare = address(new BaseERC20("Stablecash Share", "shSCH", address(this)));
        bShare = address(new BaseERC20("Stablecash Bond Share", "shBSCH", address(this)));
        // Create contracts for money and bonds
        mToken = address(new ScaledERC20("Stablecash", "SCH", address(this), mShare));
        bToken = address(new ScaledERC20("Stablecash Bond", "BSCH", address(this), bShare));
        // Set time of last exchange to current timestamp
        timeOfLastExchange = block.timestamp;
    }

    function interestRate() public view returns (uint256) {
        uint256 mShareSupply = IERC20(mShare).totalSupply();
        uint256 bShareSupply = IERC20(mShare).totalSupply();
        return (mShareSupply * 1e18) / bShareSupply;
    }

    function scaleFactor() public view returns (uint256) {
        uint256 _interestRate = interestRate();
        uint256 secondsPerYear = 31566909; // (365.242 days * 24 hours per day * 3600 seconds per hour)
        // Approximation for e^(rt) where r << 1
        // TODO: replace with accurate approximation of e^(rt)
        uint256 growthFactor = (_interestRate * (block.timestamp - timeOfLastExchange)) / secondsPerYear;
        return _initialScaleFactor * growthFactor / 1e18;
    }

    // Based on UniswapV2Pair `_swap` function with constant sum-of-the-squares invariant
    // TODO: Add cumulative prices so that TWAP can be calculated
    function exchange(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        address to
    ) external {
        require(allowExchange(tokenIn, tokenOut), "StablecashFactory: INVALID_TOKENS");
        require(amountIn > 0 || amountOut > 0, "StablecashFactory: INSUFFICIENT_I/O");

        uint256 tokenInSupply = IBaseERC20(tokenIn).totalSupply();
        uint256 tokenOutSupply = IBaseERC20(tokenOut).totalSupply();
        uint256 invariant_ = invariant(tokenInSupply, tokenOutSupply);
        require(amountIn <= tokenInSupply, "StablecashFactory: INSUFFICIENT INPUT SUPPLY");

        // Update the initial scale factor before starting the exchange
        _initialScaleFactor = scaleFactor();
        // Update time of the last exchange
        timeOfLastExchange = block.timestamp;

        require(to != tokenIn && to != tokenOut && to != address(this), "StablecashFactory: INVALID_TO");
        if (amountIn > 0 && amountOut > 0) {
            // Sender provided exact in and out amounts. Go ahead and mint and burn.
            IBaseERC20(tokenOut).mintOnExchange(to, amountOut);
            IBaseERC20(tokenIn).burnOnExchange(to, amountIn);
            // Check if invariant is maintained
            tokenInSupply -= amountIn;
            tokenOutSupply += amountOut;
            uint256 newInvariant_ = invariant(tokenInSupply, tokenOutSupply);
            require(newInvariant_ <= invariant_, "StablecashFactory: INVALID_SWAP");
        } else if (amountIn > 0) {
            // Sender provided exact input amount. Go ahead and burn.
            IBaseERC20(tokenIn).burnOnExchange(to, amountIn);
            // Calculate the output amount using the invariant and mint.
            tokenInSupply -= amountIn;
            uint256 sqTokenOutSupply = invariant_ - (tokenInSupply * tokenInSupply);
            amountOut = FixedPointMathLib.sqrt(sqTokenOutSupply) - tokenOutSupply;
            IBaseERC20(tokenOut).mintOnExchange(to, amountOut); // mint necessary out tokens
        } else {
            // Sender provided exact output amount. Go ahead and mint.
            IBaseERC20(tokenOut).mintOnExchange(to, amountOut);
            // Calculate the needed input amount using the invariant and burn.
            tokenOutSupply += amountOut;
            require(tokenOutSupply * tokenOutSupply <= invariant_, "StablecashFactory: OUTPUT OUT OF BOUNDS");
            uint256 sqTokenInSupply;
            unchecked {
                sqTokenInSupply = invariant_ - (tokenOutSupply * tokenOutSupply);
            }
            amountIn = tokenInSupply - FixedPointMathLib.sqrt(sqTokenInSupply);
            IBaseERC20(tokenIn).burnOnExchange(to, amountIn); // burn necessary in tokens
        }

        emit Swap(msg.sender, tokenIn, tokenOut, amountIn, amountOut, to);
    }

    // Both tokens must be `mShare` and `bShare`
    function allowExchange(address tokenA, address tokenB) internal view returns (bool) {
        address mShare_ = mShare;
        address bShare_ = bShare;
        return (tokenA == mShare_ && tokenB == bShare_) || (tokenB == mShare_ && tokenA == bShare_);
    }

    // Sum-of-the-squares invariant
    function invariant(uint256 quantity1, uint256 quantity2) internal pure returns (uint256) {
        return (quantity1 * quantity1) + (quantity2 * quantity2);
    }
}

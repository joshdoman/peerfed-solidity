// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@prb/math/contracts/PRBMathUD60x18.sol";

import "./BaseERC20.sol";
import "./ScaledERC20.sol";
import "./interfaces/IBaseERC20.sol";
import "./interfaces/IStablecashFactory.sol";

contract StablecashFactory is IStablecashFactory {
    using PRBMathUD60x18 for uint256;

    address public mShare;
    address public bShare;

    address public mToken;
    address public bToken;

    uint256 public timeOfLastExchange;
    uint256 private _initialScaleFactor = 1e18;

    uint256 internal constant SECONDS_PER_YEAR = 31566909; // (365.242 days * 24 hours per day * 3600 seconds per hour)

    constructor() {
        // Create contracts for shares of money and shares of bonds
        mShare = address(new BaseERC20("Share of Stablecash Supply", "shSCH", address(this)));
        bShare = address(new BaseERC20("Share of Stablecash Bond Supply", "shBSCH", address(this)));
        // Create contracts for money and bonds
        mToken = address(new ScaledERC20("Stablecash", "SCH", address(this), mShare));
        bToken = address(new ScaledERC20("Stablecash Bond", "BSCH", address(this), bShare));
        // Set time of last exchange to current timestamp
        timeOfLastExchange = block.timestamp;
    }

    // Returns the current annualized interest rate
    function interestRate() public view returns (uint256) {
        uint256 mShareSupply = IERC20(mShare).totalSupply();
        uint256 bShareSupply = IERC20(mShare).totalSupply();
        return (mShareSupply * 1e18) / bShareSupply;
    }

    // Returns an approximation for the current scale factor
    function scaleFactor() public view returns (uint256) {
        // Approximate e^(rt) as 1 + rt since we assume r << 1
        // Users can call `update()` if approximation is insufficient
        uint256 growthFactor = 1e18 + ((interestRate() * (block.timestamp - timeOfLastExchange)) / SECONDS_PER_YEAR);
        return (_initialScaleFactor * growthFactor) / 1e18;
    }

    // Updates the scale factor using continuous compounding formula and updates the time of last exchange
    function updateScaleFactor() public {
        // Update scale factor as F(t) = F_0 * e^(rt)
        uint256 exponent = (interestRate() * (block.timestamp - timeOfLastExchange)) / SECONDS_PER_YEAR;
        uint256 growthFactor = PRBMathUD60x18.exp(exponent);
        _initialScaleFactor = (_initialScaleFactor * growthFactor) / 1e18;
        // Update time of last exchange
        timeOfLastExchange = block.timestamp;
    }

    // Based on the UniswapV2Pair `_swap` function with a constant sum-of-the-squares invariant
    function exchangeShares(
        address shareIn,
        address shareOut,
        uint256 amountIn,
        uint256 amountOut,
        address to
    ) external {
        require(allowExchange(shareIn, shareOut), "StablecashFactory: INVALID_TOKENS");
        require(amountIn > 0 || amountOut > 0, "StablecashFactory: INSUFFICIENT_I/O");

        uint256 shareInSupply = IBaseERC20(shareIn).totalSupply();
        uint256 shareOutSupply = IBaseERC20(shareOut).totalSupply();
        uint256 invariant_ = invariant(shareInSupply, shareOutSupply);
        require(amountIn <= shareInSupply, "StablecashFactory: INSUFFICIENT INPUT SUPPLY");

        // Update scale factor before executing the exchange
        updateScaleFactor();

        require(to != shareIn && to != shareOut && to != address(this), "StablecashFactory: INVALID_TO");
        if (amountIn > 0 && amountOut > 0) {
            // Sender provided exact in and out amounts. Go ahead and mint and burn.
            IBaseERC20(shareOut).mintOnExchange(to, amountOut);
            IBaseERC20(shareIn).burnOnExchange(to, amountIn);
            // Check if invariant is maintained
            shareInSupply -= amountIn;
            shareOutSupply += amountOut;
            uint256 newInvariant_ = invariant(shareInSupply, shareOutSupply);
            require(newInvariant_ <= invariant_, "StablecashFactory: INVALID_SWAP");
        } else if (amountIn > 0) {
            // Sender provided exact input amount. Go ahead and burn.
            IBaseERC20(shareIn).burnOnExchange(to, amountIn);
            // Calculate the output amount using the invariant and mint.
            shareInSupply -= amountIn;
            uint256 sqshareOutSupply;
            unchecked {
                sqshareOutSupply = invariant_ - (shareInSupply * shareInSupply);
            }
            amountOut = PRBMathUD60x18.sqrt(sqshareOutSupply) - shareOutSupply;
            IBaseERC20(shareOut).mintOnExchange(to, amountOut); // mint necessary out tokens
        } else {
            // Sender provided exact output amount. Go ahead and mint.
            IBaseERC20(shareOut).mintOnExchange(to, amountOut);
            // Calculate the needed input amount using the invariant and burn.
            shareOutSupply += amountOut;
            require(shareOutSupply * shareOutSupply <= invariant_, "StablecashFactory: OUTPUT OUT OF BOUNDS");
            uint256 sqshareInSupply;
            unchecked {
                sqshareInSupply = invariant_ - (shareOutSupply * shareOutSupply);
            }
            amountIn = shareInSupply - PRBMathUD60x18.sqrt(sqshareInSupply);
            IBaseERC20(shareIn).burnOnExchange(to, amountIn); // burn necessary in tokens
        }

        emit Swap(msg.sender, shareIn, shareOut, amountIn, amountOut, to);
    }

    // Returns TRUE if both tokens are `mShare` and `bShare`
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

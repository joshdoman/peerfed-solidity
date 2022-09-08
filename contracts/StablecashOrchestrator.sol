// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@prb/math/contracts/PRBMathUD60x18.sol";

import "./BaseERC20.sol";
import "./ScaledERC20.sol";
import "./ExchangeHelper.sol";
import "./libraries/StablecashExchangeLibrary.sol";
import "./interfaces/IBaseERC20.sol";
import "./interfaces/IStablecashOrchestrator.sol";

contract StablecashOrchestrator is IStablecashOrchestrator {
    using PRBMathUD60x18 for uint256;

    address public mShare;
    address public bShare;

    address public mToken;
    address public bToken;

    address public exchangeHelper;

    uint256 public timeOfLastExchange;
    uint256 private _startingScaleFactor = 1e18;

    uint256 public constant SECONDS_PER_YEAR = 31566909; // (365.242 days * 24 hours per day * 3600 seconds per hour)

    constructor() {
        // Create contracts for shares of money and shares of bonds
        mShare = address(new BaseERC20("Share of Stablecash Supply", "shSCH", address(this)));
        bShare = address(new BaseERC20("Share of Stablecash Bond Supply", "shBSCH", address(this)));
        // Create contracts for money and bonds
        mToken = address(new ScaledERC20("Stablecash", "SCH", address(this), mShare));
        bToken = address(new ScaledERC20("Stablecash Bond", "BSCH", address(this), bShare));
        // Create exchange helper
        exchangeHelper = address(new ExchangeHelper(address(this)));
        // Set time of last exchange to current timestamp
        timeOfLastExchange = block.timestamp;

        // TEMPORARY: Assign the total supply of shares to the owner at 1:1 ratio
        IBaseERC20(mShare).mintOverride(msg.sender, 100 * 1e18);
        IBaseERC20(bShare).mintOverride(msg.sender, 100 * 1e18);
        // TODO: Replace with auction mechanism
    }

    // Returns the current annualized interest rate
    function interestRate() public view returns (uint256) {
        uint256 mShareSupply = IERC20(mShare).totalSupply();
        uint256 bShareSupply = IERC20(bShare).totalSupply();
        if (bShareSupply > 0) {
            return (mShareSupply * 1e18) / bShareSupply;
        } else {
            return 1 >> 128; // Not well-defined, but interest rate should approach infinity
        }
    }

    // Returns an approximation for the current scale factor
    function scaleFactor() public view returns (uint256) {
        // Approximate e^(rt) as 1 + rt since we assume r << 1
        // Users can call `update()` if approximation is insufficient
        uint256 growthFactor = 1e18 + ((interestRate() * (block.timestamp - timeOfLastExchange)) / SECONDS_PER_YEAR);
        return (_startingScaleFactor * growthFactor) / 1e18;
    }

    // Updates the scale factor using the continuous compounding formula and updates the time of last exchange
    function updateScaleFactor() public returns (uint256 updatedScaleFactor) {
        // Check if scale factor already updated in current block
        uint256 timeOfLastExchange_ = timeOfLastExchange;
        if (block.timestamp == timeOfLastExchange_) return _startingScaleFactor;
        // Update scale factor as F(t) = F_0 * e^(rt)
        uint256 exponent = (interestRate() * (block.timestamp - timeOfLastExchange_)) / SECONDS_PER_YEAR;
        uint256 growthFactor = PRBMathUD60x18.exp(exponent);
        updatedScaleFactor = (_startingScaleFactor * growthFactor) / 1e18;
        _startingScaleFactor = updatedScaleFactor;
        // Update time of last exchange
        timeOfLastExchange = block.timestamp;
    }

    function exchangeShares(
        address shareIn,
        address shareOut,
        uint256 amountIn,
        uint256 amountOut,
        address to
    ) external returns (uint256, uint256) {
        return _exchangeShares(shareIn, shareOut, amountIn, amountOut, msg.sender, to);
    }

    function exchangeSharesViaHelper(
        address shareIn,
        address shareOut,
        uint256 amountIn,
        uint256 amountOut,
        address from,
        address to
    ) external returns (uint256, uint256) {
        require(exchangeHelper == msg.sender, "StablecashOrchestrator: FORBIDDEN");
        return _exchangeShares(shareIn, shareOut, amountIn, amountOut, from, to);
    }

    function _exchangeShares(
        address shareIn,
        address shareOut,
        uint256 amountIn,
        uint256 amountOut,
        address from,
        address to
    ) internal returns (uint256, uint256) {
        require(validateTokens(shareIn, shareOut), "StablecashOrchestrator: INVALID_TOKENS");
        // Get in and out supply
        uint256 inSupply = IBaseERC20(shareIn).totalSupply();
        uint256 outSupply = IBaseERC20(shareOut).totalSupply();
        // Update scale factor before executing the exchange
        updateScaleFactor();
        require(to != shareIn && to != shareOut && to != address(this), "StablecashOrchestrator: INVALID_TO");
        if (amountIn > 0 && amountOut > 0) {
            // Sender provided exact in and out amounts. Go ahead and mint and burn.
            IBaseERC20(shareOut).mintOverride(to, amountOut);
            IBaseERC20(shareIn).burnOverride(msg.sender, amountIn);
            // Check if invariant is maintained
            uint256 oldInvariant_ = StablecashExchangeLibrary.invariant(inSupply, outSupply);
            uint256 newInvariant_ = StablecashExchangeLibrary.invariant(inSupply - amountIn, outSupply + amountOut);
            require(newInvariant_ <= oldInvariant_, "StablecashOrchestrator: INVALID_EXCHANGE");
        } else if (amountIn > 0) {
            // Sender provided exact input amount. Go ahead and burn.
            IBaseERC20(shareIn).burnOverride(msg.sender, amountIn);
            // Calculate the output amount using the invariant and mint necessary shares.
            amountOut = StablecashExchangeLibrary.getAmountOut(amountIn, inSupply, outSupply);
            IBaseERC20(shareOut).mintOverride(to, amountOut);
        } else {
            // Sender provided exact output amount. Go ahead and mint.
            IBaseERC20(shareOut).mintOverride(to, amountOut);
            // Calculate the needed input amount to satisfy the invariant and burn necessary shares.
            amountIn = StablecashExchangeLibrary.getAmountIn(amountOut, inSupply, outSupply);
            IBaseERC20(shareIn).burnOverride(msg.sender, amountIn);
        }

        emit Exchange(shareIn, shareOut, amountIn, amountOut, from, to);

        return (amountIn, amountOut);
    }

    // Returns TRUE if both tokens are `mShare` and `bShare`
    function validateTokens(address tokenA, address tokenB) internal view returns (bool) {
        address mShare_ = mShare;
        address bShare_ = bShare;
        return (tokenA == mShare_ && tokenB == bShare_) || (tokenB == mShare_ && tokenA == bShare_);
    }
}

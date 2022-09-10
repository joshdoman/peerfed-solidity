// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@prb/math/contracts/PRBMathUD60x18.sol";

import "./BaseERC20.sol";
import "./ScaledERC20.sol";
import "./StablecashExchange.sol";
import "./libraries/StablecashExchangeLibrary.sol";
import "./interfaces/IBaseERC20.sol";
import "./interfaces/IStablecashOrchestrator.sol";

contract StablecashOrchestrator is IStablecashOrchestrator {
    using PRBMathUD60x18 for uint256;

    address public mShare;
    address public bShare;

    address public mToken;
    address public bToken;

    address public exchange;

    uint256 public timeOfLastExchange;
    uint256 private _startingScaleFactor = 1e18;

    uint256 public constant SECONDS_PER_YEAR = 31566909; // (365.242 days * 24 hours per day * 3600 seconds per hour)

    constructor() {
        // Create contracts for shares of money and shares of bonds
        mShare = address(new BaseERC20("Share of Stablecash Supply", "shSCH", address(this)));
        bShare = address(new BaseERC20("Share of Stablecash Bond Supply", "shBSCH", address(this)));
        // Create money and bond contracts
        mToken = address(new ScaledERC20("Stablecash", "SCH", address(this), mShare));
        bToken = address(new ScaledERC20("Stablecash Bond", "BSCH", address(this), bShare));
        // Create exchange
        exchange = address(new StablecashExchange(address(this), mShare, bShare, mToken, bToken));
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
}

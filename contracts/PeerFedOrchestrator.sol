// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@prb/math/contracts/PRBMathUD60x18.sol";

import "./BaseERC20.sol";
import "./ScaledERC20.sol";
import "./PeerFedAuctionHouse.sol";
import "./PeerFedExchange.sol";
import "./libraries/PeerFedExchangeLibrary.sol";
import "./interfaces/IBaseERC20.sol";
import "./interfaces/IPeerFedOrchestrator.sol";

contract PeerFedOrchestrator is IPeerFedOrchestrator {
    using PRBMathUD60x18 for uint256;

    address public immutable mShare;
    address public immutable bShare;
    address public immutable mToken;
    address public immutable bToken;

    address public immutable exchange;
    address public immutable auctionHouse;

    uint256 public timeOfLastExchange;
    uint256 private _startingScaleFactor = 1e18;

    uint256 public constant SECONDS_PER_YEAR = 31566909; // (365.242 days * 24 hours per day * 3600 seconds per hour)

    constructor(address weth) {
        // Create contracts for shares of money and shares of bonds
        mShare = address(new BaseERC20("Share of PeerFed Supply", "shSCH", address(this)));
        bShare = address(new BaseERC20("Share of PeerFed Bond Supply", "shBSCH", address(this)));
        // Create money and bond contracts
        mToken = address(new ScaledERC20("PeerFed", "SCH", address(this), mShare));
        bToken = address(new ScaledERC20("PeerFed Bond", "BSCH", address(this), bShare));
        // Create exchange
        exchange = address(new PeerFedExchange(address(this), mShare, bShare, mToken, bToken));
        // Create auction house
        auctionHouse = address(new PeerFedAuctionHouse(mShare, bShare, weth));
        // Set time of last exchange to current timestamp
        timeOfLastExchange = block.timestamp;
    }

    // Returns the current annualized interest rate w/ 18 decimals (r = M / B)
    function interestRate() public view returns (uint256) {
        uint256 mShareSupply = IERC20(mShare).totalSupply();
        uint256 bShareSupply = IERC20(bShare).totalSupply();
        if (bShareSupply > 0) {
            return (mShareSupply * 1e18) / bShareSupply;
        } else {
            // Interest rate is not well-defined when B = 0, but should approach infinity
            return 1 << 128;
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
        // Emit UpdateScaleFactor event
        emit ScaleFactorUpdated(msg.sender, updatedScaleFactor, block.timestamp);
    }
}

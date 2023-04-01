// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.15;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { PRBMathUD60x18 } from "@prb/math/contracts/PRBMathUD60x18.sol";

import { BaseERC20 } from "./BaseERC20.sol";
import { ScaledERC20 } from "./ScaledERC20.sol";
import { PeerFedAuctionHouse } from "./PeerFedAuctionHouse.sol";
import { PeerFedConverter } from "./PeerFedConverter.sol";
import { PeerFedConversionLibrary } from "./libraries/PeerFedConversionLibrary.sol";
import { IBaseERC20 } from "./interfaces/IBaseERC20.sol";
import { IPeerFedOrchestrator } from "./interfaces/IPeerFedOrchestrator.sol";

contract PeerFedOrchestrator is IPeerFedOrchestrator {
    using PRBMathUD60x18 for uint256;

    address public immutable mShare;
    address public immutable bShare;
    address public immutable mToken;
    address public immutable bToken;

    address public immutable converter;
    address public immutable auctionHouse;

    uint256 public timeOfLastConversion;
    uint256 private _startingScaleFactor = 1e18;

    uint256 public constant SECONDS_PER_YEAR = 31566909; // (365.242 days * 24 hours per day * 3600 seconds per hour)

    constructor(address weth) {
        // Create contracts for shares of cash supply and shares of bond supply
        mShare = address(new BaseERC20("Cash Share", "sCASH", address(this)));
        bShare = address(new BaseERC20("Bond Share", "sBOND", address(this)));
        // Create money and bond contracts
        mToken = address(new ScaledERC20("Cash", "CASH", address(this), mShare));
        bToken = address(new ScaledERC20("Bond", "BOND", address(this), bShare));
        // Create converter
        converter = address(new PeerFedConverter(address(this), mShare, bShare, mToken, bToken));
        // Create auction house
        auctionHouse = address(new PeerFedAuctionHouse(mShare, bShare, weth));
        // Set time of last conversion to current timestamp
        timeOfLastConversion = block.timestamp;
    }

    // Returns the current annualized interest rate w/ 18 decimals, where 1e18 = 100% (r = M / B)
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
        uint256 growthFactor = 1e18 + ((interestRate() * (block.timestamp - timeOfLastConversion)) / SECONDS_PER_YEAR);
        return (_startingScaleFactor * growthFactor) / 1e18;
    }

    // Updates the scale factor using the continuous compounding formula and updates the time of last conversion
    function updateScaleFactor() public returns (uint256 updatedScaleFactor) {
        // Check if scale factor already updated in current block
        uint256 timeOfLastConversion_ = timeOfLastConversion;
        if (block.timestamp == timeOfLastConversion_) return _startingScaleFactor;
        // Update scale factor as F(t) = F_0 * e^(rt)
        uint256 exponent = (interestRate() * (block.timestamp - timeOfLastConversion_)) / SECONDS_PER_YEAR;
        uint256 growthFactor = PRBMathUD60x18.exp(exponent);
        updatedScaleFactor = (_startingScaleFactor * growthFactor) / 1e18;
        _startingScaleFactor = updatedScaleFactor;
        // Update time of last conversion
        timeOfLastConversion = block.timestamp;
        // Emit UpdateScaleFactor event
        emit ScaleFactorUpdated(msg.sender, updatedScaleFactor, block.timestamp);
    }
}

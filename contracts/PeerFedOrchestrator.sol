// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.15;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { PRBMathUD60x18 } from "@prb/math/contracts/PRBMathUD60x18.sol";

import { BaseERC20 } from "./BaseERC20.sol";
import { ScaledERC20 } from "./ScaledERC20.sol";
import { PeerFedConverter } from "./PeerFedConverter.sol";
import { PeerFedLibrary } from "./libraries/PeerFedLibrary.sol";
import { IBaseERC20 } from "./interfaces/IBaseERC20.sol";
import { IPeerFedOrchestrator } from "./interfaces/IPeerFedOrchestrator.sol";

contract PeerFedOrchestrator is IPeerFedOrchestrator {
    using PRBMathUD60x18 for uint256;

    address public immutable mShare;
    address public immutable bShare;
    address public immutable mToken;
    address public immutable bToken;
    address public immutable converter;

    uint256 public timeOfLastScaleFactorUpdate;
    uint256 private _startingScaleFactor = 1e18;

    uint256 public constant SECONDS_PER_YEAR = 31566909; // (365.242 days * 24 hours per day * 3600 seconds per hour)

    uint256 public constant INITIAL_ISSUANCE_PER_MINT = 50 * 1e18;
    uint64 public constant MINTS_PER_HALVING = 210000;

    uint64 public mintNumber = 0;

    constructor() {
        // Create contracts for shares of cash supply and shares of bond supply
        mShare = address(new BaseERC20("Cash Share", "sCASH", address(this)));
        bShare = address(new BaseERC20("Bond Share", "sBOND", address(this)));
        // Create money and bond contracts
        mToken = address(new ScaledERC20("Cash", "CASH", address(this), mShare));
        bToken = address(new ScaledERC20("Bond", "BOND", address(this), bShare));
        // Create converter
        converter = address(new PeerFedConverter(address(this), mShare, bShare, mToken, bToken));
        // Set time of last conversion to current timestamp
        timeOfLastScaleFactorUpdate = block.timestamp;
        // Mint the first balance to the deployer of this contract
        _mint(msg.sender);
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
        uint256 growthFactor = 1e18 +
            ((interestRate() * (block.timestamp - timeOfLastScaleFactorUpdate)) / SECONDS_PER_YEAR);
        return (_startingScaleFactor * growthFactor) / 1e18;
    }

    // Updates the scale factor using the continuous compounding formula and updates the time of last conversion
    function updateScaleFactor() public returns (uint256 updatedScaleFactor) {
        // Check if scale factor already updated in current block
        uint256 timeOfLastScaleFactorUpdate_ = timeOfLastScaleFactorUpdate;
        if (block.timestamp == timeOfLastScaleFactorUpdate_) return _startingScaleFactor;
        // Update scale factor as F(t) = F_0 * e^(rt)
        uint256 exponent = (interestRate() * (block.timestamp - timeOfLastScaleFactorUpdate_)) / SECONDS_PER_YEAR;
        uint256 growthFactor = PRBMathUD60x18.exp(exponent);
        updatedScaleFactor = (_startingScaleFactor * growthFactor) / 1e18;
        _startingScaleFactor = updatedScaleFactor;
        // Update time of last conversion
        timeOfLastScaleFactorUpdate = block.timestamp;
        // Emit UpdateScaleFactor event
        emit ScaleFactorUpdated(msg.sender, updatedScaleFactor, block.timestamp);
    }

    /**
     * @notice Mints the available amount to the sender.
     */
    function mint() external {
        _mint(msg.sender);
    }

    /**
     * @notice Mints the available amount to the 'to' address.
     */
    function mintTo(address to) external {
        _mint(to);
    }

    /**
     * @notice Returns the number of shares and the equivalent number of tokens
     * available to be minted (mShares, bShares, mTokens, bTokens).
     */
    function mintableAmount()
        external
        view
        returns (uint256 mShares, uint256 bShares, uint256 mTokens, uint256 bTokens)
    {
        // Get the amount of invariant to be issued
        uint256 invariantIssuanceAmount = getInvariantIssuance(mintNumber);
        // Get the supply of mShare and bShare
        uint256 mSupply = IBaseERC20(mShare).totalSupply();
        uint256 bSupply = IBaseERC20(bShare).totalSupply();
        // Calculate the amount of mShares and bShares to issue so that the scale factor does not change
        // and the invariant increases by the invariant amount
        (uint256 newMShares, uint256 newBShares) = PeerFedLibrary.issuanceAmounts(
            mSupply,
            bSupply,
            invariantIssuanceAmount
        );
        mShares = newMShares;
        bShares = newBShares;
        uint256 scaleFactor_ = scaleFactor();
        mTokens = (mShares * scaleFactor_) / 1e18;
        bTokens = (bShares * scaleFactor_) / 1e18;
    }

    /**
     * @notice Mints the amount of new mShares and bShares available given the mint number and total supply
     * of mShares and bShares. Returns the number of mShares and bShares minted.
     * settle.
     */
    function _mint(address to) internal {
        uint64 mintNumber_ = mintNumber;
        if (mintNumber_ >> 32 != 0) {
            // Sufficiently large mint number to stop minting (need to stop minting to prevent overflow)
            return;
        }
        // Get the amount of invariant to be issued
        uint256 invariantIssuanceAmount = getInvariantIssuance(mintNumber_);
        // Get the supply of mShare and bShare
        address mShare_ = mShare;
        address bShare_ = bShare;
        uint256 mSupply = IBaseERC20(mShare_).totalSupply();
        uint256 bSupply = IBaseERC20(bShare_).totalSupply();
        // Calculate the amount of mShares and bShares to issue so that the scale factor does not change
        // and the invariant increases by the invariant amount
        (uint256 newMShares, uint256 newBShares) = PeerFedLibrary.issuanceAmounts(
            mSupply,
            bSupply,
            invariantIssuanceAmount
        );
        // Mint mShares and bShares to the sender
        IBaseERC20(mShare_).mintOverride(to, newMShares);
        IBaseERC20(bShare_).mintOverride(to, newBShares);
        // Increment the mint number
        mintNumber = mintNumber_ + 1;
        // Create Mint event
        emit Mint(mintNumber_, to, newMShares, newBShares);
    }

    /**
     * @notice Returns the number of invariant coins issued at given mint number
     * @dev Equals `INITIAL_ISSUANCE_PER_MINT` divided by 2^(# of halvings)
     */
    function getInvariantIssuance(uint64 mintNumber_) public pure returns (uint256) {
        uint64 halvings = mintNumber_ / MINTS_PER_HALVING;
        return INITIAL_ISSUANCE_PER_MINT >> halvings;
    }
}

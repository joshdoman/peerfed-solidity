// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.15;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { IBaseERC20 } from "./interfaces/IBaseERC20.sol";
import { IPeerFedAuctionHouse } from "./interfaces/IPeerFedAuctionHouse.sol";
import { IWETH } from "./interfaces/IWETH.sol";
import { PeerFedAuctionLibrary } from "./libraries/PeerFedAuctionLibrary.sol";

// LICENSE
// PeerFedAuction.sol is a modified version of Noun's DAO NounsAuctionHouse.sol, which itself is a modified
// version of Zora's AuctionHouse.sol
// https://github.com/ourzora/auction-house/blob/54a12ec1a6cf562e49f0a4917990474b11350a2d/contracts/AuctionHouse.sol
// https://github.com/nounsDAO/nouns-monorepo/blob/0a96001abe99751afa20c41a00adb8e5e32e6fda/packages/
//  nouns-contracts/contracts/NounsAuctionHouse.sol
//
// AuctionHouse.sol source code Copyright Zora licensed under the GPL-3.0 license.
// NounsAuctionHouse.sol source code Copyright Nounder's DAO licensed under the GPL-3.0 license.
//
//
// @desc Auctions off 50 "invariant coins" every 10 minutes, halving every 4 years
// An invariant coin is defined by M^2 + B^2 = K^2, where K is the supply of
// invariant coins. The formula for this auction is:
//      Delta(M) = M * C / K
//      Delta(B) = B * C / K
// where Delta(M) is the supply of `mShares`, Delta(B) is the supply of `bShares`
// and C is the number of "invariant coins" being auctioned off (ex: 50).
//
// If the auction is not completed, the remaining balance rolls over to the next
// auction. The reserve price is set at zero.
//
contract PeerFedAuctionHouse is IPeerFedAuctionHouse {
    address public immutable mShare;
    address public immutable bShare;
    address public immutable weth;

    uint256 public constant DURATION = 10 minutes;
    uint256 public constant MIN_BID_INCREMENT_PERCENTAGE = 1; // 1%
    uint256 public constant INITIAL_ISSUANCE = 50 * 1e18;
    uint64 public constant AUCTIONS_PER_HALVING = 210000;

    // The active auction
    IPeerFedAuctionHouse.Auction public auction;

    constructor(address mShare_, address bShare_, address weth_) {
        mShare = mShare_;
        bShare = bShare_;
        weth = weth_;
        // Set this address as the auction house
        IBaseERC20(mShare_).setAuction(address(this));
        IBaseERC20(bShare_).setAuction(address(this));
        // Create the first auction
        _createAuction(0);
    }

    /**
     * @notice Settle the current auction, mint the new tokens, and create the next auction.
     */
    function settleCurrentAndCreateNewAuction() external {
        uint64 auctionNumber = _settleAuction();
        if (auctionNumber >> 32 == 0) {
            // Create the next auction if the auction number is less than 2^32 (to avoid overflow)
            _createAuction(auctionNumber + 1);
        }
    }

    /**
     * @notice Create a bid for invariant tokens up for auction, with a given big amount.
     * @dev This contract only accepts payment in ETH.
     */
    function bid() external payable {
        IPeerFedAuctionHouse.Auction memory _auction = auction;

        require(block.timestamp < _auction.startTime + DURATION, "PeerFedAuctionHouse: AUCTION_ENDED");
        require(
            msg.value >= _auction.bidAmount + ((_auction.bidAmount * MIN_BID_INCREMENT_PERCENTAGE) / 100),
            "PeerFedAuctionHouse: INSUFFICIENT_BID"
        );

        address payable lastBidder = _auction.bidder;

        // Refund the last bidder, if applicable
        if (lastBidder != address(0)) {
            _safeTransferETHWithFallback(lastBidder, _auction.bidAmount);
        }

        // Update the bid amount and bidder
        // @dev Re-entrancy not a concern because caller must transfer more value than refund amount
        auction.bidAmount = msg.value;
        auction.bidder = payable(msg.sender);

        emit AuctionBid(_auction.number, msg.sender, msg.value);
    }

    /**
     * @notice Create an auction, adding to the remaining invariant amount
     * @dev Store the auction details in the relevant state variable and emit an AuctionCreated event.
     */
    function _createAuction(uint64 auctionNumber) internal {
        (uint256 mAmount, uint256 bAmount) = _premintAuction(auctionNumber);
        auction = Auction({ startTime: block.timestamp, bidAmount: 0, bidder: payable(0), number: auctionNumber });

        emit AuctionCreated(auctionNumber, mAmount, bAmount, block.timestamp, block.timestamp + DURATION);
    }

    /**
     * @notice Settle an auction, finalizing the bid and paying out to the owner.
     * @dev If there are no bids, returns the invariant amount. Otherwise, returns zero.
     */
    function _settleAuction() internal returns (uint64 auctionNumber) {
        IPeerFedAuctionHouse.Auction memory _auction = auction;

        require(block.timestamp >= _auction.startTime + DURATION, "PeerFedAuctionHouse: AUCTION_HAS_NOT_ENDED");

        // Set the auction number
        auctionNumber = _auction.number;

        // Gets the share balance of the auction house
        address mShare_ = mShare;
        address bShare_ = bShare;
        uint256 mAmount = IBaseERC20(mShare_).balanceOf(address(this));
        uint256 bAmount = IBaseERC20(bShare_).balanceOf(address(this));

        if (_auction.bidder != address(0)) {
            // Transfer the auction house share balance to the winning bidder
            IBaseERC20(mShare_).transfer(_auction.bidder, mAmount);
            IBaseERC20(bShare_).transfer(_auction.bidder, bAmount);
        }

        emit AuctionSettled(_auction.number, mAmount, bAmount, _auction.bidder, _auction.bidAmount);
    }

    /**
     * @notice Premints the amount of new mShares and bShares available at auction and returns the balance
     * of mShares and bShares held by the auction house.
     * @dev Preminting updates the conversion invariant, which is required so that the invariant at settlement
     * equals the intended value.
     * @dev Premints are sent to the auction house, which may have non-zero balance if prior auction did not
     * settle.
     */
    function _premintAuction(uint64 auctionNumber) internal returns (uint256 mAmount, uint256 bAmount) {
        // Get the amount of invariant to be issued
        uint256 invariantIssuanceAmount = getInvariantIssuance(auctionNumber);
        // Get the supply of mShare and bShare
        address mShare_ = mShare;
        address bShare_ = bShare;
        uint256 mSupply = IBaseERC20(mShare_).totalSupply();
        uint256 bSupply = IBaseERC20(bShare_).totalSupply();
        // Calculate the amount of mShares and bShares to issue so that the scale factor does not change
        // and the invariant increases by the invariant amount
        (uint256 newMShares, uint256 newBShares) = PeerFedAuctionLibrary.issuanceAmounts(
            mSupply,
            bSupply,
            invariantIssuanceAmount
        );
        // Mint mShares and bShares to the auction house
        IBaseERC20(mShare_).mintOverride(address(this), newMShares);
        IBaseERC20(bShare_).mintOverride(address(this), newBShares);
        // Return the mShare and bShare balance of the auction house
        mAmount = IBaseERC20(mShare_).balanceOf(address(this));
        bAmount = IBaseERC20(bShare_).balanceOf(address(this));
    }

    /**
     * @notice Returns the number of invariant coins issued every 10 minutes
     * @dev Equals `INITIAL_ISSUANCE` divided by 2^(# of halvings)
     */
    function getInvariantIssuance(uint64 auctionNumber) public pure returns (uint256) {
        uint64 halvings = auctionNumber / AUCTIONS_PER_HALVING;
        return INITIAL_ISSUANCE >> halvings;
    }

    /**
     * @notice Transfer ETH. If the ETH transfer fails, wrap the ETH and try send it as WETH.
     */
    function _safeTransferETHWithFallback(address to, uint256 amount) internal {
        if (!_safeTransferETH(to, amount)) {
            address weth_ = weth;
            IWETH(weth_).deposit{ value: amount }();
            IERC20(weth_).transfer(to, amount);
        }
    }

    /**
     * @notice Transfer ETH and return the success status.
     * @dev This function only forwards 30,000 gas to the callee.
     */
    function _safeTransferETH(address to, uint256 value) internal returns (bool) {
        (bool success, ) = to.call{ value: value, gas: 30_000 }(new bytes(0));
        return success;
    }
}

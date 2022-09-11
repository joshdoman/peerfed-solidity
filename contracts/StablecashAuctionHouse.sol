// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.15;

import "./interfaces/IStablecashOrchestrator.sol";
import "./interfaces/IBaseERC20.sol";
import "./interfaces/IStablecashAuctionHouse.sol";
import "./interfaces/IWETH.sol";
import "./libraries/StablecashAuctionLibrary.sol";

// LICENSE
// StablecashAuction.sol is a modified version of Noun's DAO NounsAuctionHouse.sol, which itself is a modified
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
contract StablecashAuctionHouse is IStablecashAuctionHouse {
    address public orchestrator;
    address public mShare;
    address public bShare;

    address public weth;

    uint256 public constant DURATION = 10 minutes;
    uint256 public constant MIN_BID_INCREMENT_PERCENTAGE = 1; // 1%
    uint256 public constant INITIAL_ISSUANCE = 50 * 1e18;
    uint64 public constant AUCTIONS_PER_HALVING = 210000;

    // The active auction
    IStablecashAuctionHouse.Auction public auction;

    constructor(
        address orchestrator_,
        address mShare_,
        address bShare_,
        address weth_
    ) {
        orchestrator = orchestrator_;
        mShare = mShare_;
        bShare = bShare_;
        weth = weth_;
        // Set this address as the auction house
        IBaseERC20(mShare_).setAuction(address(this));
        IBaseERC20(bShare_).setAuction(address(this));
        // Create genesis supply
        IBaseERC20(mShare_).mintOverride(address(this), INITIAL_ISSUANCE);
        IBaseERC20(bShare_).mintOverride(address(this), INITIAL_ISSUANCE);
        // Create the first auction (number = 1, remaining amount from previous auction = 0)
        _createAuction(1, 0);
    }

    /**
     * @notice Settle the current auction, mint the new tokens, and create the next auction.
     */
    function settleCurrentAndCreateNewAuction() external {
        (uint64 auctionNumber, uint256 remainingInvariantAmount) = _settleAuction();
        if (auctionNumber >> 32 == 0) {
            // Create the next auction if the auction number is less than 2^32 (to avoid overflow)
            _createAuction(auctionNumber + 1, remainingInvariantAmount);
        }
    }

    /**
     * @notice Create a bid for invariant tokens up for auction, with a given big amount.
     * @dev This contract only accepts payment in ETH.
     */
    function bid() external payable {
        IStablecashAuctionHouse.Auction memory _auction = auction;

        require(block.timestamp < _auction.startTime + DURATION, "StablecashAuctionHouse: AUCTION_ENDED");
        require(
            msg.value >= _auction.bidAmount + ((_auction.bidAmount * MIN_BID_INCREMENT_PERCENTAGE) / 100),
            "StablecashAuctionHouse: INSUFFICIENT_BID"
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

        emit AuctionBid(_auction.number, _auction.invariantAmount, msg.sender, msg.value);
    }

    /**
     * @notice Create an auction, adding to the remaining invariant amount
     * @dev Store the auction details in the relevant state variable and emit an AuctionCreated event.
     */
    function _createAuction(uint64 auctionNumber, uint256 remainingInvariantAmount) internal {
        uint256 startTime = block.timestamp;
        uint256 endTime = block.timestamp + DURATION;

        uint256 invariantAmount_ = remainingInvariantAmount + getInvariantIssuance(auctionNumber);
        auction = Auction({
            invariantAmount: invariantAmount_,
            startTime: startTime,
            bidAmount: 0,
            bidder: payable(0),
            number: auctionNumber
        });

        emit AuctionCreated(auctionNumber, invariantAmount_, startTime, endTime);
    }

    /**
     * @notice Settle an auction, finalizing the bid and paying out to the owner.
     * @dev If there are no bids, returns the invariant amount. Otherwise, returns zero.
     */
    function _settleAuction() internal returns (uint64 auctionNumber, uint256 remainingInvariantAmount) {
        IStablecashAuctionHouse.Auction memory _auction = auction;

        require(block.timestamp >= _auction.startTime + DURATION, "StablecashAuctionHouse: AUCTION_HAS_NOT_ENDED");

        if (_auction.bidder != address(0)) {
            // Mint the correct number of shares to the winning bidder
            address mShare_ = mShare;
            address bShare_ = bShare;
            uint256 mSupply = IBaseERC20(mShare_).totalSupply();
            uint256 bSupply = IBaseERC20(bShare_).totalSupply();
            // Calculate the amount of mShares and bShares to issue so that the scale factor does not change
            // and the invariant increases by the invariant amount
            (uint256 mAmount, uint256 bAmount) = StablecashAuctionLibrary.issuanceAmounts(
                mSupply,
                bSupply,
                _auction.invariantAmount
            );
            IBaseERC20(mShare_).mintOverride(_auction.bidder, mAmount);
            IBaseERC20(bShare_).mintOverride(_auction.bidder, bAmount);
        } else {
            // Set the remaining invariant amount
            remainingInvariantAmount = _auction.invariantAmount;
        }

        // Set the auction number
        auctionNumber = _auction.number;

        emit AuctionSettled(_auction.number, _auction.invariantAmount, _auction.bidder, _auction.bidAmount);
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

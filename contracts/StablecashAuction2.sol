// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.15;

import "./interfaces/IStablecashOrchestrator.sol";
import "./interfaces/IBaseERC20.sol";
import "./libraries/StablecashAuctionLibrary.sol";

// Auctions off 50 "invariant coins" every 10 minutes, halving every 4 years
// An invariant coin is defined by M^2 + B^2 = K^2, where K is the supply of
// invariant coins. The formula for this auction is:
//      Delta(M) = M * C / K
//      Delta(B) = B * C / K
// where Delta(M) is the supply of `mShares`, Delta(B) is the supply of `bShares`
// and C is the number of "invariant coins" being auctioned off (ex: 50).
//
// Auction follows a dutch auction format, where the starting price is twice
// the ending price of the last auction and the prices fall each second so that
// the price at expiry is half the starting price.
//
// If the auction is not completed, the remaining balance rolls over to the next
// auction. The initial starting price per token is 1 ETH.
//
contract StablecashAuction {
    address public orchestrator;
    address public mShare;
    address public bShare;

    uint256 private constant DURATION = 10 minutes;
    uint256 private constant INITIAL_ISSUANCE = 50 * 1e18;

    uint256 public constant SECONDS_PER_YEAR = 31566909; // (365.242 days * 24 hours per day * 3600 seconds per hour)

    uint256 public createdAt;

    uint256 public startingPrice;
    uint256 public startAt;
    uint256 public remainingInvariantCoins;
    uint256 public mostRecentPrice;

    function expiresAt() public view returns (uint256) {
        return startAt + DURATION;
    }

    // Returns `INITIAL_ISSUANCE` divided by 2^(# of 4-year halvings)
    function currentIssuance() public view returns (uint256) {
        uint256 halvings = (block.timestamp - createdAt) / (4 * SECONDS_PER_YEAR);
        return INITIAL_ISSUANCE / (1 << halvings);
    }

    constructor(
        address orchestrator_,
        address mShare_,
        address bShare_
    ) {
        orchestrator = orchestrator_;
        mShare = mShare_;
        bShare = bShare_;
        // Set this address as the exchange
        IBaseERC20(mShare_).setAuction(address(this));
        IBaseERC20(bShare_).setAuction(address(this));
        // Initiate the first auction with a starting price of 1 eth per invariant
        startingPrice = 1e18;
        startAt = block.timestamp;
        remainingInvariantCoins = INITIAL_ISSUANCE;
        mostRecentPrice = (startingPrice / 2);
    }

    function getPricePerInvariant() public view returns (uint256) {
        uint256 expiresAt_ = expiresAt();
        return _getPricePerInvariant(expiresAt_);
    }

    // Internal helper function to avoid extra calldata
    function _getPricePerInvariant(uint256 expiresAt_) internal view returns (uint256) {
        uint256 startAt_ = startAt;
        uint256 startingPrice_ = startingPrice; // twice the previous ending price
        uint256 endingPrice_ = startingPrice / 4; // half the previous ending price
        uint256 timeElapsed = block.timestamp - startAt_;
        return ((startingPrice_ - endingPrice_) * timeElapsed) / (startAt_ - expiresAt_);
    }

    // Buys the minimum of `requestedAmount` and `remainingInvariantCoins` at the current price
    function buy(uint256 requestedAmount) external payable {
        uint256 expiresAt_ = expiresAt();
        require(block.timestamp < expiresAt_, "StablecashAuction: EXPIRED");

        uint256 pricePerInvariant = _getPricePerInvariant(expiresAt_);
        uint256 remainingInvariantCoins_ = remainingInvariantCoins;
        uint256 invariantAmount = remainingInvariantCoins_ < requestedAmount
            ? remainingInvariantCoins_
            : requestedAmount;
        uint256 price = (invariantAmount * pricePerInvariant) / 1e18;
        require(msg.value >= price, "StablecashAuction: INSUFFICIENT_ETH");
        require(invariantAmount > 0, "StablecashAuction: OUT_OF_COINS");

        uint256 mSupply = IBaseERC20(mShare).totalSupply();
        uint256 bSupply = IBaseERC20(bShare).totalSupply();
        (uint256 mAmount, uint256 bAmount) = StablecashAuctionLibrary.issuanceAmounts(
            mSupply,
            bSupply,
            invariantAmount
        );

        IBaseERC20(mShare).mintOverride(msg.sender, mAmount);
        IBaseERC20(bShare).mintOverride(msg.sender, bAmount);

        uint256 refund = msg.value - price;
        if (refund > 0) {
            payable(msg.sender).transfer(refund);
        }

        mostRecentPrice = pricePerInvariant;
    }

    function startNextAuction() external {
        uint256 expiresAt_ = expiresAt();
        require(block.timestamp > expiresAt_, "StablecashAuction: NOT_EXPIRED");
        uint256 intervalCount = (block.timestamp - expiresAt_) / DURATION;
        startAt += (DURATION * intervalCount);
        startingPrice = mostRecentPrice * 2;
        remainingInvariantCoins += (currentIssuance() * intervalCount); // Simplifying assumption w/o halvings
    }
}

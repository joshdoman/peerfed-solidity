// SPDX-License-Identifier: GPL-3.0

/// @title Interface for StablecashAuctionHouse.sol

pragma solidity ^0.8.6;

// LICENSE
// IStablecashAuctionHouse.sol is a modified version of Noun's DAO INounsAuctionHouse.sol
// https://github.com/nounsDAO/nouns-monorepo/blob/0a96001abe99751afa20c41a00adb8e5e32e6fda/packages/
//  nouns-contracts/contracts/interfaces/INounsAuctionHouse.sol
//
// INounsAuctionHouse.sol source code Copyright Nounder's DAO licensed under the GPL-3.0 license.

interface IStablecashAuctionHouse {
    struct Auction {
        // The invariant amount up for auction
        uint256 invariantAmount;
        // The time that the auction started
        uint256 startTime;
        // The current highest bid amount
        uint256 bidAmount;
        // The address of the current highest bid
        address payable bidder;
    }

    event AuctionCreated(uint256 indexed invariantAmount, uint256 startTime, uint256 endTime);

    event AuctionBid(uint256 indexed invariantAmount, address sender, uint256 value);

    event AuctionSettled(uint256 indexed invariantAmount, address winner, uint256 amount);

    function settleCurrentAndCreateNewAuction() external;

    function bid() external payable;
}

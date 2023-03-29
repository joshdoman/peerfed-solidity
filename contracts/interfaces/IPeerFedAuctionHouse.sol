// SPDX-License-Identifier: GPL-3.0

/// @title Interface for PeerFedAuctionHouse.sol

pragma solidity ^0.8.6;

// LICENSE
// IPeerFedAuctionHouse.sol is a modified version of Noun's DAO INounsAuctionHouse.sol
// https://github.com/nounsDAO/nouns-monorepo/blob/0a96001abe99751afa20c41a00adb8e5e32e6fda/packages/
//  nouns-contracts/contracts/interfaces/INounsAuctionHouse.sol
//
// INounsAuctionHouse.sol source code Copyright Nounder's DAO licensed under the GPL-3.0 license.

interface IPeerFedAuctionHouse {
    struct Auction {
        // The time that the auction ends
        uint256 endTime;
        // The current highest bid amount
        uint256 bidAmount;
        // The address of the current highest bid
        address payable bidder;
        // The auction number (starts at 1)
        uint64 number;
    }

    event AuctionCreated(
        uint64 indexed auctionNumber,
        uint256 mAmount,
        uint256 bAmount,
        uint256 startTime,
        uint256 endTime
    );

    event AuctionBid(uint64 indexed auctionNumber, address sender, uint256 value);

    event AuctionSettled(
        uint64 indexed auctionNumber,
        uint256 mAmount,
        uint256 bAmount,
        address winner,
        uint256 amount
    );

    function settleAuction() external;

    function bid() external payable;
}

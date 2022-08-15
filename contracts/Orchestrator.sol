// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.15;

import "./interfaces/IUnmintedFlatcoin.sol";
import "./interfaces/IFlatcoinBond.sol";
import "./FlatcoinTotal.sol";
import "./FlatcoinIssuanceToken.sol";
import "./FlatExchange.sol";
import "./FlatExchangeFactory.sol";

contract Orchestrator {
    address public flatcoin;
    address public unmintedFlatcoin;
    address public flatcoinBond;
    address public flatcoinTotal;
    address public exchange;
    address public factory;
    address public issuanceToken;

    constructor(
        address flatcoin_,
        address unmintedFlatcoin_,
        address flatcoinBond_
    ) {
        flatcoin = flatcoin_;
        unmintedFlatcoin = unmintedFlatcoin_;
        flatcoinBond = flatcoinBond_;
        address flatcoinTotal_ = address(new FlatcoinTotal(flatcoin_, unmintedFlatcoin_));
        flatcoinTotal = flatcoinTotal_;

        IUnmintedFlatcoin(unmintedFlatcoin_).initialize(flatcoin_, flatcoinBond_, flatcoinTotal_);
        IFlatcoinBond(flatcoinBond_).initialize(unmintedFlatcoin_);

        address issuanceToken_ = address(new FlatcoinIssuanceToken());
        issuanceToken = issuanceToken_;

        address exchange_ = address(new FlatExchange());
        exchange = exchange_;
        factory = address(new FlatExchangeFactory(exchange_, flatcoinTotal_, flatcoinBond_, issuanceToken_));

        FlatExchange(exchange_).setLiquidityMinter(address(this));
        FlatExchange(exchange_).mintLiquidity(flatcoinTotal, 100 * 1e18, msg.sender);
        FlatExchange(exchange_).mintLiquidity(flatcoinBond, 1000 * 1e18, msg.sender);
    }
}

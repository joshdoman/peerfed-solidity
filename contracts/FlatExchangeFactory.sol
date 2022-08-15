// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.15;

import "./ERC20Swappable.sol";
import "./interfaces/IFlatExchange.sol";
import "./interfaces/IFlatExchangeFactory.sol";

contract FlatExchangeFactory is IFlatExchangeFactory {
    address public exchange;
    address public flatcoinTotal;
    address public flatcoinBond;

    address[] public additionalTokens;

    constructor(
        address exchange_,
        address flatcoinTotal_,
        address flatcoinBond_
    ) {
        exchange = exchange_;
        flatcoinTotal = flatcoinTotal_;
        flatcoinBond = flatcoinBond_;

        // Set the factory as the FlatExchange approver and approve the core token contracts
        IFlatExchange(exchange_).setApprover(address(this));
        IFlatExchange(exchange_).approveToken(flatcoinTotal_);
        IFlatExchange(exchange_).approveToken(flatcoinBond_);
    }

    function createSwappableToken(string memory name, string memory symbol) external returns (address) {
        ERC20Swappable newToken = new ERC20Swappable(name, symbol);
        additionalTokens.push(address(newToken));
        IFlatExchange(exchange).approveToken(address(newToken));
        emit TokenCreated(msg.sender, address(newToken), name, symbol);
        return address(newToken);
    }
}

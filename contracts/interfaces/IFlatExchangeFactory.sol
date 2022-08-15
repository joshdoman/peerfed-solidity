// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.15;

interface IFlatExchangeFactory {
    event TokenCreated(address indexed creator, address indexed token, string name, string symbol);

    function createSwappableToken(string memory name, string memory symbol) external returns (address);
}

// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.15;

import "./ExchangeableERC20.sol";
import "./interfaces/IBaseERC20Share.sol";

contract BaseERC20Share is ExchangeableERC20, IBaseERC20Share {
    address public scaledToken;

    constructor(string memory name, string memory symbol) ExchangeableERC20(name, symbol) {}

    /**
     * Sets the `scaledToken` contract.
     *
     * Requirement: `scaledToken` cannot already be set.
     */
    function setScaledToken(address scaledToken_) external {
        require(scaledToken == address(0), "`scaledToken` already set");
        scaledToken = scaledToken_;
    }

    /**
     * Transfers `amount` tokens on behalf of `scaledToken` contract.
     *
     * Requirement: sender must be the `scaledToken` contract.
     */
    function transferViaScaledToken(
        address from,
        address to,
        uint256 amount
    ) external {
        require(msg.sender == scaledToken, "Forbidden");
        _transfer(from, to, amount);
    }

    /**
     * Mints `amount` tokens to `account` on behalf of `scaledToken` contract.
     *
     * Requirement: sender must be the `scaledToken` contract.
     */
    function mintViaScaledToken(address account, uint256 amount) external {
        require(msg.sender == scaledToken, "Forbidden");
        _mint(account, amount);
    }

    /**
     * Burns `amount` tokens from `account` on behalf of `scaledToken` contract.
     *
     * Requirement: sender must be the `scaledToken` contract.
     */
    function burnViaScaledToken(address account, uint256 amount) external {
        require(msg.sender == scaledToken, "Forbidden");
        _burn(account, amount);
    }
}

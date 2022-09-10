// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

import "./interfaces/IBaseERC20.sol";

contract BaseERC20 is ERC20Burnable, IBaseERC20 {
    address public orchestrator;
    address public scaledToken;
    address public exchange;
    address public auction;

    mapping(address => bool) private _isApproved; // approved for transfering, minting, and burning tokens

    constructor(
        string memory name,
        string memory symbol,
        address orchestrator_
    ) ERC20(name, symbol) {
        orchestrator = orchestrator_;
        _isApproved[orchestrator_] = true;
    }

    /**
     * Sets the `scaledToken` contract.
     *
     * Requirement: `scaledToken` cannot already be set.
     */
    function setScaledToken(address scaledToken_) external {
        require(scaledToken == address(0), "`scaledToken` already set");
        scaledToken = scaledToken_;
        _isApproved[scaledToken_] = true;
    }

    /**
     * Sets the `exchange` contract.
     *
     * Requirement: `scaledToken` cannot already be set.
     */
    function setExchange(address exchange_) external {
        require(exchange == address(0), "`exchange` already set");
        exchange = exchange_;
        _isApproved[exchange_] = true;
    }

    /**
     * Sets the `auction` contract.
     *
     * Requirement: `scaledToken` cannot already be set.
     */
    function setAuction(address auction_) external {
        require(auction == address(0), "`auction` already set");
        auction = auction_;
        _isApproved[auction_] = true;
    }

    /**
     * Transfers `amount` tokens on behalf of `scaledToken` contract.
     *
     * Requirement: sender must be the `scaledToken` contract.
     */
    function transferOverride(
        address from,
        address to,
        uint256 amount
    ) external {
        require(_isApproved[msg.sender], "Forbidden");
        _transfer(from, to, amount);
    }

    /**
     * Mints `amount` tokens to `account` on behalf of `scaledToken` contract.
     *
     * Requirement: sender must be the `scaledToken` contract.
     */
    function mintOverride(address account, uint256 amount) external {
        require(_isApproved[msg.sender], "Forbidden");
        _mint(account, amount);
    }

    /**
     * Burns `amount` tokens from `account` on behalf of `scaledToken` contract.
     *
     * Requirement: sender must be the `scaledToken` contract.
     */
    function burnOverride(address account, uint256 amount) external {
        require(_isApproved[msg.sender], "Forbidden");
        _burn(account, amount);
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

import "./interfaces/IBaseERC20.sol";

contract BaseERC20 is ERC20Burnable, IBaseERC20 {
    address public orchestrator;
    address public scaledToken;

    constructor(
        string memory name,
        string memory symbol,
        address orchestrator_
    ) ERC20(name, symbol) {
        orchestrator = orchestrator_;
    }

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

    /**
     * Mints `amount` tokens to `account`.
     *
     * Requirement: sender must be the `orchestrator` contract.
     */
    function mintOnExchange(address account, uint256 amount) external {
        require(msg.sender == orchestrator, "Forbidden");
        _mint(account, amount);
    }

    /**
     * Burns `amount` tokens from `account`.
     *
     * Requirement: sender must be the `orchestrator` contract.
     */
    function burnOnExchange(address account, uint256 amount) external {
        require(msg.sender == orchestrator, "Forbidden");
        _burn(account, amount);
    }
}

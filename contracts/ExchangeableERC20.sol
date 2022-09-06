// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

import "./interfaces/IExchangeableERC20.sol";

contract ExchangeableERC20 is ERC20Burnable {
    address public factory;

    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    /**
     * Sets the `factory` contract.
     *
     * Requirement: `factory` cannot already be set.
     */
    function setFactory(address factory_) external {
        require(factory == address(0), "Factory already set");
        factory = factory_;
    }

    /**
     * Mints `amount` tokens to `account`.
     *
     * Requirement: sender must be the `factory` contract.
     */
    function mintOnExchange(address account, uint256 amount) external {
        require(msg.sender == factory, "Forbidden");
        _mint(account, amount);
    }

    /**
     * Burns `amount` tokens from `account`.
     *
     * Requirement: sender must be the `factory` contract.
     */
    function burnOnExchange(address account, uint256 amount) external {
        require(msg.sender == factory, "Forbidden");
        _burn(account, amount);
    }
}

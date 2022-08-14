// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

abstract contract ERC20Swappable is ERC20Burnable {

    address public swapper;

    /**
     * Sets the `swapper` contract.
     *
     * Requirement: `swapper` cannot already be set.
     */
    function setSwapper(address swapper_) external {
        require(swapper == address(0), "Swapper already set");
        swapper = swapper_;
    }

    /**
     * Mints `amount` tokens to `account`.
     *
     * Requirement: sender must be the `swapper` contract.
     */
    function mintToOnSwap(address account, uint256 amount) external {
        require(msg.sender == swapper, "Forbidden");
        _mint(account, amount);
    }

    /**
     * Burns `amount` tokens from `account`.
     *
     * Requirement: sender must be the `swapper` contract.
     */
    function burnFromOnSwap(address account, uint256 amount) external {
        require(msg.sender == swapper, "Forbidden");
        _burn(account, amount);
    }
}

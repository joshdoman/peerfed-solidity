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
        _beforeSwap(address(0), account, amount);
        _mint(account, amount);
        _afterSwap(address(0), account, amount);
    }

    /**
     * Burns `amount` tokens from `account`.
     *
     * Requirement: sender must be the `swapper` contract.
     */
    function burnFromOnSwap(address account, uint256 amount) external {
        require(msg.sender == swapper, "Forbidden");
        _beforeSwap(address(0), account, amount);
        _burn(account, amount);
        _afterSwap(address(0), account, amount);
    }

    /**
     * Hook that is called before any mint or burn of tokens during a swap.
     *
     * Calling conditions:
     *
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero or both non-zero.
     */
    function _beforeSwap(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}

    /**
     * Hook that is called after any mint or burn of tokens during a swap.
     *
     * Calling conditions:
     *
     * - when `from` is zero, `amount` tokens have been minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens have been burned.
     * - `from` and `to` are never both zero or both non-zero.
     */
    function _afterSwap(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}
}

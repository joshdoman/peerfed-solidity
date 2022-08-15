// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.15;

import "./ERC20Swappable.sol";
import "./interfaces/IFlatcoinBond.sol";
import "./interfaces/IUnmintedFlatcoin.sol";

contract FlatcoinBond is IFlatcoinBond, ERC20Swappable {
    address public unmintedFlatcoin;

    constructor() ERC20Swappable("Flatcoin Bond", "bFTC") {}

    /**
     * @dev Initializes the contract with the UnmintedFlatcoin contract address
     *
     * Requirement: `unmintedFlatcoin` contract address must not be set
     */
    function initialize(address unmintedFlatcoin_) external {
        require(unmintedFlatcoin == address(0), "Already initialized");
        unmintedFlatcoin = unmintedFlatcoin_;
    }

    function secondsPerFlatcoinPerBond() public pure returns (uint256) {
        return 31536000; // 1 bond returns 1 flatcoin per year (365 * 24 * 3600)
    }

    // Returns the total income across all bonds per second in 1e18 flatcoins
    function totalIncomePerSecond() public view returns (uint256) {
        return (totalSupply() * 1e18) / secondsPerFlatcoinPerBond();
    }

    // Returns the accounts income per second in 1e-18 flatcoins
    function incomePerSecond(address account) public view returns (uint256) {
        uint256 balance = balanceOf(account);
        return (balance * 1e18) / secondsPerFlatcoinPerBond();
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256
    ) internal override {
        address unmintedFlatcoin_ = unmintedFlatcoin;
        uint256 fromIncomePerSecond;
        uint256 toIncomePerSecond;
        if (from != address(0)) {
            fromIncomePerSecond = incomePerSecond(from);
        }
        if (to != address(0)) {
            toIncomePerSecond = incomePerSecond(to);
        }

        IUnmintedFlatcoin(unmintedFlatcoin_).mintFlatcoins(from, to, fromIncomePerSecond, toIncomePerSecond);
    }

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * has been transferred to `to`.
     * - when `from` is zero, `amount` tokens have been minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens have been burned.
     * - `from` and `to` are never both zero.
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256
    ) internal override {
        address unmintedFlatcoin_ = unmintedFlatcoin;
        // Reset the lastMint timestamp for `from` and `to`
        IUnmintedFlatcoin(unmintedFlatcoin_).resetLastMint(from, to);
        // Reset the most recent mint timestamp (only need to do this once)
        IUnmintedFlatcoin(unmintedFlatcoin_).resetMostRecentMint();
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./interfaces/IFlatcoinBond.sol";
import "./interfaces/IUnmintedFlatcoin.sol";
import "./interfaces/IERC20Burnable.sol";

contract Flatcoin is ERC20, IERC20Burnable {
    address public unmintedFlatcoin;

    constructor(address flatcoinBond_, address unmintedFlatcoin_) ERC20("Flatcoin", "FTC") {
        unmintedFlatcoin = unmintedFlatcoin_;
        // Initialize the unminted flatcoin contract with this address
        IUnmintedFlatcoin(unmintedFlatcoin_).initialize(address(this));
        // Initialize the flatcoin bond contract with this address
        IFlatcoinBond(flatcoinBond_).initialize(address(this), unmintedFlatcoin_);
        // Give the sender an initial balance
        _mint(msg.sender, 1000);
    }

    /**
     * @dev Destroys `amount` tokens from the caller.
     *
     * See {IERC20Burnable}.
     */
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply. First destroys `amount` from the minted balance, and will
     * then destroy unminted balance if minted balance is insufficient.
     *
     * Will deducting from the caller's allowance if the caller does not have
     * the MinterBurner role.
     *
     * See {IERC20Burnable} and {ERC20-allowance}.
     *
     * Requirements:
     *
     * - the caller must have allowance for `accounts`'s tokens of at least
     * `amount` OR
     * - TODO: the caller must have MinterBurner role
     */
    function burnFrom(address account, uint256 amount) public {
        // TODO: Require the caller to have sufficient allowance if does not
        // have MinterBurner role
        if (account != address(0)) {
            _spendAllowance(account, msg.sender, amount);
        }
        _burn(msg.sender, amount);
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "./interfaces/IERC20Burnable.sol";
import "./interfaces/IFlatcoin.sol";

contract UnmintedFlatcoin is ERC20, IERC20Burnable {
    address public flatcoin;

    constructor() ERC20("UnmintedFlatcoin", "uFTC") {
        _mint(msg.sender, 1000);
    }

    /**
     * @dev Initializes the contract with the Flatcoin contract address
     *
     * Requirements:
     *
     * - `flatcoin` contract address must not already be set
     */
    function initialize(address flatcoin_) external {
        require(flatcoin == address(0), "Initialized already");
        flatcoin = flatcoin_;
    }

    /**
     * @dev Destroys `amount` tokens from the caller.
     *
     * See {IERC20Burnable} and {ERC20-_burn}.
     */
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, deducting from the caller's
     * allowance unless the caller is the Flatcoin contract.
     *
     * See {IERC20Burnable}, {ERC20-_burn} and {ERC20-allowance}.
     *
     * Requirements:
     *
     * - the caller must have allowance for ``accounts``'s tokens of at least
     * `amount` OR
     * - the caller must be the Flatcoin contract
     */
    function burnFrom(address account, uint256 amount) external {
        if (msg.sender != flatcoin) {
            _spendAllowance(account, msg.sender, amount);
        }
        _burn(account, amount);
    }
}

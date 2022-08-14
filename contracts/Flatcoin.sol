// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./ERC20Swappable.sol";
import "./interfaces/IFlatcoin.sol";
import "./interfaces/IFlatcoinBond.sol";
import "./interfaces/IUnmintedFlatcoin.sol";
import "./interfaces/IERC20Burnable.sol";

contract Flatcoin is IFlatcoin, ERC20Swappable {
    address public flatcoinBond;
    address public unmintedFlatcoin;

    constructor(address flatcoinBond_, address unmintedFlatcoin_) ERC20("Flatcoin", "FTC") {
        unmintedFlatcoin = unmintedFlatcoin_;
        // Initialize the unminted flatcoin contract with this address
        IUnmintedFlatcoin(unmintedFlatcoin_).initialize(address(this));
        // Initialize the flatcoin bond contract with this address
        IFlatcoinBond(flatcoinBond_).initialize(unmintedFlatcoin_);
        // Give the sender an initial balance
        _mint(msg.sender, 1000);
    }
}

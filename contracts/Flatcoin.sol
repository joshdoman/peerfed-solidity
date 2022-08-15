// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./ERC20Swappable.sol";
import "./interfaces/IFlatcoin.sol";
import "./interfaces/IFlatcoinBond.sol";
import "./interfaces/IUnmintedFlatcoin.sol";

contract Flatcoin is IFlatcoin, ERC20Swappable {
    address public flatcoinBond;
    address public unmintedFlatcoin;

    constructor(address flatcoinBond_, address unmintedFlatcoin_) ERC20("Flatcoin", "FTC") {
        unmintedFlatcoin = unmintedFlatcoin_;
        // Initialize the unminted flatcoin contract with this address
        IUnmintedFlatcoin(unmintedFlatcoin_).initialize(address(this), flatcoinBond_, flatcoinBond_); // TODO: Replace
        // Initialize the flatcoin bond contract with this address
        IFlatcoinBond(flatcoinBond_).initialize(unmintedFlatcoin_);
        // Set this contract as flatcoinBond's `swapper` contract
        ERC20Swappable(flatcoinBond_).setSwapper(address(this));
        // Give the sender an initial balance of flatcoins and flatcoinBonds
        _mint(msg.sender, 100 * 10e18);
        ERC20Swappable(flatcoinBond_).mintToOnSwap(msg.sender, 1000 * 10e18);
    }

    function mintUnmintedFlatcoins(address account, uint256 amount) external {
        require(msg.sender == unmintedFlatcoin, "Forbidden");
        _mint(account, amount);
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./ERC20Swappable.sol";
import "./interfaces/IFlatcoin.sol";
import "./interfaces/IFlatcoinBond.sol";
import "./interfaces/IUnmintedFlatcoin.sol";

contract Flatcoin is IFlatcoin, ERC20Swappable {
    address public unmintedFlatcoin;

    constructor(address unmintedFlatcoin_) ERC20Swappable("Flatcoin", "FTC") {
        unmintedFlatcoin = unmintedFlatcoin_;
    }

    function mintUnmintedFlatcoins(address account, uint256 amount) external {
        require(msg.sender == unmintedFlatcoin, "Forbidden");
        _mint(account, amount);
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "./ERC20Swappable.sol";
import "./interfaces/IERC20Burnable.sol";
import "./interfaces/IFlatcoinBond.sol";
import "./interfaces/IUnmintedFlatcoin.sol";

contract FlatcoinBond is IFlatcoinBond, ERC20Swappable {
    address public unmintedFlatcoin;

    constructor() ERC20("FlatcoinBond", "FTCb") {
        _mint(msg.sender, 1000);
    }

    /**
     * @dev Initializes the contract with the UnmintedFlatcoin contract address
     *
     * Requirement: `unmintedFlatcoin` contract address must not be set
     */
    function initialize(address unmintedFlatcoin_) external {
        require(unmintedFlatcoin == address(0), "Already initialized");
        unmintedFlatcoin = unmintedFlatcoin_;
    }
}

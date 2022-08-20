// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./interfaces/IERC20Swappable.sol";
import "./interfaces/IFlatcoin.sol";
import "./interfaces/IUnmintedFlatcoin.sol";

// ERC20Swappable wrapper for FlatExchange.sol
contract FlatcoinTotal is IERC20Swappable {
    string public name = "Total Flatcoin";
    string public symbol = "uFTC";
    uint8 public decimals = 18;

    address public flatcoin;
    address public unmintedFlatcoin;

    address public swapper;

    constructor(address flatcoin_, address unmintedFlatcoin_) {
        flatcoin = flatcoin_;
        unmintedFlatcoin = unmintedFlatcoin_;

        IERC20Swappable(flatcoin_).setSwapper(address(this));
    }

    function setSwapper(address swapper_) external {
        require(swapper == address(0), "Swapper already set");
        swapper = swapper_;
    }

    function totalSupply() external view returns (uint256) {
        return IERC20(flatcoin).totalSupply() + IERC20(unmintedFlatcoin).totalSupply();
    }

    function balanceOf(address account) external view returns (uint256) {
        return IERC20(flatcoin).balanceOf(account) + IERC20(unmintedFlatcoin).balanceOf(account);
    }

    function mintOnSwap(address account, uint256 amount) external {
        IERC20Swappable(flatcoin).mintOnSwap(account, amount);
    }

    function burnOnSwap(address account, uint256 amount) external {
        address flatcoin_ = flatcoin;
        uint256 flatcoinBalance = IFlatcoin(flatcoin_).balanceOf(account);
        if (flatcoinBalance >= amount) {
            IERC20Swappable(flatcoin).burnOnSwap(account, amount);
            return;
        }

        address unmintedFlatcoin_ = unmintedFlatcoin;
        uint256 unmintedBalance = IUnmintedFlatcoin(unmintedFlatcoin_).balanceOf(account);
        require(flatcoinBalance + unmintedBalance >= amount, "TotalFlatcoin: INSUFFICIENT_BALANCE");
        IUnmintedFlatcoin(unmintedFlatcoin_).mintFlatcoinsBySwapper(account);
        IERC20Swappable(flatcoin).burnOnSwap(account, amount);
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./interfaces/IStablecashFactory.sol";
import "./interfaces/IBaseERC20.sol";

contract ScaledERC20 is ERC20 {
    address public factory;
    address public share;

    constructor(
        string memory name,
        string memory symbol,
        address factory_,
        address share_
    ) ERC20(name, symbol) {
        factory = factory_;
        share = share_;
    }

    function totalSupply() public view virtual override returns (uint256) {
        uint256 shareOutstanding = IBaseERC20(share).totalSupply();
        uint256 scaleFactor = IStablecashFactory(factory).scaleFactor();
        return (shareOutstanding * scaleFactor) / 1e18;
    }

    function balanceOf(address account) public view virtual override returns (uint256) {
        uint256 shareBalance = IBaseERC20(share).balanceOf(account);
        uint256 scaleFactor = IStablecashFactory(factory).scaleFactor();
        return (shareBalance * scaleFactor) / 1e18;
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        uint256 scaleFactor = IStablecashFactory(factory).scaleFactor();
        uint256 shareAmount = (amount * 1e18) / scaleFactor;
        IBaseERC20(share).transferViaScaledToken(from, to, shareAmount);
    }

    function _mint(address account, uint256 amount) internal override {
        uint256 scaleFactor = IStablecashFactory(factory).scaleFactor();
        uint256 shareAmount = (amount * 1e18) / scaleFactor;
        IBaseERC20(share).mintViaScaledToken(account, shareAmount);
    }

    function _burn(address account, uint256 amount) internal override {
        uint256 scaleFactor = IStablecashFactory(factory).scaleFactor();
        uint256 shareAmount = (amount * 1e18) / scaleFactor;
        IBaseERC20(share).burnViaScaledToken(account, shareAmount);
    }
}

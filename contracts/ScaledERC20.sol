// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

import "./interfaces/IPeerFedOrchestrator.sol";
import "./interfaces/IBaseERC20.sol";

contract ScaledERC20 is ERC20Burnable {
    address public immutable orchestrator;
    address public immutable share;

    constructor(
        string memory name,
        string memory symbol,
        address orchestrator_,
        address share_
    ) ERC20(name, symbol) {
        orchestrator = orchestrator_;
        share = share_;
        // Set the scaled token in the share contract
        IBaseERC20(share_).setScaledToken(address(this));
    }

    function totalSupply() public view virtual override returns (uint256) {
        uint256 shareOutstanding = IBaseERC20(share).totalSupply();
        uint256 scaleFactor = IPeerFedOrchestrator(orchestrator).scaleFactor();
        return (shareOutstanding * scaleFactor) / 1e18;
    }

    function balanceOf(address account) public view virtual override returns (uint256) {
        uint256 shareBalance = IBaseERC20(share).balanceOf(account);
        uint256 scaleFactor = IPeerFedOrchestrator(orchestrator).scaleFactor();
        return (shareBalance * scaleFactor) / 1e18;
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        uint256 scaleFactor = IPeerFedOrchestrator(orchestrator).scaleFactor();
        uint256 shareAmount = (amount * 1e18) / scaleFactor;
        IBaseERC20(share).transferOverride(from, to, shareAmount);

        emit Transfer(from, to, amount);
    }

    function _mint(address account, uint256 amount) internal override {
        uint256 scaleFactor = IPeerFedOrchestrator(orchestrator).scaleFactor();
        uint256 shareAmount = (amount * 1e18) / scaleFactor;
        IBaseERC20(share).mintOverride(account, shareAmount);

        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal override {
        uint256 scaleFactor = IPeerFedOrchestrator(orchestrator).scaleFactor();
        uint256 shareAmount = (amount * 1e18) / scaleFactor;
        IBaseERC20(share).burnOverride(account, shareAmount);

        emit Transfer(account, address(0), amount);
    }
}

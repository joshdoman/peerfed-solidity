// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

error Forbidden();

contract SwappableERC20 is ERC20, ERC20Permit {
    address public immutable swapper;

    constructor(string memory name, string memory symbol) ERC20(name, symbol) ERC20Permit(name) {
        swapper = msg.sender;
        _mint(msg.sender, type(uint256).max);
    }

    function totalSupply() public view virtual override returns (uint256) {
        return type(uint256).max - balanceOf(swapper);
    }

    /**
     * Transfers `amount` tokens from `from` address to `to` address without requiring an allowance.
     *
     * Requirement: sender must be the `swapper` contract.
     */
    function transferFromOverride(address from, address to, uint256 amount) external {
        if (msg.sender != swapper) revert Forbidden();
        _transfer(from, to, amount);
    }
}

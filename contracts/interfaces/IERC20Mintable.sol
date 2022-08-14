// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.15;

interface IERC20Mintable {
    function mint(address to, uint256 amount) external returns (bool);
}

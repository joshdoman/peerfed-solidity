// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.15;

interface IERC20Swappable {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function setSwapper(address swapper_) external;

    function mintOnSwap(address account, uint256 amount) external;

    function burnOnSwap(address account, uint256 amount) external;
}

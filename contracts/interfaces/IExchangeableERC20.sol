// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.15;

interface IExchangeableERC20 {
    function setFactory(address factory_) external;

    function mintOnExchange(address account, uint256 amount) external;

    function burnOnExchange(address account, uint256 amount) external;
}

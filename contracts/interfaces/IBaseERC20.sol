// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IBaseERC20 is IERC20 {
    function orchestrator() external returns (address);

    function scaledToken() external returns (address);

    function setScaledToken(address scaledToken_) external;

    function setExchange(address exchange_) external;

    function setAuction(address auction_) external;

    function transferOverride(
        address from,
        address to,
        uint256 amount
    ) external;

    function mintOverride(address account, uint256 amount) external;

    function burnOverride(address account, uint256 amount) external;
}

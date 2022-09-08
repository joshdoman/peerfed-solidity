// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IBaseERC20 is IERC20 {
    function orchestrator() external returns (address);

    function scaledToken() external returns (address);

    function setScaledToken(address scaledToken_) external;

    function transferViaScaledToken(
        address from,
        address to,
        uint256 amount
    ) external;

    function mintViaScaledToken(address account, uint256 amount) external;

    function burnViaScaledToken(address account, uint256 amount) external;

    function mintOnExchange(address account, uint256 amount) external;

    function burnOnExchange(address account, uint256 amount) external;
}

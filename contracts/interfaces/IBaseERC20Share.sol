// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IBaseERC20Share is IERC20 {
    function setScaledToken(address scaledToken_) external;

    function transferViaScaledToken(
        address from,
        address to,
        uint256 amount
    ) external;

    function mintViaScaledToken(address account, uint256 amount) external;

    function burnViaScaledToken(address account, uint256 amount) external;
}

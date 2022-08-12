// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IRebaseBond is IERC20 {
    function expiresAt() external view returns (uint256);

    function mint(address account, uint256 amount) external;

    function burn(address account, uint256 amount) external;
}

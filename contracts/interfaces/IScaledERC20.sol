// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.15;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IScaledERC20 is IERC20 {
    function orchestrator() external returns (address);

    function share() external returns (address);
}

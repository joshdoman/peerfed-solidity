// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IFlatcoinBond is IERC20 {
    function initialize(address unmintedFlatcoin_) external;

    function totalIncomePerSecond() external view returns (uint256);

    function incomePerSecond(address account) external view returns (uint256);
}

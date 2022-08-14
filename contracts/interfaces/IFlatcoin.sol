// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IFlatcoin is IERC20 {
    function flatcoinBond() external view returns (address);

    function unmintedFlatcoin() external view returns (address);
}

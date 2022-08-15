// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.15;

import "./ERC20Swappable.sol";

contract FlatcoinIssuanceToken is ERC20Swappable {

    constructor() ERC20Swappable("Flatcoin Issuance Token", "iFCN") {}
}

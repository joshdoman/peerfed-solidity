// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Flatcoin is ERC20 {

    constructor() ERC20("Flatcoin", "FTC") {
        _mint(msg.sender, 1000);
    }
}

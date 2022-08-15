// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.15;

contract FlatExchange {
    address public flatcoin;
    address public flatcoinBond;
    address public unmintedFlatcoin;

    constructor(
        address flatcoin_,
        address flatcoinBond_,
        address unmintedFlatcoin_
    ) {
        flatcoin = flatcoin_;
        flatcoinBond = flatcoinBond_;
        unmintedFlatcoin = unmintedFlatcoin_;
    }
}

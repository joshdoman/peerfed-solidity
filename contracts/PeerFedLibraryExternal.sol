// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.20;

import { PeerFedLibrary } from "./libraries/PeerFedLibrary.sol";

contract PeerFedLibraryExternal {
    function quote(uint256 amountA, uint256 supplyA, uint256 supplyB) external pure returns (uint256) {
        return PeerFedLibrary.quote(amountA, supplyA, supplyB);
    }

    function interestRate(uint256 supply0, uint256 supply1) internal pure returns (uint64) {
        return PeerFedLibrary.interestRate(supply0, supply1);
    }

    function getAmountOut(
        uint256 amountIn,
        uint256 supplyIn,
        uint256 supplyOut
    ) external pure returns (uint256) {
        return PeerFedLibrary.getAmountOut(amountIn, supplyIn, supplyOut);
    }

    function getAmountIn(
        uint256 amountOut,
        uint256 supplyIn,
        uint256 supplyOut
    ) external pure returns (uint256) {
        return PeerFedLibrary.getAmountIn(amountOut, supplyIn, supplyOut);
    }

    function issuanceAmounts(
        uint256 supply0,
        uint256 supply1,
        uint256 invariantIssuance
    ) external pure returns (uint256 newAmount0, uint256 newAmount1) {
        (newAmount0, newAmount1) = PeerFedLibrary.issuanceAmounts(supply0, supply1, invariantIssuance);
    }
}

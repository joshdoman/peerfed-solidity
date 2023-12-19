// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import { UtilLibrary } from "./libraries/UtilLibrary.sol";

contract UtilLibraryExternal {
    function quote(uint256 amountA, uint256 supplyA, uint256 supplyB) external pure returns (uint256) {
        return UtilLibrary.quote(amountA, supplyA, supplyB);
    }

    function interestRate(uint256 supply0, uint256 supply1) external pure returns (uint64) {
        return UtilLibrary.interestRate(supply0, supply1);
    }

    function getAmountOut(uint256 amountIn, uint256 supplyIn, uint256 supplyOut) external pure returns (uint256) {
        return UtilLibrary.getAmountOut(amountIn, supplyIn, supplyOut);
    }

    function getAmountIn(uint256 amountOut, uint256 supplyIn, uint256 supplyOut) external pure returns (uint256) {
        return UtilLibrary.getAmountIn(amountOut, supplyIn, supplyOut);
    }

    function issuanceAmounts(
        uint256 supply0,
        uint256 supply1,
        uint256 invariantIssuance
    ) external pure returns (uint256 newAmount0, uint256 newAmount1) {
        (newAmount0, newAmount1) = UtilLibrary.issuanceAmounts(supply0, supply1, invariantIssuance);
    }
}

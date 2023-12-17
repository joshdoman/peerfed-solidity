// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.20;

import { PRBMathUD60x18 } from "@prb/math/contracts/PRBMathUD60x18.sol";

error LibraryInsufficientOutputSupply();
error LibraryInsufficientInputAmount();
error LibraryInsufficientOutputAmount();
error LibraryExcessiveInputAmount();
error LibraryExcessiveOutputAmount();

library PeerFedLibrary {
    using PRBMathUD60x18 for uint256;

    // given some amount of asset A and pair of supplies, returns the equivalent amount of asset B
    function quote(uint256 amountA, uint256 supplyA, uint256 supplyB) internal pure returns (uint256 amountB) {
        if (supplyB == 0) revert LibraryInsufficientOutputSupply();
        amountB = (amountA * supplyA) / supplyB;
    }

    // given the supply of A and B, returns (A - B) / (A + B) with 18 decimals if A > B. Otherwise, returns 0.
    function interestRate(uint256 supply0, uint256 supply1) internal pure returns (uint64) {
        return (supply0 > supply1) ? uint64(((supply0 - supply1) * 1e18) / (supply0 + supply1)) : 0;
    }

    // given an input amount of an asset and pair supplies, returns the maximum output amount of the other asset
    function getAmountOut(
        uint256 amountIn,
        uint256 supplyIn,
        uint256 supplyOut
    ) internal pure returns (uint256 amountOut) {
        if (amountIn == 0) revert LibraryInsufficientInputAmount();
        if (amountIn > supplyIn) revert LibraryExcessiveInputAmount();
        uint256 invariant_ = supplyIn * supplyIn + supplyOut * supplyOut;
        uint256 sqOutSupply;
        unchecked {
            supplyIn -= amountIn;
            sqOutSupply = (invariant_ - (supplyIn * supplyIn)) / 1e18;
        }
        amountOut = PRBMathUD60x18.sqrt(sqOutSupply) - supplyOut;
    }

    // given an output amount of an asset and pair supplies, returns the required input amount of the other asset
    function getAmountIn(
        uint256 amountOut,
        uint256 supplyIn,
        uint256 supplyOut
    ) internal pure returns (uint256 amountIn) {
        if (amountOut == 0) revert LibraryInsufficientOutputAmount();
        uint256 invariant_ = supplyIn * supplyIn + supplyOut * supplyOut;
        supplyOut += amountOut;
        if (supplyOut * supplyOut > invariant_) revert LibraryExcessiveOutputAmount();
        uint256 sqInSupply;
        unchecked {
            sqInSupply = (invariant_ - (supplyOut * supplyOut)) / 1e18;
        }
        amountIn = supplyIn - PRBMathUD60x18.sqrt(sqInSupply);
    }

    // Returns (Q1 * C / K, Q2 * C / K), where Q1^2 + Q2^2 = K^2 and K > 0
    // Returns (C / sqrt(2), C / sqrt(2)), where Q1 = Q2 = 0
    function issuanceAmounts(
        uint256 supply0,
        uint256 supply1,
        uint256 invariantIssuance
    ) internal pure returns (uint256 newAmount0, uint256 newAmount1) {
        uint256 squaredInvariant = supply0 * supply0 + supply1 * supply1;
        uint256 invariantAmount = PRBMathUD60x18.sqrt(squaredInvariant / 1e18);
        if (invariantAmount > 0) {
            // dQ1 = Q1 * C / K, dQ2 = Q2 * C / K
            newAmount0 = (supply0 * invariantIssuance) / invariantAmount;
            newAmount1 = (supply1 * invariantIssuance) / invariantAmount;
        } else {
            // dQ1 = dK / sqrt(2), dQ2 = dK / sqrt(2)
            newAmount0 = (invariantIssuance * 1e18) / PRBMathUD60x18.sqrt(2 * 1e18);
            newAmount1 = newAmount0;
        }
    }
}

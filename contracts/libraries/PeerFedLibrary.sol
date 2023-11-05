// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.20;

import { PRBMathUD60x18 } from "@prb/math/contracts/PRBMathUD60x18.sol";

library PeerFedLibrary {
    using PRBMathUD60x18 for uint256;

    // given some amount of asset A and pair of supplies, returns the equivalent amount of asset B
    function quote(uint256 amountA, uint256 supplyA, uint256 supplyB) internal pure returns (uint256 amountB) {
        require(supplyB > 0, "PeerFedLibrary: INSUFFICIENT_OUTPUT_SUPPLY");
        amountB = (amountA * supplyA) / supplyB;
    }

    // given an input amount of an asset and pair supplies, returns the maximum output amount of the other asset
    function getAmountOut(
        uint256 amountIn,
        uint256 supplyIn,
        uint256 supplyOut
    ) internal pure returns (uint256 amountOut) {
        require(amountIn > 0, "PeerFedLibrary: INSUFFICIENT_INPUT_AMOUNT");
        require(amountIn <= supplyIn, "PeerFedLibrary: EXCESSIVE_INPUT_AMOUNT");
        uint256 invariant_ = supplyIn * supplyIn + supplyOut * supplyOut;
        supplyIn -= amountIn;
        uint256 sqOutSupply;
        unchecked {
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
        require(amountOut > 0, "PeerFedLibrary: INSUFFICIENT_OUTPUT_AMOUNT");
        uint256 invariant_ = supplyIn * supplyIn + supplyOut * supplyOut;
        supplyOut += amountOut;
        require(supplyOut * supplyOut <= invariant_, "PeerFedLibrary: EXCESSIVE_OUTPUT_AMOUNT");
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
    ) internal pure returns (uint256 issuance1, uint256 issuance2) {
        uint256 squaredInvariant = supply0 * supply0 + supply1 * supply1;
        uint256 invariantAmount = PRBMathUD60x18.sqrt(squaredInvariant / 1e18);
        if (invariantAmount > 0) {
            // dQ1 = Q1 * C / K, dQ2 = Q2 * C / K
            issuance1 = (supply0 * invariantIssuance) / invariantAmount;
            issuance2 = (supply1 * invariantIssuance) / invariantAmount;
        } else {
            // dQ1 = dK / sqrt(2), dQ2 = dK / sqrt(2)
            issuance1 = (invariantIssuance * 1e18) / PRBMathUD60x18.sqrt(2 * 1e18);
            issuance2 = issuance1;
        }
    }
}

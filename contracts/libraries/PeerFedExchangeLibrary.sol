// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.15;

import "@prb/math/contracts/PRBMathUD60x18.sol";

// Based on UniswapV2Library
library PeerFedExchangeLibrary {
    using PRBMathUD60x18 for uint256;

    // returns sum-of-the-squares of two quantities
    function invariant(uint256 quantity1, uint256 quantity2) internal pure returns (uint256) {
        return (quantity1 * quantity1) + (quantity2 * quantity2);
    }

    // given an input amount of an asset and pair supplies, returns the maximum output amount of the other asset
    function getAmountOut(
        uint256 amountIn,
        uint256 supplyIn,
        uint256 supplyOut
    ) internal pure returns (uint256 amountOut) {
        require(amountIn > 0, "PeerFedLibrary: INSUFFICIENT_INPUT_AMOUNT");
        require(amountIn < supplyIn, "PeerFedLibrary: INSUFFICIENT_SUPPLY");
        uint256 invariant_ = invariant(supplyIn, supplyOut);
        supplyIn -= amountIn;
        uint256 sqOutSupply;
        unchecked {
            sqOutSupply = (invariant_ - (supplyIn * supplyIn)) / 1e18;
        }
        amountOut = PRBMathUD60x18.sqrt(sqOutSupply) - supplyOut;
    }

    // given an output amount of an asset and pair supplies, returns a required input amount of the other asset
    function getAmountIn(
        uint256 amountOut,
        uint256 supplyIn,
        uint256 supplyOut
    ) internal pure returns (uint256 amountIn) {
        require(amountOut > 0, "PeerFedLibrary: INSUFFICIENT_OUTPUT_AMOUNT");
        uint256 invariant_ = invariant(supplyIn, supplyOut);
        supplyOut += amountOut;
        require(supplyOut * supplyOut <= invariant_, "PeerFedLibrary: INSUFFICIENT_SUPPLY");
        uint256 sqInSupply;
        unchecked {
            sqInSupply = (invariant_ - (supplyOut * supplyOut)) / 1e18;
        }
        amountIn = supplyIn - PRBMathUD60x18.sqrt(sqInSupply);
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.15;

import "@prb/math/contracts/PRBMathUD60x18.sol";
import "./PeerFedExchangeLibrary.sol";

library PeerFedAuctionLibrary {
    using PRBMathUD60x18 for uint256;

    // Returns (Q1 * C / K, Q2 * C / K), where Q1^2 + Q2^2 = K^2 and K > 0
    // Returns (C / sqrt(2), C / sqrt(2)), where Q1 = Q2 = 0
    //
    // Proof:
    //  = (Q1 + dQ1)^2 + (Q2 + dQ2)^2
    //  = (Q1 + Q1 * C / K)^2 + (Q2 + Q2 * C / K)^2
    //  = Q1^2 * (1 + C / K)^2 + Q1^2 * (1 + C / K)^2
    //  = (Q1^2 + Q2^2) * (1 + C / K)^2
    //  = K^2 * (1 + C / K)^2
    //  = (K + C)^2
    //
    function issuanceAmounts(
        uint256 quantity1,
        uint256 quantity2,
        uint256 invariantIssuance
    ) internal pure returns (uint256 issuance1, uint256 issuance2) {
        uint256 invariantSquared = PeerFedExchangeLibrary.invariant(quantity1, quantity2);
        uint256 invariant = PRBMathUD60x18.sqrt(invariantSquared / 1e18);
        if (invariant > 0) {
            // dQ1 = Q1 * C / K, dQ2 = Q2 * C / K
            issuance1 = (quantity1 * invariantIssuance) / invariant;
            issuance2 = (quantity2 * invariantIssuance) / invariant;
        } else {
            // dQ1 = dK / sqrt(2), dQ2 = dK / sqrt(2)
            issuance1 = (invariantIssuance * 1e18) / PRBMathUD60x18.sqrt(2 * 1e18);
            issuance2 = issuance1;
        }
    }
}

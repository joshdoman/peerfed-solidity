// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.15;

interface IBondOrchestrator {
    /**
     * @dev Emitted when a redemption occurs.
     *
     * Note that `value` may be zero.
     */
    event Redemption(address indexed by, uint256 value);

    /**
     * @dev Emitted when a bond is created.
     *
     * Note that `redemptionRate` cannot be zero.
     */
    event BondCreated(address indexed by, address bond, uint256 redemptionRate);

    function currentBond() external view returns (address);

    function createNewBond(uint256 expiresAt, uint256 redemptionRate) external returns (address);

    function getBond(uint256 expiresAt) external view returns (address);

    function getRedemptionRate(address bond) external view returns (uint256);

    function isFinalized(address bond) external view returns (bool);

    function redeem(address bond) external returns (bool);

    function update(address bond) external returns (uint256);

    function finalize(address bond) external returns (uint256);

    function getOracle(address bond) external view returns (address);
}

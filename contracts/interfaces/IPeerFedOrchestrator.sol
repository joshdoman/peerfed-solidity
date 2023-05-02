// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.15;

interface IPeerFedOrchestrator {
    function mShare() external returns (address);

    function bShare() external returns (address);

    function mToken() external returns (address);

    function bToken() external returns (address);

    function converter() external returns (address);

    function interestRate() external view returns (uint256);

    function scaleFactor() external view returns (uint256);

    function updateScaleFactor() external returns (uint256);

    function mint() external;

    function mintTo(address to) external;

    function mintableAmount() external view returns (uint256, uint256, uint256, uint256);

    event ScaleFactorUpdated(address indexed sender, uint256 updatedScaleFactor, uint256 updatedAt);

    event Mint(uint64 indexed mintNumber, address to, uint256 mAmount, uint256 bAmount);
}

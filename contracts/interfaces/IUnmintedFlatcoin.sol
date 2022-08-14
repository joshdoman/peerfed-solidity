// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IUnmintedFlatcoin {
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);

    function totalSupply() external view returns (uint256);

    function balanceOf(address owner) external view returns (uint256);

    function initialize(address unmintedFlatcoin_, address flatcoinBond_) external;

    function mintFlatcoinsByOwner() external;

    function mintFlatcoins(
        address account1,
        address account2,
        uint256 incomePerSecond1,
        uint256 incomePerSecond2
    ) external;

    function resetLastMint(address account1, address account2) external;

    function resetMostRecentMint() external;
}

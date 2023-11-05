// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.20;

interface IPeerFed {
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );

    event Sync(uint256 reserve0, uint256 reserve1, uint128 accumulator);

    event AccumulatorReset();

    event Checkpoint(uint64 checkpointInterestRate, uint128 checkpointAccumulator);

    event Mint(address indexed to, uint256 newToken0, uint256 newToken1);

    // function token0() external view returns (address);

    // function token1() external view returns (address);

    // function getReserves() external view returns (uint256 reserve0, uint256 reserve1);

    // function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;

    // function skim(address to) external;

    // function sync() external;
}

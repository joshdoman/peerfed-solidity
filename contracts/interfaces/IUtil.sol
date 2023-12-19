// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

interface IUtil {
    struct Checkpoint {
        uint128 accumulator;
        uint64 interestRate;
        uint32 blocktime;
    }

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

    event NewCheckpoint(uint64 checkpointInterestRate, uint128 checkpointAccumulator);

    event Mint(address indexed to, uint256 newToken0, uint256 newToken1);

    event Bid(address indexed bidder, uint256 bid);

    function token0() external view returns (address);

    function token1() external view returns (address);

    function currentCheckpoint() external view returns (Checkpoint memory);

    function interestRate() external view returns (uint64);

    function latestAccumulator() external view returns (uint256);

    function quote() external view returns (uint256);

    function getReserves() external view returns (uint256 reserve0, uint256 reserve1, uint32 _blockTimestampLast);

    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;

    function skim(address to) external;

    function sync() external;

    function transfer(address payable to, uint256 utils, uint256 deadline) external payable returns (uint256 value);

    function swapExactTokensForTokens(
        bool input0,
        uint256 amountIn,
        uint256 amountOutMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountOut);

    function swapTokensForExactTokens(
        bool input0,
        uint256 amountOut,
        uint256 amountInMax,
        address to,
        uint256 deadline
    ) external returns (uint256 amountIn);

    function bid() external payable;

    function settle() external;

    function mintableAmount() external view returns (uint256 newToken0, uint256 newToken1);

    function invariantIssuance(uint32 mintNumber) external pure returns (uint256);

    error Locked();

    error Overflow();

    error InsufficientOutputAmount();

    error ExcessiveInputAmount();

    error InvalidTo();

    error InvalidK();

    error Expired();

    error InsufficientFunds();

    error TransferFailed();

    error InsufficientBid();

    error MintUnavailable();
}

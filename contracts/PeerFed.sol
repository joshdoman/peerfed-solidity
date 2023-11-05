// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { SwappableERC20 } from "./SwappableERC20.sol";
import { IPeerFed } from "./interfaces/IPeerFed.sol";
import { IPeerFedCallee } from "./interfaces/IPeerFedCallee.sol";
import { PeerFedLibrary } from "./libraries/PeerFedLibrary.sol";

contract PeerFed is IPeerFed {
    address public immutable token0;
    address public immutable token1;

    uint112 private reserve0;
    uint112 private reserve1;
    uint32 private blockTimestampLast;

    uint128 public accumulator = 1e18;
    uint128 public lastAccumulatorResetTimestamp;

    uint128 public checkpointAccumulator = 1e18;
    uint64 public checkpointInterestRate = 1e18;
    uint32 public checkpointTimestampLast;
    uint32 public checkpointCounter;

    uint128 public constant SECONDS_PER_YEAR = 31566909; // (365.242 days * 24 hours per day * 3600 seconds per hour)
    uint32 public constant SECONDS_PER_CHECKPOINT = 1800; // 30 minutes
    uint256 public constant INITIAL_ISSUANCE_PER_MINT = 150 * 1e18; // increase max token supply initally by 150 each mint
    uint32 public constant MINTS_PER_HALVING = 70000; // halve issuance amount approximately every 4 years

    uint8 private unlocked = 1;
    modifier lock() {
        require(unlocked == 1, "PeerFed: LOCKED");
        unlocked = 0;
        _;
        unlocked = 1;
    }

    constructor() {
        token0 = address(new SwappableERC20("PeerFed Tighten", "TIGHTEN"));
        token1 = address(new SwappableERC20("PeerFed Ease", "EASE"));
        blockTimestampLast = uint32(block.timestamp % 2 ** 32);
        checkpointTimestampLast = uint32(block.timestamp % 2 ** 32) - SECONDS_PER_CHECKPOINT;
    }

    /**
     * @notice Returns the current annualized interest rate w/ 18 decimals, where 1e18 = 100% (r = (A - B) / (A + B))
     * @notice If A is not greater than B, returns 0.
     */
    function interestRate() public view returns (uint64) {
        (uint256 _reserve0, uint256 _reserve1) = getReserves();
        if (_reserve0 > _reserve1) {
            return uint64(((_reserve0 - _reserve1) * 1e18) / (_reserve0 + _reserve1));
        } else {
            return 0;
        }
    }

    /**
     * @notice Returns the current price of BTC in "units" with 18 decimals
     * @notice Current price = accumulator / r, where r is the last checkpoint interest rate
     */
    function quote() public view returns (uint256) {
        uint32 blockTimestamp = uint32(block.timestamp % 2 ** 32);
        uint32 timeElapsed;
        unchecked {
            timeElapsed = blockTimestamp - blockTimestampLast; // overflow is desired
        }
        uint256 _interestRate = interestRate();
        uint256 _accumulator = accumulator;
        if (timeElapsed > 0 && _interestRate > 0) {
            _accumulator += (((_accumulator * _interestRate) / 1e18) * timeElapsed) / SECONDS_PER_YEAR;
        }
        return (_accumulator * 1e18) / checkpointInterestRate;
    }

    /** -------- Swap Logic -------- */

    /**
     * @notice Function to retrieve reserve{0,1}
     */
    function getReserves() public view returns (uint256 _reserve0, uint256 _reserve1) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
    }

    /**
     * @notice Internal helper function to update reserve{0,1}
     */
    function _update(uint256 supply0, uint256 supply1) private {
        require(supply0 <= type(uint112).max && supply1 <= type(uint112).max, "PeerFed: OVERFLOW");
        uint32 blockTimestamp = uint32(block.timestamp % 2 ** 32);
        uint32 timeElapsed;
        unchecked {
            timeElapsed = blockTimestamp - blockTimestampLast; // overflow is desired
        }
        uint128 _accumulator = accumulator;
        uint64 _interestRate = interestRate();
        if (timeElapsed > 0 && _interestRate > 0) {
            uint128 interest = (((_accumulator * _interestRate) / 1e18) * timeElapsed) / SECONDS_PER_YEAR;
            if (_accumulator < type(uint128).max - interest) {
                // add interest to accumulator
                _accumulator += interest;
            } else {
                // reset accumulator in case of overflow
                _accumulator = 1e18;
                lastAccumulatorResetTimestamp = uint128(block.timestamp % 2 ** 128);
                emit AccumulatorReset();
            }
            accumulator = _accumulator;
        }
        reserve0 = uint112(supply0);
        reserve1 = uint112(supply1);
        blockTimestampLast = blockTimestamp;
        emit Sync(supply0, supply1, _accumulator);
    }

    /**
     * @notice Low-level function for swapping between token{0,1}
     */
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) public {
        _swap(reserve0, reserve1, amount0Out, amount1Out, to, data);
    }

    /**
     * @notice Internal helper function for swapping between token{0,1}
     */
    function _swap(
        uint256 _reserve0,
        uint256 _reserve1,
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes memory data
    ) private lock {
        require(amount0Out > 0 || amount1Out > 0, "PeerFed: INSUFFICIENT_OUTPUT_AMOUNT");
        require(to != address(this), "PeerFed: INVALID_TO");

        if (amount0Out > 0) IERC20(token0).transfer(to, amount0Out);
        if (amount1Out > 0) IERC20(token1).transfer(to, amount1Out);
        if (data.length > 0) IPeerFedCallee(to).peerFedCall(msg.sender, amount0Out, amount1Out, data);

        uint256 amount0In;
        uint256 amount1In;
        {
            // scope for supply{0,1}
            uint256 supply0 = IERC20(token0).totalSupply();
            uint256 supply1 = IERC20(token1).totalSupply();

            amount0In = _reserve0 > supply0 ? _reserve0 - supply0 : 0;
            amount1In = _reserve1 > supply1 ? _reserve1 - supply1 : 0;

            require(
                supply0 * supply0 + supply1 * supply1 <= _reserve0 * _reserve0 + _reserve1 * _reserve1,
                "PeerFed: K"
            );

            _update(supply0, supply1);
        }

        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    // force supply to match reserves
    function skim(address to) external lock {
        uint256 amount0Out = reserve0 - IERC20(token0).totalSupply();
        uint256 amount1Out = reserve1 - IERC20(token1).totalSupply();
        if (amount0Out > 0) IERC20(token0).transfer(to, amount0Out);
        if (amount1Out > 0) IERC20(token1).transfer(to, amount1Out);
    }

    // force reserves to match supply
    function sync() external lock {
        _update(IERC20(token0).totalSupply(), IERC20(token1).totalSupply());
    }

    /** -------- Router -------- */

    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, "PeerFed: EXPIRED");
        _;
    }

    /**
     * @notice Allow this contract to receive the gas token
     */
    receive() external payable {}

    /**
     * @notice Transfers "units" of the gas token at the current quoted price
     */
    function transfer(
        address to,
        uint256 amount,
        uint256 deadline
    ) external payable ensure(deadline) returns (uint256 value) {
        uint256 currentPrice = quote();
        value = (amount * 1e18) / currentPrice;
        require(value >= msg.value, "PeerFed: INSUFFICIENT_FUNDS");
        (bool success, ) = to.call{ value: value }(new bytes(0));
        uint256 refund = msg.value - value;
        if (refund > 0) (success, ) = msg.sender.call{ value: refund }(new bytes(0));
        require(success, "PeerFed: TRANSFER_FAILED");
    }

    /**
     * @notice Swaps an exact amount of token{0,1} for a min amount of token{1,0}
     */
    function swapExactTokensForTokens(
        bool input0,
        uint256 amountIn,
        uint256 amountOutMin,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256 amountOut) {
        (uint256 _reserve0, uint256 _reserve1) = getReserves();

        if (input0) {
            SwappableERC20(token0).transferFromOverride(msg.sender, address(this), amountIn);
            amountOut = PeerFedLibrary.getAmountOut(amountIn, _reserve0, _reserve1);
        } else {
            SwappableERC20(token1).transferFromOverride(msg.sender, address(this), amountIn);
            amountOut = PeerFedLibrary.getAmountOut(amountIn, _reserve1, _reserve0);
        }
        require(amountOut >= amountOutMin, "PeerFed: INSUFFICIENT_OUTPUT_AMOUNT");

        if (input0) {
            _swap(_reserve0, _reserve1, 0, amountOut, to, new bytes(0));
        } else {
            _swap(_reserve0, _reserve1, amountOut, 0, to, new bytes(0));
        }
    }

    /**
     * @notice Swaps a max amount of token{0,1} for an exact amount of token {1,0}
     */
    function swapTokensForExactTokens(
        bool input0,
        uint256 amountOut,
        uint256 amountInMax,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256 amountIn) {
        (uint256 _reserve0, uint256 _reserve1) = getReserves();

        if (input0) {
            amountIn = PeerFedLibrary.getAmountIn(amountOut, _reserve0, _reserve1);
            SwappableERC20(token0).transferFromOverride(msg.sender, address(this), amountIn);
        } else {
            amountIn = PeerFedLibrary.getAmountIn(amountOut, _reserve1, _reserve0);
            SwappableERC20(token1).transferFromOverride(msg.sender, address(this), amountIn);
        }
        require(amountIn <= amountInMax, "PeerFed: EXCESSIVE_INPUT_AMOUNT");

        if (input0) {
            _swap(_reserve0, _reserve1, 0, amountOut, to, new bytes(0));
        } else {
            _swap(_reserve0, _reserve1, amountOut, 0, to, new bytes(0));
        }
    }

    /** -------- Mint & Checkpoint -------- */

    /**
     * @notice Mints available amount to address `to` and updates checkpoint counter and values
     */
    function mintTo(address to) public lock {
        (uint256 newToken0, uint256 newToken1, uint32 nextCheckpoint, uint32 timeElapsed) = _mintableAmount();
        require(timeElapsed > SECONDS_PER_CHECKPOINT, "PeerFed: MINT_UNAVAILABLE");
        checkpointCounter = nextCheckpoint;
        checkpointTimestampLast = uint32(block.timestamp % 2 ** 32);

        uint128 _accumulator = accumulator;
        uint64 _interestRate = interestRate();
        if (timeElapsed > 0 && _interestRate > 0) {
            uint128 interest = (((_accumulator * _interestRate) / 1e18) * timeElapsed) / SECONDS_PER_YEAR;
            accumulator = (_accumulator < type(uint128).max - interest) ? _accumulator + interest : 1e18;
        }

        uint128 _checkpointAccumulator = checkpointAccumulator;
        if (_checkpointAccumulator > _accumulator) {
            // A reset has occurred, set checkpoint accumulator to current accumulator
            checkpointAccumulator = _accumulator;
            emit Checkpoint(checkpointInterestRate, _accumulator);
        } else {
            uint64 averageInterestRate = uint64(
                ((((_accumulator - _checkpointAccumulator) * 1e18) / _checkpointAccumulator) * SECONDS_PER_YEAR) /
                    timeElapsed
            );
            if (averageInterestRate > 0) {
                // update checkpoint values if average interest rate non-zero
                checkpointInterestRate = averageInterestRate;
                checkpointAccumulator = _accumulator;
                emit Checkpoint(averageInterestRate, _accumulator);
            }
        }

        if (newToken0 > 0) IERC20(token0).transfer(to, newToken0);
        if (newToken1 > 0) IERC20(token1).transfer(to, newToken1);
        if (newToken0 > 0 || newToken1 > 0) {
            _update(IERC20(token0).totalSupply(), IERC20(token1).totalSupply());
            emit Mint(to, newToken0, newToken1);
        }
    }

    /**
     * @notice Returns the mintable amount of token{0,1}
     */
    function mintableAmount() public view returns (uint256 newToken0, uint256 newToken1) {
        (newToken0, newToken1, , ) = _mintableAmount();
    }

    /**
     * @notice Internal helper function that returns the mintable amount of token{0,1}, the next checkpoint,
     * and the time elapsed
     */
    function _mintableAmount()
        private
        view
        returns (uint256 newToken0, uint256 newToken1, uint32 nextCheckpoint, uint32 timeElapsed)
    {
        uint32 blockTimestamp = uint32(block.timestamp % 2 ** 32);
        unchecked {
            timeElapsed = blockTimestamp - checkpointTimestampLast; // overflow is desired
        }
        if (timeElapsed <= SECONDS_PER_CHECKPOINT) return (0, 0, 0, timeElapsed);

        uint32 _checkpointCounter = checkpointCounter;
        if (_checkpointCounter == type(uint32).max) {
            // Stop minting and return current counter
            return (0, 0, _checkpointCounter, timeElapsed);
        }

        uint256 supply0 = IERC20(token0).totalSupply();
        uint256 supply1 = IERC20(token1).totalSupply();
        (newToken0, newToken1) = PeerFedLibrary.issuanceAmounts(
            supply0,
            supply1,
            invariantIssuance(_checkpointCounter)
        );
        uint256 accruedMints = timeElapsed / SECONDS_PER_CHECKPOINT;
        uint256 maxAccruedMints = MINTS_PER_HALVING - (_checkpointCounter % MINTS_PER_HALVING);
        if (maxAccruedMints < accruedMints) accruedMints = maxAccruedMints;

        newToken0 *= accruedMints;
        newToken1 *= accruedMints;
        nextCheckpoint = _checkpointCounter + accruedMints < type(uint32).max
            ? uint32(_checkpointCounter + accruedMints)
            : type(uint32).max;
    }

    function invariantIssuance(uint32 mintNumber) public pure returns (uint256) {
        uint32 halvings = mintNumber / MINTS_PER_HALVING;
        return INITIAL_ISSUANCE_PER_MINT >> halvings;
    }

    /** ------ PeerFedLibrary ------ */

    function quote(uint256 amountA, uint256 supplyA, uint256 supplyB) external pure returns (uint256 amountB) {
        return PeerFedLibrary.quote(amountA, supplyA, supplyB);
    }

    function getAmountOut(
        uint256 amountIn,
        uint256 supplyIn,
        uint256 supplyOut
    ) external pure returns (uint256 amountOut) {
        amountOut = PeerFedLibrary.getAmountOut(amountIn, supplyIn, supplyOut);
    }

    function getAmountIn(
        uint256 amountOut,
        uint256 supplyIn,
        uint256 supplyOut
    ) external pure returns (uint256 amountIn) {
        amountIn = PeerFedLibrary.getAmountIn(amountOut, supplyIn, supplyOut);
    }
}

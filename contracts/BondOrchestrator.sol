// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.15;

import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";

import "./RebaseBond.sol";
import "./interfaces/IBondOrchestrator.sol";
import "./interfaces/IRebaseBond.sol";
import "./interfaces/IRebaseToken.sol";

contract BondOrchestrator is IBondOrchestrator {
    uint256 public constant MIN_TIME_BETWEEN_BONDS = 2 weeks;

    address public coin;
    address public token;
    address public factory;

    mapping(uint256 => address) public getBond;
    mapping(address => uint256) public getRedemptionRate;

    /**
     * @dev Returns TRUE once the bond's redemption rate at the time of expiry has been set.
     */
    mapping(address => bool) public isFinalized;

    mapping(uint64 => address) public getBondByIndex;
    uint64 public bondCount;
    uint64 private currentBondIndex;

    constructor(address token_, address factory_) {
        coin = msg.sender;
        token = token_;
        factory = factory_;
    }

    /**
     * @dev Returns the address of the nearest active bond.
     */
    function currentBond() public view returns (address) {
        return getBondByIndex[currentBondIndex];
    }

    /**
     * @dev Deploys a new bond with a given expiry and starting redemption rate.
     * Upon deployment, a UniswapV2 oracle is deployed with protocol created liquidity
     * at the redemption rate.
     *
     * Requirements:
     *
     * - bond must not exist
     * - redemption rate must be non-zero
     * - bond must expire at least `MIN_TIME_BETWEEN_BONDS` after the current bond expires
     */
    function createNewBond(uint256 expiresAt, uint256 redemptionRate) public returns (address) {
        require(getBond[expiresAt] == address(0), "Bond at that expiry already exists.");
        require(redemptionRate > 0, "Redemption rate must be non-zero.");

        address currentBond_ = currentBond();
        if (currentBond_ != address(0)) {
            // If a previous bond exists, verify that the new bond expires at
            // least `MIN_TIME_BETWEEN_BONDS` after the current bond expires.
            uint256 currentBondExpiry = IRebaseBond(currentBond_).expiresAt();
            require(expiresAt > (currentBondExpiry + MIN_TIME_BETWEEN_BONDS), "Bond expires too soon.");
        }

        // Create a bond with the given expiry and store a mapping of the expiry
        // to the bond address
        address bond = address(new RebaseBond(expiresAt));
        getBond[expiresAt] = bond;

        // Set the bond's redemption rate
        getRedemptionRate[bond] = redemptionRate;

        // Deploy a UniswapV2Pair to track the price of the bond
        uint256 initialBondAmount = 100 * 1e18;
        uint256 initialTokenAmount = (initialBondAmount * redemptionRate) / 1e18;
        deployOracle(bond, initialBondAmount, initialTokenAmount);

        // Add this bond to the bond index
        uint64 bondCount_ = bondCount;
        getBondByIndex[bondCount_] = bond;
        // If no current bond is set, make this the the current bond
        if (currentBond_ == address(0)) {
            currentBondIndex = bondCount_;
        }
        // Increase the bond count by one
        bondCount = bondCount_ + 1;

        emit BondCreated(msg.sender, bond, redemptionRate);
        return bond;
    }

    /**
     * @dev Deploys a UniswapV2Pair between the bond and the token and mints
     * a given amount of liquidity that is owned by the contract.
     */
    function deployOracle(
        address bond,
        uint256 bondAmount,
        uint256 tokenAmount
    ) internal returns (bool) {
        address token_ = token;
        address pair = IUniswapV2Factory(factory).createPair(bond, token_);

        IRebaseBond(bond).mint(pair, bondAmount);
        IRebaseToken(token_).mint(pair, tokenAmount);
        IUniswapV2Pair(pair).mint(address(this));
        return true;
    }

    /**
     * @dev Redeems the bond balance of `msg.sender` for the bond with the given
     * bond expiry and mints tokens at the bond's redemptionRate.
     *
     * Requirements:
     *
     * - bond must be finalized
     */
    function redeem(address bond) external returns (bool) {
        require(isFinalized[bond], "Bond has not been finalized.");

        uint256 redemptionRate = getRedemptionRate[bond];
        uint256 balance = IRebaseBond(bond).balanceOf(msg.sender);
        uint256 tokensDue = (redemptionRate * balance) / 1e18;
        IRebaseBond(bond).burn(msg.sender, balance);
        IRebaseToken(token).mint(msg.sender, tokensDue);

        emit Redemption(msg.sender, balance);
        return true;
    }

    /**
     * @dev Updates the bond's redemption rate to the current market price
     * on the UniswapV2 oracle.
     *
     * Returns the updated oracle price (in bonds)
     *
     * Requirements:
     *
     * - bond must not be finalized
     */
    function update(address bond) public returns (uint256) {
        require(!isFinalized[bond], "Bond has been finalized.");

        // TODO: Implement 1-hour TWAP

        address pair = getOracle(bond);
        (uint112 reserve0, uint112 reserve1, ) = IUniswapV2Pair(pair).getReserves();
        // UniswapV2Pair ordering is such that token0 strictly less than token1
        (uint112 bondReserve, uint112 tokenReserve) = bond < token ? (reserve0, reserve1) : (reserve1, reserve0);
        uint256 updatedRedemptionRate = (uint256(tokenReserve) * 1e18) / uint256(bondReserve);
        getRedemptionRate[bond] = updatedRedemptionRate;
        return updatedRedemptionRate;
    }

    /**
     * @dev Finalizes the redemption rate for the given bond at the market
     * price on the UniswapV2 pair at the time the bond expired.
     *
     * The bond contract blocks transfers to and from the UniswapV2 pair until
     * it has been finalized once it has expired. This guarantees the price on
     * Uniswap reflects the price at the time the bond expired. Finalizing
     * the bond will allow transfers to resume so LPs can access their positions.
     *
     * Requirements:
     *
     * - block.timestamp must be greater than or equal to the bond expiry
     * - bond must not be finalized
     */
    function finalize(address bond) external returns (uint256) {
        require(block.timestamp >= IRebaseBond(bond).expiresAt(), "Bond has not expired.");
        // Update and retrieve the final redemption rate of the bond
        uint256 finalRedemptionRate = update(bond);
        // Set the bond as finalized
        isFinalized[bond] = true;

        // Set the current bond to the next bond that hasn't been finalized
        uint64 currentBondIndex_ = currentBondIndex + 1;
        while (isFinalized[getBondByIndex[currentBondIndex_]]) {
            currentBondIndex_ += 1;
        }
        currentBondIndex = currentBondIndex_;
        return finalRedemptionRate;
    }

    /**
     * @dev Returns the address of the UniswapV2 pair for the provided bond.
     */
    function getOracle(address bond) public view returns (address) {
        address tokenA = bond;
        address tokenB = token;
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        // Source: https://docs.uniswap.org/protocol/V2/guides/smart-contract-integration/getting-pair-addresses
        address pair = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex"ff",
                            factory,
                            keccak256(abi.encodePacked(token0, token1)),
                            hex"96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f"
                        )
                    )
                )
            )
        );
        return pair;
    }
}

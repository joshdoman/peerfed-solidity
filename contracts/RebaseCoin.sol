// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";

import "hardhat/console.sol";

import "./interfaces/IRebaseToken.sol";
import "./interfaces/IRebaseToken.sol";

import "./BondOrchestrator.sol";
import "./interfaces/IRebaseBond.sol";
import "./RebaseToken.sol";

contract RebaseCoin is ERC20 {
    /**
     * @dev Emitted when a rebase occurs rebasing holdings by `rebaseFactor`.
     *
     * Note that `rebaseFactor` is represented with 18 decimals.
     */
    event Rebase(uint256 rebaseFactor);

    uint256 public coinsPerToken;
    uint256 public lastRebasedAt;

    RebaseToken public tokenContract;
    BondOrchestrator public bondOrchestrator;

    constructor(address uniswapFactory) ERC20("RebaseCoin", "RCN") {
        tokenContract = new RebaseToken();
        coinsPerToken = 1 * 1e18;

        uint256 initialSupply = 1000 * 1e18;
        _mint(msg.sender, initialSupply);

        bondOrchestrator = new BondOrchestrator(address(tokenContract), uniswapFactory);

        // Grant the bond orchestrator the ability to mint and burn tokens
        bytes32 minterBurnerRole = tokenContract.MINTER_BURNER_ROLE();
        tokenContract.grantRole(minterBurnerRole, address(bondOrchestrator));
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view override returns (uint256) {
        return (coinsPerToken * tokenContract.totalSupply()) / 1e18;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view override returns (uint256) {
        return (coinsPerToken * tokenContract.balanceOf(account)) / 1e18;
    }

    /**
     * @dev Rebases supply by increasing (or decreasing) `coinsPerToken` by
     * a given percentage.
     *
     * Emits a {Rebase} event indicating the rebase amount.
     *
     * Requirements:
     * - `rebaseFactor` is represented by 18 decimals. For example, if the
     * `rebaseFactor` is 102%, it should be represented as `1.02 * 1e18`
     * - `rebaseFactor` cannot be zero.
     */
    function rebase(uint256 rebaseFactor) external returns (bool) {
        require(rebaseFactor != 0, "Rebase factor is zero.");

        coinsPerToken = (coinsPerToken * rebaseFactor) / 1e18;
        lastRebasedAt = block.timestamp;

        emit Rebase(rebaseFactor);
        return true;
    }

    /**
     * Rebases supply by increasing (or decreasing) `coinsPerToken` by
     * pro rata for the expected redemption rate of the current bond.
     *
     * If the current bond has expired, finalizes the current bond and sets
     * `coinsPerToken` to the inverse of the bond's final redemption rate.
     *
     * Emits a {Rebase} event indicating the rebase amount.
     *
     * Requirements:
     * - `bondOrchestrator` must have a currently active bond
     */
    function rebase2() external returns (bool) {
        address currentBond = bondOrchestrator.currentBond();
        require(currentBond != address(0), "No currently active bond");

        uint256 coinsPerToken_ = coinsPerToken;
        uint256 newCoinsPerToken;

        uint256 expiresAt = IRebaseBond(currentBond).expiresAt();
        if (block.timestamp < expiresAt) {
            // If the current bond hasn't expired, update it to get the latest
            // price and increase (or decrease) the official `coinsPerToken`
            // per second between the last rebase and the bond's expiry
            uint256 expectedTokensPerCoin = bondOrchestrator.update(currentBond);
            uint256 expectedCoinsPerToken = 1e36 / expectedTokensPerCoin;
            uint256 lastRebasedAt_ = lastRebasedAt;

            // Flip ordering to ensure that underflow is not possible
            if (expectedCoinsPerToken > coinsPerToken_) {
                uint256 deltaPerSecond = (1e18 * (expectedCoinsPerToken - coinsPerToken_)) /
                    (expiresAt - lastRebasedAt_);
                newCoinsPerToken = coinsPerToken_ + (deltaPerSecond * (block.timestamp - lastRebasedAt_)) / 1e18;
            } else {
                uint256 deltaPerSecond = (1e18 * (coinsPerToken_ - expectedCoinsPerToken)) /
                    (expiresAt - lastRebasedAt_);
                newCoinsPerToken = coinsPerToken_ - (deltaPerSecond * (block.timestamp - lastRebasedAt_)) / 1e18;
            }
        } else {
            uint256 tokensPerCoin;
            if (bondOrchestrator.isFinalized(currentBond)) {
                // If the current bond is finalized, set `tokensPerCoin` to the
                // final redemption rate
                tokensPerCoin = bondOrchestrator.getRedemptionRate(currentBond);
            } else {
                // If the current bond has expired but has not been finalized,
                // finalize it and get the final redemption rate
                tokensPerCoin = bondOrchestrator.finalize(currentBond);
            }
            // Set `coinsPerToken` to the inverse of `tokensPerCoin`
            newCoinsPerToken = 1e36 / tokensPerCoin;
        }
        // Update `coinsPerToken` and `lastRebasedAt`
        coinsPerToken = newCoinsPerToken;
        lastRebasedAt = block.timestamp;

        uint256 rebaseFactor = (newCoinsPerToken * 1e18) / coinsPerToken_;
        emit Rebase(rebaseFactor);
        return true;
    }

    /**
     * @dev Moves `amount` of tokens from `from` to `to`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     */
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(from, to, amount);

        uint256 tokenAmount = (amount * 1e18) / coinsPerToken;
        tokenContract.transferFromOverride(from, to, tokenAmount);

        emit Transfer(from, to, amount);

        _afterTokenTransfer(from, to, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal override {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        uint256 tokenAmount = (amount * 1e18) / coinsPerToken;
        tokenContract.mint(account, tokenAmount);

        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal override {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 tokenAmount = (amount * 1e18) / coinsPerToken;
        tokenContract.burn(account, tokenAmount);

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
    }
}

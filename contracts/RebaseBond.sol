// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.15;

// import "@openzeppelin/contracts/utils/Strings.sol";

import "./interfaces/IBondOrchestrator.sol";
import "./external/NamelessERC20.sol";

contract RebaseBond is NamelessERC20 {
    uint256 public expiresAt;

    address private bondOrchestrator;

    constructor(uint256 expiresAt_) {
        expiresAt = expiresAt_;
        bondOrchestrator = msg.sender;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public pure override returns (string memory) {
        // TODO: Replace `bondName` with `yyyy-mm-dd` expiry
        string memory bondName = ""; //Strings.toHexString(expiresAt);
        return string.concat("RebaseBond ", bondName);
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public pure override returns (string memory) {
        // TODO: Replace `bondName` with `yyyy-mm-dd` expiry
        string memory bondName = ""; //Strings.toHexString(expiresAt);
        return string.concat("RBND", bondName);
    }

    /**
     * @dev Mints `amount` tokens to `account`
     *
     * See {ERC20-_mint}.
     *
     * Requirements:
     *
     * - the caller must be the contract owner.
     */
    function mint(address account, uint256 amount) external {
        require(bondOrchestrator == msg.sender);
        _mint(account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`
     *
     * See {ERC20-_burn}.
     *
     * Requirements:
     *
     * - the caller must be the contract owner.
     */
    function burn(address account, uint256 amount) external {
        require(bondOrchestrator == msg.sender);
        _burn(account, amount);
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
        // Once the bond has expired, block transfers to or from the oracle
        // until the bond's redemption rate has been finalized. This prevents
        // the redemption rate from changing after the bond has expired without
        // permanently locking LPs into their positions.
        if (block.timestamp >= expiresAt) {
            address pair = IBondOrchestrator(bondOrchestrator).getOracle(address(this));
            if (from == pair || to == pair) {
                bool finalized = IBondOrchestrator(bondOrchestrator).isFinalized(address(this));
                require(finalized, "Bond has expired and is not finalized.");
            }
        }
        super._transfer(from, to, amount);
    }
}

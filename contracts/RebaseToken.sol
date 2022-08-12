// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.15;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

import "./interfaces/IRebaseToken.sol";

contract RebaseToken is ERC20, AccessControl, IRebaseToken {
    bytes32 public constant MINTER_BURNER_ROLE = keccak256("MINTER_BURNER_ROLE");
    bytes32 public constant TRANSFER_ROLE = keccak256("TRANSFER_ROLE");

    constructor() ERC20("Rebase Token", "RTKN") {
        // Grant the contract deployer (RebaseCoin.sol) the default admin role:
        // it will be able to grant and revoke any roles.
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        // Grant the contract deployer (RebaseCoin.sol) the `MINTER_BURNER_ROLE`
        // so that it can mint and burn tokens on behalf of users.
        _grantRole(MINTER_BURNER_ROLE, msg.sender);
        // Grant the contract deployer (RebaseCoin.sol) the `TRANSFER_ROLE`
        // so that it can transfer tokens on behalf of users.
        _grantRole(TRANSFER_ROLE, msg.sender);
    }

    /**
     * @dev Allows the RebaseCoin contract to transfer tokens between any two
     * addresses on their behalf.
     *
     * Requirements:
     *
     * - `from` and `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     * - the caller must be the contract owner.
     */
    function transferFromOverride(
        address from,
        address to,
        uint256 amount
    ) external onlyRole(TRANSFER_ROLE) returns (bool) {
        _transfer(from, to, amount);
        return true;
    }

    /**
     * @dev Mints `amount` tokens to `account`
     *
     * See {ERC20-_mint}.
     *
     * Requirements:
     *
     * - the caller must be the MINTER_BURNER_ROLE.
     */
    function mint(address account, uint256 amount) external onlyRole(MINTER_BURNER_ROLE) {
        _mint(account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`
     *
     * See {ERC20-_burn}.
     *
     * Requirements:
     *
     * - the caller must have the MINTER_BURNER_ROLE.
     */
    function burn(address account, uint256 amount) external onlyRole(MINTER_BURNER_ROLE) {
        _burn(account, amount);
    }
}

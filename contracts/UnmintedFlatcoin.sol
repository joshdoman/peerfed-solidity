// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.15;

import "./interfaces/IFlatcoin.sol";
import "./interfaces/IFlatcoinBond.sol";
import "./interfaces/IUnmintedFlatcoin.sol";

import "hardhat/console.sol";

contract UnmintedFlatcoin is IUnmintedFlatcoin {
    string public constant name = "UnmintedFlatcoin";
    string public constant symbol = "uFTC";
    uint8 public constant decimals = 18;

    address public flatcoin;
    address public flatcoinBond;

    uint256 private _totalSupplyAfterMostRecentMint;
    uint256 private _mostRecentMint;

    mapping(address => uint256) private _lastMint;

    /**
     * @dev Initializes the contract with the Flatcoin contract address
     *
     * Requirement: `flatcoin` contract address not already set
     */
    function initialize(address flatcoin_, address flatcoinBond_) external {
        require(flatcoin == address(0), "Initialized already");
        flatcoin = flatcoin_;
        flatcoinBond = flatcoinBond_;
    }

    function totalSupply() public view returns (uint256) {
        uint256 totalIncomePerSecond = IFlatcoinBond(flatcoinBond).totalIncomePerSecond();
        uint256 newSupply = totalIncomePerSecond * (block.timestamp - _mostRecentMint) / 1e18;
        return _totalSupplyAfterMostRecentMint + newSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        uint256 incomePerSecond = IFlatcoinBond(flatcoinBond).incomePerSecond(account);
        uint256 lastMint = _lastMint[account];
        return incomePerSecond * (block.timestamp - lastMint) / 1e18;
    }

    function mintFlatcoinsByOwner() external {
        uint256 incomePerSecond = IFlatcoinBond(flatcoinBond).incomePerSecond(msg.sender);
        _mintFlatcoins(msg.sender, incomePerSecond);
        _lastMint[msg.sender] = block.timestamp;
        _mostRecentMint = block.timestamp;
    }

    function mintFlatcoins(
        address account1,
        address account2,
        uint256 incomePerSecond1,
        uint256 incomePerSecond2
    ) external {
        require(msg.sender == flatcoinBond, "Forbidden");
        if (account1 != address(0)) {
            _mintFlatcoins(account1, incomePerSecond1);
        }
        if (account2 != address(0)) {
            _mintFlatcoins(account2, incomePerSecond2);
        }
        // Will reset the income timer later in `flatcoinBond`s `_afterTokenTransfer` hook
    }

    function _mintFlatcoins(address account, uint256 incomePerSecond) internal {
        uint256 lastMint = _lastMint[account];
        if (lastMint != 0) {
            // Mint tokens received since `lastMint` given account's `incomePerSecond`
            uint256 mintAmount = incomePerSecond * (block.timestamp - lastMint) / 1e18;
            IFlatcoin(flatcoin).mintUnmintedFlatcoins(account, mintAmount);

            uint256 currentSupply = totalSupply();
            // Reduce current supply by the mint amount
            _totalSupplyAfterMostRecentMint = currentSupply - mintAmount;
        }
    }

    function resetLastMint(address account1, address account2) external {
        require(msg.sender == flatcoinBond, "Forbidden");
        if (account1 != address(0)) {
            _lastMint[account1] = block.timestamp;
        }
        if (account2 != address(0)) {
            _lastMint[account2] = block.timestamp;
        }
    }

    function resetMostRecentMint() external {
        require(msg.sender == flatcoinBond, "Forbidden");
        _mostRecentMint = block.timestamp;
    }
}

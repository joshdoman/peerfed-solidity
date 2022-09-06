// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.15;

import "./BaseERC20Share.sol";
import "./ScaledERC20.sol";
import "./interfaces/IExchangeableERC20.sol";
import "./interfaces/IStablecashFactory.sol";

contract StablecashFactory is IStablecashFactory {
    address public mShare;
    address public bShare;

    address public mToken;
    address public bToken;

    uint256 public timeOfLastExchange;
    uint256 private _initialScaleFactor = 1e18;

    constructor() {
        // Create contracts for shares of money and shares of bonds
        mShare = address(new BaseERC20Share("Stablecash Share", "shSCH"));
        bShare = address(new BaseERC20Share("Stablecash Bond Share", "shBSCH"));
        // Set this contract as the factory for `mShare` and `bShare`
        IExchangeableERC20(mShare).setFactory(address(this));
        IExchangeableERC20(bShare).setFactory(address(this));
        // Create contracts for money and bonds
        mToken = address(new ScaledERC20("Stablecash", "SCH", address(this), mShare));
        bToken = address(new ScaledERC20("Stablecash Bond", "BSCH", address(this), bShare));
        // Set time of last exchange to current timestamp
        timeOfLastExchange = block.timestamp;
    }

    function scaleFactor() external view returns (uint256) {
        return _initialScaleFactor;
    }

    function exchange(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        address to
    ) external {}
}

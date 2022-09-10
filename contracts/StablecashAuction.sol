// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.15;

import "./interfaces/IStablecashOrchestrator.sol";
import "./interfaces/IBaseERC20.sol";

contract StablecashAuction {
    address public orchestrator;
    address public mShare;
    address public bShare;

    constructor(
        address orchestrator_,
        address mShare_,
        address bShare_
    ) {
        orchestrator = orchestrator_;
        mShare = mShare_;
        bShare = bShare_;
        // Set this address as the exchange
        IBaseERC20(mShare_).setAuction(address(this));
        IBaseERC20(bShare_).setAuction(address(this));
    }
}

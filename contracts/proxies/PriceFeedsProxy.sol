// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.26;

import "./Proxy2Step.sol";

contract PriceFeedsProxy is Proxy2Step {

    constructor(address impl_) Proxy2Step(impl_) {}

    receive() external override payable {
        (bool success,) = implementation.delegatecall("");
        require(success, "subcall failed");
    }
}

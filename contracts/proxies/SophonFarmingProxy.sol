// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import "./Proxy2Step.sol";

contract SophonFarmingProxy is Proxy2Step {

    constructor(address impl_) Proxy2Step(impl_) {}

    receive() external override payable {
        (bool success,) = implementation.delegatecall("");
        require(success, "subcall failed");
    }
}

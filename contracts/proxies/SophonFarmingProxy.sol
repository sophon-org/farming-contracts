// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import "./Proxy2Step.sol";

contract SophonFarmingProxy is Proxy2Step {
    constructor(address impl_) Proxy2Step(impl_) {}
}

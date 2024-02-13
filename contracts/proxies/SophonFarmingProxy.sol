// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import "./Proxy.sol";

contract SophonFarmingProxy is Proxy {
    constructor(address impl_) Proxy(impl_) {}
}

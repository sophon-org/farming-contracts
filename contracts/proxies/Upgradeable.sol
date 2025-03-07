// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Upgradeable is Ownable {
    address public implementation;

    constructor() Ownable(msg.sender) {}

    function replaceImplementation(address impl_) public onlyOwner {
        implementation = impl_;
    }
}

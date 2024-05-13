// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Upgradeable is Ownable {
    address public implementation;

    constructor() Ownable(msg.sender) {}

    function replaceImplementation(address impl_) public onlyOwner {
        implementation = impl_;
    }
}

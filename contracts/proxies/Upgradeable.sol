// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Ownable} from "@openzeppelin/access/Ownable.sol";

contract Upgradeable is Ownable {
    address public implementation;

    constructor() Ownable(msg.sender) {}
}

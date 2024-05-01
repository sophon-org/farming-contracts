// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import "@openzeppelin/contracts/access/Ownable2Step.sol";

event ReplaceImplementationStarted(address indexed previousImplementation, address indexed newImplementation);
event ReplaceImplementation(address indexed previousImplementation, address indexed newImplementation);
error Unauthorized();

contract Upgradeable2Step is Ownable2Step {
    address public pendingImplementation;
    address public implementation;

    constructor() Ownable(msg.sender) {}

    // called on an inheriting proxy contract
    function replaceImplementation(address impl_) public onlyOwner {
        pendingImplementation = impl_;
        emit ReplaceImplementationStarted(implementation, impl_);
    }

    // called from an inheriting implementation contract
    function acceptImplementation() public {
        if (msg.sender != pendingImplementation) {
            revert OwnableUnauthorizedAccount(msg.sender);
        }
        emit ReplaceImplementation(implementation, msg.sender);
        delete pendingImplementation;
        implementation = msg.sender;
    }

    // called on an inheriting implementation contract
    function becomeImplementation(Upgradeable2Step proxy) public {
        if (msg.sender != proxy.owner()) {
            revert Unauthorized();
        }
        proxy.acceptImplementation();
    }
}

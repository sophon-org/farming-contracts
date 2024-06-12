// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import "./Upgradeable.sol";

contract Proxy is Upgradeable {

    constructor(address impl_) {
        replaceImplementation(impl_);
    }

    fallback() external payable {
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), sload(implementation.slot), 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }
}

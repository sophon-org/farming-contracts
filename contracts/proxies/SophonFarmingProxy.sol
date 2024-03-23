// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import "./Proxy2Step.sol";

contract SophonFarmingProxy is Proxy2Step {

    address public immutable weth;

    constructor(address impl_) Proxy2Step(impl_) {
        (bool success, bytes memory returnData) = impl_.delegatecall(abi.encodeWithSignature("weth()"));
        require(success, "setup failed");
        weth = abi.decode(returnData, (address));
    }

    fallback() external override payable {
        if (msg.sender == weth) {
            return;
        }
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

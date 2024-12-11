// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {IL1SharedBridge} from "../farm/interfaces/bridge/IL1SharedBridge.sol";

contract MockBridge {

    struct L2TransactionRequestTwoBridgesOuter {
        uint256 chainId;
        uint256 mintValue;
        uint256 l2Value;
        uint256 l2GasLimit;
        uint256 l2GasPerPubdataByteLimit;
        address refundRecipient;
        address secondBridgeAddress;
        uint256 secondBridgeValue;
        bytes secondBridgeCalldata;
    }

    function requestL2TransactionTwoBridges(
        L2TransactionRequestTwoBridgesOuter calldata _request
    ) external payable returns (bytes32 canonicalTxHash) {
        return bytes32(0);
    }

    function sharedBridge() external view returns (IL1SharedBridge) {
        return IL1SharedBridge(address(0x0123456789012345678901234567890123456789));
    }
}
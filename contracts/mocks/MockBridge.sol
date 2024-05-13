// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {BridgeLike} from "../farm/SophonFarmingState.sol";

contract MockBridge is BridgeLike {

    function deposit(
        address _l2Receiver,
        address _l1Token,
        uint256 _amount,
        uint256 _l2TxGasLimit,
        uint256 _l2TxGasPerPubdataByte,
        address _refundRecipient
    ) external payable returns (bytes32 l2TxHash) {
        // Future bridge implementation

        _l2Receiver;
        _l1Token;
        _amount;
        _l2TxGasLimit;
        _l2TxGasPerPubdataByte;
        _refundRecipient;

        return bytes32(0);
    }
}
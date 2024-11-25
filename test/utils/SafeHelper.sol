// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Test, console, Vm} from "forge-std/Test.sol";

interface ISafe {
    enum Operation {
        Call,
        DelegateCall
    }

    /** @notice Executes a `operation` {0: Call, 1: DelegateCall}} transaction to `to` with `value` (Native Currency)
     *          and pays `gasPrice` * `gasLimit` in `gasToken` token to `refundReceiver`.
     * @dev The fees are always transferred, even if the user transaction fails.
     *      This method doesn't perform any sanity check of the transaction, such as:
     *      - if the contract at `to` address has code or not
     *      - if the `gasToken` is a contract or not
     *      It is the responsibility of the caller to perform such checks.
     * @param to Destination address of Safe transaction.
     * @param value Ether value of Safe transaction.
     * @param data Data payload of Safe transaction.
     * @param operation Operation type of Safe transaction.
     * @param safeTxGas Gas that should be used for the Safe transaction.
     * @param baseGas Gas costs that are independent of the transaction execution(e.g. base transaction fee, signature check, payment of the refund)
     * @param gasPrice Gas price that should be used for the payment calculation.
     * @param gasToken Token address (or 0 if ETH) that is used for the payment.
     * @param refundReceiver Address of receiver of gas payment (or 0 if tx.origin).
     * @param signatures Signature data that should be verified.
     *                   Can be packed ECDSA signature ({bytes32 r}{bytes32 s}{uint8 v}), contract signature (EIP-1271) or approved hash.
     * @return success Boolean indicating transaction's success.
     */
    function execTransaction(
        address to,
        uint256 value,
        bytes calldata data,
        Operation operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address payable refundReceiver,
        bytes memory signatures
    ) external payable returns (bool success);

    function getOwners() external view returns (address[] memory);
    function getThreshold() external view returns (uint256);
    function isOwner(address owner) external view returns (bool);
    function domainSeparator() external view returns (bytes32);
    function nonce() external view returns (uint256);

    function getTransactionHash(
        address to,
        uint256 value,
        bytes calldata data,
        Operation operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address refundReceiver,
        uint256 _nonce
    ) external view returns (bytes32);

}

contract SafeTools is Test {
    bytes32 private constant SAFE_MSG_TYPEHASH = 0x60b3cbf8b4a223d68d641b3b6ddf9a298e7f33710cf3d3a9d1146b5a6150fbca;

    function getMessageHash(bytes memory message, address safeAddress) public view returns (bytes32) {
        bytes32 safeMessageHash = keccak256(abi.encode(SAFE_MSG_TYPEHASH, keccak256(message)));
        return keccak256(abi.encodePacked(bytes1(0x19), bytes1(0x01), ISafe(payable(safeAddress)).domainSeparator(), safeMessageHash));
    }

    struct STtx {
        uint8 op;
        address to;
        uint256 value;
        bytes data;
    }

    function encodeTx(STtx memory _tx) internal returns (bytes memory) {
        uint256 dataLength = _tx.data.length;
        return abi.encodePacked(_tx.op, _tx.to, _tx.value, dataLength, _tx.data);
    }

    function encodeTxs(STtx[] memory _txs) internal returns (bytes memory) {
        bytes memory encodedTxs;
        for (uint256 i = 0; i < _txs.length; i++) {
            encodedTxs = abi.encodePacked(encodedTxs, encodeTx(_txs[i]));
        }
        encodedTxs = abi.encodeWithSignature("multiSend(bytes)", encodedTxs);
        return encodedTxs;
    }

    /*
    Safe.sol storage layout
        | Name                       | Type                                            | Slot | Offset | Bytes | Contract                |
        |----------------------------|-------------------------------------------------|------|--------|-------|-------------------------|
        | singleton                  | address                                         | 0    | 0      | 20    | contracts/Safe.sol:Safe |
        | modules                    | mapping(address => address)                     | 1    | 0      | 32    | contracts/Safe.sol:Safe |
        | owners                     | mapping(address => address)                     | 2    | 0      | 32    | contracts/Safe.sol:Safe |
        | ownerCount                 | uint256                                         | 3    | 0      | 32    | contracts/Safe.sol:Safe |
        | threshold                  | uint256                                         | 4    | 0      | 32    | contracts/Safe.sol:Safe |
        | nonce                      | uint256                                         | 5    | 0      | 32    | contracts/Safe.sol:Safe |
        | _deprecatedDomainSeparator | bytes32                                         | 6    | 0      | 32    | contracts/Safe.sol:Safe |
        | signedMessages             | mapping(bytes32 => uint256)                     | 7    | 0      | 32    | contracts/Safe.sol:Safe |
        | approvedHashes             | mapping(address => mapping(bytes32 => uint256)) | 8    | 0      | 32    | contracts/Safe.sol:Safe |
    */

    // Safe stores all owners in a mapping with a starting value
    // SENTINEL_OWNERS (0x1) --> owner1 (0x111...111) --> owner2 (0x222...222) --> owner3 (0x333...333) --> SENTINEL_OWNERS (0x1)
    function spoofSigner(address signer, address safeAddress) internal {
        // Set the first owner to the SENTINEL_OWNERS address
        address SENTINEL_OWNERS = address(0x1);
        address owner = address(0x1);

        do {
            bytes32 slot = keccak256(abi.encode(owner, 2));
            owner = address(uint160(uint(vm.load(safeAddress, slot))));
            if (owner == SENTINEL_OWNERS) {
                vm.store(safeAddress, slot, bytes32(uint(uint160(signer))));
                vm.store(safeAddress, keccak256(abi.encode(signer, 2)), bytes32(uint(uint160(SENTINEL_OWNERS))));
            }
        } while(owner != SENTINEL_OWNERS);

        bytes32 one = bytes32(uint256(1));
        bytes32 slot3 = bytes32(uint256(3));
        bytes32 slot4 = bytes32(uint256(4));

        // Increase owner count by 1
        uint256 ownerCount = uint256(vm.load(safeAddress, slot3));
        vm.store(safeAddress, slot3, bytes32(ownerCount + 1));

        // Lower threshold to 1
        vm.store(safeAddress, slot4, one);
    }
}
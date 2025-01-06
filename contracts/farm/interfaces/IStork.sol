// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.26;

interface IStork {
    struct TemporalNumericValue {
        // slot 1
        // nanosecond level precision timestamp of latest publisher update in batch
        uint64 timestampNs; // 8 bytes
        // should be able to hold all necessary numbers (up to 6277101735386680763835789423207666416102355444464034512895)
        int192 quantizedValue; // 8 bytes
    }

    function getTemporalNumericValueV1(bytes32 id) external view returns (TemporalNumericValue memory value);
    function getTemporalNumericValueUnsafeV1(bytes32 id) external view returns (TemporalNumericValue memory value);
}

// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.26;

interface ILPPool {
    function token0() external view returns (address);
    function token1() external view returns (address);
}

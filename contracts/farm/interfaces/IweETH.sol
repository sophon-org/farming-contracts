// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.26;

interface IweETH {
    function wrap(uint256 _eETHAmount) external returns (uint256);
}

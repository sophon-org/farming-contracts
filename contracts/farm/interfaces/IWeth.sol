// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.24;

interface IWeth {
    function deposit() external payable;
    function withdraw(uint256 wad) external;
    function transfer(address to, uint256 value) external returns (bool);
}

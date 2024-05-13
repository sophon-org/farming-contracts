// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.25;

interface IeETHLiquidityPool {
    function deposit(address _referral) external payable returns (uint256);
}

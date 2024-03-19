// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.24;

interface IstETH {
    function submit(address _referral) external payable returns (uint256);
}

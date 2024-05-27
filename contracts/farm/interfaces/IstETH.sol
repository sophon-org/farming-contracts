// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.25;

interface IstETH {
    function submit(address _referral) external payable returns (uint256);
    function getSharesByPooledEth(uint256 _ethAmount) external view returns (uint256);
}

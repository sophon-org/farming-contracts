// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.26;

interface IstETH {
    function submit(address _referral) external payable returns (uint256);
    function getSharesByPooledEth(uint256 _ethAmount) external view returns (uint256);
    function getPooledEthByShares(uint256 _sharesAmount) external view returns (uint256);
}

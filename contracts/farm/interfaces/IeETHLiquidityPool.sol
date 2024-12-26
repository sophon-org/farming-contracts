// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.26;

interface IeETHLiquidityPool {
    function deposit(address _referral) external payable returns (uint256);
    function sharesForAmount(uint256 _amount) external view returns (uint256);
    function amountForShare(uint256 _share) external view returns (uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

interface IStETH {
    function submit(address _referral) external payable returns (uint256);
    function getSharesByPooledEth(uint256 ethAmount) external view returns (uint256);

    function getPooledEthByShares(uint256 sharesAmount) external view returns (uint256);

    function transferShares(address to, uint256 amount) external;
    function transferSharesFrom(
        address _sender,
        address _recipient,
        uint256 _sharesAmount
    ) external returns (uint256);
    function sharesOf(address _account) external view returns (uint256);
}
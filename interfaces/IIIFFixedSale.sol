// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

interface IIIFFixedSale {
    function paymentToken() external view returns (address);
    function salePrice() external view returns (uint256);
    function maxTotalPayment() external view returns (uint256);
    function saleTokenPurchased() external view returns (uint256);
    function minTotalPayment() external view returns (uint256);
    function maxTotalPurchasable() external view returns (uint256);
    function isPurchaseHalted() external view returns (bool);
    function purchaserCount() external view returns (uint256);
    function paymentReceived(address user) external view returns (uint256);
    function totalPaymentReceived() external view returns (uint256);
}

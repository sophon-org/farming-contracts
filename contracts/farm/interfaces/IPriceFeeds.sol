// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.26;

interface IPriceFeeds {

    event SetPriceFeedData(FeedType feedType, bytes32 feedHash, uint256 staleSeconds);

    error ZeroAddress();
    error CountMismatch();
    error InvalidCall();
    error InvalidType();
    error TypeMismatch();
    error InvalidStaleSeconds();

    enum FeedType {
        Undefined,
        Stork
    }

    struct StorkData {
        bytes32 feedHash;
        uint256 staleSeconds;
        FeedType feedType;
    }

    function getPrice(address poolToken_) external view returns (uint256);

    function getStorkPrice(bytes32 feedHash_, uint256 staleSeconds_) external view returns (uint256);

    function setStorkFeedsData(address farmContract, address[] memory poolTokens_, StorkData[] memory poolTokenDatas_) external;
}

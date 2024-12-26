// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.26;

import "./interfaces/IStork.sol";
import "./interfaces/IPriceFeeds.sol";
import "../proxies/Upgradeable2Step.sol";

contract PriceFeeds is IPriceFeeds, Upgradeable2Step {

    mapping(address => StorkData) public storkData;

    IStork public immutable stork;

    constructor(address stork_) {
        if (stork_ == address(0)) revert ZeroAddress();
        stork = IStork(stork_);
    }

    function getPrice(address poolToken_) external view returns (uint256) {
        StorkData storage token0Data = storkData[poolToken_];
        if (token0Data.feedType == FeedType.Stork) {
            // handle stork feed
            return getStorkPrice(token0Data.feedHash, token0Data.staleSeconds);
        } else {
            revert InvalidType();
        }
    }

    function getStorkPrice(bytes32 feedHash_, uint256 staleSeconds_) public view returns (uint256) {
        if (feedHash_ == 0) {
            // price feed not set
            return 0;
        }

        IStork.TemporalNumericValue memory storkValue = stork.getTemporalNumericValueUnsafeV1(feedHash_);

        if (staleSeconds_ != 0 && block.timestamp - (storkValue.timestampNs / 1000000000) > staleSeconds_) {
            // stale price
            return 0;
        }

        if (storkValue.quantizedValue <= 0) {
            // invalid price
            return 0;
        }
        
        return uint256(uint192(storkValue.quantizedValue));
    }

    // zero feedHash allowed, which would block updates to the pool
    function setStorkFeedsData(address farmContract, address[] memory poolTokens_, StorkData[] memory poolTokenDatas_) external onlyOwner {
        if (farmContract == address(0)) {
            revert ZeroAddress();
        }
        if (poolTokens_.length != poolTokenDatas_.length) {
            revert CountMismatch();
        }

        (bool success, ) = farmContract.call(abi.encodeWithSignature("massUpdatePools()"));
        if (!success) {
            revert InvalidCall();
        }

        for (uint256 i; i < poolTokens_.length; i++) {
            if (poolTokenDatas_[i].feedType != FeedType.Stork) {
                revert InvalidType();
            }
            if (poolTokenDatas_[i].staleSeconds == 0) {
                revert InvalidStaleSeconds();
            }

            StorkData storage tokenData = storkData[poolTokens_[i]];

            FeedType currentType = tokenData.feedType;
            if (currentType == FeedType.Undefined) {
                tokenData.feedType = poolTokenDatas_[i].feedType;
            } else {
                if (poolTokenDatas_[i].feedType != currentType) {
                    // we can't change the FeedType once it is set
                    revert TypeMismatch();
                }
            }

            tokenData.feedHash = poolTokenDatas_[i].feedHash;
            tokenData.staleSeconds = poolTokenDatas_[i].staleSeconds;

            emit SetPriceFeedData(poolTokenDatas_[i].feedType, poolTokenDatas_[i].feedHash, poolTokenDatas_[i].staleSeconds);
        }
    }
}

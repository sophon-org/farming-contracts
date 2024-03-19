// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.24;

import "@chainlink/interfaces/AggregatorV3Interface.sol";
import "../interfaces/IsDAI.sol";

contract SDaiPriceFeedAdapter {

    error InvalidPriceFeedDecimals();

    IsDAI public immutable sDAI;
    AggregatorV3Interface public immutable daiPriceFeed;

    /**
     * @return uint The scaled price in USD
     */
    function latestAnswer()
        public
        view
        returns (int256) {

        (
            ,
            int rate, // DAI/USD rate
            ,
            uint updatedAt,

        ) = daiPriceFeed.latestRoundData();

        return rate * int256(sDAI.convertToAssets(1e18)) / 1e18; // scale to 8 decimals places like Chainlink
    }

    /**
     * @return roundId always 0
     *         answer The scaled price in USD
     *         startedAt always 0
     *         updatedAt always block.timestamp
     *         answeredInRound always 0
     */
    function latestRoundData()
        public
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        ) {
        return (0, latestAnswer(), 0, block.timestamp, 0);
    }

    constructor(IsDAI sDAI_, AggregatorV3Interface daiPriceFeed_) {
        if (daiPriceFeed_.decimals() != 8) {
            revert InvalidPriceFeedDecimals();
        }
        
        sDAI = sDAI_;
        daiPriceFeed = daiPriceFeed_;
    }
}

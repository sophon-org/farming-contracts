// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.24;

import "@chainlink/interfaces/AggregatorV3Interface.sol";
import "../interfaces/IwstETH.sol";

contract WstEthPriceFeedAdapter {

    error InvalidPriceFeedDecimals();

    IwstETH public immutable wstEth;
    AggregatorV3Interface public immutable stEthPriceFeed;

    /**
     * @return uint The scaled price in USD
     */
    function latestAnswer()
        public
        view
        returns (int256) {

        (
            ,
            int rate, // stETH/USD rate
            ,
            uint updatedAt,

        ) = stEthPriceFeed.latestRoundData();

        return rate * int256(wstEth.stEthPerToken()) / 1e18; // scale to 8 decimals places like Chainlink
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

    constructor(IwstETH wstEth_, AggregatorV3Interface stEthPriceFeed_) {
        if (stEthPriceFeed_.decimals() != 8) {
            revert InvalidPriceFeedDecimals();
        }
        
        wstEth = wstEth_;
        stEthPriceFeed = stEthPriceFeed_;
    }
}

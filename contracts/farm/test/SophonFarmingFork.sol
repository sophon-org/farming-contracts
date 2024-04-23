// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.24;

import "../SophonFarming.sol";

contract SophonFarmingFork is SophonFarming {

    uint256 internalBlockNumber;

    constructor(address[5] memory tokens_) SophonFarming(tokens_) {}

    function initialize(uint256 ethAllocPoint_, uint256 sDAIAllocPoint_, uint256 _pointsPerBlock, uint256 _startBlock, uint256 _boosterMultiplier) public override onlyOwner {
        super.initialize(ethAllocPoint_, sDAIAllocPoint_, _pointsPerBlock, _startBlock, _boosterMultiplier);
        internalBlockNumber = block.number;
    }

    function getBlockNumber() override public view returns (uint256) {
        return internalBlockNumber;
    }

    function addBlocks(uint256 count) public {
        internalBlockNumber += count;
    }
}
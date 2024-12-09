// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import "../SophonFarming.sol";

contract SophonFarmingFork is SophonFarming {

    uint256 internalBlockNumber;

    constructor(address[8] memory tokens_, uint256 _CHAINID) SophonFarming(tokens_, _CHAINID) {}

    function initialize(uint256 wstEthAllocPoint_, uint256 weEthAllocPoint_, uint256 sDAIAllocPoint_, uint256 _pointsPerBlock, uint256 _startBlock, uint256 _boosterMultiplier) public override onlyOwner {
        super.initialize(wstEthAllocPoint_, weEthAllocPoint_, sDAIAllocPoint_, _pointsPerBlock, _startBlock, _boosterMultiplier);
        internalBlockNumber = block.number;
    }

    function getBlockNumber() override public view returns (uint256) {
        return internalBlockNumber > 0? internalBlockNumber: block.number;
    }

    function addBlocks(uint256 count) public {
        internalBlockNumber += count;
    }

    // Setter function for endBlock
    function setEndBlock(uint256 _endBlock) external onlyOwner {
        endBlock = _endBlock;
    }

    // Setter function for endBlock
    function setInternalBlockNumber(uint256 _internalBlockNumber) external onlyOwner {
        internalBlockNumber = _internalBlockNumber;
    }

    // Setter function for endBlockForWithdrawals
    function setEndBlockForWithdrawals(uint256 _endBlockForWithdrawals) external onlyOwner {
        endBlockForWithdrawals = _endBlockForWithdrawals;
    }

}
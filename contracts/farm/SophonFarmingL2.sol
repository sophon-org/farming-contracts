// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import "./SophonFarming.sol";

contract SophonFarmingL2 is SophonFarming {

    uint256 internalBlockNumber;

    constructor(address[8] memory tokens_) SophonFarming(tokens_) {}


    function addPool(
        IERC20 _lpToken,
        address _l2Farm,
        uint256 _amount,
        uint256 _boostAmount,
        uint256 _depositAmount,
        uint256 _allocPoint,
        uint256 _lastRewardBlock,
        uint256 _accPointsPerShare,
        uint256 _totalRewards,
        string memory _description
    ) external onlyOwner {
        // TODO any safety checks
        poolInfo.push(PoolInfo({
            lpToken: _lpToken,
            l2Farm: _l2Farm,
            amount: _amount,
            boostAmount: _boostAmount,
            depositAmount: _depositAmount,
            allocPoint: _allocPoint,
            lastRewardBlock: _lastRewardBlock,
            accPointsPerShare: _accPointsPerShare,
            totalRewards: _totalRewards,
            description: _description
        }));
    }

    function setBoosterMultiplier(uint256 _boosterMultiplier) override external onlyOwner {
        boosterMultiplier = _boosterMultiplier;
    }
    
    function setPointsPerBlock(uint256 _pointsPerBlock) override public onlyOwner {
        pointsPerBlock = _pointsPerBlock;
    }


}
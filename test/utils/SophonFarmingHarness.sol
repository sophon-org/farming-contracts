// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import "../../contracts/farm/SophonFarming.sol";

contract SophonFarmingHarness is SophonFarming {
    constructor(address[8] memory tokens_)  SophonFarming(tokens_) {}

    function getBlockMultiplier(uint256 _from, uint256 _to) external view returns (uint256) {
        return super._getBlockMultiplier(_from, _to);
    }
}
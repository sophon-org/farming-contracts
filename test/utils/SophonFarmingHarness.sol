// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import "../../contracts/farm/SophonFarming.sol";

contract SophonFarmingHarness is SophonFarming {
    constructor(address[8] memory tokens_, uint256 _CHAINID)  SophonFarming(tokens_, _CHAINID) {}

    function getBlockMultiplier(uint256 _from, uint256 _to) external view returns (uint256) {
        return super._getBlockMultiplier(_from, _to);
    }
}
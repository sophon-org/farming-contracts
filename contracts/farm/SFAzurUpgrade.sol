// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Wrapper.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./interfaces/IWeth.sol";
import "./interfaces/IstETH.sol";
import "./interfaces/IwstETH.sol";
import "./interfaces/IsDAI.sol";
import "./interfaces/IeETHLiquidityPool.sol";
import "./interfaces/IweETH.sol";
import "../proxies/Upgradeable2Step.sol";
import "./SophonFarmingState.sol";

/**
 * @title Sophon Farming Contract
 * @author Sophon
 */
contract SFAzurUpgrade is Upgradeable2Step, SophonFarmingState {
    using SafeERC20 for IERC20;

    /// @notice Emitted when setPointsPerBlock is called
    event MigrationSuccess(uint256 amount);

    error MigrationFailed();


    // This function migrates AZUR token to stAZUR 1:1
    /**
     * @notice Allows an admin to migrate AZUR to stAZUR 1:1
     * @param stAZUR address of the stakikng AZUR
     * @param pid pool id for migration
     */
    function migrateAzur(address stAZUR, uint256 pid) external onlyOwner {
        PoolInfo storage pool = poolInfo[pid];
        uint256 amount = pool.lpToken.balanceOf(address(this));
        pool.lpToken.safeIncreaseAllowance(stAZUR, amount);
        ERC20Wrapper(stAZUR).depositFor(address(this), amount);
        pool.lpToken = IERC20(stAZUR);

        if (ERC20Wrapper(stAZUR).balanceOf(address(this)) != amount) {
            // expecting 1:1 migration
            revert MigrationFailed();
        }

        emit MigrationSuccess(amount);
    }
}
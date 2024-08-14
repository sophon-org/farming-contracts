// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/bridge/IBridgehub.sol";

contract SophonFarmingState {

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken; // Address of LP token contract.
        address l2Farm; // Address of the farming contract on Sophon chain
        uint256 amount; // total amount of LP tokens earning yield from deposits and boosts
        uint256 boostAmount; // total boosted value purchased by users
        uint256 depositAmount; // remaining deposits not applied to a boost purchases
        uint256 allocPoint; // How many allocation points assigned to this pool. Points to distribute per block.
        uint256 lastRewardBlock; // Last block number that points distribution occurs.
        uint256 accPointsPerShare; // Accumulated points per share.
        uint256 totalRewards; // Total rewards earned by the pool.
        string description; // Description of pool.
    }

    // Info of each user.
    struct UserInfo {
        uint256 amount; // Amount of LP tokens the user is earning yield on from deposits and boosts
        uint256 boostAmount; // Boosted value purchased by the user
        uint256 depositAmount; // remaining deposits not applied to a boost purchases
        uint256 rewardSettled; // rewards settled
        uint256 rewardDebt; // rewards debt
    }

    enum PredefinedPool {
        sDAI,          // MakerDAO (sDAI)
        wstETH,        // Lido (wstETH)
        weETH          // ether.fi (weETH)
    }

    mapping(PredefinedPool => uint256) public typeToId;

    // held proceeds from booster sales
    mapping(uint256 => uint256) public heldProceeds;

    uint256 public boosterMultiplier;

    // Points created per block.
    uint256 public pointsPerBlock;

    // Info of each pool.
    PoolInfo[] public poolInfo;

    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;

    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint;

    // The block number when point mining ends.
    uint256 public endBlock;

    bool internal _initialized;

    mapping(address => bool) public poolExists;

    uint256 public endBlockForWithdrawals;

    IBridgehub public bridge;
    mapping(uint256 => bool) public isBridged;

    mapping(address userAdmin => mapping(address user => bool inWhitelist)) public whitelist;
    bytes32 public merkleRoot;
    mapping(uint256 => uint256) internal claimedBitMap;
}

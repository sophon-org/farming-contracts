// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.24;

import "@openzeppelin/token/ERC20/IERC20.sol";

interface BridgeLike {
    function depositERC20To(
        address _l1Token,
        address _l2Token,
        address _to,
        uint256 _amount,
        uint32 _minGasLimit,
        bytes calldata _extraData
    ) external;
}

contract SophonFarmingState {
    // Info of each user.
    struct UserInfo {
        uint256 amount; // Amount of LP tokens the user is earning yield on from deposits and boosts
        uint256 boostAmount; // Boosted value purchased by the user
        uint256 depositAmount; // remaining deposits not applied to a boost purchases
        uint256 rewardSettled; // Reward settled.
        uint256 rewardDebt; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of points
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accPointsPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accPointsPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken; // Address of LP token contract.
        address l2Token; // Address of LP token on Sophon chain
        address l2Farm; // Address of the farming contract on Sophon chain
        uint256 amount; // total amount of LP tokens earning yield from deposits and boosts
        uint256 boostAmount; // total boosted value purchased by users
        uint256 depositAmount; // remaining deposits not applied to a boost purchases
        uint256 allocPoint; // How many allocation points assigned to this pool. Points to distribute per block.
        uint256 lastRewardBlock; // Last block number that points distribution occurs.
        uint256 accPointsPerShare; // Accumulated points per share, times 1e12. See below.
        string description; // Description of pool.
    }

    uint256 public wstETH_Pool_Id;
    uint256 public sDAI_Pool_Id;

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

    // The block number when point mining starts.
    uint256 public startBlock;

    // The block number when point mining ends.
    uint256 public endBlock;

    bool internal _initialized;

    mapping(address => bool) public poolExists;

    uint256 public endBlockForWithdrawals;

    BridgeLike public bridge;
}

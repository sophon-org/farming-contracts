// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "interfaces/IPoolShareToken.sol";
import "interfaces/IBridge.sol";

interface ISophonFarming {
    // Info of each pool.
    struct PoolInfo {
        address lpToken; // Address of LP token contract.
        address l2Farm; // Address of the farming contract on Sophon chain
        uint256 amount; // total amount of LP tokens earning yield from deposits and boosts
        uint256 boostAmount; // total boosted value purchased by users
        uint256 depositAmount; // remaining deposits not applied to a boost purchases (note: tracked by PoolShareToken balances/totalSupply)
        uint256 allocPoint; // How many allocation points assigned to this pool. Points to distribute per block.
        uint256 lastRewardBlock; // Last block number that points distribution occurs.
        uint256 accPointsPerShare; // Accumulated points per share, times 1e18. See below.
        address poolShareToken; // the pool share token minted when a user deposits that represents their deposit
        string description; // Description of pool.
    }

    // Info of each user.
    struct UserInfo {
        uint256 amount; // Amount of LP tokens the user is earning yield on from deposits and boosts
        uint256 boostAmount; // Boosted value purchased by the user
        uint256 depositAmount; // remaining deposits not applied to a boost purchases (note: tracked by PoolShareToken balances/totalSupply)
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


    enum PredefinedPool {
        sDAI,           // MakerDAO (sDAI)
        wstETH,         // Lido (wstETH)
        weETH,          // ether.fi (weETH)
        ezETH,          // Renzo (ezETH)
        rsETH,          // Kelp Dao (rsETH)
        rswETH,         // Swell (rswETH)
        uniETH,         // Bedrock (uniETH)
        pufETH          // Puffer (pufETH)
    }


    event Add(address indexed lpToken, uint256 indexed pid, address poolShareToken, uint256 allocPoint);
    event Deposit(address indexed user, uint256 indexed pid, uint256 depositAmount, uint256 boostAmount);
    event Exit(address indexed user, uint256 indexed pid, uint256 amount);
    event Bridge(address indexed user, uint256 indexed pid, uint256 amount);
    event IncreaseBoost(address indexed user, uint256 indexed pid, uint256 boostAmount);
    event WithdrawProceeds(uint256 indexed pid, uint256 amount);

    error AlreadyInitialized();
    error NotFound(address lpToken);
    error FarmingIsStarted();
    error FarmingIsEnded();
    error ExitNotAllowed();
    error InvalidStartBlock();
    error InvalidEndBlock();
    error InvalidDeposit();
    error InvalidTransfer();
    error NoEthSent();
    error BoostTooHigh(uint256 maxAllowed);
    error BoostIsZero();
    error BridgeInvalid();

    function typeToId(PredefinedPool pool) external view returns (uint256);
    function heldProceeds(uint256 poolId) external view returns (uint256);
    function boosterMultiplier() external view returns (uint256);
    function pointsPerBlock() external view returns (uint256);
    function poolInfo(uint256 index) external view returns (PoolInfo calldata);
    function userInfo(uint256 poolId, address user) external view returns (UserInfo memory);
    function totalAllocPoint() external view returns (uint256);
    function startBlock() external view returns (uint256);
    function endBlock() external view returns (uint256);
    function poolExists(address poolAddress) external view returns (bool);
    function endBlockForWithdrawals() external view returns (uint256);
    function bridge() external view returns (IBridge);

    function poolLength() external view returns (uint256);

    function initialize(uint256 ethAllocPoint_, uint256 sDAIAllocPoint_, uint256 _pointsPerBlock, uint256 _startBlock, uint256 _boosterMultiplier) external;

    function add(uint256 _allocPoint, address _lpToken, string memory _poolShareSymbol, string memory _description, bool _withUpdate) external returns (uint256);

    function set(uint256 _pid, uint256 _allocPoint, bool _withUpdate) external;

    function isFarmingEnded() external view returns (bool);

    function isExitPeriodEnded() external view returns (bool);

    function setBridge(address _bridge) external;

    function setBridgeForPool(uint256 _pid, address _l2Farm) external;

    function setStartBlock(uint256 _startBlock) external;

    function setEndBlocks(uint256 _endBlock, uint256 _withdrawalBlocks) external;

    function setPointsPerBlock(uint256 _pointsPerBlock) external;

    function setBoosterMultiplier(uint256 _boosterMultiplier) external;

    function getBlockMultiplier(uint256 _from, uint256 _to) external view returns (uint256);

    function pendingPoints(uint256 _pid, address _user) external view returns (uint256);

    function massUpdatePools() external;

    function updatePool(uint256 _pid) external;

    function deposit(uint256 _pid, uint256 _amount, uint256 _boostAmount) external;

    function exit(uint256 _pid) external;

    function bridgePool(uint256 _pid) external;

    function increaseBoost(uint256 _pid, uint256 _boostAmount) external;

    function getMaxAdditionalBoost(address _user, uint256 _pid) external view returns (uint256);

    function withdrawProceeds(uint256 _pid) external;

    function getPoolInfo() external view returns (PoolInfo[] memory);

    function getOptimizedUserInfo(address[] memory _users) external view returns (uint256[4][][] memory);

    function getUserInfo(address[] memory _users) external view returns (UserInfo[][] memory);
}

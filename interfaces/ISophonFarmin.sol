// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.25;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ISophonFarming {
    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken; // Address of LP token contract.
        address l2Farm; // Address of the farming contract on Sophon chain
        uint256 amount; // total amount of LP tokens earning yield from deposits and boosts
        uint256 boostAmount; // total boosted value purchased by users
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
        sDAI,
        wstETH,
        weETH,
        ezETH,
        rsETH,
        rswETH,
        uniETH,
        pufETH
    }
    

    event Add(address indexed lpToken, uint256 indexed pid, uint256 allocPoint);
    event Deposit(address indexed user, uint256 indexed pid, uint256 depositAmount, uint256 boostAmount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event IncreaseBoost(address indexed user, uint256 indexed pid, uint256 boostAmount);
    event WithdrawProceeds(uint256 indexed pid, uint256 amount);
    event Bridge(address indexed user, uint256 indexed pid, uint256 amount);

    function initialize(uint256 ethAllocPoint_, uint256 sDAIAllocPoint_, uint256 _pointsPerBlock, uint256 _startBlock, uint256 _boosterMultiplier) external;
    function add(uint256 _allocPoint, address _lpToken, string memory _description, bool _withUpdate) external returns (uint256);
    function set(uint256 _pid, uint256 _allocPoint, bool _withUpdate) external;
    function poolLength() external view returns (uint256);
    function isFarmingEnded() external view returns (bool);
    function isWithdrawPeriodEnded() external view returns (bool);
    function setBridge(address _bridge) external;
    function setBridgeForPool(uint256 _pid, address _l2Farm) external;
    function setStartBlock(uint256 _startBlock) external;
    function setEndBlock(uint256 _endBlock, uint256 _withdrawalBlocks) external;
    function setPointsPerBlock(uint256 _pointsPerBlock) external;
    function setBoosterMultiplier(uint256 _boosterMultiplier) external;
    function pendingPoints(uint256 _pid, address _user) external view returns (uint256);
    function massUpdatePools() external;
    function updatePool(uint256 _pid) external;
    function deposit(uint256 _pid, uint256 _amount, uint256 _boostAmount) external;
    function depositDai(uint256 _amount, uint256 _boostAmount) external;
    function depositStEth(uint256 _amount, uint256 _boostAmount) external;
    function depositEth(uint256 _boostAmount, PredefinedPool predefinedPool) external payable;
    function depositeEth(uint256 _amount, uint256 _boostAmount) external;
    function depositWeth(uint256 _amount, uint256 _boostAmount, PredefinedPool predefinedPool) external;
    function withdraw(uint256 _pid, uint256 _withdrawAmount) external;
    function bridgePool(uint256 _pid) external;
    function revertFailedBridge(uint256 _pid) external;
    function increaseBoost(uint256 _pid, uint256 _boostAmount) external;
    function withdrawProceeds(uint256 _pid) external;
    function getPoolInfo() external view returns (PoolInfo[] memory);
    function getOptimizedUserInfo(address[] memory _users) external view returns (uint256[4][][] memory);
    function getUserInfo(address[] memory _users) external view returns (UserInfo[][] memory);
    function getPendingPoints(address[] memory _users) external view returns (uint256[][] memory);
    function getBlockMultiplier(uint256 _from, uint256 _to) external view returns (uint256);


    function typeToId(PredefinedPool poolType) external view returns (uint256);
    function heldProceeds(uint256 poolId) external view returns (uint256);
    function boosterMultiplier() external view returns (uint256);
    function pointsPerBlock() external view returns (uint256);
    function poolInfo(uint256 pid) external view returns (PoolInfo memory);
    function userInfo(uint256 pid, address user) external view returns (UserInfo memory);
    function totalAllocPoint() external view returns (uint256);
    function startBlock() external view returns (uint256);
    function endBlock() external view returns (uint256);
    function poolExists(address pool) external view returns (bool);
    function endBlockForWithdrawals() external view returns (uint256);
    function bridge() external view returns (address);
    function isBridged(uint256 poolId) external view returns (bool);

    
    
    function pendingOwner() external view returns (address);
    function transferOwnership(address newOwner) external;
    function acceptOwnership() external;
    function owner() external view returns (address);
    // onlyOwner
    function replaceImplementation(address impl_) external;
    function becomeImplementation(address proxy) external;
    function pendingImplementation() external returns(address);

    
}

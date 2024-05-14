// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.25;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ISophonFarming {
    struct PoolInfo {
        IERC20 lpToken;
        address l2Farm;
        uint256 amount;
        uint256 boostAmount;
        uint256 depositAmount;
        uint256 allocPoint;
        uint256 lastRewardBlock;
        uint256 accPointsPerShare;
        string description;
    }

    struct UserInfo {
        uint256 amount;
        uint256 boostAmount;
        uint256 depositAmount;
        uint256 rewardSettled;
        uint256 rewardDebt;
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
    function setEndBlocks(uint256 _endBlock, uint256 _withdrawalBlocks) external;
    function setPointsPerBlock(uint256 _pointsPerBlock) external;
    function setBoosterMultiplier(uint256 _boosterMultiplier) external;
    function pendingPoints(uint256 _pid, address _user) external view returns (uint256);
    function massUpdatePools() external;
    function updatePool(uint256 _pid) external;
    function deposit(uint256 _pid, uint256 _amount, uint256 _boostAmount) external;
    function depositDai(uint256 _amount, uint256 _boostAmount) external;
    function depositStEth(uint256 _amount, uint256 _boostAmount) external;
    function depositEth(uint256 _boostAmount, PredefinedPool predefinedPool) external payable;
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

}

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
    
    /// @notice Emitted when a new pool is added
    event Add(address indexed lpToken, uint256 indexed pid, uint256 allocPoint);

    /// @notice Emitted when a pool is updated
    event Set(address indexed lpToken, uint256 indexed pid, uint256 allocPoint);

    /// @notice Emitted when a user deposits to a pool
    event Deposit(address indexed user, uint256 indexed pid, uint256 depositAmount, uint256 boostAmount);

    /// @notice Emitted when a user withdraws from a pool
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);

    /// @notice Emitted when a whitelisted admin transfers points from one user to another
    event TransferPoints(address indexed sender, address indexed receiver, uint256 indexed pid, uint256 amount);

    /// @notice Emitted when a user increases the boost of an existing deposit
    event IncreaseBoost(address indexed user, uint256 indexed pid, uint256 boostAmount);

    /// @notice Emitted when all pool funds are bridged to Sophon blockchain
    event BridgePool(address indexed user, uint256 indexed pid, uint256 amount);

    /// @notice Emitted when the admin bridges booster proceeds
    event BridgeProceeds(uint256 indexed pid, uint256 proceeds);

    /// @notice Emitted when the the revertFailedBridge function is called
    event RevertFailedBridge(uint256 indexed pid);

    /// @notice Emitted when the the updatePool function is called
    event PoolUpdated(uint256 indexed pid);

    error ZeroAddress();
    error PoolExists();
    error PoolDoesNotExist();
    error AlreadyInitialized();
    error NotFound(address lpToken);
    error FarmingIsStarted();
    error FarmingIsEnded();
    error TransferNotAllowed();
    error TransferTooHigh(uint256 maxAllowed);
    error InvalidEndBlock();
    error InvalidDeposit();
    error InvalidBooster();
    error InvalidPointsPerBlock();
    error InvalidTransfer();
    error WithdrawNotAllowed();
    error WithdrawTooHigh(uint256 maxAllowed);
    error WithdrawIsZero();
    error NothingInPool();
    error NoEthSent();
    error BoostTooHigh(uint256 maxAllowed);
    error BoostIsZero();
    error BridgeInvalid();

    function initialize(uint256 wstEthAllocPoint_, uint256 weEthAllocPoint_, uint256 sDAIAllocPoint_, uint256 _pointsPerBlock, uint256 _startBlock, uint256 _boosterMultiplier) external;
    function add(uint256 _allocPoint, address _lpToken, string memory _description, uint256 _poolStartBlock, uint256 _newPointsPerBlock) external returns (uint256);
    function set(uint256 _pid, uint256 _allocPoint, uint256 _poolStartBlock, uint256 _newPointsPerBlock) external;
    function poolLength() external view returns (uint256);
    function isFarmingEnded() external view returns (bool);
    function isWithdrawPeriodEnded() external view returns (bool);
    function setBridge(address _bridge) external;
    function setBridgeForPool(uint256 _pid, address _l2Farm) external;
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
    function bridgePool(uint256 _pid, uint256 _l2TxGasLimit, uint256 _l2TxGasPerPubdataByte) external;
    function revertFailedBridge(uint256 _pid) external;
    function increaseBoost(uint256 _pid, uint256 _boostAmount) external;
    function bridgeProceeds(uint256 _pid, uint256 _l2TxGasLimit, uint256 _l2TxGasPerPubdataByte) external;
    function getPoolInfo() external view returns (PoolInfo[] memory);
    function getOptimizedUserInfo(address[] memory _users) external view returns (uint256[4][][] memory);
    function getPendingPoints(address[] memory _users) external view returns (uint256[][] memory);
    function getBlockMultiplier(uint256 _from, uint256 _to) external view returns (uint256);
    function isInWhitelist(address user) external view returns (bool);


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
    function transferPoints(uint256 _pid, address _sender, address _receiver, uint256 _transferAmount) external;
    
    
    function pendingOwner() external view returns (address);
    function transferOwnership(address newOwner) external;
    function acceptOwnership() external;
    function owner() external view returns (address);
    // onlyOwner
    function replaceImplementation(address impl_) external;
    function becomeImplementation(address proxy) external;
    function pendingImplementation() external returns(address);
    function setUsersWhitelisted(address _userAdmin, address[] memory _users, bool _isInWhitelist) external;

    
}

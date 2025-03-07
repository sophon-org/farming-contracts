// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.26;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./interfaces/IWeth.sol";
import "./interfaces/IstETH.sol";
import "./interfaces/IwstETH.sol";
import "./interfaces/IsDAI.sol";
import "./interfaces/IeETHLiquidityPool.sol";
import "./interfaces/IweETH.sol";
import "../proxies/Upgradeable2Step.sol";
import "./SophonFarmingState.sol";
import 'contracts/interfaces/uniswap/IUniswapV2Router02.sol';

/**
 * @title Sophon Farming Contract
 * @author Sophon
 */
contract SophonFarming is Upgradeable2Step, SophonFarmingState {
    using SafeERC20 for IERC20;

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

    /// @notice Emitted when the the revertFailedBridge function is called
    event RevertFailedBridge(uint256 indexed pid);

    /// @notice Emitted when the the updatePool function is called
    event PoolUpdated(uint256 indexed pid);

    /// @notice Emitted when setPointsPerBlock is called
    event SetPointsPerBlock(uint256 oldValue, uint256 newValue);

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

    address public immutable dai;
    address public immutable sDAI;
    address public immutable weth;
    address public immutable stETH;
    address public immutable wstETH;
    address public immutable eETH;
    address public immutable eETHLiquidityPool;
    address public immutable weETH;
    uint256 public immutable CHAINID;
    uint256 internal constant PEPE_PID = 9;
    address internal constant PENDLE_EXCEPTION = 0x065347C1Dd7A23Aa043e3844B4D0746ff7715246;

    /**
     * @notice Construct SophonFarming
     * @param tokens_ Immutable token addresses
     * @dev 0:dai, 1:sDAI, 2:weth, 3:stETH, 4:wstETH, 5:eETH, 6:eETHLiquidityPool, 7:weETH
     */
    constructor(address[8] memory tokens_, uint256 _CHAINID) {
        for (uint256 i = 0; i < tokens_.length; i++) {
            require(tokens_[i] != address(0), "cannot be zero");
        }

        dai = tokens_[0];
        sDAI = tokens_[1];
        weth = tokens_[2];
        stETH = tokens_[3];
        wstETH = tokens_[4];
        eETH = tokens_[5];
        eETHLiquidityPool = tokens_[6];
        weETH = tokens_[7];
        CHAINID = _CHAINID;
    }

    /**
     * @notice Allows direct deposits of ETH for deposit to the wstETH pool
     */
    receive() external payable {
        if (msg.sender == weth) {
            return;
        }

        depositEth(0, PredefinedPool.wstETH);
    }

    /**
     * @notice Initialize the farm
     * @param wstEthAllocPoint_ wstEth alloc points
     * @param weEthAllocPoint_ weEth alloc points
     * @param sDAIAllocPoint_ sdai alloc points
     * @param _pointsPerBlock points per block
     * @param _initialPoolStartBlock start block
     * @param _boosterMultiplier booster multiplier
     */
    function initialize(uint256 wstEthAllocPoint_, uint256 weEthAllocPoint_, uint256 sDAIAllocPoint_, uint256 _pointsPerBlock, uint256 _initialPoolStartBlock, uint256 _boosterMultiplier) public virtual onlyOwner {
        if (_initialized) {
            revert AlreadyInitialized();
        }

        if (_pointsPerBlock < 1e18 || _pointsPerBlock > 1_000e18) {
            revert InvalidPointsPerBlock();
        }
        pointsPerBlock = _pointsPerBlock;

        if (_boosterMultiplier < 1e18 || _boosterMultiplier > 10e18) {
            revert InvalidBooster();
        }
        boosterMultiplier = _boosterMultiplier;

        poolExists[dai] = true;
        poolExists[weth] = true;
        poolExists[stETH] = true;
        poolExists[eETH] = true;

        _initialized = true;

        // sDAI
        typeToId[PredefinedPool.sDAI] = add(sDAIAllocPoint_, sDAI, "sDAI", _initialPoolStartBlock, 0);
        IERC20(dai).approve(sDAI, type(uint256).max);

        // wstETH
        typeToId[PredefinedPool.wstETH] = add(wstEthAllocPoint_, wstETH, "wstETH", _initialPoolStartBlock, 0);
        IERC20(stETH).approve(wstETH, type(uint256).max);

        // weETH
        typeToId[PredefinedPool.weETH] = add(weEthAllocPoint_, weETH, "weETH", _initialPoolStartBlock, 0);
        IERC20(eETH).approve(weETH, type(uint256).max);
    }

    /**
     * @notice Adds a new pool to the farm. Can only be called by the owner.
     * @param _allocPoint alloc point for new pool
     * @param _lpToken lpToken address
     * @param _description description of new pool
     * @param _poolStartBlock block at which points start to accrue for the pool
     * @param _newPointsPerBlock update global points per block; 0 means no update
     * @return uint256 The pid of the newly created asset
     */
    function add(uint256 _allocPoint, address _lpToken, string memory _description, uint256 _poolStartBlock, uint256 _newPointsPerBlock) public onlyOwner returns (uint256) {
        if (_lpToken == address(0)) {
            revert ZeroAddress();
        }
        if (poolExists[_lpToken]) {
            revert PoolExists();
        }
        if (isFarmingEnded()) {
            revert FarmingIsEnded();
        }

        if (_newPointsPerBlock != 0) {
            setPointsPerBlock(_newPointsPerBlock);
        } else {
            massUpdatePools();
        }

        uint256 lastRewardBlock =
            getBlockNumber() > _poolStartBlock ? getBlockNumber() : _poolStartBlock;
        totalAllocPoint = totalAllocPoint + _allocPoint;
        poolExists[_lpToken] = true;

        uint256 pid = poolInfo.length;

        poolInfo.push(
            PoolInfo({
                lpToken: IERC20(_lpToken),
                l2Farm: address(0),
                amount: 0,
                boostAmount: 0,
                depositAmount: 0,
                allocPoint: _allocPoint,
                lastRewardBlock: lastRewardBlock,
                accPointsPerShare: 0,
                totalRewards: 0,
                description: _description
            })
        );

        emit Add(_lpToken, pid, _allocPoint);

        return pid;
    }

    /**
     * @notice Updates the given pool's allocation point. Can only be called by the owner.
     * @param _pid The pid to update
     * @param _allocPoint The new alloc point to set for the pool
     * @param _poolStartBlock block at which points start to accrue for the pool; 0 means no update
     * @param _newPointsPerBlock update global points per block; 0 means no update
     */
    function set(uint256 _pid, uint256 _allocPoint, uint256 _poolStartBlock, uint256 _newPointsPerBlock) external onlyOwner {
        if (isFarmingEnded()) {
            revert FarmingIsEnded();
        }

        if (_newPointsPerBlock != 0) {
            setPointsPerBlock(_newPointsPerBlock);
        } else {
            massUpdatePools();
        }

        PoolInfo storage pool = poolInfo[_pid];
        address lpToken = address(pool.lpToken);
        if (lpToken == address(0) || !poolExists[lpToken]) {
            revert PoolDoesNotExist();
        }
        totalAllocPoint = totalAllocPoint - pool.allocPoint + _allocPoint;
        pool.allocPoint = _allocPoint;

        // pool starting block is updated if farming hasn't started and _poolStartBlock is non-zero
        if (_poolStartBlock != 0 && getBlockNumber() < pool.lastRewardBlock) {
            pool.lastRewardBlock =
                getBlockNumber() > _poolStartBlock ? getBlockNumber() : _poolStartBlock;
        }

        emit Set(lpToken, _pid, _allocPoint);
    }

    /**
     * @notice Returns the number of pools in the farm
     * @return uint256 number of pools
     */
    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    /**
     * @notice Checks if farming is ended
     * @return bool True if farming is ended
     */
    function isFarmingEnded() public view returns (bool) {
        uint256 _endBlock = endBlock;
        return _endBlock != 0 && getBlockNumber() > _endBlock;
    }

    /**
     * @notice Checks if the withdrawal period is ended
     * @return bool True if withdrawal period is ended
     */
    function isWithdrawPeriodEnded() public view returns (bool) {
        uint256 _endBlockForWithdrawals = endBlockForWithdrawals;
        return _endBlockForWithdrawals != 0 && getBlockNumber() > _endBlockForWithdrawals;
    }

    /**
     * @notice Updates the bridge contract
     */
    function setBridge(address _bridge) external onlyOwner {
        if (_bridge == address(0)) {
            revert ZeroAddress();
        }
        bridge = IBridgehub(_bridge);
    }

    /**
     * @notice Updates the L2 Farm for the pool
     * @param _pid the pid
     * @param _l2Farm the l2Farm address
     */
    function setL2FarmForPool(uint256 _pid, address _l2Farm) external onlyOwner {
        if (_l2Farm == address(0)) {
            revert ZeroAddress();
        }
        PoolInfo storage pool = poolInfo[_pid];
        if (address(pool.lpToken) == address(0)) {
            revert PoolDoesNotExist();
        }
        pool.l2Farm = _l2Farm;
    }
    /**
     * @notice Set the end block of the farm
     * @param _endBlock the end block
     * @param _withdrawalBlocks the last block that withdrawals are allowed
     */
    function setEndBlock(uint256 _endBlock, uint256 _withdrawalBlocks) external onlyOwner {
        if (isFarmingEnded()) {
            revert FarmingIsEnded();
        }
        uint256 _endBlockForWithdrawals;
        if (_endBlock != 0) {
            if (getBlockNumber() > _endBlock) {
                revert InvalidEndBlock();
            }
            _endBlockForWithdrawals = _endBlock + _withdrawalBlocks;
        } else {
            // withdrawal blocks needs an endBlock
            _endBlockForWithdrawals = 0;
        }
        massUpdatePools();
        endBlock = _endBlock;
        endBlockForWithdrawals = _endBlockForWithdrawals;
    }

    /**
     * @notice Set points per block
     * @param _pointsPerBlock points per block to set
     */
    function setPointsPerBlock(uint256 _pointsPerBlock) virtual public onlyOwner {
        if (isFarmingEnded()) {
            revert FarmingIsEnded();
        }
        if (_pointsPerBlock < 1e18 || _pointsPerBlock > 1_000e18) {
            revert InvalidPointsPerBlock();
        }
        massUpdatePools();
        emit SetPointsPerBlock(pointsPerBlock, _pointsPerBlock);
        pointsPerBlock = _pointsPerBlock;
    }

    /**
     * @notice Set booster multiplier
     * @param _boosterMultiplier booster multiplier to set
     */
    function setBoosterMultiplier(uint256 _boosterMultiplier) virtual external onlyOwner {
        if (_boosterMultiplier < 1e18 || _boosterMultiplier > 10e18) {
            revert InvalidBooster();
        }
        if (isFarmingEnded()) {
            revert FarmingIsEnded();
        }
        massUpdatePools();
        boosterMultiplier = _boosterMultiplier;
    }

    /**
     * @notice Returns the block multiplier
     * @param _from from block
     * @param _to to block
     * @return uint256 The block multiplier
     */
    function _getBlockMultiplier(uint256 _from, uint256 _to) internal view returns (uint256) {
        uint256 _endBlock = endBlock;
        if (_endBlock != 0) {
            _to = Math.min(_to, _endBlock);
        }
        if (_to > _from) {
            return (_to - _from) * 1e18;
        } else {
            return 0;
        }
    }

    /**
     * @notice Adds or removes users from the whitelist
     * @param _userAdmin an admin user who can transfer points for users
     * @param _users list of users
     * @param _isInWhitelist to add or remove
     */
    function setUsersWhitelisted(address _userAdmin, address[] memory _users, bool _isInWhitelist) external onlyOwner {
        mapping(address user => bool inWhitelist) storage whitelist_ = whitelist[_userAdmin];
        for(uint i = 0; i < _users.length; i++) {
            whitelist_[_users[i]] = _isInWhitelist;
        }
    }

    /**
     * @notice Returns pending points for user in a pool
     * @param _pid pid of the pool
     * @param _user user in the pool
     * @return uint256 pendings points
     */
    function _pendingPoints(uint256 _pid, address _user) internal view returns (uint256) {
        UserInfo storage user = userInfo[_pid][_user];
        (uint256 accPointsPerShare, ) = _settlePool(_pid);

        return user.amount *
            accPointsPerShare /
            1e18 +
            user.rewardSettled -
            user.rewardDebt;
    }

    /**
     * @notice Returns accPointsPerShare and totalRewards to date for the pool
     * @param _pid pid of the pool
     * @return accPointsPerShare
     * @return totalRewards
     */
    function _settlePool(uint256 _pid) internal view returns (uint256 accPointsPerShare, uint256 totalRewards) {
        PoolInfo storage pool = poolInfo[_pid];

        accPointsPerShare = pool.accPointsPerShare;
        totalRewards = pool.totalRewards;

        uint256 lpSupply = pool.amount;
        if (getBlockNumber() > pool.lastRewardBlock && lpSupply != 0) {
            uint256 blockMultiplier = _getBlockMultiplier(pool.lastRewardBlock, getBlockNumber());

            uint256 pointReward =
                blockMultiplier *
                pointsPerBlock *
                pool.allocPoint /
                totalAllocPoint;

            totalRewards = totalRewards + pointReward / 1e18;

            accPointsPerShare = pointReward /
                lpSupply +
                accPointsPerShare;
        }
    }

    /**
     * @notice Returns pending points for user in a pool
     * @param _pid pid of the pool
     * @param _user user in the pool
     * @return uint256 pendings points
     */
    function pendingPoints(uint256 _pid, address _user) external view returns (uint256) {
        return _pendingPoints(_pid, _user);
    }

    /**
     * @notice Update accounting of all pools
     */
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for(uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    /**
     * @notice Updating accounting of a single pool
     * @param _pid pid to update
     */
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (getBlockNumber() <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.amount;
        uint256 _pointsPerBlock = pointsPerBlock;
        uint256 _allocPoint = pool.allocPoint;
        if (lpSupply == 0 || _pointsPerBlock == 0 || _allocPoint == 0) {
            pool.lastRewardBlock = getBlockNumber();
            return;
        }
        uint256 blockMultiplier = _getBlockMultiplier(pool.lastRewardBlock, getBlockNumber());
        uint256 pointReward =
            blockMultiplier *
            _pointsPerBlock *
            _allocPoint /
            totalAllocPoint;

        pool.totalRewards = pool.totalRewards + pointReward / 1e18;

        pool.accPointsPerShare = pointReward /
            lpSupply +
            pool.accPointsPerShare;

        pool.lastRewardBlock = getBlockNumber();

        emit PoolUpdated(_pid);
    }

    /**
     * @notice Deposit assets to SophonFarming
     * @param _pid pid of the pool
     * @param _amount amount of the deposit
     * @param _boostAmount amount to boost
     */
    function deposit(uint256 _pid, uint256 _amount, uint256 _boostAmount) external {
        poolInfo[_pid].lpToken.safeTransferFrom(
            msg.sender,
            address(this),
            _amount
        );

        _deposit(_pid, _amount, _boostAmount);
    }

    /**
     * @notice Deposit DAI to SophonFarming
     * @param _amount amount of the deposit
     * @param _boostAmount amount to boost
     */
    function depositDai(uint256 _amount, uint256 _boostAmount) external {
        IERC20(dai).safeTransferFrom(
            msg.sender,
            address(this),
            _amount
        );

        _depositPredefinedAsset(_amount, _amount, _boostAmount, PredefinedPool.sDAI);
    }

    /**
     * @notice Deposit stETH to SophonFarming
     * @param _amount amount of the deposit
     * @param _boostAmount amount to boost
     */
    function depositStEth(uint256 _amount, uint256 _boostAmount) external {
        uint256 beforeBalance = IERC20(stETH).balanceOf(address(this));
        IERC20(stETH).safeTransferFrom(
            msg.sender,
            address(this),
            _amount
        );
        uint256 _finalAmount = IERC20(stETH).balanceOf(address(this)) - beforeBalance;

        _depositPredefinedAsset(_finalAmount, _amount, _boostAmount, PredefinedPool.wstETH);
    }

    /**
     * @notice Deposit eETH to SophonFarming
     * @param _amount amount of the deposit
     * @param _boostAmount amount to boost
     */
    function depositeEth(uint256 _amount, uint256 _boostAmount) external {
        uint256 beforeBalance = IERC20(eETH).balanceOf(address(this));
        IERC20(eETH).safeTransferFrom(
            msg.sender,
            address(this),
            _amount
        );
        uint256 _finalAmount = IERC20(eETH).balanceOf(address(this)) - beforeBalance;

        _depositPredefinedAsset(_finalAmount, _amount, _boostAmount, PredefinedPool.weETH);
    }

    /**
     * @notice Deposit ETH to SophonFarming when specifying a pool
     * @param _boostAmount amount to boost
     * @param _predefinedPool specific pool type to deposit to
     */
    function depositEth(uint256 _boostAmount, PredefinedPool _predefinedPool) public payable {
        if (msg.value == 0) {
            revert NoEthSent();
        }

        uint256 _finalAmount = msg.value;
        if (_predefinedPool == PredefinedPool.wstETH) {
            _finalAmount = _ethTOstEth(_finalAmount);
        } else if (_predefinedPool == PredefinedPool.weETH) {
            _finalAmount = _ethTOeEth(_finalAmount);
        } else {
            revert InvalidDeposit();
        }

        _depositPredefinedAsset(_finalAmount, msg.value, _boostAmount, _predefinedPool);
    }

    /**
     * @notice Deposit WETH to SophonFarming when specifying a pool
     * @param _amount amount of the deposit
     * @param _boostAmount amount to boost
     * @param _predefinedPool specific pool type to deposit to
     */
    function depositWeth(uint256 _amount, uint256 _boostAmount, PredefinedPool _predefinedPool) external {
        IERC20(weth).safeTransferFrom(
            msg.sender,
            address(this),
            _amount
        );

        uint256 _finalAmount = _wethTOEth(_amount);
        if (_predefinedPool == PredefinedPool.wstETH) {
            _finalAmount = _ethTOstEth(_finalAmount);
        } else if (_predefinedPool == PredefinedPool.weETH) {
            _finalAmount = _ethTOeEth(_finalAmount);
        } else {
            revert InvalidDeposit();
        }

        _depositPredefinedAsset(_finalAmount, _amount, _boostAmount, _predefinedPool);
    }

    /**
     * @notice Deposit a predefined asset to SophonFarming
     * @param _amount amount of the deposit
     * @param _initalAmount amount of the deposit prior to conversions
     * @param _boostAmount amount to boost
     * @param _predefinedPool specific pool type to deposit to
     */
    function _depositPredefinedAsset(uint256 _amount, uint256 _initalAmount, uint256 _boostAmount, PredefinedPool _predefinedPool) internal {

        uint256 _finalAmount;

        if (_predefinedPool == PredefinedPool.sDAI) {
            _finalAmount = _daiTOsDai(_amount);
        } else if (_predefinedPool == PredefinedPool.wstETH) {
            _finalAmount = _stEthTOwstEth(_amount);
        } else if (_predefinedPool == PredefinedPool.weETH) {
            _finalAmount = _eethTOweEth(_amount);
        } else {
            revert InvalidDeposit();
        }

        // adjust boostAmount for the new asset
        _boostAmount = _boostAmount * _finalAmount / _initalAmount;

        _deposit(typeToId[_predefinedPool], _finalAmount, _boostAmount);
    }

    /**
     * @notice Deposit an asset to SophonFarming
     * @param _pid pid of the deposit
     * @param _depositAmount amount of the deposit
     * @param _boostAmount amount to boost
     */
    function _deposit(uint256 _pid, uint256 _depositAmount, uint256 _boostAmount) internal {
        if (isFarmingEnded()) {
            revert FarmingIsEnded();
        }
        if (_depositAmount == 0) {
            revert InvalidDeposit();
        }
        if (_boostAmount > _depositAmount) {
            revert BoostTooHigh(_depositAmount);
        }

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);

        uint256 userAmount = user.amount;

        user.rewardSettled =
            userAmount *
            pool.accPointsPerShare /
            1e18 +
            user.rewardSettled -
            user.rewardDebt;

        // booster purchase proceeds
        heldProceeds[_pid] = heldProceeds[_pid] + _boostAmount;

        // deposit amount is reduced by amount of the deposit to boost
        _depositAmount = _depositAmount - _boostAmount;

        // set deposit amount
        user.depositAmount = user.depositAmount + _depositAmount;
        pool.depositAmount = pool.depositAmount + _depositAmount;

        // apply the boost multiplier
        _boostAmount = _boostAmount * boosterMultiplier / 1e18;

        user.boostAmount = user.boostAmount + _boostAmount;
        pool.boostAmount = pool.boostAmount + _boostAmount;

        // userAmount is increased by remaining deposit amount + full boosted amount
        userAmount = userAmount + _depositAmount + _boostAmount;

        user.amount = userAmount;
        pool.amount = pool.amount + _depositAmount + _boostAmount;

        user.rewardDebt = userAmount *
            pool.accPointsPerShare /
            1e18;

        emit Deposit(msg.sender, _pid, _depositAmount, _boostAmount);
    }

    /**
     * @notice Increase boost from existing deposits
     * @param _pid pid to pool
     * @param _boostAmount amount to boost
     */
    function increaseBoost(uint256 _pid, uint256 _boostAmount) external {
        if (isFarmingEnded()) {
            revert FarmingIsEnded();
        }

        if (_boostAmount == 0) {
            revert BoostIsZero();
        }

        uint256 maxAdditionalBoost = getMaxAdditionalBoost(msg.sender, _pid);
        if (_boostAmount > maxAdditionalBoost) {
            revert BoostTooHigh(maxAdditionalBoost);
        }

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);

        uint256 userAmount = user.amount;

        user.rewardSettled =
            userAmount *
            pool.accPointsPerShare /
            1e18 +
            user.rewardSettled -
            user.rewardDebt;

        // booster purchase proceeds
        heldProceeds[_pid] = heldProceeds[_pid] + _boostAmount;

        // user's remaining deposit is reduced by amount of the deposit to boost
        user.depositAmount = user.depositAmount - _boostAmount;
        pool.depositAmount = pool.depositAmount - _boostAmount;

        // apply the multiplier
        uint256 finalBoostAmount = _boostAmount * boosterMultiplier / 1e18;

        user.boostAmount = user.boostAmount + finalBoostAmount;
        pool.boostAmount = pool.boostAmount + finalBoostAmount;

        // user amount is increased by the full boosted amount - deposit amount used to boost
        userAmount = userAmount + finalBoostAmount - _boostAmount;

        user.amount = userAmount;
        pool.amount = pool.amount + finalBoostAmount - _boostAmount;

        user.rewardDebt = userAmount *
            pool.accPointsPerShare /
            1e18;

        emit IncreaseBoost(msg.sender, _pid, finalBoostAmount);
    }

    /**
     * @notice Returns max additional boost amount allowed to boost current deposits
     * @dev total allowed boost is 100% of total deposit
     * @param _user user in pool
     * @param _pid pid of pool
     * @return uint256 max additional boost
     */
    function getMaxAdditionalBoost(address _user, uint256 _pid) public view returns (uint256) {
        return userInfo[_pid][_user].depositAmount;
    }

    /**
     * @notice Withdraw an asset to SophonFarming
     * @param _pid pid of the withdraw
     * @param _withdrawAmount amount of the withdraw
     */
    function withdraw(uint256 _pid, uint256 _withdrawAmount) external {
        if (isWithdrawPeriodEnded() && msg.sender != PENDLE_EXCEPTION) {
            revert WithdrawNotAllowed();
        }
        if (_withdrawAmount == 0) {
            revert WithdrawIsZero();
        }

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);

        uint256 userDepositAmount = user.depositAmount;

        if (_withdrawAmount == type(uint256).max) {
            _withdrawAmount = userDepositAmount;
        } else if (_withdrawAmount > userDepositAmount) {
            revert WithdrawTooHigh(userDepositAmount);
        }

        uint256 userAmount = user.amount;

        user.rewardSettled =
            userAmount *
            pool.accPointsPerShare /
            1e18 +
            user.rewardSettled -
            user.rewardDebt;

        user.depositAmount = userDepositAmount - _withdrawAmount;
        pool.depositAmount = pool.depositAmount - _withdrawAmount;

        userAmount = userAmount - _withdrawAmount;

        user.amount = userAmount;
        pool.amount = pool.amount - _withdrawAmount;

        user.rewardDebt = userAmount *
            pool.accPointsPerShare /
            1e18;

        pool.lpToken.safeTransfer(msg.sender, _withdrawAmount);

        emit Withdraw(msg.sender, _pid, _withdrawAmount);
    }

    
    /**
     * @notice Permissionless function to allow anyone to bridge during the correct period
     * @param _pid pid to bridge
     * @param _mintValue _mintValue SOPH gas price
     */
    
    function bridgePool(uint256 _pid, uint256 _mintValue, address _sophToken) external payable {
        // USDC exception
        if (_pid == 7) {
            revert Unauthorized();
        }

        _bridgePool(_pid, _mintValue, _sophToken, address(bridge.sharedBridge()));
    }

    function _bridgePool(uint256 _pid, uint256 _mintValue, address _sophToken, address sharedBridge) internal {

        if (!isFarmingEnded() || !isWithdrawPeriodEnded() || isBridged[_pid]) {
            revert Unauthorized();
        }

        updatePool(_pid);
        PoolInfo storage pool = poolInfo[_pid];

        if (pool.depositAmount == 0 || address(bridge) == address(0) || pool.l2Farm == address(0)) {
            revert BridgeInvalid();
        }
        uint256 depositAmount = IERC20(pool.lpToken).balanceOf(address(this));

        if (_pid == PEPE_PID) {
            UserInfo storage user = userInfo[PEPE_PID][PENDLE_EXCEPTION];
            depositAmount -= user.depositAmount;
        }

        L2TransactionRequestTwoBridgesOuter memory _request = L2TransactionRequestTwoBridgesOuter({
            chainId: CHAINID,
            mintValue: _mintValue,
            l2Value: 0,
            l2GasLimit: 2000000,
            l2GasPerPubdataByteLimit: 800,
            refundRecipient: 0x50B238788747B26c408681283D148659F9da7Cf9,
            secondBridgeAddress: sharedBridge,
            secondBridgeValue: 0,
            secondBridgeCalldata: abi.encode(pool.lpToken, depositAmount, pool.l2Farm)
        });

        if (pool.lpToken.allowance(address(this), _request.secondBridgeAddress) < depositAmount) {
            pool.lpToken.forceApprove(_request.secondBridgeAddress, type(uint256).max);
        }
        IERC20(_sophToken).safeTransferFrom(msg.sender, address(this), _mintValue);
        IERC20(_sophToken).safeIncreaseAllowance(address(bridge.sharedBridge()), _mintValue);
        
        // Actual values are pending the launch of Sophon testnet
        bridge.requestL2TransactionTwoBridges(_request);

        isBridged[_pid] = true;
        emit BridgePool(msg.sender, _pid, depositAmount);
    }


    // bridge USDC
    function bridgeUSDC(uint256 _mintValue, address _sophToken) external {
        uint256 _pid = 7;
        // IBridgehub _bridge = IBridgehub(address(0));
        address sharedBridge = 0xf553E6D903AA43420ED7e3bc2313bE9286A8F987; // USDC L1USDCBridge
        _bridgePool(_pid, _mintValue, _sophToken, sharedBridge);

    }

    /**
     * @notice Set L2Farming contract for particular pool
     * @param _pid pid to bridge
     * @param _l2Farm address of the contract for farming on L2 side
     */
    function setL2Farm(uint256 _pid, address _l2Farm) external onlyOwner {
        if (_pid >= poolInfo.length) {
            revert PoolDoesNotExist();
        }

        if (_l2Farm == address(0)) {
            revert ZeroAddress();
        }

        poolInfo[_pid].l2Farm = _l2Farm;
    }


    /**
     * @notice Called by an admin if a bridge process to Sophon fails
     * @param _pid pid of the failed bridge to revert
     */
    function revertFailedBridge(
        address _l1SharedBridge,
        uint256 _pid,       
        uint256 _chainId,
        address _depositSender,
        address _l1Token,
        uint256 _amount,
        bytes32 _l2TxHash,
        uint256 _l2BatchNumber,
        uint256 _l2MessageIndex,
        uint16 _l2TxNumberInBatch,
        bytes32[] calldata _merkleProof) external onlyOwner {

        if (address(poolInfo[_pid].lpToken) == address(0)) {
            revert PoolDoesNotExist();
        }
        
        IL1SharedBridge(_l1SharedBridge).claimFailedDeposit(
            _chainId,
            _depositSender,
            _l1Token,
            _amount,
            _l2TxHash,
            _l2BatchNumber,
            _l2MessageIndex,
            _l2TxNumberInBatch,
            _merkleProof
        );

        isBridged[_pid] = false;
        emit RevertFailedBridge(_pid);
    }

    /**
     * @notice Called by an whitelisted admin to transfer points to another user
     * @param _pid pid of the pool to transfer points from
     * @param _sender address to send accrued points
     * @param _receiver address to receive accrued points
     * @param _transferAmount amount of points to transfer
     */
    function transferPoints(uint256 _pid, address _sender, address _receiver, uint256 _transferAmount) external {

        if (!whitelist[msg.sender][_sender]) {
            revert TransferNotAllowed();
        }

        if (_sender == _receiver || _receiver == address(this) || _transferAmount == 0) {
            revert InvalidTransfer();
        }

        PoolInfo storage pool = poolInfo[_pid];

        if (address(pool.lpToken) == address(0)) {
            revert PoolDoesNotExist();
        }

        updatePool(_pid);
        uint256 accPointsPerShare = pool.accPointsPerShare;

        UserInfo storage userFrom = userInfo[_pid][_sender];
        UserInfo storage userTo = userInfo[_pid][_receiver];

        uint256 userFromAmount = userFrom.amount;
        uint256 userToAmount = userTo.amount;

        uint userFromRewardSettled =
            userFromAmount *
            accPointsPerShare /
            1e18 +
            userFrom.rewardSettled -
            userFrom.rewardDebt;

        if (_transferAmount == type(uint256).max) {
            _transferAmount = userFromRewardSettled;
        } else if (_transferAmount > userFromRewardSettled) {
            revert TransferTooHigh(userFromRewardSettled);
        }

        userFrom.rewardSettled = userFromRewardSettled - _transferAmount;

        userTo.rewardSettled =
            userToAmount *
            accPointsPerShare /
            1e18 +
            userTo.rewardSettled -
            userTo.rewardDebt +
            _transferAmount;

        userFrom.rewardDebt = userFromAmount *
            accPointsPerShare /
            1e18;

        userTo.rewardDebt = userToAmount *
            accPointsPerShare /
            1e18;

        emit TransferPoints(_sender, _receiver, _pid, _transferAmount);
    }

    /**
     * @notice Converts WETH to ETH
     * @dev WETH withdrawl
     * @param _amount in amount
     * @return uint256 out amount
     */
    function _wethTOEth(uint256 _amount) internal returns (uint256) {
        // unwrap weth to eth
        IWeth(weth).withdraw(_amount);
        return _amount;
    }

    /**
     * @notice Converts ETH to stETH
     * @dev Lido
     * @param _amount in amount
     * @return uint256 out amount
     */
    function _ethTOstEth(uint256 _amount) internal returns (uint256) {
        return IstETH(stETH).getPooledEthByShares(
            IstETH(stETH).submit{value: _amount}(owner())
        );
    }

    /**
     * @notice Converts stETH to wstETH
     * @dev Lido
     * @param _amount in amount
     * @return uint256 out amount
     */
    function _stEthTOwstEth(uint256 _amount) internal returns (uint256) {
        // wrap returns exact amount of wstETH
        return IwstETH(wstETH).wrap(_amount);
    }

    /**
     * @notice Converts ETH to eETH
     * @dev ether.fi
     * @param _amount in amount
     * @return uint256 out amount
     */
    function _ethTOeEth(uint256 _amount) internal returns (uint256) {
        return IeETHLiquidityPool(eETHLiquidityPool).amountForShare(
            IeETHLiquidityPool(eETHLiquidityPool).deposit{value: _amount}(owner())
        );
    }

    /**
     * @notice Converts eETH to weETH
     * @dev ether.fi
     * @param _amount in amount
     * @return uint256 out amount
     */
    function _eethTOweEth(uint256 _amount) internal returns (uint256) {
        // wrap returns exact amount of weETH
        return IweETH(weETH).wrap(_amount);
    }

    /**
     * @notice Converts DAI to sDAI
     * @dev MakerDao
     * @param _amount in amount
     * @return uint256 out amount
     */
    function _daiTOsDai(uint256 _amount) internal returns (uint256) {
        // deposit DAI to sDAI
        return IsDAI(sDAI).deposit(_amount, address(this));
    }


    /**
     * @notice Returns the current block number
     * @dev Included to help with testing since it can be overridden for custom functionality
     * @return uint256 current block number
     */
    function getBlockNumber() virtual public view returns (uint256) {
        return block.number;
    }

    /**
     * @notice Returns info about each pool
     * @return poolInfos all pool info
     */
    function getPoolInfo() external view returns (PoolInfo[] memory poolInfos) {
        uint256 length = poolInfo.length;
        poolInfos = new PoolInfo[](length);
        for(uint256 pid = 0; pid < length; ++pid) {
            poolInfos[pid] = poolInfo[pid];
            (, poolInfos[pid].totalRewards) = _settlePool(pid);
        }
    }

    /**
     * @notice Returns user info for a list of users
     * @param _users list of users
     * @return userInfos optimized user info
     */
    function getOptimizedUserInfo(address[] memory _users) external view returns (uint256[4][][] memory userInfos) {
        uint256 usersLen = _users.length;
        userInfos = new uint256[4][][](usersLen);
        uint256 poolLen = poolInfo.length;
        for(uint256 i = 0; i < usersLen; i++) {
            address _user = _users[i];
            userInfos[i] = new uint256[4][](poolLen);
            for(uint256 pid = 0; pid < poolLen; ++pid) {
                UserInfo memory uinfo = userInfo[pid][_user];
                userInfos[i][pid][0] = uinfo.amount;
                userInfos[i][pid][1] = uinfo.boostAmount;
                userInfos[i][pid][2] = uinfo.depositAmount;
                userInfos[i][pid][3] = _pendingPoints(pid, _user);
            }
        }
    }

    /**
     * @notice Returns accrued points for a list of users
     * @param _users list of users
     * @return pendings accured points for user
     */
    function getPendingPoints(address[] memory _users) external view returns (uint256[][] memory pendings) {
        uint256 usersLen = _users.length;
        pendings = new uint256[][](usersLen);
        uint256 poolLen = poolInfo.length;
        for(uint256 i = 0; i < usersLen; i++) {
            address _user = _users[i];
            pendings[i] = new uint256[](poolLen);
            for(uint256 pid = 0; pid < poolLen; ++pid) {
                pendings[i][pid] = _pendingPoints(pid, _user);
            }
        }
    }
}
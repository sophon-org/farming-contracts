// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./interfaces/IWeth.sol";
import "./interfaces/IstETH.sol";
import "./interfaces/IwstETH.sol";
import "./interfaces/IsDAI.sol";
import "./interfaces/IeETHLiquidityPool.sol";
import "./interfaces/IweETH.sol";
import "./interfaces/IStork.sol";
import "../proxies/Upgradeable2Step.sol";
import "./SophonFarmingState.sol";

/**
 * @title Sophon Farming Contract
 * @author Sophon
 */
contract SophonFarmingL2 is Upgradeable2Step, SophonFarmingState {
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

    /// @notice Emitted when the the updatePool function is called
    event PoolUpdated(uint256 indexed pid);

    /// @notice Emitted when setPointsPerBlock is called
    event SetPointsPerBlock(uint256 oldValue, uint256 newValue);

    /// @notice Emitted when the pool price feed data is updated
    event SetPriceFeedData(bytes32 newHash, uint256 newStaleSeconds);

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
    error OnlyMerkle();
    error DuplicatePriceFeed();
    error PriceFeedNotSet();
    error InvalidStaleSeconds();
    error InvalidPrice(uint256 pid, uint256 price);
    error InvalidValue(uint256 value);

    address public immutable MERKLE;

    IStork public immutable stork;

    /**
     * @notice Construct SophonFarming
     */
    constructor(address _MERKLE, address _stork) {
        MERKLE = _MERKLE;

        if (_stork == address(0)) {
            revert ZeroAddress();
        }
        stork = IStork(_stork);
    }

    // Order is important
    function addPool(
        uint256 _pid,
        IERC20 _lpToken,
        address _l2Farm,
        uint256 _amount,
        uint256 _boostAmount,
        uint256 _depositAmount,
        uint256 _allocPoint,
        uint256 _lastRewardBlock,
        uint256 _accPointsPerShare,
        uint256 _totalRewards,
        string memory _description,
        uint256 _heldProceeds
    ) public onlyOwner {
        require(_amount == _boostAmount + _depositAmount, "balances don't match");

        PoolInfo memory pool = PoolInfo({
            lpToken: _lpToken,
            l2Farm: _l2Farm,
            amount: _amount,
            boostAmount: _boostAmount,
            depositAmount: _depositAmount,
            allocPoint: 0,
            lastRewardBlock: _lastRewardBlock,
            accPointsPerShare: 0,
            totalRewards: _totalRewards,
            description: _description
        });

        if (_pid < poolInfo.length) {
            poolInfo[_pid] = pool;
        } else if (_pid == poolInfo.length) {
            poolInfo.push(pool);
        } else {
            revert("wrong pid");
        }
        heldProceeds[_pid] = _heldProceeds;
        poolExists[address(_lpToken)] = true;
        // require(IERC20(_lpToken).balanceOf(address(this)) >= _amount, "balances don't match");
    }

    function updateUserInfo(address _user, uint256 _pid, UserInfo memory _userFromClaim) public {
        if (msg.sender != MERKLE) revert OnlyMerkle();
        require(_userFromClaim.amount == _userFromClaim.boostAmount + _userFromClaim.depositAmount, "balances don't match");

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        massUpdatePools(true);

        uint256 userAmount = user.amount;

        user.rewardSettled =
            user.amount *
            pool.accPointsPerShare /
            1e18 +
            user.rewardSettled -
            user.rewardDebt;

        // _userFromClaim.rewardDebt is ignored since user.rewardSettled is already settled
        user.rewardSettled = user.rewardSettled + _userFromClaim.rewardSettled;

        user.boostAmount = user.boostAmount + _userFromClaim.boostAmount;
        pool.boostAmount = pool.boostAmount + _userFromClaim.boostAmount;

        user.depositAmount = user.depositAmount + _userFromClaim.depositAmount;
        pool.depositAmount = pool.depositAmount + _userFromClaim.depositAmount;

        user.amount = user.amount + _userFromClaim.amount;
        pool.amount = pool.amount + _userFromClaim.amount;

        user.rewardDebt = user.amount *
            pool.accPointsPerShare /
            1e18;
    }

    /**
     * @notice Adds a new pool to the farm. Can only be called by the owner.
     * @param _lpToken lpToken address
     * @param _priceFeedHash lpToken price feed hash
     * @param _staleSeconds lpToken price stale seconds
     * @param _emissionsMultiplier multiplier for emissions fine tuning; use 0 or 1e18 for 1x
     * @param _description description of new pool
     * @param _poolStartBlock block at which points start to accrue for the pool
     * @param _newPointsPerBlock update global points per block; 0 means no update
     * @return uint256 The pid of the newly created asset
     */
    function add(address _lpToken, bytes32 _priceFeedHash, uint256 _staleSeconds, uint256 _emissionsMultiplier, string memory _description, uint256 _poolStartBlock, uint256 _newPointsPerBlock) public onlyOwner returns (uint256) {
        if (_lpToken == address(0)) {
            revert ZeroAddress();
        }
        if (poolExists[_lpToken]) {
            revert PoolExists();
        }
        if (isFarmingEnded()) {
            revert FarmingIsEnded();
        }

        if (_priceFeedHash == 0) {
            revert PriceFeedNotSet();
        }
        if (_staleSeconds == 0) {
            revert InvalidStaleSeconds();
        }

        if (_newPointsPerBlock != 0) {
            setPointsPerBlock(_newPointsPerBlock);
        } else {
            massUpdatePools();
        }

        uint256 lastRewardBlock =
            getBlockNumber() > _poolStartBlock ? getBlockNumber() : _poolStartBlock;
        poolExists[_lpToken] = true;

        uint256 pid = poolInfo.length;

        poolInfo.push(
            PoolInfo({
                lpToken: IERC20(_lpToken),
                l2Farm: address(0),
                amount: 0,
                boostAmount: 0,
                depositAmount: 0,
                allocPoint: 0,
                lastRewardBlock: lastRewardBlock,
                accPointsPerShare: 0,
                totalRewards: 0,
                description: _description
            })
        );

        if (_emissionsMultiplier == 0) {
            // set multiplier to 1x
            _emissionsMultiplier = 1e18;
        }

        PoolValue storage pv = poolValue[pid];
        pv.emissionsMultiplier = _emissionsMultiplier;
        pv.feedHash = _priceFeedHash;
        pv.staleSeconds = _staleSeconds;
        emit SetPriceFeedData(_priceFeedHash, _staleSeconds);

        emit Add(_lpToken, pid, 0);

        return pid;
    }

    /**
     * @notice Updates the given pool's allocation point. Can only be called by the owner.
     * @param _pid The pid to update
     * @param _emissionsMultiplier multiplier for emissions fine tuning; use 0 for no update OR 1e18 for 1x
     * @param _poolStartBlock block at which points start to accrue for the pool; 0 means no update
     * @param _newPointsPerBlock update global points per block; 0 means no update
     */
    function set(uint256 _pid, uint256 _emissionsMultiplier, uint256 _poolStartBlock, uint256 _newPointsPerBlock) external onlyOwner {
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

        if (_emissionsMultiplier != 0) {
            poolValue[_pid].emissionsMultiplier = _emissionsMultiplier;
        }

        // pool starting block is updated if farming hasn't started and _poolStartBlock is non-zero
        if (_poolStartBlock != 0 && getBlockNumber() < pool.lastRewardBlock) {
            pool.lastRewardBlock =
                getBlockNumber() > _poolStartBlock ? getBlockNumber() : _poolStartBlock;
        }

        emit Set(lpToken, _pid, 0);
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
        if (_endBlock != 0 && getBlockNumber() > _endBlock) {
            return true;
        } else {
            return false;
        }
    }

    /**
     * @notice Checks if the withdrawal period is ended
     * @return bool True if withdrawal period is ended
     */
    function isWithdrawPeriodEnded() public view returns (bool) {
        uint256 _endBlockForWithdrawals = endBlockForWithdrawals;
        if (_endBlockForWithdrawals != 0 && getBlockNumber() > _endBlockForWithdrawals) {
            return true;
        } else {
            return false;
        }
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
        if (_pointsPerBlock < 1e18 || _pointsPerBlock > 1000e18) {
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
        for(uint i = 0; i < _users.length; i++) {
            whitelist[_userAdmin][_users[i]] = _isInWhitelist;
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

    // zero hash allowed; blocks updates to the pool
    // zero stale seconds means no change
    function setPriceFeedData(uint256 _pid, bytes32 _newHash, uint256 _newStaleSeconds, uint256 _emissionsMultiplier) external onlyOwner {
        PoolValue storage pv = poolValue[_pid];
        if (_newHash == pv.feedHash) {
            revert DuplicatePriceFeed();
        }

        pv.feedHash = _newHash;
        pv.staleSeconds = _newStaleSeconds;
        pv.emissionsMultiplier = _emissionsMultiplier;

        emit SetPriceFeedData(_newHash, _newStaleSeconds);
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
        uint256 _totalValue = totalValue;
        if (getBlockNumber() > pool.lastRewardBlock && lpSupply != 0 && _totalValue != 0) {
            uint256 blockMultiplier = _getBlockMultiplier(pool.lastRewardBlock, getBlockNumber());

            uint256 pointReward =
                blockMultiplier *
                pointsPerBlock *
                poolValue[_pid].lastValue /
                _totalValue;

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
        massUpdatePools(false);
    }

    /**
     * @notice Update accounting of all pools
     * @param _silent emit event if false
     */
    function massUpdatePools(bool _silent) public {
        uint256 length = poolInfo.length;
        for(uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid, _silent);
        }
    }

    /**
     * @notice Updating accounting of a single pool
     * @param _pid pid to update
     */
    function updatePool(uint256 _pid) public {
        updatePool(_pid, false);
    }

    /**
     * @notice Updating accounting of a single pool
     * @param _pid pid to update
     * @param _silent emit event if false
     */
    function updatePool(uint256 _pid, bool _silent) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (getBlockNumber() <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.amount;
        uint256 _pointsPerBlock = pointsPerBlock;
        if (lpSupply == 0 || _pointsPerBlock == 0) {
            pool.lastRewardBlock = getBlockNumber();
            return;
        }

        /* START Update Pool Weighting Block */
        PoolValue storage pv = poolValue[_pid];
        bytes32 feedHash = pv.feedHash;
        if (feedHash == 0) {
            //revert PriceFeedNotSet();
            pool.lastRewardBlock = getBlockNumber();
            return;
        }

        IStork.TemporalNumericValue memory storkValue = stork.getTemporalNumericValueUnsafeV1(feedHash);

        if (block.timestamp - (storkValue.timestampNs / 1000000000) > pv.staleSeconds) {
            // stale price
            pool.lastRewardBlock = getBlockNumber();
            return;
        }

        if (storkValue.quantizedValue <= 0) {
            // invalid price
            pool.lastRewardBlock = getBlockNumber();
            return;
        }
        uint256 newPrice = uint256(uint192(storkValue.quantizedValue));

        uint256 newValue = lpSupply * newPrice / 1e18;
        newValue = newValue * pv.emissionsMultiplier / 1e18;
        if (newValue == 0) {
            //revert InvalidValue(newValue);
            pool.lastRewardBlock = getBlockNumber();
            return;
        }

        totalValue = totalValue - pv.lastValue + newValue;
        pv.lastValue = newValue;
        /* END Update Pool Weighting Block */

        uint256 blockMultiplier = _getBlockMultiplier(pool.lastRewardBlock, getBlockNumber());
        uint256 pointReward =
            blockMultiplier *
            _pointsPerBlock *
            newValue /
            totalValue;

        pool.totalRewards = pool.totalRewards + pointReward / 1e18;

        pool.accPointsPerShare = pointReward /
            lpSupply +
            pool.accPointsPerShare;

        pool.lastRewardBlock = getBlockNumber();

        if (!_silent) {
            emit PoolUpdated(_pid);
        }
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
        massUpdatePools(true);

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
        massUpdatePools(true);

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
        if (isWithdrawPeriodEnded()) {
            revert WithdrawNotAllowed();
        }
        if (_withdrawAmount == 0) {
            revert WithdrawIsZero();
        }

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        massUpdatePools(true);

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

        massUpdatePools(true);
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
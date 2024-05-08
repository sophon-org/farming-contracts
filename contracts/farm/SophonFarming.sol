// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.24;

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

contract SophonFarming is Upgradeable2Step, SophonFarmingState {
    using SafeERC20 for IERC20;

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

    address public immutable dai;
    address public immutable sDAI;
    address public immutable weth;
    address public immutable stETH;
    address public immutable wstETH;
    address public immutable eETH;
    address public immutable eETHLiquidityPool;
    address public immutable weETH;

    modifier nonDuplicated(address _lpToken) {
        require(!poolExists[_lpToken], "pool exists");
        _;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    constructor(address[8] memory tokens_) {
        dai = tokens_[0];
        sDAI = tokens_[1];
        weth = tokens_[2];
        stETH = tokens_[3];
        wstETH = tokens_[4];
        eETH = tokens_[5];
        eETHLiquidityPool = tokens_[6];
        weETH = tokens_[7];
    }

    receive() external payable {
        if (msg.sender == weth) {
            return;
        }

        depositEth(0, PredefinedPool.wstETH);
    }

    function initialize(uint256 ethAllocPoint_, uint256 sDAIAllocPoint_, uint256 _pointsPerBlock, uint256 _startBlock, uint256 _boosterMultiplier) public virtual onlyOwner {
        if (_initialized) {
            revert AlreadyInitialized();
        }

        pointsPerBlock = _pointsPerBlock;

        if (_startBlock == 0) {
            revert InvalidStartBlock();
        }
        startBlock = _startBlock;

        boosterMultiplier = _boosterMultiplier;

        poolExists[dai] = true;
        poolExists[weth] = true;
        poolExists[stETH] = true;
        poolExists[eETH] = true;

        // sDAI
        typeToId[PredefinedPool.sDAI] = add(sDAIAllocPoint_, sDAI, "sDAI", "sDAI", false);
        IERC20(dai).approve(sDAI, 2**256-1);

        // wstETH
        typeToId[PredefinedPool.wstETH] = add(ethAllocPoint_, wstETH, "wstETH", "wstETH", false);
        IERC20(stETH).approve(wstETH, 2**256-1);

        // weETH
        typeToId[PredefinedPool.weETH] = add(ethAllocPoint_, weETH, "weETH", "weETH", false);
        IERC20(eETH).approve(weETH, 2**256-1);

        _initialized = true;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    function add(uint256 _allocPoint, address _lpToken, string memory _poolShareSymbol, string memory _description, bool _withUpdate) public onlyOwner nonDuplicated(_lpToken) returns (uint256) {
        if (isFarmingEnded()) {
            revert FarmingIsEnded();
        }
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock =
            getBlockNumber() > startBlock ? getBlockNumber() : startBlock;
        totalAllocPoint = totalAllocPoint + _allocPoint;
        poolExists[_lpToken] = true;

        uint256 pid = poolInfo.length;
        PoolShareToken poolShareToken = new PoolShareToken(_poolShareSymbol, pid);

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
                poolShareToken: poolShareToken,
                description: _description
            })
        );

        emit Add(_lpToken, pid, address(poolShareToken), _allocPoint);

        return pid;
    }

    // Update the given pool's allocation point. Can only be called by the owner.
    function set(uint256 _pid, uint256 _allocPoint, bool _withUpdate) public onlyOwner {
        if (isFarmingEnded()) {
            revert FarmingIsEnded();
        }
        if (_withUpdate) {
            massUpdatePools();
        }

        PoolInfo storage pool = poolInfo[_pid];
        require(address(pool.lpToken) != address(0) && poolExists[address(pool.lpToken)], "pool not exists");
        totalAllocPoint = totalAllocPoint - pool.allocPoint + _allocPoint;
        pool.allocPoint = _allocPoint;

        if (getBlockNumber() < pool.lastRewardBlock) {
            pool.lastRewardBlock = startBlock;
        }
    }

    function isFarmingEnded() public view returns (bool) {
        uint256 _endBlock = endBlock;
        if (_endBlock != 0 && getBlockNumber() > _endBlock) {
            return true;
        } else {
            return false;
        }
    }

    function isExitPeriodEnded() public view returns (bool) {
        uint256 _endBlockForWithdrawals = endBlockForWithdrawals;
        if (_endBlockForWithdrawals != 0 && getBlockNumber() > _endBlockForWithdrawals) {
            return true;
        } else {
            return false;
        }
    }

    function setBridge(BridgeLike _bridge) public onlyOwner {
        bridge = _bridge;
    }

    function setBridgeForPool(uint256 _pid, address _l2Farm) public onlyOwner {
        poolInfo[_pid].l2Farm = _l2Farm;
    }

    function setStartBlock(uint256 _startBlock) public onlyOwner {
        if (_startBlock == 0 || (endBlock != 0 && _startBlock >= endBlock)) {
            revert InvalidStartBlock();
        }
        if (getBlockNumber() > startBlock) {
            revert FarmingIsStarted();
        }
        startBlock = _startBlock;
    }

    function setEndBlocks(uint256 _endBlock, uint256 _withdrawalBlocks) public onlyOwner {
        uint256 _endBlockForWithdrawals;
        if (_endBlock != 0) {
            if (_endBlock <= startBlock || getBlockNumber() > _endBlock) {
                revert InvalidEndBlock();
            }
            if (isFarmingEnded()) {
                revert FarmingIsEnded();
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

    function setPointsPerBlock(uint256 _pointsPerBlock) public onlyOwner {
        if (isFarmingEnded()) {
            revert FarmingIsEnded();
        }
        massUpdatePools();
        pointsPerBlock = _pointsPerBlock;
    }

    function setBoosterMultiplier(uint256 _boosterMultiplier) public onlyOwner {
        if (isFarmingEnded()) {
            revert FarmingIsEnded();
        }
        massUpdatePools();
        boosterMultiplier = _boosterMultiplier;
    }

    function getBlockMultiplier(uint256 _from, uint256 _to) public view returns (uint256) {
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

    function _handleTransfer(uint256 _pid, address _from, address _to, uint256 _amount, uint256 _depositBeforeTransfer) external {

        if (_from == _to || _to == address(this) || _amount == 0) {
            revert InvalidTransfer();
        }

        PoolInfo storage pool = poolInfo[_pid];
        if (msg.sender != address(poolInfo[_pid].poolShareToken)) {
            revert Unauthorized();
        }

        updatePool(_pid);
        uint256 accPointsPerShare = pool.accPointsPerShare;

        UserInfo storage userFrom = userInfo[_pid][_from];
        UserInfo storage userTo = userInfo[_pid][_to];

        uint256 userFromAmount = userFrom.amount;
        uint256 userToAmount = userTo.amount;

        uint256 rewardSettledFrom =
            userFromAmount *
            accPointsPerShare /
            1e18 +
            userFrom.rewardSettled -
            userFrom.rewardDebt;

        uint256 rewardSettledTo =
            userToAmount *
            accPointsPerShare /
            1e18 +
            userTo.rewardSettled -
            userTo.rewardDebt;

        // adjust balances

        userFromAmount = userFromAmount - _amount;
        userFrom.amount = userFromAmount;
        userFrom.rewardDebt = userFromAmount *
            accPointsPerShare /
            1e18;

        userToAmount = userToAmount + _amount;
        userTo.amount = userToAmount;
        userTo.rewardDebt = userToAmount *
            accPointsPerShare /
            1e18;

        assert(_amount <= _depositBeforeTransfer);
        uint256 pointsTransferAmount = rewardSettledFrom * _amount / _depositBeforeTransfer;

        userFrom.rewardSettled = rewardSettledFrom - pointsTransferAmount;
        userTo.rewardSettled = rewardSettledTo + pointsTransferAmount;

    }

    function _pendingPoints(uint256 _pid, address _user) internal view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];

        uint256 accPointsPerShare = pool.accPointsPerShare * 1e18;

        uint256 lpSupply = pool.amount;
        if (getBlockNumber() > pool.lastRewardBlock && lpSupply != 0) {
            uint256 blockMultiplier = getBlockMultiplier(pool.lastRewardBlock, getBlockNumber());

            uint256 pointReward =
                blockMultiplier *
                pointsPerBlock *
                pool.allocPoint /
                totalAllocPoint;

            accPointsPerShare = pointReward *
                1e18 /
                lpSupply +
                accPointsPerShare;
        }

        return user.amount *
            accPointsPerShare /
            1e36 +
            user.rewardSettled -
            user.rewardDebt;
    }

    function pendingPoints(uint256 _pid, address _user) external view returns (uint256) {
        return _pendingPoints(_pid, _user);
    }


    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for(uint256 pid = 0; pid < length;) {
            updatePool(pid);
            unchecked { ++pid; }
        }
    }

    // Update reward variables of the given pool to be up-to-date.
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
        uint256 blockMultiplier = getBlockMultiplier(pool.lastRewardBlock, getBlockNumber());
        uint256 pointReward =
            blockMultiplier *
            _pointsPerBlock *
            _allocPoint /
            totalAllocPoint;

        pool.accPointsPerShare = pointReward /
            /*1e6 /*/
            lpSupply +
            pool.accPointsPerShare;

        pool.lastRewardBlock = getBlockNumber();
    }

    // Deposit LP tokens to SophonFarming for Point allocation.
    function deposit(uint256 _pid, uint256 _amount, uint256 _boostAmount) external {
        poolInfo[_pid].lpToken.safeTransferFrom(
            msg.sender,
            address(this),
            _amount
        );

        _deposit(_pid, _amount, _boostAmount);
    }

    function depositDai(uint256 _amount, uint256 _boostAmount) external {
        IERC20(dai).safeTransferFrom(
            msg.sender,
            address(this),
            _amount
        );

        _depositPredefinedAsset(_amount, _amount, _boostAmount, PredefinedPool.sDAI);
    }

    function depositStEth(uint256 _amount, uint256 _boostAmount) external {
        IERC20(stETH).safeTransferFrom(
            msg.sender,
            address(this),
            _amount
        );

        _depositPredefinedAsset(_amount, _amount, _boostAmount, PredefinedPool.wstETH);
    }

    function depositeEth(uint256 _amount, uint256 _boostAmount) external {
        IERC20(eETH).safeTransferFrom(
            msg.sender,
            address(this),
            _amount
        );

        _depositPredefinedAsset(_amount, _amount, _boostAmount, PredefinedPool.weETH);
    }

    function depositEth(uint256 _boostAmount, PredefinedPool predefinedPool) public payable {
        if (msg.value == 0) {
            revert NoEthSent();
        }

        uint256 _finalAmount = msg.value;
        if (predefinedPool == PredefinedPool.wstETH) {
            _finalAmount = _ethTOstEth(_finalAmount);
        } else if (predefinedPool == PredefinedPool.weETH) {
            _finalAmount = _ethTOeEth(_finalAmount);
        }

        _depositPredefinedAsset(_finalAmount, msg.value, _boostAmount, predefinedPool);
    }

    function depositWeth(uint256 _amount, uint256 _boostAmount, PredefinedPool predefinedPool) external {
        IERC20(weth).safeTransferFrom(
            msg.sender,
            address(this),
            _amount
        );

        uint256 _finalAmount = _wethTOEth(_amount);
        if (predefinedPool == PredefinedPool.wstETH) {
            _finalAmount = _ethTOstEth(_finalAmount);
        } else if (predefinedPool == PredefinedPool.weETH) {
            _finalAmount = _ethTOeEth(_finalAmount);
        }

        _depositPredefinedAsset(_finalAmount, _amount, _boostAmount, predefinedPool);
    }

    function _depositPredefinedAsset(uint256 _amount, uint256 _initalAmount, uint256 _boostAmount, PredefinedPool predefinedPool) internal {

        uint256 _finalAmount;

        if (predefinedPool == PredefinedPool.sDAI) {
            _finalAmount = _daiTOsDai(_amount);
        } else if (predefinedPool == PredefinedPool.wstETH) {
            _finalAmount = _stEthTOwstEth(_amount);
        } else if (predefinedPool == PredefinedPool.weETH) {
            _finalAmount = _eethTOweEth(_amount);
        } else {
            revert InvalidDeposit();
        }

        // adjust boostAmount for the new asset
        _boostAmount = _boostAmount * _finalAmount / _initalAmount;

        _deposit(typeToId[predefinedPool], _finalAmount, _boostAmount);
    }

    // Deposit LP tokens to SophonFarming for Point allocation.
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

        // mint share token based on deposit amount
        pool.poolShareToken.mint(msg.sender, _depositAmount);

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

    // Withdraw LP tokens from SophonFarming and accept a slash on points
    function exit(uint256 _pid) external {
        if (!isFarmingEnded() || isExitPeriodEnded()) {
            revert ExitNotAllowed();
        }
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        uint256 _amount = user.amount;
        require(_amount != 0, "nothing in pool");
        updatePool(_pid);

        user.rewardSettled =
            (_amount *
            pool.accPointsPerShare /
            1e18 +
            user.rewardSettled -
            user.rewardDebt) / 2;

        PoolShareToken poolShareToken = pool.poolShareToken;
        uint256 depositAmount = poolShareToken.balanceOf(msg.sender);

        pool.amount = pool.amount - _amount;
        pool.boostAmount = pool.boostAmount - user.boostAmount;

        // burn share token based on withdrawn deposit amount
        poolShareToken.burn(msg.sender, depositAmount);

        user.amount = 0;
        user.boostAmount = 0;
        user.rewardDebt = 0;

        pool.lpToken.safeTransfer(msg.sender, depositAmount);

        emit Exit(msg.sender, _pid, depositAmount);
    }

    // permissionless function to allow anyone to bridge during the correct period
    // TODO: add logic to reward the permissionless caller
    function bridgePool(uint256 _pid) external {
        if (!isFarmingEnded() || !isExitPeriodEnded() || isBridged[_pid]) {
            revert Unauthorized();
        }

        updatePool(_pid);
        PoolInfo storage pool = poolInfo[_pid];

        uint256 depositAmount = pool.poolShareToken.totalSupply();
        if (depositAmount == 0 || address(bridge) == address(0) || pool.l2Farm == address(0)) {
            revert BridgeInvalid();
        }

        IERC20 lpToken = pool.lpToken;
        lpToken.approve(address(bridge), depositAmount);

        // TODO: change _refundRecipient, verify l2Farm, _l2TxGasLimit and _l2TxGasPerPubdataByte
        bridge.deposit(
            pool.l2Farm,            // _l2Receiver
            address(lpToken),       // _l1Token
            depositAmount,          // _amount
            200000,                 // _l2TxGasLimit
            0,                      // _l2TxGasPerPubdataByte
            owner()                 // _refundRecipient
        );

        isBridged[_pid] = true;

        emit Bridge(msg.sender, _pid, depositAmount);
    }

    // TODO: does this function need to call claimFailedDeposit on the bridge?
    function revertFailedBridge(uint256 _pid) external onlyOwner {
        isBridged[_pid] = false;
    }

    // Increase boost from existing deposits.
    function increaseBoost(uint256 _pid, uint256 _boostAmount) external {
        if (isFarmingEnded()) {
            revert FarmingIsEnded();
        }

        if (_boostAmount == 0) {
            revert BoostIsZero();
        }

        PoolInfo storage pool = poolInfo[_pid];

        // burn share token based on reduced deposit amount
        // will revert if boostAmount too high
        // (calling earlier since we don't have a separate balance check)
        pool.poolShareToken.burn(msg.sender, _boostAmount);

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

    // total allowed boost is 100% of total deposit
    // returns max additional boost amount allowed to boost current deposits
    function getMaxAdditionalBoost(address _user, uint256 _pid) public view returns (uint256) {
        return poolInfo[_pid].poolShareToken.balanceOf(_user);
    }

    // WETH
    function _wethTOEth(uint256 _amount) internal returns (uint256) {
        // unwrap weth to eth
        IWeth(weth).withdraw(_amount);
        return _amount;
    }

    // Lido
    function _ethTOstEth(uint256 _amount) internal returns (uint256) {
        // submit function does not return exact amount of stETH so we need to check balances
        uint256 balanceBefore = IERC20(stETH).balanceOf(address(this));
        IstETH(stETH).submit{value: _amount}(address(this));
        return (IERC20(stETH).balanceOf(address(this)) - balanceBefore);
    }

    // Lido
    function _stEthTOwstEth(uint256 _amount) internal returns (uint256) {
        // wrap returns exact amount of wstETH
        return IwstETH(wstETH).wrap(_amount);
    }

    // ether.fi
    function _ethTOeEth(uint256 _amount) internal returns (uint256) {
        // deposit returns exact amount of eETH
        return IeETHLiquidityPool(eETHLiquidityPool).deposit{value: _amount}(address(this));
    }

    // ether.fi
    function _eethTOweEth(uint256 _amount) internal returns (uint256) {
        // wrap returns exact amount of weETH
        return IweETH(weETH).wrap(_amount);
    }

    // MakerDao
    function _daiTOsDai(uint256 _amount) internal returns (uint256) {
        // deposit DAI to sDAI
        return IsDAI(sDAI).deposit(_amount, address(this));
    }

    function withdrawProceeds(uint256 _pid) external onlyOwner {
        PoolInfo storage pool = poolInfo[_pid];
        uint256 _proceeds = heldProceeds[_pid];
        heldProceeds[_pid] = 0;
        pool.lpToken.safeTransfer(msg.sender, _proceeds);
        emit WithdrawProceeds(_pid, _proceeds);
    }

    function getBlockNumber() virtual public view returns (uint256) {
        return block.number;
    }

    function getPoolInfo() external view returns (PoolInfo[] memory poolInfos) {
        uint256 length = poolInfo.length;
        poolInfos = new PoolInfo[](length);
        for(uint256 pid = 0; pid < length;) {
            poolInfos[pid] = poolInfo[pid];
            unchecked { ++pid; }
        }
    }

    function getOptimizedUserInfo(address[] memory _users) external view returns (uint256[4][][] memory userInfos) {
        userInfos = new uint256[4][][](_users.length);
        uint256 len = poolInfo.length;
        for(uint256 i = 0; i < _users.length;) {
            address _user = _users[i];
            userInfos[i] = new uint256[4][](len);
            for(uint256 pid = 0; pid < len;) {
                userInfos[i][pid][0] = userInfo[pid][_user].amount;
                userInfos[i][pid][1] = userInfo[pid][_user].boostAmount;
                userInfos[i][pid][2] = poolInfo[pid].poolShareToken.balanceOf(_user);
                userInfos[i][pid][3] = _pendingPoints(pid, _user);
                unchecked { ++pid; }
            }
            unchecked { i++; }
        }
    }

    function getUserInfo(address[] memory _users) external view returns (UserInfo[][] memory userInfos) {
        userInfos = new UserInfo[][](_users.length);
        uint256 len = poolInfo.length;
        for(uint256 i = 0; i < _users.length;) {
            address _user = _users[i];
            userInfos[i] = new UserInfo[](len);
            for(uint256 pid = 0; pid < len;) {
                UserInfo memory uinfo = userInfo[pid][_user];
                uinfo.depositAmount = poolInfo[pid].poolShareToken.balanceOf(_user);
                userInfos[i][pid] = uinfo;
                unchecked { ++pid; }
            }
            unchecked { i++; }
        }
    }

    function getPendingPoints(address[] memory _users) external view returns (uint256[][] memory pendings) {
        pendings = new uint256[][](_users.length);
        uint256 len = poolInfo.length;
        for(uint256 i = 0; i < _users.length;) {
            address _user = _users[i];
            pendings[i] = new uint256[](len);
            for(uint256 pid = 0; pid < len;) {
                pendings[i][pid] = _pendingPoints(pid, _user);
                unchecked { ++pid; }
            }
            unchecked { i++; }
        }
    }
}
// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.24;

import "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/utils/math/Math.sol";
import "./interfaces/IWeth.sol";
import "./interfaces/IstETH.sol";
import "./interfaces/IwstETH.sol";
import "./interfaces/IsDAI.sol";
import "../proxies/Upgradeable2Step.sol";
import "./SophonFarmingState.sol";

contract SophonFarming is Upgradeable2Step, SophonFarmingState {
    using SafeERC20 for IERC20;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount, uint256 boostAmount);
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
    error NoEthSent();
    error BoostTooHigh(uint256 maxAllowed);
    error BridgeInvalid();


    address public immutable dai;
    address public immutable sDAI;
    address public immutable weth;
    address public immutable stETH;
    address public immutable wstETH;
    address public immutable uSDe;
    address public immutable sUSDe;
    address public immutable weETH;
    address public immutable ezETH;
    address public immutable rsETH;
    address public immutable rswETH;
    address public immutable uniETH;
    address public immutable pufETH;

    modifier nonDuplicated(address _lpToken) {
        require(!poolExists[_lpToken], "pool exists");
        _;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }


    // Mainnet ->
    // weth: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
    // stETH: 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84
    // wstETH: 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0

    // todo: add LSDs seen here -> https://app.pendle.finance/points
    // ether.fi ETH (eETH): 0x35fA164735182de50811E8e2E824cFb9B6118ac2
    // ether.fi Wrapped eETH (weETH): 0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee
    // Renzo ezETH (Renzo Restaked ETH): 0xbf5495Efe5DB9ce00f80364C8B423567e58d2110
    // Kelp Dao rsETH (rsETH): 0xA1290d69c65A6Fe4DF752f95823fae25cB99e5A7
    // Swell rswETH (rswETH): 0xFAe103DC9cf190eD75350761e95403b7b8aFa6c0
    // Bedrock uniETH (Universal ETH): 0xF1376bceF0f78459C0Ed0ba5ddce976F1ddF51F4
    // Puffer pufETH (pufETH): 0xD9A442856C234a39a81a089C06451EBAa4306a72

    // DAI: 0x6B175474E89094C44Da98b954EedeAC495271d0F
    // sDAI: 0x83F20F44975D03b1b09e64809B757c47f942BEeA
    constructor(address[13] memory tokens_) {
        dai = tokens_[0];
        sDAI = tokens_[1];
        weth = tokens_[2];
        stETH = tokens_[3];
        wstETH = tokens_[4];
        uSDe = tokens_[5];
        sUSDe = tokens_[6];
        weETH = tokens_[7];
        ezETH = tokens_[8];
        rsETH = tokens_[9];
        rswETH = tokens_[10];
        uniETH = tokens_[11];
        pufETH = tokens_[12];
    }

    receive() external payable {
        if (msg.sender == weth) {
            return;
        }

        depositEth(0, PredefinedPool.wstETH);
    }

    function initialize(uint256 ethAllocPoint_, uint256 sDAIAllocPoint_, uint256 _pointsPerBlock, uint256 _startBlock, uint256 _boosterMultiplier) external onlyOwner {
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

        // sDAI
        typeToId[PredefinedPool.sDAI] = add(sDAIAllocPoint_, sDAI, "sDAI", false);
        IERC20(dai).approve(sDAI, 2**256-1);

        // wstETH
        typeToId[PredefinedPool.wstETH] = add(ethAllocPoint_, wstETH, "wstETH", false);
        IERC20(stETH).approve(wstETH, 2**256-1);

        // weETH
        typeToId[PredefinedPool.weETH] = add(ethAllocPoint_, weETH, "weETH", false);

        // ezETH
        typeToId[PredefinedPool.ezETH] = add(ethAllocPoint_, ezETH, "ezETH", false);

        // rsETH
        typeToId[PredefinedPool.rsETH] = add(ethAllocPoint_, rsETH, "rsETH", false);

        // rswETH
        typeToId[PredefinedPool.rswETH] = add(ethAllocPoint_, rswETH, "rswETH", false);

        // uniETH
        typeToId[PredefinedPool.uniETH] = add(ethAllocPoint_, uniETH, "uniETH", false);

        // pufETH
        typeToId[PredefinedPool.pufETH] = add(ethAllocPoint_, pufETH, "pufETH", false);

        _initialized = true;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    function add(uint256 _allocPoint, address _lpToken, string memory _description, bool _withUpdate) public onlyOwner nonDuplicated(_lpToken) returns (uint256) {
        if (isFarmingEnded()) {
            revert FarmingIsEnded();
        }
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock =
            block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint + _allocPoint;
        poolExists[_lpToken] = true;
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
                description: _description
            })
        );

        return poolInfo.length - 1;
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

        if (block.number < pool.lastRewardBlock) {
            pool.lastRewardBlock = startBlock;
        }
    }

    function isFarmingEnded() public view returns (bool) {
        uint256 _endBlock = endBlock;
        if (_endBlock != 0 && block.number > _endBlock) {
            return true;
        } else {
            return false;
        }
    }

    function isExitPeriodEnded() public view returns (bool) {
        uint256 _endBlockForWithdrawals = endBlockForWithdrawals;
        if (_endBlockForWithdrawals != 0 && block.number > _endBlockForWithdrawals) {
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
        if (block.number > startBlock) {
            revert FarmingIsStarted();
        }
        startBlock = _startBlock;
    }

    function setEndBlocks(uint256 _endBlock, uint256 _withdrawalBlocks) public onlyOwner {
        uint256 _endBlockForWithdrawals;
        if (endBlock != 0) {
            if (_endBlock <= startBlock || block.number > _endBlock) {
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
        _to = Math.min(_to, endBlock);
        if (_to > _from) {
            return (_to - _from) * 1e18;
        } else {
            return 0;
        }
    }

    function _pendingPoints(uint256 _pid, address _user) internal view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];

        uint256 accPointsPerShare = pool.accPointsPerShare * 1e18;

        uint256 lpSupply = pool.amount;
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 blockMultiplier = getBlockMultiplier(pool.lastRewardBlock, block.number);

            uint256 pointReward =
                blockMultiplier *
                pointsPerBlock *
                pool.allocPoint /
                totalAllocPoint;

            accPointsPerShare = pointReward *
                1e12 /
                lpSupply +
                accPointsPerShare;
        }

        return user.amount *
            accPointsPerShare /
            1e30 +
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
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.amount;
        uint256 _pointsPerBlock = pointsPerBlock;
        uint256 _allocPoint = pool.allocPoint;
        if (lpSupply == 0 || _pointsPerBlock == 0 || _allocPoint == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 blockMultiplier = getBlockMultiplier(pool.lastRewardBlock, block.number);
        uint256 pointReward =
            blockMultiplier *
            _pointsPerBlock *
            _allocPoint /
            totalAllocPoint;

        pool.accPointsPerShare = pointReward /
            1e6 /
            lpSupply +
            pool.accPointsPerShare;

        pool.lastRewardBlock = block.number;
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

    function depositEth(uint256 _boostAmount, PredefinedPool predefinedPool) public payable {
        if (msg.value == 0) {
            revert NoEthSent();
        }

        uint256 _finalAmount = msg.value;
        if (predefinedPool == PredefinedPool.wstETH) {
            _finalAmount = _ethTOstEth(_finalAmount);
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
            _finalAmount = _ethTOweEth(_amount);
        } else if (predefinedPool == PredefinedPool.ezETH) {
            _finalAmount = _ethTOezEth(_amount);
        } else if (predefinedPool == PredefinedPool.rsETH) {
            _finalAmount = _ethTOrsEth(_amount);
        } else if (predefinedPool == PredefinedPool.rswETH) {
            _finalAmount = _ethTOrswEth(_amount);
        } else if (predefinedPool == PredefinedPool.uniETH) {
            _finalAmount = _ethTOuniEth(_amount);
        } else if (predefinedPool == PredefinedPool.pufETH) {
            _finalAmount = _ethTOpufEth(_amount);
        } else {
            revert InvalidDeposit();
        }

        // adjust boostAmount for the new asset
        _boostAmount = _boostAmount * _finalAmount / _initalAmount;

        _deposit(typeToId[predefinedPool], _finalAmount, _boostAmount);
    }

    // Deposit LP tokens to SophonFarming for Point allocation.
    function _deposit(uint256 _pid, uint256 _amount, uint256 _boostAmount) internal {
        if (isFarmingEnded()) {
            revert FarmingIsEnded();
        }
        if (_amount == 0) {
            revert InvalidDeposit();
        }
        if (_boostAmount > _amount) {
            revert BoostTooHigh(_amount);
        }

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);

        uint256 userAmount = user.amount;
  
        if (userAmount != 0) {
            user.rewardSettled = 
                userAmount *
                pool.accPointsPerShare /
                1e12 +
                user.rewardSettled -
                user.rewardDebt;
        }

        // booster purchase proceeds
        heldProceeds[_pid] = heldProceeds[_pid] + _boostAmount;

        // set deposit amount
        user.depositAmount = user.depositAmount + _amount - _boostAmount;
        pool.depositAmount = pool.depositAmount + _amount - _boostAmount;

        // apply the multiplier
        _boostAmount = _boostAmount * boosterMultiplier / 1e18;

        user.boostAmount = user.boostAmount + _boostAmount;

        userAmount = userAmount + _amount + _boostAmount;
        user.amount = userAmount;
        user.rewardDebt = userAmount *
            pool.accPointsPerShare /
            1e12;

        // boosted value added to pool balance
        pool.amount = pool.amount + _amount + _boostAmount;
        pool.boostAmount = pool.boostAmount + _boostAmount;

        emit Deposit(msg.sender, _pid, _amount, _boostAmount);
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
            1e12 +
            user.rewardSettled -
            user.rewardDebt) / 2;

        uint256 depositAmount = user.depositAmount;

        pool.amount = pool.amount - _amount;
        pool.boostAmount = pool.boostAmount - user.boostAmount;
        pool.depositAmount = pool.depositAmount - depositAmount;

        user.amount = 0;
        user.boostAmount = 0;
        user.depositAmount = 0;
        user.rewardDebt = 0;

        pool.lpToken.safeTransfer(msg.sender, depositAmount);

        emit Exit(msg.sender, _pid, depositAmount);
    }

    // TODO: reward for caller; change _refundRecipient
    // permissionless function to allow anyone to bridge during the correct period
    function bridgePool(uint256 _pid) external {
        if (!isFarmingEnded() || !isExitPeriodEnded()) {
            revert Unauthorized();
        }

        updatePool(_pid);
        PoolInfo storage pool = poolInfo[_pid];

        if (pool.depositAmount == 0 || address(bridge) == address(0) || pool.l2Farm == address(0)) {
            revert BridgeInvalid();
        }

        // TODO: change _refundRecipient
        bridge.deposit(
            pool.l2Farm,            // _l2Receiver
            address(pool.lpToken),  // _l1Token
            pool.depositAmount,     // _amount
            200000,                 // _l2TxGasLimit
            0,                      // _l2TxGasPerPubdataByte
            owner()                 // _refundRecipient
        );

        pool.depositAmount = 0;

        emit Bridge(msg.sender, _pid, pool.depositAmount);
    }

    // Increase boost from existing deposits.
    function increaseBoost(uint256 _pid, uint256 _boostAmount) external {
        if (isFarmingEnded()) {
            revert FarmingIsEnded();
        }

        uint256 maxAdditionalBoost = getMaxAdditionalBoost(msg.sender, _pid);
        if (_boostAmount > maxAdditionalBoost) {
            revert BoostTooHigh(maxAdditionalBoost);
        }

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);

        uint256 userAmount = user.amount;
  
        if (userAmount != 0) {
            user.rewardSettled = 
                userAmount *
                pool.accPointsPerShare /
                1e12 +
                user.rewardSettled -
                user.rewardDebt;
        }

        // booster purchase proceeds
        heldProceeds[_pid] = heldProceeds[_pid] + _boostAmount;

        // set deposit amount
        user.depositAmount = user.depositAmount - _boostAmount;
        pool.depositAmount = pool.depositAmount - _boostAmount;

        // apply the multiplier
        _boostAmount = _boostAmount * boosterMultiplier / 1e18;

        user.boostAmount = user.boostAmount + _boostAmount;

        userAmount = userAmount + _boostAmount;
        user.amount = userAmount;
        user.rewardDebt = userAmount *
            pool.accPointsPerShare /
            1e12;

        // boosted value added to pool balance
        pool.amount = pool.amount + _boostAmount;
        pool.boostAmount = pool.boostAmount + _boostAmount;

        emit IncreaseBoost(msg.sender, _pid, _boostAmount);
    }

	// total allowed boost is 100% of total deposit
    // returns max additional boost amount allowed to boost current deposits
	function getMaxAdditionalBoost(address _user, uint256 _pid) public view returns (uint256) {
		return userInfo[_pid][_user].depositAmount;
	}

    function _wethTOEth(uint256 _amount) internal returns (uint256) {
        // unwrap weth to eth
        IWeth(weth).withdraw(_amount);
        return _amount;
    }

    function _ethTOstEth(uint256 _amount) internal returns (uint256) {
        // submit function does not return exact amount of stETH so we need to check balances
        uint256 balanceBefore = IERC20(stETH).balanceOf(address(this));
        IstETH(stETH).submit{value: _amount}(address(this));
        return (IERC20(stETH).balanceOf(address(this)) - balanceBefore);
    }

    function _stEthTOwstEth(uint256 _amount) internal returns (uint256) {
        // wrap returns exact amount of wstETH
        return IwstETH(wstETH).wrap(_amount);
    }

    // TODO: all these below
    function _ethTOweEth(uint256 _amount) internal returns (uint256) {
        uint256 balanceBefore = IERC20(weETH).balanceOf(address(this));
        IstETH(weETH).submit{value: _amount}(address(this));
        return (IERC20(weETH).balanceOf(address(this)) - balanceBefore);
    }
    function _ethTOezEth(uint256 _amount) internal returns (uint256) {
        uint256 balanceBefore = IERC20(weETH).balanceOf(address(this));
        IstETH(weETH).submit{value: _amount}(address(this));
        return (IERC20(weETH).balanceOf(address(this)) - balanceBefore);
    }
    function _ethTOrsEth(uint256 _amount) internal returns (uint256) {
        uint256 balanceBefore = IERC20(weETH).balanceOf(address(this));
        IstETH(weETH).submit{value: _amount}(address(this));
        return (IERC20(weETH).balanceOf(address(this)) - balanceBefore);
    }
    function _ethTOrswEth(uint256 _amount) internal returns (uint256) {
        uint256 balanceBefore = IERC20(weETH).balanceOf(address(this));
        IstETH(weETH).submit{value: _amount}(address(this));
        return (IERC20(weETH).balanceOf(address(this)) - balanceBefore);
    }
    function _ethTOuniEth(uint256 _amount) internal returns (uint256) {
        uint256 balanceBefore = IERC20(weETH).balanceOf(address(this));
        IstETH(weETH).submit{value: _amount}(address(this));
        return (IERC20(weETH).balanceOf(address(this)) - balanceBefore);
    }
    function _ethTOpufEth(uint256 _amount) internal returns (uint256) {
        uint256 balanceBefore = IERC20(weETH).balanceOf(address(this));
        IstETH(weETH).submit{value: _amount}(address(this));
        return (IERC20(weETH).balanceOf(address(this)) - balanceBefore);
    }

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
                userInfos[i][pid][2] = userInfo[pid][_user].depositAmount;
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
                userInfos[i][pid] = userInfo[pid][_user];
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
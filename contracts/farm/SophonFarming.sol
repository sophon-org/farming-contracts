// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.24;

import "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/utils/math/Math.sol";
import "@chainlink/interfaces/AggregatorV3Interface.sol";
import "./interfaces/IWeth.sol";
import "./interfaces/IstETH.sol";
import "./interfaces/IwstETH.sol";
import "./interfaces/IsDAI.sol";
import "../proxies/Upgradeable2Step.sol";

contract SophonFarming is Upgradeable2Step {
    using SafeERC20 for IERC20;

    address public immutable weth;
    address public immutable stETH;
    address public immutable wstETH;

    address public immutable dai;
    address public immutable sDAI;

    uint256 public immutable wstETH_Pool_Id;
    uint256 public immutable sDAI_Pool_Id;

    mapping(address => address) public priceFeeds;
    mapping(address => uint) public decimals;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Exit(address indexed user, uint256 indexed pid, uint256 amount);

    error NotFound(address lpToken);

    error AlreadyInitialized();
    error FarmingIsStarted();
    error FarmingIsEnded();
    error FarmingNotEnded();
    error InvalidStartBlock();
    error InvalidEndBlock();
    error InvalidDeposit();
    error NoEthSent();
    error FeedMissing();
    error PriceError();
    error InvalidDecimals();

    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
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
        uint256 allocPoint; // How many allocation points assigned to this pool. Points to distribute per block.
        uint256 lastRewardBlock; // Last block number that points distribution occurs.
        uint256 accPointsPerShare; // Accumulated points per share, times 1e12. See below.
    }

    // total deposits in a pool
    mapping(uint256 => uint256) public balanceOf;

    // Points created per block.
    uint256 public pointsPerBlock;

    // Info of each pool.
    PoolInfo[] public poolInfo;

    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;

    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;

    // The block number when point mining starts.
    uint256 public startBlock;

    // The block number when point mining ends.
    uint256 public endBlock;

    mapping(address => bool) public poolExists;

    modifier nonDuplicated(address _lpToken) {
        require(!poolExists[_lpToken], "pool exists");
        _;
    }

    mapping(address => uint256) public points;
    uint256 public totalPoints;


    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }


    // weth: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
    // stETH: 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84
    // wstETH: 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0
    // DAI: 0x6B175474E89094C44Da98b954EedeAC495271d0F
    // sDAI: 0x83F20F44975D03b1b09e64809B757c47f942BEeA
    constructor(address weth_, address stETH_, address wstETH_, address _wstETH_Feed, address dai_, address sDAI_, address _sDAI_Feed, uint256 _pointsPerBlock, uint256 _startBlock) {
        weth = weth_;
        stETH = stETH_;
        wstETH = wstETH_;
        dai = dai_;
        sDAI = sDAI_;
        pointsPerBlock = _pointsPerBlock;

        if (_startBlock == 0) {
            revert InvalidStartBlock();
        }
        startBlock = _startBlock;

        wstETH_Pool_Id = add(10000, wstETH_, false, _wstETH_Feed);
        poolExists[weth_] = true;
        poolExists[stETH_] = true;
        IERC20(stETH_).approve(wstETH_, 2**256-1);

        sDAI_Pool_Id = add(10000, sDAI_, false, _sDAI_Feed);
        poolExists[dai_] = true;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    function add(uint256 _allocPoint, address _lpToken, bool _withUpdate, address _priceFeed) public onlyOwner nonDuplicated(_lpToken) returns (uint256) {
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
                allocPoint: _allocPoint,
                lastRewardBlock: lastRewardBlock,
                accPointsPerShare: 0
            })
        );

        if (_priceFeed != address(0)) {
            setAssetPriceFeed(_lpToken, _priceFeed);
        }

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

    function setStartBlock(uint256 _startBlock) public onlyOwner {
        if (_startBlock == 0 || (endBlock != 0 && _startBlock >= endBlock)) {
            revert InvalidStartBlock();
        }
        if (block.number > startBlock) {
            revert FarmingIsStarted();
        }
        startBlock = _startBlock;
    }

    function setEndBlock(uint256 _endBlock) public onlyOwner {
        if (endBlock != 0) {
            if (_endBlock <= startBlock || block.number > _endBlock) {
                revert InvalidEndBlock();
            }
            if (isFarmingEnded()) {
                revert FarmingIsEnded();
            }
        }
        massUpdatePools();
        endBlock = _endBlock;
    }

    function setPointsPerBlock(uint256 _pointsPerBlock) public onlyOwner {
        if (isFarmingEnded()) {
            revert FarmingIsEnded();
        }
        massUpdatePools();
        pointsPerBlock = _pointsPerBlock;
    }

    function getMultiplier(uint256 _from, uint256 _to) public view returns (uint256) {
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

        uint256 lpSupply = balanceOf[_pid];
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);

            uint256 pointReward =
                multiplier *
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
        uint256 lpSupply = balanceOf[_pid];
        uint256 _pointsPerBlock = pointsPerBlock;
        uint256 _allocPoint = pool.allocPoint;
        if (lpSupply == 0 || _pointsPerBlock == 0 || _allocPoint == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 pointReward =
            multiplier *
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
    function deposit(uint256 _pid, uint256 _amount) external {
        IERC20 lpToken;
        (lpToken, _amount) = _deposit(_pid, _amount);
        if (_amount != 0) {
            lpToken.safeTransferFrom(
                msg.sender,
                address(this),
                _amount
            );
            balanceOf[_pid] = balanceOf[_pid] + _amount;
        }
    }

    // Deposit wstEth to SophonFarming for Point allocation after sending ETH
    function depositEth() external payable {
        if (msg.value == 0) {
            revert NoEthSent();
        }

        // ETH is converted to wstETH
        uint256 _amount = _stEthTOwstEth(_ethTOstEth(msg.value));

        IERC20 lpToken;
        (lpToken, _amount) = _deposit(wstETH_Pool_Id, _amount);
        if (address(lpToken) != wstETH) {
            revert InvalidDeposit();
        }
        if (_amount != 0) {
            balanceOf[wstETH_Pool_Id] = balanceOf[wstETH_Pool_Id] + _amount;
        }
    }

    // Deposit wstEth to SophonFarming for Point allocation after sending WETH
    function depositWeth(uint256 _amount) external {
        IERC20(weth).safeTransferFrom(
            msg.sender,
            address(this),
            _amount
        );

        // weth is converted to wstETH
        uint256 _amount = _stEthTOwstEth(_ethTOstEth(_wethTOEth(_amount)));

        IERC20 lpToken;
        (lpToken, _amount) = _deposit(wstETH_Pool_Id, _amount);
        if (address(lpToken) != wstETH) {
            revert InvalidDeposit();
        }
        if (_amount != 0) {
            balanceOf[wstETH_Pool_Id] = balanceOf[wstETH_Pool_Id] + _amount;
        }
    }

    // Deposit wstEth to SophonFarming for Point allocation after sending stETH
    function depositStEth(uint256 _amount) external {
        IERC20(stETH).safeTransferFrom(
            msg.sender,
            address(this),
            _amount
        );

        // stETH is converted to wstETH
        uint256 _amount = _stEthTOwstEth(_amount);

        IERC20 lpToken;
        (lpToken, _amount) = _deposit(wstETH_Pool_Id, _amount);
        if (address(lpToken) != wstETH) {
            revert InvalidDeposit();
        }
        if (_amount != 0) {
            balanceOf[wstETH_Pool_Id] = balanceOf[wstETH_Pool_Id] + _amount;
        }
    }

    // Deposit sDAI to SophonFarming for Point allocation after sending DAI
    function depositDai(uint256 _amount) external {
        IERC20(dai).safeTransferFrom(
            msg.sender,
            address(this),
            _amount
        );

        // DAI is converted to sDAI
        uint256 _amount = _daiTOsDai(_amount);

        IERC20 lpToken;
        (lpToken, _amount) = _deposit(sDAI_Pool_Id, _amount);
        if (address(lpToken) != sDAI) {
            revert InvalidDeposit();
        }
        if (_amount != 0) {
            balanceOf[sDAI_Pool_Id] = balanceOf[sDAI_Pool_Id] + _amount;
        }
    }

    // Deposit LP tokens to SophonFarming for Point allocation.
    function _deposit(uint256 _pid, uint256 _amount) internal returns (IERC20, uint256) {
        if (isFarmingEnded()) {
            revert FarmingIsEnded();
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

        userAmount = userAmount + _amount;

        user.rewardDebt = userAmount *
            pool.accPointsPerShare /
            1e12;

        user.amount = userAmount;

        emit Deposit(msg.sender, _pid, _amount);

        return (pool.lpToken, _amount);
    }

    // Withdraw LP tokens from SophonFarming and accept a slash on points
    function exit(uint256 _pid) external {
        if (!isFarmingEnded()) {
            revert FarmingNotEnded();
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

        user.rewardDebt = 0;
        user.amount = 0;

        balanceOf[_pid] = balanceOf[_pid] - _amount;
        pool.lpToken.safeTransfer(address(msg.sender), _amount);

        emit Exit(msg.sender, _pid, _amount);
    }

    mapping(address => uint256) internal _boosts;
    function getBoostMultiplier(address _user) public view returns (uint256) {
        return _boosts[_user];
    }

    // dummy logic - not complete
    function purchaseBooster() external payable {
        if (isFarmingEnded()) {
            revert FarmingIsEnded();
        }

        _boosts[msg.sender] = 1.7e18;
        //uint256 dummy_eth_price = 3500;
        //_boosts[msg.sender] = _boosts[msg.sender] + msg.value * dummy_eth_price / 1000000e18 * 2
    }

    function _wethTOEth(uint256 _amount) internal returns (uint256) {
        // unwrap weth to eth
        IWeth(weth).withdraw(_amount);
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

    function _daiTOsDai(uint256 _amount) internal returns (uint256) {
        // deposit DAI to sDAI
        return IsDAI(sDAI).deposit(_amount, address(this));
    }

    function getPoolInfo() external view returns(PoolInfo[] memory poolInfos) {
        uint256 length = poolInfo.length;
        poolInfos = new PoolInfo[](length);
        for(uint256 pid = 0; pid < length;) {
            poolInfos[pid] = poolInfo[pid];
            unchecked { ++pid; }
        }
    }

    function getOptimizedUserInfo(address[] memory _users) external view returns(uint256[2][][] memory userInfos) {
        userInfos = new uint256[2][][](_users.length);
        uint256 len = poolInfo.length;
        for(uint256 i = 0; i < _users.length;) {
            address _user = _users[i];
            userInfos[i] = new uint256[2][](len);
            for(uint256 pid = 0; pid < len;) {
                userInfos[i][pid][0] = userInfo[pid][_user].amount;
                userInfos[i][pid][1] = _pendingPoints(pid, _user);
                unchecked { ++pid; }
            }
            unchecked { i++; }
        }
    }

    function getUserInfo(address[] memory _users) external view returns(UserInfo[][] memory userInfos) {
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

    function getPendingPoints(address[] memory _users) external view returns(uint256[][] memory pendings) {
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

    /**
      * @notice Get the price of an asset
      * @param asset The asset to get the price of
      * @return price The asset USD price scaled up by 10 ^ (36 - underlying asset decimals).
      *  Zero means the price is unavailable.
      *  Chainlink Asset/USD feeds are scaled to 8 decimal places (asset USD price * 10 ^ 8)
      */
    function getAssetPrice(address asset) public view returns (uint price) {
        AggregatorV3Interface feed = AggregatorV3Interface(priceFeeds[asset]);
        if (address(feed) == address(0)) {
            revert FeedMissing();
        }

        (
            /*uint80 roundID*/,
            int rate,
            /*uint startedAt*/,
            uint updatedAt,
            /*uint80 answeredInRound*/
        ) = feed.latestRoundData();
        if (rate == 0 || (rate >> 128) != 0) {
            revert PriceError();
        }

        // decimals[asset] checked for <= 18 on setting
        price = uint(rate) * 10**(36 - 8 - decimals[asset]);
    }

    /**
     * @notice Set the price feed for the given asset.
     * @param asset The asset for whose underlying the price feed should be set
     * @param newFeed The address of the price feed
     */
    function setAssetPriceFeed(address asset, address newFeed) public onlyOwner {

        priceFeeds[asset] = newFeed;

        uint _decimals;
        if (asset != 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE) {
            (bool success, bytes memory data) = asset.call(abi.encodeWithSelector(
                IERC20Metadata(asset).decimals.selector
            ));
            if (success) {
                (_decimals) = abi.decode(data, (uint256));
                if (_decimals > 18) {
                    revert InvalidDecimals();
                }
            } else {
                _decimals = 18;
            }
        } else {
            _decimals = 18;
        }
        decimals[asset] = _decimals;
    }
}
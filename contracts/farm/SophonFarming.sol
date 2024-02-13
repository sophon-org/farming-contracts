// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.24;

import "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "../proxies/Upgradeable.sol";
import "./interfaces/ERC721Interfaces.sol";

contract SophonFarming is IERC721Receiver, Upgradeable {
    using SafeERC20 for IERC20;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event WithdrawNFTs(address indexed user, uint256 indexed pid, uint256 nftCount);
    event EmergencyWithdrawNFTs(address indexed user, uint256 indexed pid, uint256 nftCount);

    error NotFound(address lpToken);

    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardSettled; // Reward settled.
        uint256 rewardDebt; // Reward debt. See explanation below.
        uint256[] heldNFTs; // Ids of NFTs the user has deposited (n/a for non-NFT pools)
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
        address lpToken; // Address of LP token contract.
        uint256 allocPoint; // How many allocation points assigned to this pool. Points to distribute per block.
        uint256 lastRewardBlock; // Last block number that points distribution occurs.
        uint256 accPointsPerShare; // Accumulated points per share, times 1e12. See below.
    }

    // Block number when bonus point period ends.
    uint256 public bonusEndBlock;

    // Points created per block.
    uint256 public pointsPerBlock;

    // Bonus muliplier for early point makers.
    uint256 public constant BONUS_MULTIPLIER = 0;

    // Info of each pool.
    PoolInfo[] public poolInfo;

    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;

    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;

    // The block number when point mining starts.
    uint256 public startBlock;

    mapping(address => bool) public poolExists;

    modifier nonDuplicated(address _lpToken) {
        require(!poolExists[_lpToken], "pool exists");
        _;
    }

    // total deposits in a pool
    mapping(uint256 => uint256) public balanceOf;

    mapping(address => uint256) public points;
    uint256 public totalPoints;


    bool public notPaused;

    modifier checkNoPause() {
        require(notPaused || msg.sender == owner(), "paused");
        _;
    }

    // vestingStamp for a user
    mapping(address => uint256) public userStartVestingStamp;

    //default value if userStartVestingStamp[user] == 0
    uint256 public startVestingStamp;

    uint256 public vestingDuration; // 15768000 6 months (6 * 365 * 24 * 60 * 60)

    bool public vestingDisabled;

    function initialize(uint256 _pointsPerBlock, uint256 _startBlock, uint256 _bonusEndBlock) public onlyOwner {
        pointsPerBlock = _pointsPerBlock;
        startBlock = _startBlock;
        bonusEndBlock = _bonusEndBlock;
    }

    function setVestingDuration(uint256 _vestingDuration) external onlyOwner {
        vestingDuration = _vestingDuration;
    }

    function setStartVestingStamp(uint256 _startVestingStamp) external onlyOwner {
        startVestingStamp = _startVestingStamp;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    function add(uint256 _allocPoint, address _lpToken, bool _withUpdate) public onlyOwner nonDuplicated(_lpToken) {
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock =
            block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint + _allocPoint;
        poolExists[_lpToken] = true;
        poolInfo.push(
            PoolInfo({
                lpToken: _lpToken,
                allocPoint: _allocPoint,
                lastRewardBlock: lastRewardBlock,
                accPointsPerShare: 0
            })
        );
    }

    // Update the given pool's allocation point. Can only be called by the owner.
    function set(uint256 _pid, uint256 _allocPoint, bool _withUpdate) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }

        PoolInfo storage pool = poolInfo[_pid];
        require(address(pool.lpToken) != address(0) && poolExists[pool.lpToken], "pool not exists");
        totalAllocPoint = totalAllocPoint - pool.allocPoint + _allocPoint;
        pool.allocPoint = _allocPoint;

        if (block.number < pool.lastRewardBlock) {
            pool.lastRewardBlock = startBlock;
        }
    }

    function setStartBlock(uint256 _startBlock) public onlyOwner {
        startBlock = _startBlock;
    }

    function setpointsPerBlock(uint256 _pointsPerBlock) public onlyOwner {
        massUpdatePools();
        pointsPerBlock = _pointsPerBlock;
    }

    function getMultiplierNow() public view returns (uint256) {
        return getMultiplier(block.number - 1, block.number);
    }

    function getMultiplier(uint256 _from, uint256 _to) public view returns (uint256) {
        return getMultiplierPrecise(_from, _to) / 1e18;
    }

    function getMultiplierPrecise(uint256 _from, uint256 _to) public view returns (uint256) {
        return _getDecliningMultipler(_from, _to, startBlock);
    }

    function _getDecliningMultipler(uint256 _from, uint256 _to, uint256 _bonusStartBlock) internal view returns (uint256) {
        return (_to - _from) * 1e18;
        /*
        // _periodBlocks = 1296000 = 60 * 60 * 24 * 30 / 2 = blocks_in_30_days (assume 2 second blocks)
        uint256 _bonusEndBlock = _bonusStartBlock + 1296000;

        // multiplier = 10e18
        // declinePerBlock = 6944444444444 = (10e18 - 1e18) / _periodBlocks

        uint256 _startMultipler;
        uint256 _endMultipler;
        uint256 _avgMultiplier;

        if (_to <= _bonusEndBlock) {
            _startMultipler = SafeMath.sub(10e18,
                _from.sub(_bonusStartBlock)
                    .mul(6944444444444)
            );

            _endMultipler = SafeMath.sub(10e18,
                _to.sub(_bonusStartBlock)
                    .mul(6944444444444)
            );

            _avgMultiplier = (_startMultipler + _endMultipler) / 2;

            return _to.sub(_from).mul(_avgMultiplier);
        } else if (_from >= _bonusEndBlock) {
            return _to.sub(_from).mul(1e18);
        } else {

            _startMultipler = SafeMath.sub(10e18,
                _from.sub(_bonusStartBlock)
                    .mul(6944444444444)
            );

            _endMultipler = 1e18;

            _avgMultiplier = (_startMultipler + _endMultipler) / 2;

            return _bonusEndBlock.sub(_from).mul(_avgMultiplier) + (
                (_to - _bonusEndBlock) * 1e18)
            );
        }*/
    }

    function _pendingPoints(uint256 _pid, address _user) internal view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];

        uint256 accPointsPerShare = pool.accPointsPerShare * 1e18;

        uint256 lpSupply = balanceOf[_pid];
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplierPrecise(pool.lastRewardBlock, block.number);

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

    function toggleVesting(bool _isEnabled) external onlyOwner {
        vestingDisabled = !_isEnabled;
    }

    function togglePause(bool _isPaused) external onlyOwner {
        notPaused = !_isPaused;
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public checkNoPause {
        uint256 length = poolInfo.length;
        for(uint256 pid = 0; pid < length;) {
            updatePool(pid);
            unchecked { ++pid; }
        }
    }

    function massMigrateToBalanceOf() public onlyOwner {
        require(!notPaused, "!paused");
        uint256 length = poolInfo.length;
        for(uint256 pid = 0; pid < length;) {
            balanceOf[pid] = IERC20(poolInfo[pid].lpToken).balanceOf(address(this));
            unchecked { ++pid; }
        }
        massUpdatePools();
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public checkNoPause {
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
        uint256 multiplier = getMultiplierPrecise(pool.lastRewardBlock, block.number);
        uint256 pointReward =
            multiplier *
            _pointsPerBlock *
            _allocPoint /
            totalAllocPoint;
        // 250m = 250 * 1e6
        /*if (totalPoints >= 250*1e6*1e18) {
            pool.allocPoint = 0;
            return;
        }*/

        points[msg.sender] += pointReward / 1e18;

        pool.accPointsPerShare = pointReward /
            1e6 /
            lpSupply +
            pool.accPointsPerShare;

        pool.lastRewardBlock = block.number;
    }

    // Deposit LP tokens to SophonFarming for Point allocation.
    function deposit(uint256 _pid, uint256 _amount) public checkNoPause {
        IERC20(poolInfo[_pid].lpToken).safeTransferFrom(
            msg.sender,
            address(this),
            _amount
        );
        _deposit(_pid, _amount);
    }

    function depositNFTs(uint256 _pid, uint[] memory nftIds) public checkNoPause {
        // Read from storage once
        IERC721 nftContract = IERC721(poolInfo[_pid].lpToken);

        UserInfo storage user = userInfo[_pid][msg.sender];

        uint balanceBefore = nftContract.balanceOf(address(this));

        uint nftCount = nftIds.length;
        for(uint i = 0; i < nftCount;) {
            nftContract.safeTransferFrom(msg.sender, address(this), nftIds[i]);
            user.heldNFTs.push(nftIds[i]);
            unchecked { i++; }
        }

        // Calculate the amount that was *actually* transferred
        uint balanceAfter = nftContract.balanceOf(address(this));
        if (balanceAfter - balanceBefore != nftCount) {
            revert("balance mismatch");
        }

        _deposit(_pid, nftCount * 1e18);
    }

    /*function getNFTsHeld() public view returns (uint) {
        //return IERC721(underlying).balanceOf(address(this));
        return heldNFTs.length;
    }*/

    function _deposit(uint256 _pid, uint256 _amount) internal {
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

        if (_amount != 0) {
            balanceOf[_pid] = balanceOf[_pid] + _amount;
            userAmount = userAmount + _amount;
            emit Deposit(msg.sender, _pid, _amount);
        }
        user.rewardDebt = userAmount *
            pool.accPointsPerShare /
            1e12;

        user.amount = userAmount;
    }

    // Withdraw LP tokens from SophonFarming.
    function withdraw(uint256 _pid, uint256 _amount) public checkNoPause {
        address _lpToken = _withdrawValue(_pid, _amount);
        IERC20(_lpToken).safeTransfer(msg.sender, _amount);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public checkNoPause {
        (address _lpToken, uint256 _amount) = _emergencyWithdrawValue(_pid);
        IERC20(_lpToken).safeTransfer(msg.sender, _amount);
        emit EmergencyWithdraw(msg.sender, _pid, _amount);
    }

    // Withdraw NFTs from SophonFarming.
    function withdrawNFTs(uint256 _pid, uint _nftCount) public checkNoPause {
        address _lpToken = _withdrawValue(_pid, _nftCount * 1e18);
        _transferOutNFTs(IERC721(_lpToken), _pid, _nftCount);
        emit WithdrawNFTs(msg.sender, _pid, _nftCount);
    }

    // Withdraw NFTS without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdrawNFTs(uint256 _pid) public checkNoPause {
        (address _lpToken, uint256 _amount) = _emergencyWithdrawValue(_pid);
        uint256 _nftCount = _amount / 1e18;
        _transferOutNFTs(IERC721(_lpToken), _pid, _nftCount);
        emit EmergencyWithdrawNFTs(msg.sender, _pid, _nftCount);
    }

    function _transferOutNFTs(IERC721 nftContract, uint256 _pid, uint _nftCount) internal {
        uint256 nftID;
        uint256[] storage heldNFTs = userInfo[_pid][msg.sender].heldNFTs;
        uint idx = heldNFTs.length;
        require(idx >= _nftCount, "count too high");

        for(uint i = 0; i < _nftCount;) {
            unchecked { idx--; }
            nftID = heldNFTs[idx];
            nftContract.transferFrom(address(this), msg.sender, nftID);
            heldNFTs.pop();
            unchecked { i++; }
        }
    }

    function _withdrawValue(uint256 _pid, uint256 _amount) internal returns (address) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        uint256 userAmount = user.amount;
        require(_amount != 0 && userAmount >= _amount, "withdraw: not good");
        updatePool(_pid);

        user.rewardSettled = 
            userAmount *
            pool.accPointsPerShare /
            1e12 +
            user.rewardSettled -
            user.rewardDebt;

        balanceOf[_pid] = balanceOf[_pid] - _amount;
        userAmount = userAmount - _amount;
        user.rewardDebt = userAmount * pool.accPointsPerShare / 1e12;
        user.amount = userAmount;
        return pool.lpToken;
    }

    function _emergencyWithdrawValue(uint256 _pid) internal returns (address, uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        uint256 _amount = user.amount;

        balanceOf[_pid] = balanceOf[_pid] - _amount;
        user.amount = 0;
        user.rewardDebt = 0;
        return (pool.lpToken, _amount);
    }

    function getPoolInfo() external view returns(PoolInfo[] memory poolInfos) {
        uint256 length = poolInfo.length;
        poolInfos = new PoolInfo[](length);
        for(uint256 pid = 0; pid < length;) {
            poolInfos[pid] = poolInfo[pid];
            unchecked { ++pid; }
        }
    }

    function getOptimisedUserInfo(address[] memory _users) external view returns(uint256[2][][] memory userInfos) {
        userInfos = new uint256[2][][](_users.length);
        uint256 poolLength = poolInfo.length;
        for(uint256 i = 0; i < _users.length;) {
            address _user = _users[i];
            userInfos[i] = new uint256[2][](poolLength);
            for(uint256 pid = 0; pid < poolLength;) {
                userInfos[i][pid][0] = userInfo[pid][_user].amount;
                if (userInfo[pid][_user].heldNFTs.length != 0) {
                    userInfos[i][pid][0] = userInfos[i][pid][0] / 1e18;
                }

                userInfos[i][pid][1] = _pendingPoints(pid, _user);
                unchecked { ++pid; }
            }
            unchecked { i++; }
        }
    }

    function getUserInfo(address[] memory _users) external view returns(UserInfo[][] memory userInfos) {
        userInfos = new UserInfo[][](_users.length);
        uint256 poolLength = poolInfo.length;
        for(uint256 i = 0; i < _users.length;) {
            address _user = _users[i];
            userInfos[i] = new UserInfo[](poolLength);
            for(uint256 pid = 0; pid < poolLength;) {
                userInfos[i][pid] = userInfo[pid][_user];
                unchecked { ++pid; }
            }
            unchecked { i++; }
        }
    }

    function getPendingPoints(address[] memory _users) external view returns(uint256[][] memory pendings) {
        pendings = new uint256[][](_users.length);
        uint256 poolLength = poolInfo.length;
        for(uint256 i = 0; i < _users.length;) {
            address _user = _users[i];
            pendings[i] = new uint256[](poolLength);
            for(uint256 pid = 0; pid < poolLength;) {
                pendings[i][pid] = _pendingPoints(pid, _user);
                unchecked { ++pid; }
            }
            unchecked { i++; }
        }
    }

    /**
     * @notice Requires operator to be this contract
     */
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external override returns (bytes4) {
        require(operator == address(this), "unauthorized");
        return IERC721Receiver.onERC721Received.selector;
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "contracts/token/LinearVestingWithPenalty.sol";
import "contracts/farm/SophonFarmingL2.sol";

contract MerkleAirdrop is Initializable, AccessControlUpgradeable, UUPSUpgradeable {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    uint256 public constant VESTING_DURATION = 60 * 60 * 24 * 365; // 1 year
    uint256 public constant VESTING_LOCK_PERIOD = 60 * 60 * 24 * 365; // 1 year
    LinearVestingWithPenalty public vSOPH;
    SophonFarmingL2 public SF_L2;
    bytes32 public merkleRoot;

    // Changed mapping to track claims per user per PID
    mapping(address => mapping(uint256 => bool)) public hasClaimed;

    uint256 public totalPointRewards;  // Total points accumulated by all users
    uint256 public totalTokenRewards;  // Total tokens to be distributed

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
    // Info of each pool.
    PoolInfo[] public poolInfo;

    event Claimed(address indexed account, uint256 pid, uint256 amount);
    event MerkleRootUpdated(bytes32 newMerkleRoot);

    error AlreadyClaimed();
    error InvalidMerkleProof();
    error NotAuthorized();
    error InvalidInputLengths();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _vSOPH, address _SF_L2) public initializer {
        vSOPH = LinearVestingWithPenalty(_vSOPH);
        SF_L2 = SophonFarmingL2(_SF_L2);

        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    /**
     * @dev Sets the Merkle root for the airdrop.
     * @param _merkleRoot The new Merkle root.
     */
    function setMerkleRoot(bytes32 _merkleRoot) external onlyRole(ADMIN_ROLE) {
        merkleRoot = _merkleRoot;
        emit MerkleRootUpdated(_merkleRoot);
    }

    function setTotalTokenRewards(uint256 _totalTokenRewards) external onlyRole(ADMIN_ROLE) {
        totalTokenRewards = _totalTokenRewards;
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
        string memory _description
    ) public onlyRole(ADMIN_ROLE) {
        require(_amount == _boostAmount + _depositAmount, "balances don't match");
        poolInfo[_pid] = PoolInfo({
            lpToken: _lpToken,
            l2Farm: _l2Farm,
            amount: _amount,
            boostAmount: _boostAmount,
            depositAmount: _depositAmount,
            allocPoint: _allocPoint,
            lastRewardBlock: _lastRewardBlock,
            accPointsPerShare: _accPointsPerShare,
            totalRewards: _totalRewards,
            description: _description
        });
        totalPointRewards = totalPointRewards + _totalRewards;
    }

    function claim(address _user, address _customReceiver, uint256 _pid, SophonFarmingState.UserInfo memory _userInfo, bytes32[] calldata _merkleProof) external onlyRole(ADMIN_ROLE) {
        _claim(_user, _customReceiver, _pid, _userInfo, _merkleProof);
    }

    /**
     * @dev Allows users to claim their tokens if they are part of the Merkle tree.
     * @param _user The address of the user that is participating.
     * @param _pid The pool ID that the user is participating in.
     * @param _userInfo The `UserInfo` struct containing the user's info.
     * @param _merkleProof The Merkle proof to verify the user's inclusion in the tree.
     */
    function claim(address _user, uint256 _pid, SophonFarmingState.UserInfo memory _userInfo, bytes32[] calldata _merkleProof) external {
        if (msg.sender != _user) revert NotAuthorized();
        _claim(_user, _user, _pid, _userInfo, _merkleProof);
    }

    /**
    * @dev Allows users to claim multiple tokens if they are part of the Merkle tree.
    * @param _user The address of the user that is participating.
    * @param _pids An array of pool IDs that the user is participating in.
    * @param _userInfos An array of `UserInfo` structs containing the user's info for each pool.
    * @param _merkleProofs An array of Merkle proofs to verify the user's inclusion in the tree for each pool.
    */
    function claimMultiple(
        address _user,
        uint256[] calldata _pids,
        SophonFarmingState.UserInfo[] calldata _userInfos,
        bytes32[][] calldata _merkleProofs
    ) external {
        if (msg.sender != _user) revert NotAuthorized();
        if (_pids.length != _userInfos.length || _userInfos.length != _merkleProofs.length) revert InvalidInputLengths();

        for (uint256 i = 0; i < _pids.length; i++) {
            _claim(_user, _user, _pids[i], _userInfos[i], _merkleProofs[i]);
        }
    }

    // TODO add index
    function _claim(address _user, address _customReceiver, uint256 _pid, SophonFarmingState.UserInfo memory _userInfo, bytes32[] calldata _merkleProof) internal {
        if (hasClaimed[_user][_pid]) revert AlreadyClaimed();

        // Verify the Merkle proof.
        bytes32 leaf = keccak256(abi.encodePacked(_user, _pid, _userInfo.amount, _userInfo.boostAmount, _userInfo.depositAmount, _userInfo.rewardSettled, _userInfo.rewardDebt));
        if (!MerkleProof.verify(_merkleProof, merkleRoot, leaf)) revert InvalidMerkleProof();

        // Calculate the total reward based on points (assumed as total LP tokens, i.e., amount).
        uint256 reward = _calculateReward(_pid, _userInfo);
        PoolInfo storage poolInfo = poolInfo[_pid];
        // Mark it claimed and transfer the tokens.
        hasClaimed[_user][_pid] = true;
        vSOPH.addVestingSchedule(_customReceiver, VESTING_DURATION, reward, VESTING_DURATION);
        _userInfo.rewardDebt = _userInfo.amount * poolInfo.accPointsPerShare / 1e18;
        _userInfo.rewardSettled = 0;
        SF_L2.updateUserInfo(_customReceiver, _pid, _userInfo);
        emit Claimed(_user, _pid, reward);
    }

    function _calculateReward(uint256 _pid, SophonFarmingState.UserInfo memory _userInfo) internal view returns (uint256) {
        uint256 userPoints = _pendingPoints(_pid, _userInfo);
        return (userPoints * totalTokenRewards) / totalPointRewards;
    }

    function _pendingPoints(uint256 _pid, SophonFarmingState.UserInfo memory _userInfo) internal view returns (uint256) {
        PoolInfo memory pool = poolInfo[_pid];
        return _userInfo.amount *
            pool.accPointsPerShare /
            1e18 +
            _userInfo.rewardSettled -
            _userInfo.rewardDebt;
    }

    /**
     * @dev Allows the recovery of any ERC20 tokens sent to the contract by mistake.
     * @param token The address of the token to recover.
     * @param to The address to send the recovered tokens to.
     */
    function rescue(IERC20 token, address to) external onlyRole(ADMIN_ROLE) {
        SafeERC20.safeTransfer(token, to, token.balanceOf(address(this)));
    }

    /**
     * @dev Required by UUPSUpgradeable to authorize upgrades.
     * @param newImplementation The address of the new implementation.
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(ADMIN_ROLE) {}
}
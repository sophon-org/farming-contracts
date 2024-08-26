// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "contracts/token/LinearVestingSophon.sol";
import "contracts/farm/SophonFarmingL2.sol";

contract MerkleAirdrop is Initializable, AccessControlUpgradeable, UUPSUpgradeable {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    uint256 public constant VESTING_DURATION = 60 * 60 * 24 * 365; // 1 year
    LinearVestingSophon public vSOPH;
    SophonFarmingL2 public SF_L2;
    bytes32 public merkleRoot;
    mapping(address => bool) public hasClaimed;

    event Claimed(address indexed account, uint256 amount);
    event MerkleRootUpdated(bytes32 newMerkleRoot);

    error AlreadyClaimed();
    error InvalidMerkleProof();
    error NotAuthorized();


    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _vSOPH, address _SF_L2) public initializer {
        vSOPH = LinearVestingSophon(_vSOPH);
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

    /**
     * @dev Allows users to claim their tokens if they are part of the Merkle tree.
     * @param _user The address of the user that is participating.
     * @param _pid The pool ID that the user is participating in.
     * @param _userInfo The `UserInfo` struct containing the user's info.
     * @param _merkleProof The Merkle proof to verify the user's inclusion in the tree.
     */
    function claim(address _user, uint256 _pid, SophonFarmingState.UserInfo memory _userInfo, bytes32[] calldata _merkleProof) external {
  
        if (hasClaimed[_user]) revert AlreadyClaimed();

        // Verify the Merkle proof.
        bytes32 leaf = keccak256(abi.encodePacked(_user, _pid, _userInfo.amount, _userInfo.boostAmount, _userInfo.depositAmount, _userInfo.rewardSettled, _userInfo.rewardDebt));
        if (!MerkleProof.verify(_merkleProof, merkleRoot, leaf)) revert InvalidMerkleProof();

        // Calculate the total reward based on points (assumed as total LP tokens, i.e., amount).
        uint256 reward = _calculateReward(_userInfo.amount, _userInfo.boostAmount);

        // Mark it claimed and transfer the tokens.
        hasClaimed[_user] = true;
        vSOPH.addVestingSchedule(_user, block.timestamp, VESTING_DURATION, reward);
        SF_L2.updateUserInfo(_user, _pid, _userInfo);
        emit Claimed(_user, reward);
    }

    /**
     * @dev Calculates the reward based on the user's points (LP tokens).
     * @param amount The amount of LP tokens the user has.
     * @param boostAmount The amount of boosted tokens.
     * @return The amount of tokens the user can claim.
     */
    function _calculateReward(uint256 amount, uint256 boostAmount) internal pure returns (uint256) {
        // Example: if 1 point (amount + boostAmount) = 10 tokens, return totalPoints * 10.
        // Adjust the ratio as needed. Here, I'm using 10 as an arbitrary multiplier.
        uint256 totalPoints = amount + boostAmount;
        uint256 tokenRatio = 10; // Example: 1 point = 10 tokens
        return totalPoints * tokenRatio;
    }

    // function _pendingPoints(uint256 _pid, address _user, UserInfo _userInfo) internal view returns (uint256) {
    //     UserInfo userInfo = userInfo[_pid][_user];
    //     PoolInfo poolInfo = poolInfo[_pid];
    //     return user.amount *
    //         accPointsPerShare /
    //         1e18 +
    //         user.rewardSettled -
    //         user.rewardDebt;
    // }

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

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "contracts/token/LinearVestingWithPenalty.sol";
import "contracts/farm/SophonFarmingL2.sol";

contract MerkleAirdrop is Initializable, AccessControlUpgradeable, UUPSUpgradeable {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    SophonFarmingL2 public SF_L2;
    bytes32 public merkleRoot;

    // Changed mapping to track claims per user per PID
    mapping(address => mapping(uint256 => bool)) public hasClaimed;


    event Claimed(address indexed account, uint256 pid);
    event MerkleRootUpdated(bytes32 newMerkleRoot);
    event SFL2AddressUpdated(address indexed oldAddress, address indexed newAddress);

    error AlreadyClaimed();
    error InvalidMerkleProof();
    error NotAuthorized();
    error InvalidInputLengths();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }


    function unclaim(address user, uint256 id) public onlyRole(ADMIN_ROLE) {
        hasClaimed[user][id] = false; // Unset the boolean
    }

    function initialize(address _SF_L2) public initializer {
        require(_SF_L2 != address(0), "SF_L2 is zero address");
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
     * @dev Sets or updates the SF_L2 contract address.
     * @param _SF_L2 The address of the new SophonFarmingL2 contract.
     */
    function setSFL2(address _SF_L2) external onlyRole(ADMIN_ROLE) {
        require(_SF_L2 != address(0), "Invalid address");
        address oldAddress = address(SF_L2);
        SF_L2 = SophonFarmingL2(_SF_L2);
        emit SFL2AddressUpdated(oldAddress, _SF_L2);
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

    function _claim(address _user, address _customReceiver, uint256 _pid, SophonFarmingState.UserInfo memory _userInfo, bytes32[] calldata _merkleProof) internal {
        bool alreadyClaimed = hasClaimed[_user][_pid];
        if (alreadyClaimed) revert AlreadyClaimed();

        // Verify the Merkle proof.
        bytes32 leaf = keccak256(abi.encodePacked(_user, _pid, _userInfo.amount, _userInfo.boostAmount, _userInfo.depositAmount, _userInfo.rewardSettled, _userInfo.rewardDebt));
        if (!MerkleProof.verify(_merkleProof, merkleRoot, leaf)) revert InvalidMerkleProof();

        // Mark it claimed and update user info.
        hasClaimed[_user][_pid] = true;

        SF_L2.updateUserInfo(_customReceiver, _pid, _userInfo);
        emit Claimed(_user, _pid);
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

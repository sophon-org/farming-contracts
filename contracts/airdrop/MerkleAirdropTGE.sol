// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.26;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract MerkleAirdropTGE is Initializable, AccessControlUpgradeable {
    using SafeERC20 for IERC20;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public merkleRoot;
    mapping(address => bool) public hasClaimed;

    event Claimed(address indexed account, uint256 amount);
    event MerkleRootUpdated(bytes32 newMerkleRoot);

    error AlreadyClaimed();
    error InvalidMerkleProof();
    error NotAuthorized();
    error InvalidInputLengths();

    constructor() {
        _disableInitializers();
    }

    function initialize() external initializer {
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    function setMerkleRoot(bytes32 _merkleRoot) external onlyRole(ADMIN_ROLE) {
        merkleRoot = _merkleRoot;
        emit MerkleRootUpdated(_merkleRoot);
    }

    function claim(address _user, uint256 _amount, bytes32[] calldata _merkleProof) external {
        if (msg.sender != _user) revert NotAuthorized();
        _processClaim(_user, _user, _amount, _merkleProof);
    }

    function claimWithCustomReceiver(
        address _user, 
        address _customReceiver, 
        uint256 _amount, 
        bytes32[] calldata _merkleProof
    ) external onlyRole(ADMIN_ROLE) {
        _processClaim(_user, _customReceiver, _amount, _merkleProof);
    }

    function unclaim(address user) external onlyRole(ADMIN_ROLE) {
        hasClaimed[user] = false;
    }

    function rescue(IERC20 token, address to) external onlyRole(ADMIN_ROLE) {
        token.safeTransfer(to, token.balanceOf(address(this)));
    }

    function _processClaim(
        address _user, 
        address _customReceiver, 
        uint256 _amount, 
        bytes32[] calldata _merkleProof
    ) internal {
        if (hasClaimed[_user]) revert AlreadyClaimed();

        bytes32 leaf = keccak256(abi.encodePacked(_user, _amount));
        if (!MerkleProof.verify(_merkleProof, merkleRoot, leaf)) revert InvalidMerkleProof();

        hasClaimed[_user] = true;
        emit Claimed(_user, _amount);
    }
}

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.26;

interface IMerkleClaimer {
    event Claimed(address indexed account, uint256 amount, uint256 merkleIndex);
    event ClaimedAndStaked(address indexed account, uint256 claimAmount, uint256 stakedAmount, uint256 merkleIndex);
    event Funded(address indexed sender, uint256 amount);
    event MerkleRootUpdated(bytes32 newMerkleRoot);

    error IsClaimed();
    error InvalidMerkleProof();
    error InvalidInputLengths();
    error InvalidStakeAmount();
    error InvalidSignature();
    error NotAuthorized();
    error SignatureExpired();
    error TransferFailed();
    error ZeroAddress();

    function initialize(address admin) external;
    function setDomainSeparator() external;
    function setMerkleRoot(bytes32 _merkleRoot) external;
    function claim(address _user, uint256 _amount, uint256 _merkleIndex, bytes32[] calldata _merkleProof) external;
    function claim(
        address _user,
        uint256 _amount,
        uint256 _merkleIndex,
        bytes32[] calldata _merkleProof,
        bytes calldata _signature,
        uint256 _expiry
    ) external;

    function claimAndStake(
        address _user,
        uint256 _amount,
        uint256 _stakeAmount,
        uint256 _merkleIndex,
        bytes32[] calldata _merkleProof
    ) external payable;

    function claimAndStake(
        address _user,
        uint256 _amount,
        uint256 _stakeAmount,
        uint256 _merkleIndex,
        bytes32[] calldata _merkleProof,
        bytes calldata _signature,
        uint256 _expiry
    ) external payable;

    function claimWithCustomReceiver(
        address _user,
        address _customReceiver,
        uint256 _amount,
        uint256 _merkleIndex,
        bytes32[] calldata _merkleProof
    ) external;

    function batchClaim(
        address[] calldata users,
        uint256[] calldata amounts,
        uint256[] calldata merkleIndices,
        bytes32[][] calldata merkleProofs
    ) external;

    function batchClaimAndStake(
        address[] calldata users,
        uint256[] calldata amounts,
        uint256[] calldata stakeAmounts,
        uint256[] calldata merkleIndices,
        bytes32[][] calldata merkleProofs
    ) external;

    function unclaim(uint256 merkleIndex) external;
    function unclaimBatch(uint256[] calldata merkleIndices) external;

    function merkleRoot() external view returns (bytes32);
    function domainSeparator() external view returns (bytes32);
    function isClaimed(uint256 index) external view returns (bool);
    function nonces(address user) external view returns (uint256);
}

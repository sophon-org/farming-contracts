// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

interface SophonFarmingLike {
    function _handleTransfer(uint256 pid, address from, address to, uint256 amount, uint256 depositBeforeTransfer) external;
}

contract PoolShareToken {

    error Unauthorized();
    error InsufficientBalance();
    error InsufficientAllowance();
    error DeadlineExpired();
    error InvalidSignature();

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);

    // --- ERC20 Data ---
    string  public name;
    string  public symbol;
    uint8   public immutable decimals;
    uint256 public totalSupply;

    mapping (address => uint256)                      public balanceOf;
    mapping (address => mapping (address => uint256)) public allowance;
    mapping (address => uint256)                      public nonces;

    // --- EIP712 niceties ---
    bytes32 public DOMAIN_SEPARATOR;
    // keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes32 public constant PERMIT_TYPEHASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;

    uint256 public immutable pid;
    SophonFarmingLike public immutable controller;

    constructor(string memory symbol_, uint256 pid_) {
        name = string(abi.encodePacked(symbol_, " Token"));
        symbol = symbol_;
        decimals = 18;

        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(name)),
                keccak256(bytes("1")),
                block.chainid,
                address(this)
            )
        );

        pid = pid_;
        controller = SophonFarmingLike(msg.sender);
    }

    // --- Token ---

    function transfer(address to, uint256 value) external returns (bool) {
        return transferFrom(msg.sender, to, value);
    }

    function transferFrom(address from, address to, uint256 value) public returns (bool) {
        uint256 balanceFromBeforeTransfer = balanceOf[from];
        if (value > balanceFromBeforeTransfer) {
            revert InsufficientBalance();
        }

        uint256 allowed = allowance[from][msg.sender];
        if (from != msg.sender && allowed != type(uint256).max) {
            if (allowed < value) {
                revert InsufficientAllowance();
            }

            unchecked {
                allowance[from][msg.sender] = allowed - value;
            }
        }

        if (value != 0) {
            // settle pool balances
            controller._handleTransfer(pid, from, to, value, balanceFromBeforeTransfer);

            balanceOf[from] = balanceFromBeforeTransfer - value;
            balanceOf[to] = balanceOf[to] + value;
        }

        emit Transfer(from, to, value);

        return true;
    }

    function mint(address user, uint256 value) external {
        if (msg.sender != address(controller)) {
            revert Unauthorized();
        }

        balanceOf[user] = balanceOf[user] + value;
        totalSupply     = totalSupply + value;

        emit Transfer(address(0), user, value);
    }

    function burn(address user, uint256 value) external {
        if (msg.sender != address(controller)) {
            revert Unauthorized();
        }

        uint256 userBalance = balanceOf[user];
        if (userBalance < value) {
            revert InsufficientBalance();
        }

        unchecked {
            balanceOf[user] = userBalance - value;
            totalSupply     = totalSupply - value;
        }

        emit Transfer(user, address(0), value);
    }

    function approve(address user, uint256 value) external returns (bool) {
        allowance[msg.sender][user] = value;
        emit Approval(msg.sender, user, value);
        return true;
    }

    // --- Approve by signature ---
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        if (deadline < block.timestamp) {
            revert DeadlineExpired();
        }

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, nonces[owner]++, deadline))));
        address recoveredAddress = ecrecover(digest, v, r, s);

        if (recoveredAddress == address(0) || recoveredAddress != owner) {
            revert InvalidSignature();
        }

        allowance[owner][spender] = value;
        emit Approval(owner, spender, value);
    }
}

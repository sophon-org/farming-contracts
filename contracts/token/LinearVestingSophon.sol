// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract LinearVestingSophon is Initializable, ERC20Upgradeable, AccessControlUpgradeable, UUPSUpgradeable {
    struct VestingSchedule {
        uint256 totalAmount;
        uint256 released;
        uint256 start;
        uint256 duration;
    }

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    IERC20 public sophtoken;
    uint256 public vestingStartTime;
    mapping(address => VestingSchedule) public vestingSchedules;

    event TokensReleased(address indexed beneficiary, uint256 amount);
    event TokensRecovered(address indexed admin, uint256 amount);
    event VestingScheduleAdded(address indexed beneficiary, uint256 totalAmount, uint256 start, uint256 duration);
    event VestingStartTimeUpdated(uint256 newVestingStartTime);

    // Custom errors
    error VestingScheduleAlreadyExists();
    error TotalAmountMustBeGreaterThanZero();
    error DurationMustBeGreaterThanZero();
    error NoVestingSchedule();
    error VestingHasNotStartedYet();
    error NoTokensToRelease();
    error InsufficientVestedAmount();
    error InsufficientBalanceInContract();
    error TokenTransferFailed();
    error VestingStartTimeCannotBeInThePast();

    // Initializer function
    function initialize(address tokenAddress) public initializer {
        __ERC20_init("vesting Sophon Token", "vSOPH");
        __AccessControl_init();
        __UUPSUpgradeable_init();

        sophtoken = IERC20(tokenAddress);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    function setVestingStartTime(uint256 newVestingStartTime) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newVestingStartTime < block.timestamp) revert VestingStartTimeCannotBeInThePast();
        vestingStartTime = newVestingStartTime;
        emit VestingStartTimeUpdated(newVestingStartTime);
    }

    function addVestingSchedule(
        address beneficiary,
        uint256 start,
        uint256 duration,
        uint256 totalAmount
    ) external onlyRole(ADMIN_ROLE) {
        if (vestingSchedules[beneficiary].totalAmount > 0) revert VestingScheduleAlreadyExists();
        if (totalAmount == 0) revert TotalAmountMustBeGreaterThanZero();
        if (duration == 0) revert DurationMustBeGreaterThanZero();

        // Ensure start time is not before vestingStartTime
        uint256 adjustedStart = start < vestingStartTime ? vestingStartTime : start;

        vestingSchedules[beneficiary] = VestingSchedule({
            totalAmount: totalAmount,
            released: 0,
            start: adjustedStart,
            duration: duration
        });

        // Mint vesting tokens to the beneficiary
        _mint(beneficiary, totalAmount);

        // Ensure the contract receives SOPH tokens for vesting
        if (!sophtoken.transferFrom(msg.sender, address(this), totalAmount)) revert TokenTransferFailed();

        emit VestingScheduleAdded(beneficiary, totalAmount, adjustedStart, duration);
    }

    function release() external {
        VestingSchedule storage schedule = vestingSchedules[msg.sender];
        if (schedule.totalAmount == 0) revert NoVestingSchedule();
        if (block.timestamp < schedule.start) revert VestingHasNotStartedYet();

        uint256 vestedAmount = _vestedAmount(schedule);
        uint256 releasableAmount = vestedAmount - schedule.released;

        if (releasableAmount == 0) revert NoTokensToRelease();

        schedule.released += releasableAmount;
        _burn(msg.sender, releasableAmount);

        // Transfer the equivalent amount of SOPH tokens to the user
        if (!sophtoken.transfer(msg.sender, releasableAmount)) revert TokenTransferFailed();

        emit TokensReleased(msg.sender, releasableAmount);
    }

    function _vestedAmount(VestingSchedule storage schedule) internal view returns (uint256) {
        if (block.timestamp >= schedule.start + schedule.duration) {
            return schedule.totalAmount;
        } else {
            return (schedule.totalAmount * (block.timestamp - schedule.start)) / schedule.duration;
        }
    }

    function vestedAmount(address beneficiary) external view returns (uint256) {
        VestingSchedule storage schedule = vestingSchedules[beneficiary];
        return _vestedAmount(schedule);
    }

    function releasableAmount(address beneficiary) external view returns (uint256) {
        VestingSchedule storage schedule = vestingSchedules[beneficiary];
        return _vestedAmount(schedule) - schedule.released;
    }

    function transferTokens(address from, address to, uint256 amount) external onlyRole(ADMIN_ROLE) {
        VestingSchedule storage fromSchedule = vestingSchedules[from];
        VestingSchedule storage toSchedule = vestingSchedules[to];

        if (fromSchedule.released < amount) revert InsufficientVestedAmount();
        
        fromSchedule.released -= amount;
        toSchedule.released += amount;

        _transfer(from, to, amount);
    }


    function recoverTokens(uint256 amount) external onlyRole(ADMIN_ROLE) {
        uint256 contractBalance = sophtoken.balanceOf(address(this));
        if (amount > contractBalance) revert InsufficientBalanceInContract();
        if (!sophtoken.transfer(msg.sender, amount)) revert TokenTransferFailed();
        emit TokensRecovered(msg.sender, amount);
    }

    // Function required by UUPSUpgradeable
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}
}

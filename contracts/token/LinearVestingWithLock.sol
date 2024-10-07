// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract LinearVestingWithLock is Initializable, ERC20Upgradeable, AccessControlUpgradeable, UUPSUpgradeable {
    struct VestingSchedule {
        uint256 totalAmount;
        uint256 released;
        uint256 start;
        uint256 duration;
        uint256 lockPeriod; // New: lock period in seconds
    }

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    IERC20 public sophtoken;
    address public paymaster; // New: address to receive penalties
    uint256 public vestingStartTime;
    mapping(address => VestingSchedule) public vestingSchedules;

    event TokensReleased(address indexed beneficiary, uint256 amount);
    event VestingScheduleAdded(address indexed beneficiary, uint256 totalAmount, uint256 start, uint256 duration, uint256 lockPeriod);
    event VestingStartTimeUpdated(uint256 newVestingStartTime);
    event PaymasterUpdated(address newPaymaster); // New event
    event PenaltyPaid(address indexed beneficiary, uint256 penaltyAmount); // New event

    // Custom errors
    error TotalAmountMustBeGreaterThanZero();
    error DurationMustBeGreaterThanZero();
    error NoVestingSchedule();
    error VestingHasNotStartedYet();
    error NoTokensToRelease();
    error InsufficientVestedAmount();
    error TokenTransferFailed();
    error VestingStartTimeCannotBeInThePast();
    error LockPeriodActive(); // New error for lock period violation

    // Initializer function
    function initialize(address tokenAddress, address initialPaymaster) public initializer {
        __ERC20_init("vesting Sophon Token", "vSOPH");
        __AccessControl_init();
        __UUPSUpgradeable_init();

        sophtoken = IERC20(tokenAddress);
        paymaster = initialPaymaster; // Set the initial paymaster
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    function setPaymaster(address newPaymaster) external onlyRole(ADMIN_ROLE) {
        paymaster = newPaymaster;
        emit PaymasterUpdated(newPaymaster);
    }

    function setVestingStartTime(uint256 newVestingStartTime) external onlyRole(ADMIN_ROLE) {
        if (newVestingStartTime < block.timestamp) revert VestingStartTimeCannotBeInThePast();
        vestingStartTime = newVestingStartTime;
        emit VestingStartTimeUpdated(newVestingStartTime);
    }

    function addVestingSchedule(
        address beneficiary,
        uint256 start,
        uint256 duration,
        uint256 lockPeriod,
        uint256 totalAmount
    ) external onlyRole(ADMIN_ROLE) {
        VestingSchedule storage schedule = vestingSchedules[beneficiary];

        if (schedule.totalAmount > 0) {
            // If a schedule exists, merge the new values using weighted averages

            uint256 totalAmountBefore = schedule.totalAmount;
            uint256 newTotalAmount = totalAmountBefore + totalAmount;

            // Weighted average for duration
            schedule.duration = (
                (schedule.duration * totalAmountBefore) + (duration * totalAmount)
            ) / newTotalAmount;

            // Weighted average for start time
            schedule.start = (
                (schedule.start * totalAmountBefore) + (start * totalAmount)
            ) / newTotalAmount;

            // Weighted average for lock period
            schedule.lockPeriod = (
                (schedule.lockPeriod * totalAmountBefore) + (lockPeriod * totalAmount)
            ) / newTotalAmount;

            // Update total amount
            schedule.totalAmount = newTotalAmount;
        } else {
            // Create a new schedule
            if (totalAmount == 0) revert TotalAmountMustBeGreaterThanZero();
            if (duration == 0) revert DurationMustBeGreaterThanZero();

            // Ensure start time is not before vestingStartTime
            schedule.start = start < vestingStartTime ? vestingStartTime : start;
            schedule.totalAmount = totalAmount;
            schedule.released = 0;
            schedule.duration = duration;
            schedule.lockPeriod = lockPeriod; // Set the lock period

            // Mint vesting tokens to the beneficiary
            _mint(beneficiary, totalAmount);
        }

        emit VestingScheduleAdded(beneficiary, schedule.totalAmount, schedule.start, schedule.duration, schedule.lockPeriod);
    }


    function release(bool acceptPenalty) external {
        VestingSchedule storage schedule = vestingSchedules[msg.sender];
        if (schedule.totalAmount == 0) revert NoVestingSchedule();

        uint256 currentTime = block.timestamp;

        // Check if still in lock period
        if (currentTime < schedule.start + schedule.lockPeriod) {
            if (!acceptPenalty) revert LockPeriodActive(); // User did not accept the penalty

            // Apply penalty: Reduce total amount by 50%
            uint256 penalty = (schedule.totalAmount * 50) / 100;
            schedule.totalAmount -= penalty;

            // Transfer the penalty to the paymaster
            if (!sophtoken.transfer(paymaster, penalty)) revert TokenTransferFailed();

            // Burn the penalized tokens from the beneficiary's balance
            _burn(msg.sender, penalty);

            emit PenaltyPaid(msg.sender, penalty);
        }

        // Proceed with the usual vesting logic
        if (currentTime < schedule.start) revert VestingHasNotStartedYet();

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
        uint256 currentTime = block.timestamp;

        if (currentTime >= schedule.start + schedule.duration) {
            return schedule.totalAmount;
        } else if (currentTime < schedule.start) {
            return 0;
        } else {
            return (schedule.totalAmount * (currentTime - schedule.start)) / schedule.duration;
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

        // Check that `from` has a vesting schedule
        if (fromSchedule.totalAmount == 0) revert NoVestingSchedule();

        // Check that `from` has enough unredeemed tokens to transfer
        uint256 transferableAmount = fromSchedule.totalAmount - fromSchedule.released;
        if (amount > transferableAmount) revert InsufficientVestedAmount();

        // Deduct the amount from `from` account's schedule
        fromSchedule.totalAmount -= amount;

        // If the `to` account already has a schedule, merge the schedules
        if (toSchedule.totalAmount > 0) {
            uint256 totalAmount = toSchedule.totalAmount + amount;

            // Calculate weighted averages
            toSchedule.start = (
                (toSchedule.start * toSchedule.totalAmount) + (fromSchedule.start * amount)
            ) / totalAmount;

            toSchedule.duration = (
                (toSchedule.duration * toSchedule.totalAmount) + (fromSchedule.duration * amount)
            ) / totalAmount;

            toSchedule.lockPeriod = (
                (toSchedule.lockPeriod * toSchedule.totalAmount) + (fromSchedule.lockPeriod * amount)
            ) / totalAmount;

            // Update the total amount
            toSchedule.totalAmount = totalAmount;
            // `released` remains unchanged
        } else {
            // Create a new schedule for `to`
            toSchedule.totalAmount = amount;
            toSchedule.released = 0;
            toSchedule.start = fromSchedule.start;
            toSchedule.duration = fromSchedule.duration;
            toSchedule.lockPeriod = fromSchedule.lockPeriod;
        }

        // Transfer the `vSOPH` tokens
        _transfer(from, to, amount);
    }


    function rescue(IERC20 token, address to) external onlyRole(ADMIN_ROLE) {
        SafeERC20.safeTransfer(token, to, token.balanceOf(address(this)));
    }

    // Function required by UUPSUpgradeable
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(ADMIN_ROLE) {}
}

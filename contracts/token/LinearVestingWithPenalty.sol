// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract LinearVestingWithPenalty is Initializable, ERC20Upgradeable, AccessControlUpgradeable, UUPSUpgradeable {
    struct VestingSchedule {
        uint256 totalAmount;
        uint256 released;
        uint256 duration;
    }

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    IERC20 public sophtoken;
    address public paymaster; // Address to receive penalties
    uint256 public vestingStartDate; // Global start date for all vesting schedules
    mapping(address => VestingSchedule) public vestingSchedules;

    event TokensReleased(address indexed beneficiary, uint256 amount);
    event VestingScheduleAdded(address indexed beneficiary, uint256 totalAmount, uint256 duration);
    event VestingStartDateUpdated(uint256 newVestingStartDate);
    event PaymasterUpdated(address newPaymaster);
    event PenaltyPaid(address indexed beneficiary, uint256 penaltyAmount);

    // Custom errors
    error TotalAmountMustBeGreaterThanZero();
    error DurationMustBeGreaterThanZero();
    error NoVestingSchedule();
    error VestingHasNotStartedYet();
    error NoTokensToRelease();
    error InsufficientVestedAmount();
    error TokenTransferFailed();
    error VestingStartDateAlreadySet(); // New error for vesting start date already set
    error VestingStartDateCannotBeInThePast();

    // Initializer function
    function initialize(address tokenAddress, address initialPaymaster) public initializer {
        __ERC20_init("vesting Sophon Token", "vSOPH");
        __AccessControl_init();
        __UUPSUpgradeable_init();

        sophtoken = IERC20(tokenAddress);
        paymaster = initialPaymaster;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    function setPaymaster(address newPaymaster) external onlyRole(ADMIN_ROLE) {
        paymaster = newPaymaster;
        emit PaymasterUpdated(newPaymaster);
    }

    function setVestingStartDate(uint256 newVestingStartDate) external onlyRole(ADMIN_ROLE) {
        if (vestingStartDate != 0) revert VestingStartDateAlreadySet();
        if (newVestingStartDate < block.timestamp) revert VestingStartDateCannotBeInThePast();
        vestingStartDate = newVestingStartDate;
        emit VestingStartDateUpdated(newVestingStartDate);
    }

    function addVestingSchedule(
        address beneficiary,
        uint256 duration,
        uint256 totalAmount
    ) external onlyRole(ADMIN_ROLE) {
        VestingSchedule storage schedule = vestingSchedules[beneficiary];

        if (schedule.totalAmount > 0) {
            uint256 totalAmountBefore = schedule.totalAmount;
            uint256 newTotalAmount = totalAmountBefore + totalAmount;

            // Weighted average for duration
            schedule.duration = (
                (schedule.duration * totalAmountBefore) + (duration * totalAmount)
            ) / newTotalAmount;

            schedule.totalAmount = newTotalAmount;
        } else {
            if (totalAmount == 0) revert TotalAmountMustBeGreaterThanZero();
            if (duration == 0) revert DurationMustBeGreaterThanZero();

            schedule.totalAmount = totalAmount;
            schedule.released = 0;
            schedule.duration = duration;

            _mint(beneficiary, totalAmount);
        }

        emit VestingScheduleAdded(beneficiary, schedule.totalAmount, schedule.duration);
    }

    function release(bool acceptPenalty, uint256 amount) external {
        VestingSchedule storage schedule = vestingSchedules[msg.sender];
        if (schedule.totalAmount == 0) revert NoVestingSchedule();

        uint256 currentTime = block.timestamp;
        if (vestingStartDate == 0 || currentTime < vestingStartDate) revert VestingHasNotStartedYet();

        uint256 vestedAmount = _vestedAmount(schedule);
        uint256 releasableAmount = vestedAmount - schedule.released;

        if (amount > releasableAmount) revert NoTokensToRelease();

        uint256 penalty = 0;
        if (acceptPenalty) {
            penalty = (amount * 50) / 100;
            schedule.totalAmount -= penalty;

            if (!sophtoken.transfer(paymaster, penalty)) revert TokenTransferFailed();

            _burn(msg.sender, penalty);
            emit PenaltyPaid(msg.sender, penalty);
        }

        schedule.released += amount - penalty;
        _burn(msg.sender, amount - penalty);

        if (!sophtoken.transfer(msg.sender, amount - penalty)) revert TokenTransferFailed();

        emit TokensReleased(msg.sender, amount - penalty);
    }

    function _vestedAmount(VestingSchedule storage schedule) internal view returns (uint256) {
        if (vestingStartDate == 0 || block.timestamp < vestingStartDate) {
            return 0; // No vesting if the global start date is not defined or hasn’t passed
        }

        uint256 currentTime = block.timestamp;

        if (currentTime >= vestingStartDate + schedule.duration) {
            return schedule.totalAmount;
        } else {
            return (schedule.totalAmount * (currentTime - vestingStartDate)) / schedule.duration;
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

        if (fromSchedule.totalAmount == 0) revert NoVestingSchedule();

        uint256 transferableAmount = fromSchedule.totalAmount - fromSchedule.released;
        if (amount > transferableAmount) revert InsufficientVestedAmount();

        fromSchedule.totalAmount -= amount;

        if (toSchedule.totalAmount > 0) {
            uint256 totalAmount = toSchedule.totalAmount + amount;

            toSchedule.duration = (
                (toSchedule.duration * toSchedule.totalAmount) + (fromSchedule.duration * amount)
            ) / totalAmount;

            toSchedule.totalAmount = totalAmount;
        } else {
            toSchedule.totalAmount = amount;
            toSchedule.released = 0;
            toSchedule.duration = fromSchedule.duration;
        }

        _transfer(from, to, amount);
    }

    function rescue(IERC20 token, address to) external onlyRole(ADMIN_ROLE) {
        SafeERC20.safeTransfer(token, to, token.balanceOf(address(this)));
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(ADMIN_ROLE) {}
}

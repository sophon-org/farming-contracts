// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title LinearVestingWithPenalty
 * @dev This contract manages multiple vesting schedules with an optional early withdrawal penalty.
 * Beneficiaries can have multiple schedules and release tokens according to their schedules.
 * The contract is upgradeable and uses role-based access control.
 */
contract LinearVestingWithPenalty is Initializable, ERC20Upgradeable, AccessControlUpgradeable, UUPSUpgradeable {
    using SafeERC20 for IERC20;

    struct VestingSchedule {
        uint256 totalAmount; // Total tokens to be vested
        uint256 released;    // Amount of tokens released so far
        uint256 duration;    // Duration of the vesting schedule in seconds
        uint256 startDate;   // Start date of the vesting schedule
    }

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant SCHEDULE_MANAGER_ROLE = keccak256("SCHEDULE_MANAGER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    IERC20 public sophtoken;                 // The underlying token being vested
    address public penaltyRecipient;         // Address receiving penalties
    uint256 public vestingStartDate;         // Global vesting start date
    uint256 public penaltyPercentage;        // Penalty percentage for early withdrawals (e.g., 50 for 50%)

    mapping(address => VestingSchedule[]) public vestingSchedules; // Vesting schedules per beneficiary
    mapping(address => uint256) public activeVestingSchedulesCount; // Active vesting schedules per beneficiary

    event TokensReleased(address indexed beneficiary, uint256 grossAmount, uint256 netAmount, uint256 penaltyAmount);
    event VestingScheduleAdded(address indexed beneficiary, uint256 totalAmount, uint256 duration, uint256 startDate);
    event VestingStartDateUpdated(uint256 newVestingStartDate);
    event PenaltyRecipientUpdated(address newPenaltyRecipient);
    event PenaltyPercentageUpdated(uint256 newPenaltyPercentage);
    event PenaltyPaid(address indexed beneficiary, uint256 penaltyAmount);

    error TotalAmountMustBeGreaterThanZero();
    error DurationMustBeGreaterThanZero();
    error NoVestingSchedule();
    error VestingHasNotStartedYet();
    error NoTokensToRelease();
    error TokenTransferFailed();
    error VestingStartDateAlreadySet();
    error VestingStartDateCannotBeInThePast();
    error EtherNotAccepted();
    error InvalidScheduleIndex();
    error InvalidRange();
    error InvalidRecipientAddress();

    /**
     * @dev Initializes the contract with the given token address, initial penalty recipient, and penalty percentage.
     * @param tokenAddress The address of the token to be vested.
     * @param initialPenaltyRecipient The address that will receive penalties.
     * @param initialPenaltyPercentage The initial penalty percentage (e.g., 50 for 50%).
     */
    function initialize(
        address tokenAddress,
        address initialPenaltyRecipient,
        uint256 initialPenaltyPercentage
    ) public initializer {
        if (tokenAddress == address(0)) revert InvalidRecipientAddress();
        if (initialPenaltyRecipient == address(0)) revert InvalidRecipientAddress();
        require(initialPenaltyPercentage <= 100, "Penalty must be <= 100%");

        __ERC20_init("vesting Sophon Token", "vSOPH");
        __AccessControl_init();
        __UUPSUpgradeable_init();

        sophtoken = IERC20(tokenAddress);
        penaltyRecipient = initialPenaltyRecipient;
        penaltyPercentage = initialPenaltyPercentage;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(SCHEDULE_MANAGER_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);
    }

    /**
     * @dev Sets the penalty recipient address.
     * @param newPenaltyRecipient The new penalty recipient address.
     */
    function setPenaltyRecipient(address newPenaltyRecipient) external onlyRole(ADMIN_ROLE) {
        if (newPenaltyRecipient == address(0)) revert InvalidRecipientAddress();
        penaltyRecipient = newPenaltyRecipient;
        emit PenaltyRecipientUpdated(newPenaltyRecipient);
    }

    /**
     * @dev Sets the penalty percentage.
     * @param newPenaltyPercentage The new penalty percentage (e.g., 50 for 50%).
     */
    function setPenaltyPercentage(uint256 newPenaltyPercentage) external onlyRole(ADMIN_ROLE) {
        require(newPenaltyPercentage <= 100, "Penalty must be <= 100%");
        penaltyPercentage = newPenaltyPercentage;
        emit PenaltyPercentageUpdated(newPenaltyPercentage);
    }

    /**
     * @dev Sets the global vesting start date.
     * @param newVestingStartDate The new vesting start date.
     */
    function setVestingStartDate(uint256 newVestingStartDate) external onlyRole(SCHEDULE_MANAGER_ROLE) {
        if (vestingStartDate != 0) revert VestingStartDateAlreadySet();
        if (newVestingStartDate < block.timestamp) revert VestingStartDateCannotBeInThePast();
        vestingStartDate = newVestingStartDate;
        emit VestingStartDateUpdated(newVestingStartDate);
    }

    /**
     * @dev Adds a vesting schedule for a beneficiary.
     * @param beneficiary The address of the beneficiary.
     * @param amount The total amount to be vested.
     * @param duration The duration of the vesting schedule in seconds.
     * @param startDate The start date of the vesting schedule.
     */
    function addVestingSchedule(
        address beneficiary,
        uint256 amount,
        uint256 duration,
        uint256 startDate
    ) external onlyRole(SCHEDULE_MANAGER_ROLE) {
        _addVestingSchedule(beneficiary, amount, duration, startDate);
    }

    /**
     * @dev Internal function to add a vesting schedule.
     * @param beneficiary The address of the beneficiary.
     * @param amount The total amount to be vested.
     * @param duration The duration of the vesting schedule in seconds.
     * @param startDate The start date of the vesting schedule.
     */
    function _addVestingSchedule(
        address beneficiary,
        uint256 amount,
        uint256 duration,
        uint256 startDate
    ) internal {
        if (beneficiary == address(0)) revert InvalidRecipientAddress();
        if (amount == 0) revert TotalAmountMustBeGreaterThanZero();
        if (duration == 0) revert DurationMustBeGreaterThanZero();

        VestingSchedule memory schedule = VestingSchedule({
            totalAmount: amount,
            released: 0,
            duration: duration,
            startDate: startDate
        });

        vestingSchedules[beneficiary].push(schedule);
        activeVestingSchedulesCount[beneficiary] += 1;

        _mint(beneficiary, amount);

        emit VestingScheduleAdded(beneficiary, amount, duration, startDate);
    }

    /**
     * @dev Adds multiple vesting schedules at once.
     * @param beneficiaries The addresses of the beneficiaries.
     * @param amounts The total amounts to be vested.
     * @param durations The durations of the vesting schedules in seconds.
     * @param startDates The start dates of the vesting schedules.
     */
    function addMultipleVestingSchedules(
        address[] calldata beneficiaries,
        uint256[] calldata amounts,
        uint256[] calldata durations,
        uint256[] calldata startDates
    ) external onlyRole(SCHEDULE_MANAGER_ROLE) {
        if (
            beneficiaries.length != amounts.length ||
            beneficiaries.length != durations.length ||
            beneficiaries.length != startDates.length
        ) revert InvalidRange();

        for (uint256 i = 0; i < beneficiaries.length; i++) {
            _addVestingSchedule(beneficiaries[i], amounts[i], durations[i], startDates[i]);
        }
    }

    /**
     * @dev Internal function to release tokens from a vesting schedule.
     * @param schedule The vesting schedule.
     * @param amount The amount to release.
     * @param acceptPenalty Whether to accept an early withdrawal penalty.
     */
    function _releaseFromSchedule(VestingSchedule storage schedule, uint256 amount, bool acceptPenalty) internal {
        uint256 releasable = _releasableAmount(schedule);
        if (amount > releasable) revert NoTokensToRelease();

        schedule.released += amount;

        uint256 penalty = 0;
        uint256 amountToRelease = amount;

        bool isFullyVested = schedule.released >= schedule.totalAmount;

        if (acceptPenalty && !isFullyVested) {
            penalty = (amount * penaltyPercentage) / 100;
            if (penalty > amount) revert TokenTransferFailed();
            amountToRelease = amount - penalty;

            schedule.totalAmount -= penalty;

            _burn(msg.sender, penalty);

            if (!sophtoken.transfer(penaltyRecipient, penalty)) revert TokenTransferFailed();
            emit PenaltyPaid(msg.sender, penalty);
        }

        _burn(msg.sender, amountToRelease);

        if (!sophtoken.transfer(msg.sender, amountToRelease)) revert TokenTransferFailed();
        emit TokensReleased(msg.sender, amount, amountToRelease, penalty);
    }

    /**
     * @dev Calculates the vested amount for a vesting schedule.
     * @param schedule The vesting schedule.
     * @return The vested amount.
     */
    function _vestedAmount(VestingSchedule storage schedule) internal view returns (uint256) {
        if (block.timestamp < schedule.startDate || schedule.startDate == 0) {
            return 0;
        }

        uint256 elapsedTime = block.timestamp - schedule.startDate;
        if (elapsedTime >= schedule.duration) {
            return schedule.totalAmount;
        } else {
            return (schedule.totalAmount * elapsedTime) / schedule.duration;
        }
    }

    /**
     * @dev Calculates the releasable amount for a vesting schedule.
     * @param schedule The vesting schedule.
     * @return The releasable amount.
     */
    function _releasableAmount(VestingSchedule storage schedule) internal view returns (uint256) {
        return _vestedAmount(schedule) - schedule.released;
    }

    /**
     * @dev Checks if vesting has started for a schedule.
     * @param schedule The vesting schedule.
     * @return True if vesting has started, false otherwise.
     */
    function _hasVestingStarted(VestingSchedule storage schedule) internal view returns (bool) {
        return schedule.startDate != 0 && block.timestamp >= schedule.startDate;
    }

    /**
     * @dev Returns the total vested amount for a beneficiary across all schedules.
     * @param beneficiary The address of the beneficiary.
     * @return totalVestedAmount total vested amount.
     */
    function vestedAmount(address beneficiary) external view returns (uint256 totalVestedAmount) {
        VestingSchedule[] storage schedules = vestingSchedules[beneficiary];

        for (uint256 i = 0; i < schedules.length; i++) {
            totalVestedAmount += _vestedAmount(schedules[i]);
        }
    }

    /**
     * @dev Returns the total releasable amount for a beneficiary across all schedules.
     * @param beneficiary The address of the beneficiary.
     * @return totalReleasableAmount total releasable amount.
     */
    function releasableAmount(address beneficiary) external view returns (uint256 totalReleasableAmount) {
        VestingSchedule[] storage schedules = vestingSchedules[beneficiary];

        for (uint256 i = 0; i < schedules.length; i++) {
            totalReleasableAmount += _releasableAmount(schedules[i]);
        }
    }

    /**
     * @dev Returns all vesting schedules for a beneficiary.
     * @param beneficiary The address of the beneficiary.
     * @return An array of VestingSchedule structs.
     */
    function getVestingSchedules(address beneficiary) external view returns (VestingSchedule[] memory) {
        return vestingSchedules[beneficiary];
    }

    /**
     * @dev Returns a range of vesting schedules for a beneficiary.
     * @param beneficiary The address of the beneficiary.
     * @param start The starting index.
     * @param end The ending index (exclusive).
     * @return An array of VestingSchedule structs.
     */
    function getVestingSchedulesInRange(
        address beneficiary,
        uint256 start,
        uint256 end
    ) external view returns (VestingSchedule[] memory) {
        VestingSchedule[] storage schedules = vestingSchedules[beneficiary];
        if (start >= end || end > schedules.length) revert InvalidRange();

        uint256 length = end - start;
        VestingSchedule[] memory rangeSchedules = new VestingSchedule[](length);

        for (uint256 i = 0; i < length; i++) {
            rangeSchedules[i] = schedules[start + i];
        }

        return rangeSchedules;
    }

    /**
     * @dev Returns the number of vesting schedules for a beneficiary.
     * @param beneficiary The address of the beneficiary.
     * @return The number of vesting schedules.
     */
    function getVestingSchedulesCount(address beneficiary) external view returns (uint256) {
        return vestingSchedules[beneficiary].length;
    }

    /**
     * @dev Rescue function to transfer stuck tokens.
     * @param token The token to rescue.
     * @param to The address to send the tokens to.
     */
    function rescue(IERC20 token, address to) external onlyRole(ADMIN_ROLE) {
        if (to == address(0)) revert InvalidRecipientAddress();
        token.safeTransfer(to, token.balanceOf(address(this)));
    }

    /**
     * @dev Authorizes upgrades to the contract.
     * @param newImplementation The address of the new implementation.
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}
}
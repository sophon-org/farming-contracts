// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
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

    IERC20 public sophtoken;        // The underlying token being vested
    address public penaltyRecipient;           // Address receiving penalties
    uint256 public vestingStartDate;           // Global vesting start date
    uint256 public penaltyPercentage;          // Penalty percentage for early withdrawals (e.g., 50 for 50%)

    mapping(address => VestingSchedule[]) public vestingSchedules; // Vesting schedules per beneficiary

    // Events
    event TokensReleased(address indexed beneficiary, uint256 grossAmount, uint256 netAmount, uint256 penaltyAmount);
    event VestingScheduleAdded(address indexed beneficiary, uint256 totalAmount, uint256 duration, uint256 startDate);
    event VestingStartDateUpdated(uint256 newVestingStartDate);
    event PenaltyRecipientUpdated(address newPenaltyRecipient);
    event PenaltyPercentageUpdated(uint256 newPenaltyPercentage);
    event PenaltyPaid(address indexed beneficiary, uint256 penaltyAmount);
    event BeneficiaryTransferred(address indexed oldBeneficiary, address indexed newBeneficiary, uint256 transferredBalance, uint256 transferredSchedulesCount);

    // Custom Errors
    error StartDateCannotBeInThePast();
    error CannotTransferToSelf();
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
    error PenaltyMustBeLessThanOrEqualTo100Percent();
    error AmountExceedsReleasableAmount();
    error MismatchedArrayLengths();

    /**
     * @dev Initializes the contract with the given token address, initial penalty recipient, and penalty percentage.
     * @param tokenAddress The address of the token to be vested.
     * @param initialPenaltyRecipient The address that will receive penalties.
     * @param initialPenaltyPercentage The initial penalty percentage (e.g., 50 for 50%).
     */
    function initialize(
        address tokenAddress,
        address adminAddress,
        address initialPenaltyRecipient,
        uint256 initialPenaltyPercentage
    ) public initializer {
        if (tokenAddress == address(0) || initialPenaltyRecipient == address(0)) revert InvalidRecipientAddress();
        if (initialPenaltyPercentage > 100) revert PenaltyMustBeLessThanOrEqualTo100Percent();

        __ERC20_init("vesting Sophon Token", "vSOPH");
        __AccessControl_init();
        __UUPSUpgradeable_init();

        sophtoken = IERC20(tokenAddress);
        penaltyRecipient = initialPenaltyRecipient;
        penaltyPercentage = initialPenaltyPercentage;

        _grantRole(DEFAULT_ADMIN_ROLE, adminAddress);
        _grantRole(ADMIN_ROLE, adminAddress);
        _grantRole(SCHEDULE_MANAGER_ROLE, adminAddress);
        _grantRole(UPGRADER_ROLE, adminAddress);
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
        if (newPenaltyPercentage > 100) revert PenaltyMustBeLessThanOrEqualTo100Percent();
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
     * If `startDate` is zero, the schedule will adopt `vestingStartDate` at claiming time.
     * @param beneficiary The address of the beneficiary.
     * @param amount The total amount to be vested.
     * @param duration The duration of the vesting schedule in seconds.
     * @param startDate The start date of the vesting schedule. If zero, will adopt `vestingStartDate` at claiming time.
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
     * @param startDate The start date of the vesting schedule. If zero, will adopt `vestingStartDate` at claiming time.
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

        uint256 scheduleStartDate = startDate;
        if (vestingStartDate != 0 && startDate <= vestingStartDate) {
            scheduleStartDate = vestingStartDate;
        }

        VestingSchedule memory schedule = VestingSchedule({
            totalAmount: amount,
            released: 0,
            duration: duration,
            startDate: scheduleStartDate
        });

        vestingSchedules[beneficiary].push(schedule);
        _mint(beneficiary, amount);
        emit VestingScheduleAdded(beneficiary, amount, duration, scheduleStartDate);
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
        ) revert MismatchedArrayLengths();

        for (uint256 i = 0; i < beneficiaries.length; i++) {
            _addVestingSchedule(beneficiaries[i], amounts[i], durations[i], startDates[i]);
        }
    }

    /**
     * @dev Calculates the vested amount for a vesting schedule.
     * @param schedule The vesting schedule.
     * @return The vested amount.
     */
    function _vestedAmount(VestingSchedule storage schedule) internal view returns (uint256) {
        
        // vesting not started yet or in the future
        if (vestingStartDate == 0 || block.timestamp < schedule.startDate) {
            return 0;
        }

        uint256 effectiveStartDate = schedule.startDate;
        if (effectiveStartDate < vestingStartDate) {
            effectiveStartDate = vestingStartDate;
        }

        uint256 elapsedTime = block.timestamp - effectiveStartDate;
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
    * @dev Claims the full vested tokens for the caller from specific vesting schedules and burns the claimed vSOPH tokens.
    * @param scheduleIndexes The indexes of the vesting schedules to claim from.
    */
    function claim(uint256[] calldata scheduleIndexes) external {
        if (vestingStartDate > block.timestamp) revert VestingHasNotStartedYet();
        uint256 totalReleasable = 0;
        uint256 penaltyAmount = 0;

        for (uint256 i = 0; i < scheduleIndexes.length; i++) {
            uint256 index = scheduleIndexes[i];
            
            // Ensure the schedule index is valid
            if (index >= vestingSchedules[msg.sender].length) revert InvalidScheduleIndex();

            VestingSchedule storage schedule = vestingSchedules[msg.sender][index];
            uint256 releasable = _releasableAmount(schedule);

            if (releasable > 0) {
                // Claim the full vested amount for this schedule
                schedule.released += releasable;
                totalReleasable += releasable;
            }
        }

        require(totalReleasable > 0, "No tokens available for release");

        // Burn the equivalent amount of vSOPH tokens from the caller
        _burn(msg.sender, totalReleasable);

        // Transfer the releasable amount of the underlying token to the beneficiary
        sophtoken.safeTransfer(msg.sender, totalReleasable);

        emit TokensReleased(msg.sender, totalReleasable, totalReleasable, penaltyAmount);
    }


    /**
    * @dev Returns the list of unclaimed vesting schedule indexes for the beneficiary within a specified range and their respective releasable amounts.
    * @param beneficiary The address of the beneficiary to check unclaimed schedules for.
    * @param start The starting index of the range (inclusive).
    * @param end The ending index of the range (exclusive).
    * @return indexes An array of indexes for schedules with unclaimed tokens within the specified range.
    * @return amounts An array of unclaimed amounts corresponding to each index within the specified range.
    */
    function getUnclaimedSchedulesInRange(
        address beneficiary,
        uint256 start,
        uint256 end
    ) external view returns (uint256[] memory indexes, uint256[] memory amounts) {
        uint256 scheduleCount = vestingSchedules[beneficiary].length;
        require(start < end && end <= scheduleCount, "Invalid range");

        // Create temporary arrays with a fixed maximum size (end - start)
        uint256[] memory tempIndexes = new uint256[](end - start);
        uint256[] memory tempAmounts = new uint256[](end - start);
        uint256 unclaimedCount = 0;

        // Single loop to collect unclaimed schedules within the range
        for (uint256 i = start; i < end; i++) {
            VestingSchedule storage schedule = vestingSchedules[beneficiary][i];
            uint256 releasable = _releasableAmount(schedule);

            if (releasable > 0) {
                tempIndexes[unclaimedCount] = i;
                tempAmounts[unclaimedCount] = releasable;
                unclaimedCount++;
            }
        }

        // Create result arrays with exact size of unclaimed schedules
        indexes = new uint256[](unclaimedCount);
        amounts = new uint256[](unclaimedCount);

        // Copy collected data to result arrays
        for (uint256 j = 0; j < unclaimedCount; j++) {
            indexes[j] = tempIndexes[j];
            amounts[j] = tempAmounts[j];
        }

        return (indexes, amounts);
    }


    /**
    * @dev Claims the entire releasable amount for specific vesting schedule indexes with an applied penalty.
    * @param scheduleIndexes An array of indexes of the vesting schedules to claim from.
    */
    function claimSpecificSchedulesWithPenalty(uint256[] calldata scheduleIndexes) external {
        if (vestingStartDate > block.timestamp) revert VestingHasNotStartedYet();

        uint256 totalReleasable = 0;
        uint256 totalPenaltyAmount = 0;

        for (uint256 i = 0; i < scheduleIndexes.length; i++) {
            uint256 index = scheduleIndexes[i];
            
            // Ensure the schedule index is valid
            if (index >= vestingSchedules[msg.sender].length) revert InvalidScheduleIndex();

            VestingSchedule storage schedule = vestingSchedules[msg.sender][index];
            uint256 releasable = _releasableAmount(schedule);

            if (releasable > 0) {
                uint256 penaltyAmount = (releasable * penaltyPercentage) / 100;
                uint256 netAmount = releasable - penaltyAmount;

                totalReleasable += netAmount;
                totalPenaltyAmount += penaltyAmount;

                // Update the schedule to reflect the claimed amount
                schedule.released += releasable;
            }
        }

        require(totalReleasable > 0, "No tokens available for release");

        // Transfer total penalty amount to the penalty recipient
        if (totalPenaltyAmount > 0) {
            sophtoken.safeTransfer(penaltyRecipient, totalPenaltyAmount);
            emit PenaltyPaid(msg.sender, totalPenaltyAmount);
        }

        // Transfer the total net amount to the beneficiary
        sophtoken.safeTransfer(msg.sender, totalReleasable);
        emit TokensReleased(msg.sender, totalReleasable + totalPenaltyAmount, totalReleasable, totalPenaltyAmount);

        // Burn the equivalent amount of vSOPH tokens from the caller
        _burn(msg.sender, totalReleasable + totalPenaltyAmount);
    }




    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}
}

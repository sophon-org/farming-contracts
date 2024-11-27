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

    IERC20 public sophtoken;                       // The underlying token being vested
    address public penaltyRecipient;               // Address receiving penalties
    uint256 public vestingStartDate;               // Global vesting start date
    uint256 public penaltyPercentage;              // Penalty percentage for early withdrawals (e.g., 50 for 50%)

    mapping(address => VestingSchedule[]) public vestingSchedules; // Vesting schedules per beneficiary

    // Events
    event TokensReleased(address indexed beneficiary, uint256 netAmount, uint256 penaltyAmount);
    event VestingScheduleAdded(address indexed beneficiary, uint256 totalAmount, uint256 duration, uint256 startDate);
    event VestingStartDateUpdated(uint256 newVestingStartDate);
    event PenaltyRecipientUpdated(address newPenaltyRecipient);
    event PenaltyPercentageUpdated(uint256 newPenaltyPercentage);
    event PenaltyPaid(address indexed beneficiary, uint256 penaltyAmount);

    // Custom Errors
    error TotalAmountMustBeGreaterThanZero();
    error DurationMustBeGreaterThanZero();
    error VestingHasNotStartedYet();
    error VestingStartDateAlreadySet();
    error VestingStartDateCannotBeInThePast();
    error InvalidScheduleIndex();
    error InvalidRange();
    error InvalidRecipientAddress();
    error PenaltyMustBeLessThanOrEqualTo100Percent();
    error MismatchedArrayLengths();
    error NoTokensToRelease();
    error NoVestingSchedule();

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
    function setVestingStartDate(uint256 newVestingStartDate) external onlyRole(ADMIN_ROLE) {
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
     * @dev Internal function to process and release tokens from a vesting schedule.
     * @param schedule The vesting schedule.
     * @param acceptPenalty Whether to accept an early withdrawal penalty.
     * @return releasedAmount The amount of tokens released.
     */
    function _processSchedule(VestingSchedule storage schedule, bool acceptPenalty) internal returns (uint256 releasedAmount) {
        // this is critical part. set startDate if  schedule.startDate was zero
        if (vestingStartDate != 0 && block.timestamp >= vestingStartDate && schedule.startDate == 0) {
            schedule.startDate = vestingStartDate;
        }

        if (!_hasVestingStarted(schedule)) revert VestingHasNotStartedYet();

        return _releaseFromSchedule(schedule, acceptPenalty);
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
     * @dev Releases vested tokens from specific schedules provided as an array.
     * @param scheduleIndices The indices of the vesting schedules.
     * @param acceptPenalty Whether to accept an early withdrawal penalty.
     */
    function releaseSpecificSchedules(uint256[] calldata scheduleIndices, bool acceptPenalty) external {
        VestingSchedule[] storage schedules = vestingSchedules[msg.sender];
        if (schedules.length == 0) revert NoVestingSchedule();

        uint256 totalAmountToRelease = 0;

        for (uint256 i = 0; i < scheduleIndices.length; i++) {
            uint256 scheduleIndex = scheduleIndices[i];
            if (scheduleIndex >= schedules.length) revert InvalidScheduleIndex();

            VestingSchedule storage schedule = schedules[scheduleIndex];

            uint256 released = _processSchedule(schedule, acceptPenalty);
            totalAmountToRelease += released;
        }

        if (totalAmountToRelease == 0) revert NoTokensToRelease();
    }

    /**
     * @dev Releases vested tokens from a range of schedules.
     * @param startIndex The starting index.
     * @param endIndex The ending index (exclusive).
     * @param acceptPenalty Whether to accept an early withdrawal penalty.
     */
    function releaseSchedulesInRange(uint256 startIndex, uint256 endIndex, bool acceptPenalty) external {
        VestingSchedule[] storage schedules = vestingSchedules[msg.sender];
        if (schedules.length == 0) revert NoVestingSchedule();
        if (startIndex >= endIndex || endIndex > schedules.length) revert InvalidRange();

        uint256 totalAmountToRelease = 0;

        for (uint256 i = startIndex; i < endIndex; i++) {
            VestingSchedule storage schedule = schedules[i];

            uint256 released = _processSchedule(schedule, acceptPenalty);
            totalAmountToRelease += released;
        }

        if (totalAmountToRelease == 0) revert NoTokensToRelease();
    }

    /**
     * @dev Internal function to release tokens from a vesting schedule.
     * @param schedule The vesting schedule.
     * @param acceptPenalty Whether to accept an early withdrawal penalty.
     * @return releasedAmount Amount that was released
     */
    function _releaseFromSchedule(VestingSchedule storage schedule, bool acceptPenalty) internal returns(uint256 releasedAmount) {
        uint256 amountToRelease = _releasableAmount(schedule);
        uint256 penalty = 0;
        schedule.released += amountToRelease;
        uint256 unvestedAmount = schedule.totalAmount - schedule.released;
        if (acceptPenalty && unvestedAmount > 0) {
            penalty = (unvestedAmount * penaltyPercentage) / 100;
            amountToRelease += unvestedAmount - penalty;

            // at this point schedule.released should be 100%
            schedule.released += unvestedAmount;

            _burn(msg.sender, penalty);
            sophtoken.safeTransfer(penaltyRecipient, penalty);
            emit PenaltyPaid(msg.sender, penalty);
        }

        _burn(msg.sender, amountToRelease);
        releasedAmount = amountToRelease;
        sophtoken.safeTransfer(msg.sender, amountToRelease);
        emit TokensReleased(msg.sender, amountToRelease, penalty);
    }

    /**
     * @dev Calculates the vested amount for a vesting schedule.
     */
    function _vestedAmount(VestingSchedule storage schedule) internal view returns (uint256) {
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
    * @dev Claims the full vested tokens for the caller from specific vesting schedules and burns the claimed vSOPH tokens.
    * @param scheduleIndexes The indexes of the vesting schedules to claim from.
    */
    function claim(uint256[] calldata scheduleIndexes) external {
        if (vestingStartDate > block.timestamp) revert VestingHasNotStartedYet();
        uint256 totalReleasable = 0;

        for (uint256 i = 0; i < scheduleIndexes.length; i++) {
            uint256 index = scheduleIndexes[i];
            if (index >= vestingSchedules[msg.sender].length) revert InvalidScheduleIndex();

            VestingSchedule storage schedule = vestingSchedules[msg.sender][index];
            uint256 releasable = _releasableAmount(schedule);

            if (releasable > 0) {
                schedule.released += releasable;
                totalReleasable += releasable;
            }
        }

        require(totalReleasable > 0, "No tokens available for release");

        _burn(msg.sender, totalReleasable);
        sophtoken.safeTransfer(msg.sender, totalReleasable);
        emit TokensReleased(msg.sender, totalReleasable, 0);
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

        uint256 totalNetToUser = 0;
        uint256 totalPenaltyAmount = 0;

        for (uint256 i = 0; i < scheduleIndexes.length; i++) {
            uint256 index = scheduleIndexes[i];
            if (index >= vestingSchedules[msg.sender].length) revert InvalidScheduleIndex();

            VestingSchedule storage schedule = vestingSchedules[msg.sender][index];
            
            // Calculate the releasable (vested) amount that must be released without penalty
            uint256 releasable = _releasableAmount(schedule);
            
            // Calculate the unvested amount
            uint256 unvestedAmount = schedule.totalAmount - schedule.released - releasable;
            
            // Calculate the penalty amount on the unvested portion
            uint256 penaltyAmount = (unvestedAmount * penaltyPercentage) / 100;
            
            // Calculate the net amount for the user: full releasable + (unvested - penalty)
            uint256 netAmountToUser = releasable + (unvestedAmount - penaltyAmount);

            // Accumulate amounts for total transfer
            totalNetToUser += netAmountToUser;
            totalPenaltyAmount += penaltyAmount;

            // Mark the entire schedule as claimed by setting released to totalAmount
            schedule.released = schedule.totalAmount;
        }

        require(totalNetToUser > 0, "No tokens available for release");

        // Transfer the penalty amount to the penalty recipient, if any
        if (totalPenaltyAmount > 0) {
            sophtoken.safeTransfer(penaltyRecipient, totalPenaltyAmount);
            emit PenaltyPaid(msg.sender, totalPenaltyAmount);
        }

        // Burn the claimed vSOPH tokens equivalent to the total released amount plus penalties
        _burn(msg.sender, totalNetToUser + totalPenaltyAmount);

        // Transfer the total net amount (releasable + post-penalty unvested) to the beneficiary
        sophtoken.safeTransfer(msg.sender, totalNetToUser);
        emit TokensReleased(msg.sender, totalNetToUser, totalPenaltyAmount);
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

    // /**
    // * @dev Overrides the internal _update function to transfer vesting schedules
    // * and enforce admin-only access through the onlyAdmin modifier.
    // */
    // function _update(address from, address to, uint256 value) internal virtual override onlyRole(ADMIN_ROLE) {
    //     if (to == address(0)) revert InvalidRecipientAddress();

    //     // except minting
    //     if (from != address(0)) {
    //         _transferVestingSchedules(from, to); // Streamlined transfer of schedules
    //     }
        

    //     // Call the parent _update function to maintain balance updates and event emissions
    //     super._update(from, to, value);
    // }

    function transfer(address to, uint256 value) public virtual override onlyRole(ADMIN_ROLE) returns (bool) {
        super.transfer(to, value);
    }

    function transferFrom(address from, address to, uint256 value) public virtual override onlyRole(ADMIN_ROLE) returns (bool) {
        super.transferFrom(from, to, value);
    }

    function adminTransfer(
        address from,
        address to
    ) public onlyRole(ADMIN_ROLE) returns (bool) {
        // Transfer the specified amount of tokens
        uint256 amount = balanceOf(from);
        _transfer(from, to, amount);

        // Transfer all vesting schedules from 'from' to 'to'
        _transferVestingSchedules(from, to);

        return true;
    }

    /**
    * @dev Helper function to transfer all vesting schedules from one address to another.
    * @param from The address to transfer schedules from.
    * @param to The address to transfer schedules to.
    */
    function _transferVestingSchedules(address from, address to) internal {
        VestingSchedule[] storage schedulesFrom = vestingSchedules[from];
        for (uint256 i = 0; i < schedulesFrom.length; i++) {
            vestingSchedules[to].push(schedulesFrom[i]);
        }
        delete vestingSchedules[from];
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}
}

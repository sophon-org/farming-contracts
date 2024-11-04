// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title LinearVestingWithPenalty
 * @dev This contract manages multiple vesting schedules with an optional early withdrawal penalty.
 * Beneficiaries can have multiple schedules and release tokens according to their schedules.
 * The contract is upgradeable and uses role-based access control.
 */
contract LinearVestingWithPenalty is Initializable, ERC20Upgradeable, AccessControlUpgradeable, UUPSUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;

    struct VestingSchedule {
        uint256 totalAmount; // Total tokens to be vested
        uint256 released;    // Amount of tokens released so far
        uint256 duration;    // Duration of the vesting schedule in seconds
        uint256 startDate;   // Start date of the vesting schedule
    }

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    IERC20 public sophtoken;         // The underlying token being vested
    address public paymaster;        // Address receiving penalties
    uint256 public vestingStartDate; // Global vesting start date
    mapping(address => VestingSchedule[]) public vestingSchedules; // Vesting schedules per beneficiary

    event TokensReleased(address indexed beneficiary, uint256 grossAmount, uint256 netAmount, uint256 penaltyAmount);
    event VestingScheduleAdded(address indexed beneficiary, uint256 totalAmount, uint256 duration, uint256 startDate);
    event VestingStartDateUpdated(uint256 newVestingStartDate);
    event PaymasterUpdated(address newPaymaster);
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

    /**
     * @dev Initializes the contract with the given token address and initial paymaster.
     * @param tokenAddress The address of the token to be vested.
     * @param initialPaymaster The address that will receive penalties.
     */
    function initialize(address tokenAddress, address initialPaymaster) public initializer {
        require(tokenAddress != address(0), "Invalid token address");
        require(initialPaymaster != address(0), "Invalid paymaster address");

        __ERC20_init("vesting Sophon Token", "vSOPH");
        __AccessControl_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        sophtoken = IERC20(tokenAddress);
        paymaster = initialPaymaster;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    // Prevent contract from accepting Ether
    receive() external payable {
        revert EtherNotAccepted();
    }

    fallback() external payable {
        revert EtherNotAccepted();
    }

    /**
     * @dev Sets the paymaster address.
     * @param newPaymaster The new paymaster address.
     */
    function setPaymaster(address newPaymaster) external onlyRole(ADMIN_ROLE) {
        require(newPaymaster != address(0), "Invalid paymaster address");
        paymaster = newPaymaster;
        emit PaymasterUpdated(newPaymaster);
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
     */
    function addVestingSchedule(
        address beneficiary,
        uint256 amount,
        uint256 duration
    ) external onlyRole(ADMIN_ROLE) {
        require(beneficiary != address(0), "Invalid beneficiary address");
        if (amount == 0) revert TotalAmountMustBeGreaterThanZero();
        if (duration == 0) revert DurationMustBeGreaterThanZero();

        uint256 scheduleStartDate = 0;

        if (vestingStartDate != 0) {
            if (block.timestamp < vestingStartDate) {
                // Vesting has not started yet, set schedule startDate to global vestingStartDate
                scheduleStartDate = vestingStartDate;
            } else {
                // Vesting has started, set schedule startDate to current timestamp
                scheduleStartDate = block.timestamp;
            }
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
     * @dev Releases vested tokens from a specific schedule.
     * @param scheduleIndex The index of the vesting schedule.
     * @param acceptPenalty Whether to accept an early withdrawal penalty.
     * @param amount The amount to release.
     */
    function release(uint256 scheduleIndex, bool acceptPenalty, uint256 amount) external nonReentrant {
        VestingSchedule[] storage schedules = vestingSchedules[msg.sender];
        if (schedules.length == 0) revert NoVestingSchedule();
        if (scheduleIndex >= schedules.length) revert InvalidScheduleIndex();

        VestingSchedule storage schedule = schedules[scheduleIndex];

        // If vesting has started globally and schedule.startDate is zero, set schedule.startDate to vestingStartDate
        if (vestingStartDate != 0 && block.timestamp >= vestingStartDate && schedule.startDate == 0) {
            schedule.startDate = vestingStartDate;
        }

        if (!_hasVestingStarted(schedule)) revert VestingHasNotStartedYet();

        _releaseFromSchedule(schedule, amount, acceptPenalty);
    }

    /**
     * @dev Releases all releasable tokens across all schedules.
     * @param acceptPenalty Whether to accept an early withdrawal penalty.
     */
    function releaseAll(bool acceptPenalty) external nonReentrant {
        VestingSchedule[] storage schedules = vestingSchedules[msg.sender];
        if (schedules.length == 0) revert NoVestingSchedule();

        uint256 totalAmountToRelease = 0;

        for (uint256 i = 0; i < schedules.length; i++) {
            VestingSchedule storage schedule = schedules[i];

            // If vesting has started globally and schedule.startDate is zero, set schedule.startDate to vestingStartDate
            if (vestingStartDate != 0 && block.timestamp >= vestingStartDate && schedule.startDate == 0) {
                schedule.startDate = vestingStartDate;
            }

            if (_hasVestingStarted(schedule)) {
                uint256 releasable = _releasableAmount(schedule);

                if (releasable > 0) {
                    _releaseFromSchedule(schedule, releasable, acceptPenalty);
                    totalAmountToRelease += releasable;
                }
            }
        }

        if (totalAmountToRelease == 0) revert NoTokensToRelease();
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

        // Update state variables
        schedule.released += amount;

        uint256 penalty = 0;
        uint256 amountToRelease = amount;

        bool isFullyVested = schedule.released >= schedule.totalAmount;

        if (acceptPenalty && !isFullyVested) {
            penalty = (amount * 50) / 100;
            require(penalty <= amount, "Penalty exceeds amount");
            amountToRelease = amount - penalty;

            schedule.totalAmount -= penalty;

            // Burn the penalty tokens
            _burn(msg.sender, penalty);

            // Transfer penalty to paymaster
            if (!sophtoken.transfer(paymaster, penalty)) revert TokenTransferFailed();
            emit PenaltyPaid(msg.sender, penalty);
        }

        // Burn the claimed tokens
        _burn(msg.sender, amountToRelease);

        // Transfer the underlying tokens to the beneficiary
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
        uint256 vested = _vestedAmount(schedule);
        return vested - schedule.released;
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
     * @return The total vested amount.
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
     * @return The total releasable amount.
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
        token.safeTransfer(to, token.balanceOf(address(this)));
    }

    /**
     * @dev Authorizes upgrades to the contract.
     * @param newImplementation The address of the new implementation.
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(ADMIN_ROLE) {}
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract LinearVestingWithPenalty is Initializable, ERC20Upgradeable, AccessControlUpgradeable, UUPSUpgradeable {
    using SafeERC20 for IERC20;

    struct VestingSchedule {
        uint256 totalAmount;
        uint256 released;
        uint256 duration;
    }

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    IERC20 public sophtoken;
    address public paymaster;
    uint256 public vestingStartDate;
    mapping(address => VestingSchedule) public vestingSchedules;

    event TokensReleased(address indexed beneficiary, uint256 amount);
    event VestingScheduleAdded(address indexed beneficiary, uint256 totalAmount, uint256 duration);
    event VestingStartDateUpdated(uint256 newVestingStartDate);
    event PaymasterUpdated(address newPaymaster);
    event PenaltyPaid(address indexed beneficiary, uint256 penaltyAmount);

    error TotalAmountMustBeGreaterThanZero();
    error DurationMustBeGreaterThanZero();
    error NoVestingSchedule();
    error VestingHasNotStartedYet();
    error NoTokensToRelease();
    error InsufficientVestedAmount();
    error TokenTransferFailed();
    error VestingStartDateAlreadySet();
    error VestingStartDateCannotBeInThePast();
    error EtherNotAccepted(); // Custom error for ETH rejection

    function initialize(address tokenAddress, address initialPaymaster) public initializer {
        __ERC20_init("vesting Sophon Token", "vSOPH");
        __AccessControl_init();
        __UUPSUpgradeable_init();

        sophtoken = IERC20(tokenAddress);
        paymaster = initialPaymaster;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    // Function to prevent receiving Ether with a custom error
    receive() external payable {
        revert EtherNotAccepted();
    }

    fallback() external payable {
        revert EtherNotAccepted();
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
        uint256 additionalAmount,
        uint256 additionalDuration
    ) external onlyRole(ADMIN_ROLE) {
        if (additionalAmount == 0) revert TotalAmountMustBeGreaterThanZero();
        if (additionalDuration == 0) revert DurationMustBeGreaterThanZero();

        VestingSchedule storage schedule = vestingSchedules[beneficiary];

        schedule.totalAmount += additionalAmount;
        schedule.duration += additionalDuration;

        _mint(beneficiary, additionalAmount);

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
            return 0;
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

    function rescue(IERC20 token, address to) external onlyRole(ADMIN_ROLE) {
        token.safeTransfer(to, token.balanceOf(address(this)));
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(ADMIN_ROLE) {}
}

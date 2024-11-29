// // SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {MockERC20} from "./../contracts/mocks/MockERC20.sol";
import {LinearVestingWithPenalty} from "../contracts/token/LinearVestingWithPenalty.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract LinearVestingWithPenaltyTest is Test {

    address internal admin = makeAddr("admin");
    address internal scheduleManager = makeAddr("scheduleManager");
    address internal upgrader = makeAddr("upgrader");
    address internal penaltyRecipient = makeAddr("penaltyRecipient");
    address internal attacker = makeAddr("attacker");
    address internal user1 = makeAddr("user1");
    address internal user2 = makeAddr("user2");
    uint256 internal PENALTY = 50; // 50%
    bytes32 internal INITIALIZABLE_STORAGE = 0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00; // From Initializable.sol
    uint256 internal VESTING_SCHEDULE_AMOUNT = 100 ether;
    uint256 internal VESTING_SCHEDULE_DURATION = 3600 * 24 * 90; // 90 days
    uint256 internal SOPHON_SUPPLY = 10_000_000_000e18;
    
    uint256[] internal auxiliarArray1;
    uint256[] internal auxiliarArray2;

    MockERC20 SOPH;
    LinearVestingWithPenalty vSOPH;

    function setUp() public {
        vm.startPrank(admin);

        SOPH = new MockERC20("Sophon token", "SOPH", 18);

        vSOPH = new LinearVestingWithPenalty();
        vSOPH.initialize(address(SOPH), admin, penaltyRecipient, PENALTY);

        vSOPH.grantRole(vSOPH.SCHEDULE_MANAGER_ROLE(), scheduleManager);
        vSOPH.grantRole(vSOPH.UPGRADER_ROLE(), upgrader);

        deal(address(SOPH), address(vSOPH), SOPHON_SUPPLY);

        vm.stopPrank();
    }

    // INITIALIZE FUNCTION
    function test_Initialize() public {
        assertEq(address(vSOPH.sophtoken()), address(SOPH));
        assertEq(vSOPH.penaltyPercentage(), PENALTY);
        assertEq(vSOPH.penaltyRecipient(), penaltyRecipient);

        assertEq(vSOPH.hasRole(vSOPH.DEFAULT_ADMIN_ROLE(), admin), true);
        assertEq(vSOPH.hasRole(vSOPH.ADMIN_ROLE(), admin), true);
        assertEq(vSOPH.hasRole(vSOPH.SCHEDULE_MANAGER_ROLE(), admin), true);
        assertEq(vSOPH.hasRole(vSOPH.SCHEDULE_MANAGER_ROLE(), scheduleManager), true);
        assertEq(vSOPH.hasRole(vSOPH.UPGRADER_ROLE(), admin), true);
        assertEq(vSOPH.hasRole(vSOPH.UPGRADER_ROLE(), upgrader), true);

        assertEq(uint256(vm.load(address(vSOPH), INITIALIZABLE_STORAGE)), 1);
    }

    function test_RevertIfInvalidInitialization_Initialize() public {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        vSOPH.initialize(address(0), admin, penaltyRecipient, PENALTY);

        vm.expectRevert(Initializable.InvalidInitialization.selector);
        vSOPH.initialize(address(SOPH), admin, address(0), PENALTY);

        vm.expectRevert(Initializable.InvalidInitialization.selector);
        vSOPH.initialize(address(SOPH), admin, penaltyRecipient, PENALTY + 100);
    }

    // SET PENALTY RECIPIENT FUNCTION
    function test_SetPenaltyRecipient() public {
        address newPenaltyRecipient = makeAddr("newPenaltyRecipient");
        
        vm.expectEmit(true, true, true, true);
        emit LinearVestingWithPenalty.PenaltyRecipientUpdated(newPenaltyRecipient);

        vm.prank(admin);
        vSOPH.setPenaltyRecipient(newPenaltyRecipient);

        assertEq(vSOPH.penaltyRecipient(), newPenaltyRecipient);
    }

    function test_RevertIfAccessControlUnauthorizedAccount_SetPenaltyRecipient() public {
        address newPenaltyRecipient = makeAddr("newPenaltyRecipient");

        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, attacker, vSOPH.ADMIN_ROLE())
        );

        vm.prank(attacker);
        vSOPH.setPenaltyRecipient(newPenaltyRecipient);
    }

    function test_RevertIfInvalidRecipientAddress_SetPenaltyRecipient() public {
        address newPenaltyRecipient = address(0);

        vm.expectRevert(LinearVestingWithPenalty.InvalidRecipientAddress.selector);
        vm.prank(admin);
        vSOPH.setPenaltyRecipient(newPenaltyRecipient);
    }

    // SET PENALTY PERCCENTAGE FUNCTION
    function test_SetPenaltyPercentage() public {
        uint256 newPenalty = 30;
        
        vm.expectEmit(true, true, true, true);
        emit LinearVestingWithPenalty.PenaltyPercentageUpdated(newPenalty);

        vm.prank(admin);
        vSOPH.setPenaltyPercentage(newPenalty);

        assertEq(vSOPH.penaltyPercentage(), newPenalty);
    }

    function test_RevertIfPenaltyMustBeLessThanOrEqualTo100Percent_SetPenaltyPercentage() public {
        uint256 newPenalty = 101;

        vm.expectRevert(LinearVestingWithPenalty.PenaltyMustBeLessThanOrEqualTo100Percent.selector);
        vm.prank(admin);
        vSOPH.setPenaltyPercentage(newPenalty);
    }

    // SET VESTING START DATE FUNCTION
    function test_SetVestingStartDate() public {
        uint256 newVestingStartDate = block.timestamp + 60;
        
        vm.expectEmit(true, true, true, true);
        emit LinearVestingWithPenalty.VestingStartDateUpdated(newVestingStartDate);

        vm.prank(admin);
        vSOPH.setVestingStartDate(newVestingStartDate);

        assertEq(vSOPH.vestingStartDate(), newVestingStartDate);
    }

    function test_RevertIfAccessControlUnauthorizedAccount_SetVestingStartDate() public {
        uint256 newVestingStartDate = block.timestamp + 60;

        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, attacker, vSOPH.ADMIN_ROLE())
        );

        vm.prank(attacker);
        vSOPH.setVestingStartDate(newVestingStartDate);
    }

    function test_RevertIfVestingStartDateAlreadySet_SetVestingStartDate() public {
        uint256 newVestingStartDate = block.timestamp + 60;
        
        vm.prank(admin);
        vSOPH.setVestingStartDate(newVestingStartDate);

        vm.expectRevert(LinearVestingWithPenalty.VestingStartDateAlreadySet.selector);
        vm.prank(admin);
        vSOPH.setVestingStartDate(newVestingStartDate);
    }

    function test_RevertIfVestingStartDateCannotBeInThePast_SetVestingStartDate() public {
        uint256 newVestingStartDate = block.timestamp - 1;
        
        vm.expectRevert(LinearVestingWithPenalty.VestingStartDateCannotBeInThePast.selector);
        vm.prank(admin);
        vSOPH.setVestingStartDate(newVestingStartDate);
    }

    // ADD VESTING SCHEDULE FUNCTION
    function testFuzz_AddVestingSchedule(uint256 amount, uint256 duration, uint256 startDate) public {
        amount = bound(amount, 1, type(uint256).max);
        startDate = bound(startDate, block.timestamp, type(uint256).max);
        duration = bound(duration, 1, type(uint256).max);

        vm.prank(scheduleManager);
        vSOPH.addVestingSchedule(user1, amount, duration, startDate);

        LinearVestingWithPenalty.VestingSchedule memory schedule;
        (schedule.totalAmount, schedule.released, schedule.duration, schedule.startDate) = vSOPH.vestingSchedules(user1, 0);

        assertEq(schedule.totalAmount, amount);
        assertEq(schedule.released, 0);
        assertEq(schedule.duration, duration);
        assertEq(schedule.startDate, startDate);
        assertEq(vSOPH.balanceOf(user1), amount);
    }

    function test_RevertIfInvalidRecipientAddress_AddVestingSchedule() public {
        vm.prank(scheduleManager);
        vm.expectRevert(LinearVestingWithPenalty.InvalidRecipientAddress.selector);
        vSOPH.addVestingSchedule(address(0), VESTING_SCHEDULE_AMOUNT, VESTING_SCHEDULE_DURATION, block.timestamp);
    }

    function test_RevertIfTotalAmountMustBeGreaterThanZero_AddVestingSchedule() public {
        vm.prank(scheduleManager);
        vm.expectRevert(LinearVestingWithPenalty.TotalAmountMustBeGreaterThanZero.selector);
        vSOPH.addVestingSchedule(user1, 0, VESTING_SCHEDULE_DURATION, block.timestamp);
    }

    function test_RevertIfDurationMustBeGreaterThanZero_AddVestingSchedule() public {
        vm.prank(scheduleManager);
        vm.expectRevert(LinearVestingWithPenalty.DurationMustBeGreaterThanZero.selector);
        vSOPH.addVestingSchedule(user1, VESTING_SCHEDULE_AMOUNT, 0, block.timestamp);
    }

    // ADD MULTIPLE VESTING SCHEDULES
    function testFuzz_AddMultipleVestingSchedules(uint256 seed) public {
        uint256 numberOfSchedules = bound(seed, 1, 20);

        address[] memory beneficiaries = new address[](numberOfSchedules);
        uint256[] memory amounts = new uint256[](numberOfSchedules);
        uint256[] memory durations = new uint256[](numberOfSchedules);
        uint256[] memory startDates = new uint256[](numberOfSchedules);
        uint256 totalAmount;

        for (uint256 i = 0; i < numberOfSchedules; i++) {
            uint256 rand = uint256(keccak256(abi.encodePacked(seed, i)));
            beneficiaries[i] = makeAddr(string(bytes(abi.encodePacked(rand))));
            amounts[i] = bound(rand, 1, SOPHON_SUPPLY) * 3 / 100;
            totalAmount += amounts[i];
            durations[i] = bound(rand, 1, 3600 * 24 * 365); // Between 1 and 1 year
            startDates[i] = bound(rand, block.timestamp, 3600 * 24 * 90); // Between 1 and 90 days
            vm.expectEmit(true, true, true, true);
            emit LinearVestingWithPenalty.VestingScheduleAdded(beneficiaries[i], amounts[i], durations[i], startDates[i]);
        }

        vm.prank(scheduleManager);
        vSOPH.addMultipleVestingSchedules(beneficiaries, amounts, durations, startDates);

        for (uint256 i = 0; i < numberOfSchedules; i++) {
            LinearVestingWithPenalty.VestingSchedule memory schedule;
            (schedule.totalAmount, schedule.released, schedule.duration, schedule.startDate) = vSOPH.vestingSchedules(beneficiaries[i], 0);

            assertEq(schedule.totalAmount, amounts[i]);
            assertEq(schedule.released, 0);
            assertEq(schedule.duration, durations[i]);
            assertEq(schedule.startDate, startDates[i]);
            assertEq(vSOPH.balanceOf(beneficiaries[i]), amounts[i]);
        }

        assertEq(vSOPH.totalSupply(), totalAmount);
    }

    function test_RevertIfMismatchedArrayLengths_AddMultipleVestingSchedules() public {
        address[] memory beneficiaries = new address[](10);
        uint256[] memory amounts = new uint256[](10);
        uint256[] memory durations = new uint256[](10);
        uint256[] memory startDates = new uint256[](10);

        assembly { mstore(amounts, sub(mload(amounts), 1)) } // memory array pop
        vm.expectRevert(LinearVestingWithPenalty.MismatchedArrayLengths.selector);
        vm.prank(scheduleManager);
        vSOPH.addMultipleVestingSchedules(beneficiaries, amounts, durations, startDates);

        assembly { mstore(beneficiaries, sub(mload(beneficiaries), 1)) } // memory array pop
        assembly { mstore(durations, sub(mload(durations), 1)) } // memory array pop
        assembly { mstore(durations, sub(mload(durations), 1)) } // memory array pop
        assembly { mstore(startDates, sub(mload(startDates), 1)) } // memory array pop
        vm.expectRevert(LinearVestingWithPenalty.MismatchedArrayLengths.selector);
        vm.prank(scheduleManager);
        vSOPH.addMultipleVestingSchedules(beneficiaries, amounts, durations, startDates);

        assembly { mstore(beneficiaries, sub(mload(beneficiaries), 1)) } // memory array pop
        assembly { mstore(amounts, sub(mload(amounts), 1)) } // memory array pop
        assembly { mstore(startDates, sub(mload(startDates), 1)) } // memory array pop
        assembly { mstore(startDates, sub(mload(startDates), 1)) } // memory array pop
        vm.expectRevert(LinearVestingWithPenalty.MismatchedArrayLengths.selector);
        vm.prank(scheduleManager);
        vSOPH.addMultipleVestingSchedules(beneficiaries, amounts, durations, startDates);
    }

    // RELEASE SPECIFIC SCHEDULES FUNCTION
    function testFuzz_ReleaseSpecificSchedules_OneDeposit_GTEDuration(uint256 rand, uint256 amount, uint256 duration, uint256 startDate, bool penalty) public {
        vm.prank(admin);
        vSOPH.setVestingStartDate(1);
    
        rand = bound(rand, 0, 100);
        amount = bound(amount, 1, SOPHON_SUPPLY * 3 / 100);
        startDate = bound(startDate, block.timestamp, 3600 * 24 * 365); // Between 1 sec and 1 year
        duration = bound(duration, 1, 3600 * 24 * 90); // Between 1 sec and 90 days

        vm.prank(scheduleManager);
        vSOPH.addVestingSchedule(user1, amount, duration, startDate);

        LinearVestingWithPenalty.VestingSchedule memory schedule;
        (schedule.totalAmount, schedule.released, schedule.duration, schedule.startDate) = vSOPH.vestingSchedules(user1, 0);

        // Elapsed duration: duration or until twice the duration
        uint256 elapsedTime = (duration * (100 + rand)) / 100;
        vm.warp(startDate + elapsedTime);
    
        uint256[] memory scheduleIndices = new uint256[](1);

        vm.prank(user1);
        vSOPH.approve(address(vSOPH), type(uint256).max);
            
        vm.expectEmit(true, true, true, true);
        emit LinearVestingWithPenalty.TokensReleased(user1, amount, 0);
        
        vm.prank(user1);
        vSOPH.releaseSpecificSchedules(scheduleIndices, penalty);
    }

    function testFuzz_ReleaseSpecificSchedules_OneDeposit_LTDuration(uint256 rand, uint256 amount, uint256 duration, uint256 startDate, bool penalty) public {
        vm.prank(admin);
        vSOPH.setVestingStartDate(1);

        rand = bound(rand, 0, 99);
        amount = bound(amount, 1, SOPHON_SUPPLY * 3 / 100);
        startDate = bound(startDate, block.timestamp, 3600 * 24 * 365); // Between 1 sec and 1 year
        duration = bound(duration, 1, 3600 * 24 * 90); // Between 1 sec and 90 days

        vm.prank(scheduleManager);
        vSOPH.addVestingSchedule(user1, amount, duration, startDate);

        LinearVestingWithPenalty.VestingSchedule memory schedule;
        (schedule.totalAmount, schedule.released, schedule.duration, schedule.startDate) = vSOPH.vestingSchedules(user1, 0);
        
        // Elapsed duration: a fraction of the duration (could be zero)
        uint256 elapsedTime = duration * rand / 100;
        vm.warp(startDate + elapsedTime);

        uint256[] memory scheduleIndices = new uint256[](1);

        vm.prank(user1);
        vSOPH.approve(address(vSOPH), type(uint256).max);

        // Proportional to the elapsed time
        uint256 amountToRelease = amount * elapsedTime / duration;

        // If there's no tokens to release, it should revert
        if (amountToRelease == 0 && !penalty) {
            console.log(amount, elapsedTime, duration);
            console.log(amountToRelease);
            vm.expectRevert(LinearVestingWithPenalty.NoTokensToRelease.selector);
        } else {
            
            uint256 penaltyAmount;
            if (penalty) {
                // If there's penalty, take that into account
                penaltyAmount = penalty ? (amount - amountToRelease) * PENALTY / 100 : 0;
                amountToRelease = amount - penaltyAmount; // Net amount
            }

            vm.expectEmit(true, true, true, true);
            emit LinearVestingWithPenalty.TokensReleased(user1, amountToRelease, penaltyAmount);
        }

        vm.prank(user1);
        vSOPH.releaseSpecificSchedules(scheduleIndices, penalty);
    }

    function testFuzz_ReleaseSpecificSchedules_MultipleDeposits_ClaimAfterVestingEnds() public {
        vm.prank(admin);
        vSOPH.setVestingStartDate(1);

        uint256 numberOfSchedules = 52;
        uint256 amount = SOPHON_SUPPLY * 3 / 1000;
        uint256 duration = 3600 * 24 * 90; // 90 days
        uint256 startDate = block.timestamp;

        address[] memory beneficiaries = new address[](numberOfSchedules);
        uint256[] memory amounts = new uint256[](numberOfSchedules);
        uint256[] memory durations = new uint256[](numberOfSchedules);
        uint256[] memory startDates = new uint256[](numberOfSchedules);
        uint256[] memory scheduleIndices = new uint256[](numberOfSchedules);

        for (uint256 i = 0; i < numberOfSchedules; i++) {
            beneficiaries[i] = user1;
            amounts[i] = amount;
            durations[i] = duration;
            startDates[i] = startDate + i * 3600 * 24 * 7; // 1 week apart
            scheduleIndices[i] = i;
        }

        vm.prank(scheduleManager);
        vSOPH.addMultipleVestingSchedules(beneficiaries, amounts, durations, startDates);

        uint256 elapsedTime = startDates[numberOfSchedules - 1] + duration;

        vm.warp(elapsedTime);

        vm.prank(user1);
        vSOPH.releaseSpecificSchedules(scheduleIndices, false);

        assertEq(vSOPH.balanceOf(user1), 0);
    }

    // RELEASE SCHEDULES IN RANGE FUNCTION
    function testFuzz_ReleaseSchedulesInRange_MultipleDeposits_ClaimWithoutPenaltyEachWeek() public {
        vm.prank(admin);
        vSOPH.setVestingStartDate(1);

        uint256 numberOfSchedules = 52;
        uint256 amount = SOPHON_SUPPLY * 3 / 1000;
        uint256 duration = 3600 * 24 * 90; // 90 days
        uint256 startDate = block.timestamp;

        address[] memory beneficiaries = new address[](numberOfSchedules);
        uint256[] memory amounts = new uint256[](numberOfSchedules);
        uint256[] memory durations = new uint256[](numberOfSchedules);
        uint256[] memory startDates = new uint256[](numberOfSchedules);
        uint256[] memory scheduleIndices = new uint256[](numberOfSchedules);

        for (uint256 i = 0; i < numberOfSchedules; i++) {
            beneficiaries[i] = user1;
            amounts[i] = amount;
            durations[i] = duration;
            startDates[i] = startDate + i * 3600 * 24 * 7; // 1 week apart
            scheduleIndices[i] = i;
        }

        vm.prank(scheduleManager);
        vSOPH.addMultipleVestingSchedules(beneficiaries, amounts, durations, startDates);

        assertEq(vSOPH.balanceOf(user1), amount * numberOfSchedules);

        uint256 elapsedTime;
        // This should work without _transferVestingSchedules function
        for (uint256 i = 1; i < numberOfSchedules + 13; i++) {
            uint256 start;
            uint256 end;

            // ranges are dynamic
            if (i < 14) {
                start = 0;
                end = i + 1;
            } else if (i < 52) {
                start = i - 14;
                end = i + 1;
            } else {
                start = i - 14;
                end = 52;
            }

            // Warp function behaves differently when using forge test and forge coverage --ir-minimum:
            // forge test: it sets the block.timestamp to the uint256 passed, as expected
            // forge coverage --ir-minimum: it sets the block.timestamp to the previus block.timestamp + uint256 passed
            // create an accumulator to calculate the elapsed time

            // elapsedTime = i * 3600 * 24 * 7; // forge test
            elapsedTime = 3600 * 24 * 7; // forge coverage --ir-minimum
            
            vm.warp(startDate + elapsedTime);

            vm.prank(user1);
            vSOPH.releaseSchedulesInRange(start, end, false);
        }

        assertEq(vSOPH.balanceOf(user1), 0);
        assertEq(SOPH.balanceOf(user1), amount * numberOfSchedules);
    }

    function testFuzz_ReleaseSchedulesInRange_MultipleDeposits_ClaimWithPenaltyEachWeek() public {
        vm.prank(admin);
        vSOPH.setVestingStartDate(1);

        uint256 numberOfSchedules = 52;
        uint256 amount = SOPHON_SUPPLY * 3 / 1000;
        uint256 duration = 3600 * 24 * 90; // 90 days
        uint256 startDate = block.timestamp;

        address[] memory beneficiaries = new address[](numberOfSchedules);
        uint256[] memory amounts = new uint256[](numberOfSchedules);
        uint256[] memory durations = new uint256[](numberOfSchedules);
        uint256[] memory startDates = new uint256[](numberOfSchedules);
        uint256[] memory scheduleIndices = new uint256[](numberOfSchedules);

        for (uint256 i = 0; i < numberOfSchedules; i++) {
            beneficiaries[i] = user1;
            amounts[i] = amount;
            durations[i] = duration;
            startDates[i] = startDate + i * 3600 * 24 * 7; // 1 week apart
            scheduleIndices[i] = i;
        }

        vm.prank(scheduleManager);
        vSOPH.addMultipleVestingSchedules(beneficiaries, amounts, durations, startDates);

        assertEq(vSOPH.balanceOf(user1), amount * numberOfSchedules);

        vm.warp(duration);

        uint256 elapsedTime;
        // This should work without _transferVestingSchedules function
        for (uint256 i = 0; i < numberOfSchedules; i++) {
            uint256 start = i;
            uint256 end = i + 1;

            // Warp function behaves differently when using forge test and forge coverage --ir-minimum:
            // forge test: it sets the block.timestamp to the uint256 passed, as expected
            // forge coverage --ir-minimum: it sets the block.timestamp to the previus block.timestamp + uint256 passed
            // create an accumulator to calculate the elapsed time

            // elapsedTime = i * 3600 * 24 * 7; // forge test
            elapsedTime = 3600 * 24 * 7; // forge coverage --ir-minimum
            
            vm.warp(startDate + elapsedTime);

            vm.prank(user1);
            vSOPH.releaseSchedulesInRange(start, end, true);
        }

        assertEq(vSOPH.balanceOf(user1), 0);
        assertEq(SOPH.balanceOf(user1), amount * numberOfSchedules);
    }

    function test_RevertIfNoVestingSchedule_ReleaseSchedulesInRange() public {
        vm.expectRevert(LinearVestingWithPenalty.NoVestingSchedule.selector);
        vm.prank(user1);
        vSOPH.releaseSchedulesInRange(0, 1, false);
    }

    function test_RevertIfInvalidRange_ReleaseSchedulesInRange() public {
        vm.prank(admin);
        vSOPH.setVestingStartDate(1);

        uint256 numberOfSchedules = 52;
        uint256 amount = SOPHON_SUPPLY * 3 / 1000;
        uint256 duration = 3600 * 24 * 90; // 90 days
        uint256 startDate = block.timestamp;

        address[] memory beneficiaries = new address[](numberOfSchedules);
        uint256[] memory amounts = new uint256[](numberOfSchedules);
        uint256[] memory durations = new uint256[](numberOfSchedules);
        uint256[] memory startDates = new uint256[](numberOfSchedules);
        uint256[] memory scheduleIndices = new uint256[](numberOfSchedules);

        for (uint256 i = 0; i < numberOfSchedules; i++) {
            beneficiaries[i] = user1;
            amounts[i] = amount;
            durations[i] = duration;
            startDates[i] = startDate + i * 3600 * 24 * 7; // 1 week apart
            scheduleIndices[i] = i;
        }

        vm.prank(scheduleManager);
        vSOPH.addMultipleVestingSchedules(beneficiaries, amounts, durations, startDates);

        vm.expectRevert(LinearVestingWithPenalty.InvalidRange.selector);
        vm.prank(user1);
        vSOPH.releaseSchedulesInRange(1, 0, false);
    }

    function test_RevertIfNoTokensToRelease_ReleaseSchedulesInRange() public {
        vm.prank(admin);
        vSOPH.setVestingStartDate(1);

        uint256 numberOfSchedules = 52;
        uint256 amount = SOPHON_SUPPLY * 3 / 1000;
        uint256 duration = 3600 * 24 * 90; // 90 days
        uint256 startDate = block.timestamp + 100;

        address[] memory beneficiaries = new address[](numberOfSchedules);
        uint256[] memory amounts = new uint256[](numberOfSchedules);
        uint256[] memory durations = new uint256[](numberOfSchedules);
        uint256[] memory startDates = new uint256[](numberOfSchedules);
        uint256[] memory scheduleIndices = new uint256[](numberOfSchedules);

        for (uint256 i = 0; i < numberOfSchedules; i++) {
            beneficiaries[i] = user1;
            amounts[i] = amount;
            durations[i] = duration;
            startDates[i] = startDate + i * 3600 * 24 * 7; // 1 week apart
            scheduleIndices[i] = i;
        }

        vm.prank(scheduleManager);
        vSOPH.addMultipleVestingSchedules(beneficiaries, amounts, durations, startDates);

        vm.warp(startDate + 3 * 3600 * 24 * 7);

        // Release all schedules
        vm.prank(user1);
        vSOPH.releaseSchedulesInRange(0, 1, false);

        // Now there's no tokens to release
        vm.expectRevert(LinearVestingWithPenalty.NoTokensToRelease.selector);
        vm.prank(user1);
        vSOPH.releaseSchedulesInRange(0, 1, false);
    }

    // GET VESTING SCHEDULES FUNCTION
    function testFuzz_GetVestingSchedules(uint256 seed) public {
        uint256 numberOfSchedules = bound(seed, 1, 20);

        address[] memory beneficiaries = new address[](numberOfSchedules);
        uint256[] memory amounts = new uint256[](numberOfSchedules);
        uint256[] memory durations = new uint256[](numberOfSchedules);
        uint256[] memory startDates = new uint256[](numberOfSchedules);
        uint256 totalAmount;

        for (uint256 i = 0; i < numberOfSchedules; i++) {
            uint256 rand = uint256(keccak256(abi.encodePacked(seed, i)));
            beneficiaries[i] = user1;
            amounts[i] = bound(rand, 1, SOPHON_SUPPLY) * 3 / 100;
            totalAmount += amounts[i];
            durations[i] = bound(rand, 1, 3600 * 24 * 365); // Between 1 and 1 year
            startDates[i] = bound(rand, block.timestamp, 3600 * 24 * 90); // Between 1 and 90 days
        }

        vm.prank(scheduleManager);
        vSOPH.addMultipleVestingSchedules(beneficiaries, amounts, durations, startDates);

        LinearVestingWithPenalty.VestingSchedule[] memory schedules = new LinearVestingWithPenalty.VestingSchedule[](numberOfSchedules);
        schedules = vSOPH.getVestingSchedules(user1);

        for (uint256 i = 0; i < numberOfSchedules; i++) {
            LinearVestingWithPenalty.VestingSchedule memory schedule;
            (schedule.totalAmount, schedule.released, schedule.duration, schedule.startDate) = vSOPH.vestingSchedules(user1, i);

            assertEq(schedule.totalAmount, amounts[i]);
            assertEq(schedules[i].totalAmount, amounts[i]);
            assertEq(schedule.released, 0);
            assertEq(schedules[i].released, 0);
            assertEq(schedule.duration, durations[i]);
            assertEq(schedules[i].duration, durations[i]);
            assertEq(schedule.startDate, startDates[i]);
            assertEq(schedules[i].startDate, startDates[i]);
        }

        assertEq(vSOPH.balanceOf(user1), totalAmount);
        assertEq(vSOPH.totalSupply(), totalAmount);
    }

    // GET VESTING SCHEDULES IN RANGE FUNCTION
    function testFuzz_GetVestingSchedulesInRange(uint256 seed, uint256 start, uint256 end) public {
        uint256 numberOfSchedules = bound(seed, 2, 20);
        start = bound(seed, 0, numberOfSchedules - 1);
        end = bound(seed, start + 1, numberOfSchedules);

        address[] memory beneficiaries = new address[](numberOfSchedules);
        uint256[] memory amounts = new uint256[](numberOfSchedules);
        uint256[] memory durations = new uint256[](numberOfSchedules);
        uint256[] memory startDates = new uint256[](numberOfSchedules);
        uint256 totalAmount;

        for (uint256 i = 0; i < numberOfSchedules; i++) {
            uint256 rand = uint256(keccak256(abi.encodePacked(seed, i)));
            beneficiaries[i] = user1;
            amounts[i] = bound(rand, 1, SOPHON_SUPPLY) * 3 / 100;
            totalAmount += amounts[i];
            durations[i] = bound(rand, 1, 3600 * 24 * 365); // Between 1 and 1 year
            startDates[i] = bound(rand, block.timestamp, 3600 * 24 * 90); // Between 1 and 90 days
            vm.expectEmit(true, true, true, true);
            emit LinearVestingWithPenalty.VestingScheduleAdded(beneficiaries[i], amounts[i], durations[i], startDates[i]);
        }

        vm.prank(scheduleManager);
        vSOPH.addMultipleVestingSchedules(beneficiaries, amounts, durations, startDates);


        LinearVestingWithPenalty.VestingSchedule[] memory schedules = new LinearVestingWithPenalty.VestingSchedule[](end - start);
        schedules = vSOPH.getVestingSchedulesInRange(user1, start, end);

        for (uint256 i = start; i < end - start; i++) {
            LinearVestingWithPenalty.VestingSchedule memory schedule;
            (schedule.totalAmount, schedule.released, schedule.duration, schedule.startDate) = vSOPH.vestingSchedules(user1, i);

            assertEq(schedule.totalAmount, amounts[i]);
            assertEq(schedules[i - start].totalAmount, amounts[i]);
            assertEq(schedule.released, 0);
            assertEq(schedules[i - start].released, 0);
            assertEq(schedule.duration, durations[i]);
            assertEq(schedules[i - start].duration, durations[i]);
            assertEq(schedule.startDate, startDates[i]);
            assertEq(schedules[i - start].startDate, startDates[i]);
        }

        assertEq(vSOPH.balanceOf(user1), totalAmount);
        assertEq(vSOPH.totalSupply(), totalAmount);
    }

    function test_RevertIfInvalidRange_GetVestingSchedulesInRange() public {
        vm.expectRevert(LinearVestingWithPenalty.InvalidRange.selector);
        vSOPH.getVestingSchedulesInRange(user1, 1, 0);

        vm.expectRevert(LinearVestingWithPenalty.InvalidRange.selector);
        vSOPH.getVestingSchedulesInRange(user1, 0, 1);
    }

    // VESTED AMOUNT AND RELEASABLE AMOUNT FUNCTION
    function testFuzz_VestedAmountAndReleasableAmount_FullAmount(uint256 seed, uint256 warpTime) public {
        vm.prank(admin);
        vSOPH.setVestingStartDate(1);

        uint256 numberOfSchedules = bound(seed, 1, 20);

        address[] memory beneficiaries = new address[](numberOfSchedules);
        uint256[] memory amounts = new uint256[](numberOfSchedules);
        uint256[] memory durations = new uint256[](numberOfSchedules);
        uint256[] memory startDates = new uint256[](numberOfSchedules);
        uint256 totalAmount;

        warpTime = bound(warpTime, block.timestamp, 3600 * 24 * 365);

        for (uint256 i = 0; i < numberOfSchedules; i++) {
            uint256 rand = uint256(keccak256(abi.encodePacked(seed, i)));
            beneficiaries[i] = user1;
            amounts[i] = bound(rand, 1, SOPHON_SUPPLY) * 3 / 100;
            totalAmount += amounts[i];
            durations[i] = bound(rand, 1, 3600 * 24 * 365); // Between 1 and 1 year
            startDates[i] = bound(rand, block.timestamp, 3600 * 24 * 90); // Between 1 and 90 days
        }

        vm.prank(scheduleManager);
        vSOPH.addMultipleVestingSchedules(beneficiaries, amounts, durations, startDates);

        vm.warp(warpTime);
        uint256 totalVestedAmount;

        for (uint256 i = 0; i < numberOfSchedules; i++) {
            uint256 vestedTime = warpTime > durations[i] + startDates[i] ? durations[i] : warpTime > startDates[i] ? warpTime - startDates[i] : 0;
            totalVestedAmount += amounts[i] * vestedTime / durations[i];
        }

        assertEq(vSOPH.vestedAmount(user1), totalVestedAmount);
        assertEq(vSOPH.releasableAmount(user1), totalVestedAmount);
    }
        
    function testFuzz_VestedAmountAndReleasableAmount_PartialAmounts(uint256 seed, uint256 warpTime) public {
        vm.prank(admin);
        vSOPH.setVestingStartDate(1);

        uint256 numberOfSchedules = bound(seed, 1, 20);

        address[] memory beneficiaries = new address[](numberOfSchedules);
        uint256[] memory amounts = new uint256[](numberOfSchedules);
        uint256[] memory durations = new uint256[](numberOfSchedules);
        uint256[] memory startDates = new uint256[](numberOfSchedules);
        uint256 totalAmount;

        warpTime = bound(warpTime, block.timestamp, 3600 * 24 * 365);

        for (uint256 i = 0; i < numberOfSchedules; i++) {
            uint256 rand = uint256(keccak256(abi.encodePacked(seed, i)));
            beneficiaries[i] = user1;
            amounts[i] = bound(rand, 1, SOPHON_SUPPLY) * 3 / 100;
            totalAmount += amounts[i];
            durations[i] = bound(rand, 1, 3600 * 24 * 365); // Between 1 and 1 year
            startDates[i] = bound(rand, block.timestamp, 3600 * 24 * 90); // Between 1 and 90 days
        }

        vm.prank(scheduleManager);
        vSOPH.addMultipleVestingSchedules(beneficiaries, amounts, durations, startDates);

        vm.warp(warpTime);
        uint256 totalVestedAmount;
        uint256 totalReleasableAmount;

        for (uint256 i = 0; i < numberOfSchedules; i++) {
            uint256 vestedTime = warpTime > durations[i] + startDates[i] ? durations[i] : warpTime > startDates[i] ? warpTime - startDates[i] : 0;
            console.log("Vested time: ", vestedTime);
            if (vestedTime > 0) {
                uint256[] memory scheduleIndices = new uint256[](1);
                scheduleIndices[0] = i;
                vm.prank(user1);
                vSOPH.claim(scheduleIndices);
            } else {
                totalReleasableAmount += amounts[i] * vestedTime / durations[i];
            }
            totalVestedAmount += amounts[i] * vestedTime / durations[i];
        }

        assertEq(vSOPH.vestedAmount(user1), totalVestedAmount);
        assertEq(vSOPH.releasableAmount(user1), totalReleasableAmount);
    }

    // CLAIM FUNCTION
    function testFuzz_Claim(uint256 amount, uint256 duration, uint256 startDate) public {
        amount = bound(amount, 1, type(uint256).max);
        startDate = bound(startDate, block.timestamp, type(uint256).max);
        duration = bound(duration, 1, type(uint256).max);

        vm.prank(scheduleManager);
        vSOPH.addVestingSchedule(user1, amount, duration, startDate);

        LinearVestingWithPenalty.VestingSchedule memory schedule;
        (schedule.totalAmount, schedule.released, schedule.duration, schedule.startDate) = vSOPH.vestingSchedules(user1, 0);

        assertEq(schedule.totalAmount, amount);
        assertEq(schedule.released, 0);
        assertEq(schedule.duration, duration);
        assertEq(schedule.startDate, startDate);
        assertEq(vSOPH.balanceOf(user1), amount);
    }

    function test_RevertIfVestingHasNotStartedYet_Claim() public {
        vm.prank(admin);
        vSOPH.setVestingStartDate(block.timestamp + 1);

        uint256[] memory scheduleIndices = new uint256[](1);

        vm.prank(user1);
        vm.expectRevert(LinearVestingWithPenalty.VestingHasNotStartedYet.selector);
        vSOPH.claim(scheduleIndices);
    }

    function test_RevertIfInvalidScheduleIndex_Claim() public {
        uint256[] memory scheduleIndices = new uint256[](1);

        vm.prank(user1);
        vm.expectRevert(LinearVestingWithPenalty.InvalidScheduleIndex.selector);
        vSOPH.claim(scheduleIndices);
    }

    function test_RevertIfNoTokensAvailableForRelease_Claim() public {
        uint256[] memory scheduleIndices = new uint256[](1);

        vm.prank(user1);
        vm.expectRevert(LinearVestingWithPenalty.InvalidScheduleIndex.selector);
        vSOPH.claim(scheduleIndices);
    }


    function testFuzz_RevertIfNoTokensAvailableForRelease_Claim(uint256 amount, uint256 duration, uint256 startDate) public {
        amount = bound(amount, 1, SOPHON_SUPPLY / 1000);
        duration = bound(duration, block.timestamp, 3600 * 24 * 90); // Between 1 and 90 days
        startDate = bound(startDate, 1, 3600 * 24 * 365); // Between 1 and 1 year

        vm.prank(scheduleManager);
        vSOPH.addVestingSchedule(user1, amount, duration, startDate);

        vm.warp((startDate + duration) / 2);
        uint256[] memory scheduleIndices = new uint256[](1);
        vm.prank(user1);
        vm.expectRevert("No tokens available for release");
        vSOPH.claim(scheduleIndices);
    }

    // GET UNCLAIMED SCHEDULES IN RANGE FUNCTION
    function testFuzz_GetUnclaimedSchedulesInRange(uint256 seed, uint256 warpTime) public {
        vm.prank(admin);
        vSOPH.setVestingStartDate(1);

        uint256 numberOfSchedules = bound(seed, 1, 20);

        address[] memory beneficiaries = new address[](numberOfSchedules);
        uint256[] memory amounts = new uint256[](numberOfSchedules);
        uint256[] memory durations = new uint256[](numberOfSchedules);
        uint256[] memory startDates = new uint256[](numberOfSchedules);
        uint256 totalAmount;

        warpTime = bound(warpTime, block.timestamp, 3600 * 24 * 365);

        for (uint256 i = 0; i < numberOfSchedules; i++) {
            uint256 rand = uint256(keccak256(abi.encodePacked(seed, i)));
            beneficiaries[i] = user1;
            amounts[i] = bound(rand, 1, SOPHON_SUPPLY) * 3 / 100;
            totalAmount += amounts[i];
            durations[i] = bound(rand, 1, 3600 * 24 * 365); // Between 1 and 1 year
            startDates[i] = bound(rand, block.timestamp, 3600 * 24 * 90); // Between 1 and 90 days
        }

        vm.prank(scheduleManager);
        vSOPH.addMultipleVestingSchedules(beneficiaries, amounts, durations, startDates);

        vm.warp(warpTime);
        uint256 totalVestedAmount;

        (auxiliarArray1, auxiliarArray2) = vSOPH.getUnclaimedSchedulesInRange(user1, 0, numberOfSchedules);
        uint256 totalUnclaimed;
        for (uint256 i = 0; i < auxiliarArray2.length; i++) {
            totalUnclaimed += auxiliarArray2[i];
        }

        for (uint256 i = 0; i < numberOfSchedules; i++) {
            uint256 vestedTime = warpTime > durations[i] + startDates[i] ? durations[i] : warpTime > startDates[i] ? warpTime - startDates[i] : 0;
            totalVestedAmount += amounts[i] * vestedTime / durations[i];
        }

        assertEq(vSOPH.vestedAmount(user1), totalVestedAmount);
        assertEq(vSOPH.releasableAmount(user1), totalVestedAmount);
        assertEq(vSOPH.releasableAmount(user1), totalUnclaimed);
    }

    function test_RevertIfInvalidRange_GetUnclaimedSchedulesInRange() public {
        vm.expectRevert("Invalid range");
        vSOPH.getUnclaimedSchedulesInRange(user1, 1, 0);

        vm.expectRevert("Invalid range");
        vSOPH.getUnclaimedSchedulesInRange(user1, 0, 1); // No schedules
    }

    // CLAIM SPECIFIC SCHEDULES WITH PENALTY FUNCTION
    function testFuzz_ClaimSpecificSchedulesWithPenalty() public {
        vm.prank(admin);
        vSOPH.setVestingStartDate(1);

        uint256 numberOfSchedules = 52;
        uint256 amount = SOPHON_SUPPLY * 3 / 1000;
        uint256 duration = 3600 * 24 * 90; // 90 days
        uint256 startDate = block.timestamp;

        address[] memory beneficiaries = new address[](numberOfSchedules);
        uint256[] memory amounts = new uint256[](numberOfSchedules);
        uint256[] memory durations = new uint256[](numberOfSchedules);
        uint256[] memory startDates = new uint256[](numberOfSchedules);
        uint256[] memory scheduleIndices = new uint256[](numberOfSchedules);

        for (uint256 i = 0; i < numberOfSchedules; i++) {
            beneficiaries[i] = user1;
            amounts[i] = amount;
            durations[i] = duration;
            startDates[i] = startDate + i * 3600 * 24 * 7; // 1 week apart
            scheduleIndices[i] = i;
        }

        vm.prank(scheduleManager);
        vSOPH.addMultipleVestingSchedules(beneficiaries, amounts, durations, startDates);

        uint256 elapsedTime = startDates[numberOfSchedules - 1] + duration;

        vm.warp(elapsedTime);

        vm.prank(user1);
        vSOPH.claimSpecificSchedulesWithPenalty(scheduleIndices);

        assertEq(vSOPH.balanceOf(user1), 0);
    }

    // RESCUE FUNCTION
    function testFuzz_Rescue(uint256 amount) public {
        vm.startPrank(admin);

        IERC20 token = IERC20(address(new MockERC20("MockToken", "MTK", 18)));
        deal(address(token), address(vSOPH), amount);

        assertEq(token.balanceOf(address(vSOPH)), amount);
        assertEq(token.balanceOf(address(admin)), 0);

        vSOPH.rescue(token, admin);

        assertEq(token.balanceOf(address(vSOPH)), 0);
        assertEq(token.balanceOf(address(admin)), amount);
    }

    // TRANSFER FUNCTION
    function testFuzz_Transfer(uint256 amount) public {
        vm.startPrank(admin);
        amount = bound(amount, 1, type(uint256).max);

        deal(address(vSOPH), admin, amount);

        vSOPH.transfer(user1, amount);

        assertEq(vSOPH.balanceOf(admin), 0);
        assertEq(vSOPH.balanceOf(user1), amount);
    }

    function testFuzz_RevertIfAccessControlUnauthorizedAccount_Transfer(uint256 amount) public {
        vm.startPrank(user1);
        amount = bound(amount, 1, type(uint256).max);

        deal(address(vSOPH), admin, amount);

        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, user1, vSOPH.ADMIN_ROLE())
        );
        vSOPH.transfer(user1, amount);
    }

    // TRANSFER FROM FUNCTION
    function testFuzz_TransferFrom(uint256 amount) public {
        amount = bound(amount, 1, type(uint256).max);

        deal(address(vSOPH), user1, amount);
        
        vm.prank(user1);
        vSOPH.approve(admin, amount);

        vm.prank(admin);
        vSOPH.transferFrom(user1, user2, amount);

        assertEq(vSOPH.balanceOf(user1), 0);
        assertEq(vSOPH.balanceOf(user2), amount);
    }

    function testFuzz_RevertIfAccessControlUnauthorizedAccount_TransferFrom(uint256 amount) public {
        amount = bound(amount, 1, type(uint256).max);

        deal(address(vSOPH), user1, amount);
        
        vm.prank(user1);
        vSOPH.approve(user2, amount);

        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, user2, vSOPH.ADMIN_ROLE())
        );
        vm.prank(user2);
        vSOPH.transferFrom(user1, user2, amount);
    }

    // ADMIN TRANSFER FUNCTION
    function testFuzz_AdminTransfer(uint256 seed) public {
        uint256 numberOfSchedules = bound(seed, 1, 20);

        address[] memory beneficiaries = new address[](numberOfSchedules);
        uint256[] memory amounts = new uint256[](numberOfSchedules);
        uint256[] memory durations = new uint256[](numberOfSchedules);
        uint256[] memory startDates = new uint256[](numberOfSchedules);
        uint256 totalAmount;

        for (uint256 i = 0; i < numberOfSchedules; i++) {
            uint256 rand = uint256(keccak256(abi.encodePacked(seed, i)));
            beneficiaries[i] = user1;
            amounts[i] = bound(rand, 1, SOPHON_SUPPLY) * 3 / 100;
            totalAmount += amounts[i];
            durations[i] = bound(rand, 1, 3600 * 24 * 365); // Between 1 and 1 year
            startDates[i] = bound(rand, block.timestamp, 3600 * 24 * 90); // Between 1 and 90 days
        }

        vm.prank(scheduleManager);
        vSOPH.addMultipleVestingSchedules(beneficiaries, amounts, durations, startDates);

        vm.prank(admin);
        vSOPH.adminTransfer(user1, user2);

        LinearVestingWithPenalty.VestingSchedule[] memory user1Schedules = new LinearVestingWithPenalty.VestingSchedule[](numberOfSchedules);
        user1Schedules = vSOPH.getVestingSchedules(user1);

        LinearVestingWithPenalty.VestingSchedule[] memory user2Schedules = new LinearVestingWithPenalty.VestingSchedule[](numberOfSchedules);
        user2Schedules = vSOPH.getVestingSchedules(user2);
        
        assertEq(user1Schedules.length, 0);

        for (uint256 i = 0; i < numberOfSchedules; i++) {            
            assertEq(user2Schedules[i].totalAmount, amounts[i]);
            assertEq(user2Schedules[i].released, 0);
            assertEq(user2Schedules[i].duration, durations[i]);
            assertEq(user2Schedules[i].startDate, startDates[i]);
        }

        assertEq(vSOPH.balanceOf(user1), 0);
        assertEq(vSOPH.balanceOf(user2), totalAmount);
    }

    function testFuzz_RevertIfAccessControlUnauthorizedAccount_AdminTransfer(uint256 seed) public {
        uint256 numberOfSchedules = bound(seed, 1, 20);

        address[] memory beneficiaries = new address[](numberOfSchedules);
        uint256[] memory amounts = new uint256[](numberOfSchedules);
        uint256[] memory durations = new uint256[](numberOfSchedules);
        uint256[] memory startDates = new uint256[](numberOfSchedules);
        uint256 totalAmount;

        for (uint256 i = 0; i < numberOfSchedules; i++) {
            uint256 rand = uint256(keccak256(abi.encodePacked(seed, i)));
            beneficiaries[i] = user1;
            amounts[i] = bound(rand, 1, SOPHON_SUPPLY) * 3 / 100;
            totalAmount += amounts[i];
            durations[i] = bound(rand, 1, 3600 * 24 * 365); // Between 1 and 1 year
            startDates[i] = bound(rand, block.timestamp, 3600 * 24 * 90); // Between 1 and 90 days
        }

        vm.prank(scheduleManager);
        vSOPH.addMultipleVestingSchedules(beneficiaries, amounts, durations, startDates);

        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, user1, vSOPH.ADMIN_ROLE())
        );

        vm.prank(user1);
        vSOPH.adminTransfer(user1, user2);
    }

    // AUTHORIZE UPGRADE FUNCTION
    // function test_AuthorizeUpgrade() public {
    //     address newImplementation = makeAddr("newImplementation");

    //     vm.prank(upgrader);
    //     vSOPH.authorizeUpgrade(newImplementation);
    // }

    // function test_RevertIfAccessControlUnauthorizedAccount_AuthorizeUpgrade() public {
    //     address newImplementation = makeAddr("newImplementation");

    //     vm.expectRevert(
    //         abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, attacker, vSOPH.ADMIN_ROLE())
    //     );
    //     vm.prank(attacker);
    //     vSOPH.authorizeUpgrade(newImplementation);
    // }


    //     // function testFuzz_RevertIfVestingHasNotStartedYet_Claim(uint256 amount, uint256 duration, uint256 startDate) public {
    //     // function testFuzz_RevertIfInvalidScheduleIndex_Claim(uint256 amount, uint256 duration, uint256 startDate) public {

}

// Can claim with or without penalty. There needs to be a releasable amount.
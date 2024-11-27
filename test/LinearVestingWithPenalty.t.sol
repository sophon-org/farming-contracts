// // SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {MockERC20} from "./../contracts/mocks/MockERC20.sol";
import {LinearVestingWithPenalty} from "../contracts/token/LinearVestingWithPenalty.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";



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

        vm.prank(scheduleManager); // TODO reverts because _update function has only admin role required
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
        vm.prank(scheduleManager); // TODO reverts because _update function has only admin role required
        vm.expectRevert(LinearVestingWithPenalty.InvalidRecipientAddress.selector);
        vSOPH.addVestingSchedule(address(0), VESTING_SCHEDULE_AMOUNT, VESTING_SCHEDULE_DURATION, block.timestamp);
    }

    function test_RevertIfTotalAmountMustBeGreaterThanZero_AddVestingSchedule() public {
        vm.prank(scheduleManager); // TODO reverts because _update function has only admin role required
        vm.expectRevert(LinearVestingWithPenalty.TotalAmountMustBeGreaterThanZero.selector);
        vSOPH.addVestingSchedule(user1, 0, VESTING_SCHEDULE_DURATION, block.timestamp);
    }

    function test_RevertIfDurationMustBeGreaterThanZero_AddVestingSchedule() public {
        vm.prank(scheduleManager); // TODO reverts because _update function has only admin role required
        vm.expectRevert(LinearVestingWithPenalty.DurationMustBeGreaterThanZero.selector);
        vSOPH.addVestingSchedule(user1, VESTING_SCHEDULE_AMOUNT, 0, block.timestamp);
    }

    // ADD MULTIPLE VESTING SCHEDULES
    function testFuzz_AddMultipleVestingSchedule(uint256 seed) public {
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

        vm.prank(scheduleManager); // TODO reverts because _update function has only admin role required
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

    function test_RevertIfMismatchedArrayLengths_AddMultipleVestingSchedule() public {
        address[] memory beneficiaries = new address[](10);
        uint256[] memory amounts = new uint256[](10);
        uint256[] memory durations = new uint256[](10);
        uint256[] memory startDates = new uint256[](10);

        assembly { mstore(amounts, sub(mload(amounts), 1)) } // memory array pop
        vm.expectRevert(LinearVestingWithPenalty.MismatchedArrayLengths.selector);
        vm.prank(scheduleManager); // TODO reverts because _update function has only admin role required
        vSOPH.addMultipleVestingSchedules(beneficiaries, amounts, durations, startDates);

        assembly { mstore(beneficiaries, sub(mload(beneficiaries), 1)) } // memory array pop
        assembly { mstore(durations, sub(mload(durations), 1)) } // memory array pop
        assembly { mstore(durations, sub(mload(durations), 1)) } // memory array pop
        assembly { mstore(startDates, sub(mload(startDates), 1)) } // memory array pop
        vm.expectRevert(LinearVestingWithPenalty.MismatchedArrayLengths.selector);
        vm.prank(scheduleManager); // TODO reverts because _update function has only admin role required
        vSOPH.addMultipleVestingSchedules(beneficiaries, amounts, durations, startDates);

        assembly { mstore(beneficiaries, sub(mload(beneficiaries), 1)) } // memory array pop
        assembly { mstore(amounts, sub(mload(amounts), 1)) } // memory array pop
        assembly { mstore(startDates, sub(mload(startDates), 1)) } // memory array pop
        assembly { mstore(startDates, sub(mload(startDates), 1)) } // memory array pop
        vm.expectRevert(LinearVestingWithPenalty.MismatchedArrayLengths.selector);
        vm.prank(scheduleManager); // TODO reverts because _update function has only admin role required
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

        vm.prank(scheduleManager); // TODO reverts because _update function has only admin role required
        vSOPH.addVestingSchedule(user1, amount, duration, startDate);

        LinearVestingWithPenalty.VestingSchedule memory schedule;
        (schedule.totalAmount, schedule.released, schedule.duration, schedule.startDate) = vSOPH.vestingSchedules(user1, 0);

        // Elapsed duration: duration or until twice the duration
        uint256 elapsedTime = (duration * (100 + rand)) / 100;
        vm.warp(startDate + elapsedTime);
    
        uint256[] memory scheduleIndices = new uint256[](1);

        vm.prank(user1);
        vSOPH.approve(address(vSOPH), type(uint256).max);

        console.log(vSOPH.balanceOf(user1));
            
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

        vm.prank(scheduleManager); // TODO reverts because _update function has only admin role required
        vSOPH.addVestingSchedule(user1, amount, duration, startDate);

        LinearVestingWithPenalty.VestingSchedule memory schedule;
        (schedule.totalAmount, schedule.released, schedule.duration, schedule.startDate) = vSOPH.vestingSchedules(user1, 0);
        
        // Elapsed duration: a fraction of the duration (could be zero)
        uint256 elapsedTime = duration * rand / 100;
        vm.warp(startDate + elapsedTime);

        uint256[] memory scheduleIndices = new uint256[](1);

        vm.prank(user1);
        vSOPH.approve(address(vSOPH), type(uint256).max);

        console.log(vSOPH.balanceOf(user1));

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

    function testFuzz_ReleaseSpecificSchedules_MultipleDeposits(/*uint256 seed*/) public {
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

        vm.prank(scheduleManager); // TODO reverts because _update function has only admin role required
        vSOPH.addMultipleVestingSchedules(beneficiaries, amounts, durations, startDates);

        uint256 elapsedTime = startDate;

        // LinearVestingWithPenalty.VestingSchedule[] memory schedules = new LinearVestingWithPenalty.VestingSchedule[](numberOfSchedules);
        // schedules = vSOPH.getVestingSchedules(user1);

        // This should work without _transferVestingSchedules function
        for (uint256 i = 0; i < numberOfSchedules; i++) {
            uint256[] memory releaseSchedule = new uint256[](1);

            releaseSchedule[0] = i;
            elapsedTime += (i + 1) * 3600 * 24 * 7 + 1;
            vm.warp(startDate + elapsedTime);
            vm.prank(user1);
            vSOPH.releaseSpecificSchedules(releaseSchedule, true);
        }
    }
}

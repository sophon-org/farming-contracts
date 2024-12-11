# tests/test_linear_vesting_with_penalty.py

import pytest
from brownie import reverts, accounts, exceptions


@pytest.fixture
def ADMIN():
    return accounts[0]


@pytest.fixture
def SCHEDULE_MANAGER():
    return accounts[1]


@pytest.fixture
def UPGRADER():
    return accounts[2]


@pytest.fixture
def PENALTY_RECIPIENT():
    return accounts[3]


@pytest.fixture
def USER1():
    return accounts[4]


@pytest.fixture
def USER2():
    return accounts[5]


@pytest.fixture
def SOPHTOKEN(ADMIN, MockERC20):
    return MockERC20.deploy("Mock SOPH Token", "MockSOPH", 18, {"from": ADMIN})


@pytest.fixture
def VESTING_CONTRACT(ADMIN, SOPHTOKEN, PENALTY_RECIPIENT, LinearVestingWithPenalty, chain):
    vSOPH = LinearVestingWithPenalty.deploy({"from": ADMIN})
    vSOPH.initialize(
        SOPHTOKEN.address,
        ADMIN.address,
        PENALTY_RECIPIENT.address,
        50,  # 50% penalty
        {"from": ADMIN}
    )
    vSOPH.setVestingStartDate(chain.time() + 100, {"from": ADMIN})
    return vSOPH


@pytest.fixture
def VESTING_CONTRACT_WITHOUT_START_DATE(ADMIN, SOPHTOKEN, PENALTY_RECIPIENT, LinearVestingWithPenalty):
    vSOPH = LinearVestingWithPenalty.deploy({"from": ADMIN})
    vSOPH.initialize(
        SOPHTOKEN.address,
        ADMIN.address,
        PENALTY_RECIPIENT.address,
        50,  # 50% penalty
        {"from": ADMIN}
    )
    return vSOPH


@pytest.fixture(autouse=True)
def DEPLOY_ROLES(ADMIN, VESTING_CONTRACT, UPGRADER, SCHEDULE_MANAGER):
    # Grant roles to respective accounts
    VESTING_CONTRACT.grantRole(
        VESTING_CONTRACT.SCHEDULE_MANAGER_ROLE(), SCHEDULE_MANAGER.address, {"from": ADMIN}
    )
    VESTING_CONTRACT.grantRole(
        VESTING_CONTRACT.UPGRADER_ROLE(), UPGRADER.address, {"from": ADMIN}
    )


def test_initialization(VESTING_CONTRACT, SOPHTOKEN, ADMIN, PENALTY_RECIPIENT, SCHEDULE_MANAGER, UPGRADER):
    assert VESTING_CONTRACT.sophtoken() == SOPHTOKEN.address
    assert VESTING_CONTRACT.penaltyRecipient() == PENALTY_RECIPIENT.address
    assert VESTING_CONTRACT.penaltyPercentage() == 50

    # Check roles
    assert VESTING_CONTRACT.hasRole(VESTING_CONTRACT.DEFAULT_ADMIN_ROLE(), ADMIN.address)
    assert VESTING_CONTRACT.hasRole(VESTING_CONTRACT.ADMIN_ROLE(), ADMIN.address)
    assert VESTING_CONTRACT.hasRole(VESTING_CONTRACT.SCHEDULE_MANAGER_ROLE(), SCHEDULE_MANAGER.address)
    assert VESTING_CONTRACT.hasRole(VESTING_CONTRACT.UPGRADER_ROLE(), UPGRADER.address)


def test_access_control_set_penalty_recipient(VESTING_CONTRACT, ADMIN, USER1):
    new_recipient = USER1
    VESTING_CONTRACT.setPenaltyRecipient(new_recipient.address, {"from": ADMIN})
    assert VESTING_CONTRACT.penaltyRecipient() == new_recipient.address

    # Attempt to set penalty recipient from non-admin account
    with pytest.raises(exceptions.VirtualMachineError, match="AccessControlUnauthorizedAccount"):
        VESTING_CONTRACT.setPenaltyRecipient(USER1.address, {"from": USER1})


def test_access_control_set_penalty_percentage(VESTING_CONTRACT, ADMIN):
    VESTING_CONTRACT.setPenaltyPercentage(30, {"from": ADMIN})
    assert VESTING_CONTRACT.penaltyPercentage() == 30

    # Attempt to set penalty percentage above 100%
    with pytest.raises(exceptions.VirtualMachineError, match="PenaltyMustBeLessThanOrEqualTo100Percent"):
        VESTING_CONTRACT.setPenaltyPercentage(150, {"from": ADMIN})

    # Attempt to set penalty percentage from non-admin account
    with pytest.raises(exceptions.VirtualMachineError, match="AccessControlUnauthorizedAccount"):
        VESTING_CONTRACT.setPenaltyPercentage(20, {"from": accounts[4]})


def test_access_control_add_vesting_schedule(VESTING_CONTRACT, SCHEDULE_MANAGER, ADMIN, USER1, SOPHTOKEN, chain):
    # Mint SOPH tokens to the vesting contract
    SOPHTOKEN.mint(VESTING_CONTRACT.address, 5000 * 10 ** 18, {"from": ADMIN})

    # Add vesting schedule as SCHEDULE_MANAGER
    start_date = chain.time() + 1000  # Vesting starts in the future
    VESTING_CONTRACT.addVestingSchedule(
        USER1.address, 2000 * 10 ** 18, 2000, start_date, {"from": SCHEDULE_MANAGER}
    )

    schedules = VESTING_CONTRACT.getVestingSchedules(USER1.address)
    assert len(schedules) == 1
    assert schedules[0][0] == 2000 * 10 ** 18  # totalAmount
    assert schedules[0][1] == 0                # released
    assert schedules[0][2] == 2000             # duration
    assert schedules[0][3] == start_date       # startDate

    # Attempt to add vesting schedule from non-schedule_manager account
    with pytest.raises(exceptions.VirtualMachineError, match="AccessControl"):
        VESTING_CONTRACT.addVestingSchedule(
            USER1.address, 1000 * 10 ** 18, 1000, start_date, {"from": accounts[4]}
        )


def test_add_multiple_vesting_schedules(VESTING_CONTRACT, SCHEDULE_MANAGER, ADMIN, USER1, USER2, SOPHTOKEN, chain):
    # Mint SOPH tokens to the vesting contract
    SOPHTOKEN.mint(VESTING_CONTRACT.address, 10_000 * 10 ** 18, {"from": ADMIN})

    beneficiaries = [USER1.address, USER2.address]
    amounts = [1500 * 10 ** 18, 2500 * 10 ** 18]
    durations = [1500, 2500]
    start_dates = [chain.time() + 500, chain.time() + 1000]

    VESTING_CONTRACT.addMultipleVestingSchedules(
        beneficiaries,
        amounts,
        durations,
        start_dates,
        {"from": SCHEDULE_MANAGER},
    )

    # Verify schedules for USER1
    schedules_user1 = VESTING_CONTRACT.getVestingSchedules(USER1.address)
    assert len(schedules_user1) == 1
    assert schedules_user1[0][0] == amounts[0]
    assert schedules_user1[0][1] == 0
    assert schedules_user1[0][2] == durations[0]
    assert schedules_user1[0][3] == start_dates[0]

    # Verify schedules for USER2
    schedules_user2 = VESTING_CONTRACT.getVestingSchedules(USER2.address)
    assert len(schedules_user2) == 1
    assert schedules_user2[0][0] == amounts[1]
    assert schedules_user2[0][1] == 0
    assert schedules_user2[0][2] == durations[1]
    assert schedules_user2[0][3] == start_dates[1]

    # Attempt to add multiple schedules with mismatched array lengths
    with pytest.raises(exceptions.VirtualMachineError, match="MismatchedArrayLengths"):
        VESTING_CONTRACT.addMultipleVestingSchedules(
            [USER1.address],
            [1000 * 10 ** 18, 2000 * 10 ** 18],
            [1000],
            [chain.time()],
            {"from": SCHEDULE_MANAGER},
        )


def test_add_vesting_schedule_invalid_inputs(VESTING_CONTRACT_WITHOUT_START_DATE, ADMIN, chain):
    beneficiary = accounts[4]
    amount = 0
    duration = 1000
    start_date = chain.time() + 500

    # Attempt to add schedule with zero amount
    with pytest.raises(exceptions.VirtualMachineError, match="TotalAmountMustBeGreaterThanZero"):
        VESTING_CONTRACT_WITHOUT_START_DATE.addVestingSchedule(
            beneficiary.address, amount, duration, start_date, {"from": ADMIN}
        )

    # Attempt to add schedule with zero duration
    with pytest.raises(exceptions.VirtualMachineError, match="DurationMustBeGreaterThanZero"):
        VESTING_CONTRACT_WITHOUT_START_DATE.addVestingSchedule(
            beneficiary.address, 1000 * 10 ** 18, 0, start_date, {"from": ADMIN}
        )

    # Attempt to add schedule with zero address
    with pytest.raises(exceptions.VirtualMachineError, match="InvalidRecipientAddress"):
        VESTING_CONTRACT_WITHOUT_START_DATE.addVestingSchedule(
            "0x0000000000000000000000000000000000000000", 1000 * 10 ** 18, duration, start_date, {"from": ADMIN}
        )


def test_set_vesting_start_date(VESTING_CONTRACT_WITHOUT_START_DATE, ADMIN, chain):
    new_start_date = chain.time() + 2000

    # Attempt to set vesting start date in the past
    with pytest.raises(exceptions.VirtualMachineError, match="VestingStartDateCannotBeInThePast"):
        VESTING_CONTRACT_WITHOUT_START_DATE.setVestingStartDate(chain.time() - 100, {"from": ADMIN})
        


    # Attempt to set vesting start date from non-admin account
    with pytest.raises(exceptions.VirtualMachineError, match="AccessControl"):
        VESTING_CONTRACT_WITHOUT_START_DATE.setVestingStartDate(chain.time() + 3000, {"from": accounts[4]})
        
    # Set vesting start date
    VESTING_CONTRACT_WITHOUT_START_DATE.setVestingStartDate(new_start_date, {"from": ADMIN})
    assert VESTING_CONTRACT_WITHOUT_START_DATE.vestingStartDate() == new_start_date
    
    # Attempt to set vesting start date again
    with pytest.raises(exceptions.VirtualMachineError, match="VestingStartDateAlreadySet"):
        VESTING_CONTRACT_WITHOUT_START_DATE.setVestingStartDate(new_start_date + 1000, {"from": ADMIN})


def test_claim_vested_tokens(VESTING_CONTRACT, SCHEDULE_MANAGER, ADMIN, SOPHTOKEN, USER1, chain):
    # Add vesting schedule
    SOPHTOKEN.mint(VESTING_CONTRACT.address, 10_000 * 10 ** 18, {"from": ADMIN})

    start_date = chain.time()
    duration = 6050000  # seconds - ~10 weeks
    amount = 1000 * 10 ** 18

    VESTING_CONTRACT.addVestingSchedule(USER1.address, amount, duration, start_date, {"from": SCHEDULE_MANAGER})
    schedule = VESTING_CONTRACT.getVestingSchedules(USER1.address)
    start_date = schedule[0][3]
    # Fast forward half the duration
    vesting_half_date = start_date + duration//2
    chain.sleep(vesting_half_date - chain.time() - 1)
    chain.mine()


    # Expected vested amount: half
    expected_vested = amount // 2

    # USER1 claims tokens
    initial_balance = SOPHTOKEN.balanceOf(USER1.address)
    initial_vsoph = VESTING_CONTRACT.balanceOf(USER1.address)

    tx = VESTING_CONTRACT.releaseSpecificSchedules([0], False, {"from": USER1})

    assert "TokensReleased" in tx.events
    event = tx.events["TokensReleased"]
    assert event["beneficiary"] == USER1.address
    assert abs(event["netAmount"] - expected_vested) < 0.01e18
    assert event["penaltyAmount"] == 0

    # Check SOPH balance
    assert abs(SOPHTOKEN.balanceOf(USER1.address) - (initial_balance + expected_vested)) < 0.01e18

    # Check vSOPH balance
    assert abs(VESTING_CONTRACT.balanceOf(USER1.address) - (initial_vsoph - expected_vested)) < 0.01e18

    # Check released amount in schedule
    schedules = VESTING_CONTRACT.getVestingSchedules(USER1.address)
    assert abs(schedules[0][1] - expected_vested) < 0.01e18


def test_claim_before_vesting_start(VESTING_CONTRACT, SCHEDULE_MANAGER, ADMIN, SOPHTOKEN, USER1, chain):
    # Add vesting schedule with future start date
    SOPHTOKEN.mint(VESTING_CONTRACT.address, 1000 * 10 ** 18, {"from": ADMIN})

    start_date = chain.time() + 1000  # Vesting starts in the future
    duration = 1000
    amount = 1000 * 10 ** 18

    VESTING_CONTRACT.addVestingSchedule(USER1.address, amount, duration, start_date, {"from": SCHEDULE_MANAGER})

    # Attempt to claim before vesting start
    with pytest.raises(exceptions.VirtualMachineError, match="VestingHasNotStartedYet"):
        VESTING_CONTRACT.releaseSpecificSchedules([0], True, {"from": USER1})


def test_claim_no_releasable_tokens(VESTING_CONTRACT, SCHEDULE_MANAGER, ADMIN, SOPHTOKEN, USER1, chain):
    # Add vesting schedule
    SOPHTOKEN.mint(VESTING_CONTRACT.address, 1000 * 10 ** 18, {"from": ADMIN})

    start_date = chain.time() - 1500  # Vesting started 1500 seconds ago
    duration = 1000  # seconds
    amount = 1000 * 10 ** 18

    VESTING_CONTRACT.addVestingSchedule(USER1.address, amount, duration, start_date, {"from": SCHEDULE_MANAGER})

    # Fast forward time beyond vesting duration
    chain.sleep(1500)
    chain.mine()

    # USER1 claims tokens
    tx = VESTING_CONTRACT.releaseSpecificSchedules([0], True, {"from": USER1})
    assert "TokensReleased" in tx.events
    event = tx.events["TokensReleased"]
    assert event["netAmount"] == amount
    assert event["penaltyAmount"] == 0

    # Attempt to claim again should fail
    with pytest.raises(exceptions.VirtualMachineError, match="NoTokensToRelease"):
        VESTING_CONTRACT.releaseSpecificSchedules([0], True, {"from": USER1})


def test_claim_with_penalty(VESTING_CONTRACT, SCHEDULE_MANAGER, ADMIN, SOPHTOKEN, PENALTY_RECIPIENT, USER1, chain):
    # Add vesting schedule
    SOPHTOKEN.mint(VESTING_CONTRACT.address, 2000 * 10 ** 18, {"from": ADMIN})

    start_date = chain.time() - 500  # Vesting started 500 seconds ago
    duration = 1000  # seconds
    amount = 1000 * 10 ** 18

    VESTING_CONTRACT.addVestingSchedule(USER1.address, amount, duration, start_date, {"from": SCHEDULE_MANAGER})
    schedule = VESTING_CONTRACT.getVestingSchedules(USER1.address)
    start_date = schedule[0][3]
    # Fast forward time by 500 seconds
    vesting_half_date = start_date + duration//2
    chain.sleep(vesting_half_date - chain.time() - 1)
    chain.mine()

    # USER1 claims with penalty
    initial_user_balance = SOPHTOKEN.balanceOf(USER1.address)
    initial_penalty_balance = SOPHTOKEN.balanceOf(PENALTY_RECIPIENT.address)
    initial_vsoph = VESTING_CONTRACT.balanceOf(USER1.address)
    schedule = VESTING_CONTRACT.getVestingSchedules(USER1.address)
    ct = chain.time()
    
    tx = VESTING_CONTRACT.releaseSpecificSchedules([0], True, {"from": USER1})
    assert "TokensReleased" in tx.events
    event = tx.events["TokensReleased"]

    # Calculate expected values
    # Vested: (1000 * 500) / 1000 = 500
    # Unvested: 1000 - 500 = 500
    # Penalty: 50% of 500 = 250
    # Net to user: 500 + (500 - 250) = 750
    # Penalty sent: 250
    assert event["netAmount"] == 750 * 10 ** 18
    assert event["penaltyAmount"] == 250 * 10 ** 18
    assert "PenaltyPaid" in tx.events
    penalty_event = tx.events["PenaltyPaid"]
    assert penalty_event["beneficiary"] == USER1.address
    assert penalty_event["penaltyAmount"] == 250 * 10 ** 18

    # Check SOPH balance
    assert SOPHTOKEN.balanceOf(USER1.address) == initial_user_balance + 750 * 10 ** 18
    assert SOPHTOKEN.balanceOf(PENALTY_RECIPIENT.address) == initial_penalty_balance + 250 * 10 ** 18

    # Check vSOPH balance
    assert VESTING_CONTRACT.balanceOf(USER1.address) == initial_vsoph - (750 + 250) * 10 ** 18

    # Check released amount in schedule
    schedules = VESTING_CONTRACT.getVestingSchedules(USER1.address)
    assert schedules[0][1] == 1000 * 10 ** 18  # Entire amount released


def test_set_penalty_recipient(VESTING_CONTRACT, ADMIN, USER1):
    new_recipient = USER1
    VESTING_CONTRACT.setPenaltyRecipient(new_recipient.address, {"from": ADMIN})
    assert VESTING_CONTRACT.penaltyRecipient() == new_recipient.address

    # Attempt to set penalty recipient to zero address
    with pytest.raises(exceptions.VirtualMachineError, match="InvalidRecipientAddress"):
        VESTING_CONTRACT.setPenaltyRecipient("0x0000000000000000000000000000000000000000", {"from": ADMIN})


def test_set_penalty_percentage(VESTING_CONTRACT, ADMIN):
    VESTING_CONTRACT.setPenaltyPercentage(30, {"from": ADMIN})
    assert VESTING_CONTRACT.penaltyPercentage() == 30

    # Attempt to set penalty percentage above 100%
    with pytest.raises(exceptions.VirtualMachineError, match="PenaltyMustBeLessThanOrEqualTo100Percent"):
        VESTING_CONTRACT.setPenaltyPercentage(150, {"from": ADMIN})


def test_vested_amount_calculation(VESTING_CONTRACT, SCHEDULE_MANAGER, ADMIN, SOPHTOKEN, USER1, chain):
    # Add vesting schedule
    SOPHTOKEN.mint(VESTING_CONTRACT.address, 3000 * 10 ** 18, {"from": ADMIN})

    start_date = chain.time()
    duration = 2000  # seconds
    amount = 2000 * 10 ** 18

    VESTING_CONTRACT.addVestingSchedule(USER1.address, amount, duration, start_date, {"from": SCHEDULE_MANAGER})
    schedule = VESTING_CONTRACT.getVestingSchedules(USER1.address)
    start_date = schedule[0][3]

    vested = VESTING_CONTRACT.vestedAmount(USER1.address)
    expected_vested = 0
    assert vested == expected_vested

    # Fast forward to half of the duration
    vesting_half_date = start_date + duration//2
    chain.sleep(vesting_half_date - chain.time())
    chain.mine()

    vested = VESTING_CONTRACT.vestedAmount(USER1.address)
    assert abs(vested - amount // 2) < 0.01e18

    # Fast forward to end of vesting
    chain.sleep(start_date + duration - chain.time())
    chain.mine()
    vested = VESTING_CONTRACT.vestedAmount(USER1.address)
    assert abs(vested - amount) < 0.01e18


def test_releasable_amount_calculation(VESTING_CONTRACT, SCHEDULE_MANAGER, ADMIN, SOPHTOKEN, USER1, chain):
    # Add vesting schedule
    SOPHTOKEN.mint(VESTING_CONTRACT.address, 3000 * 10 ** 18, {"from": ADMIN})

    start_date = chain.time()
    duration = 1000  # seconds
    amount = 1000 * 10 ** 18

    VESTING_CONTRACT.addVestingSchedule(USER1.address, amount, duration, start_date, {"from": SCHEDULE_MANAGER})
    schedule = VESTING_CONTRACT.getVestingSchedules(USER1.address)
    start_date = schedule[0][3]
    # Fast forward half the duration
    vesting_half_date = start_date + duration//2
    chain.sleep(vesting_half_date - chain.time())
    chain.mine()

    # Check releasable amount
    releasable = VESTING_CONTRACT.releasableAmount(USER1.address)
    expected_releasable = amount // 2
    assert abs(releasable - expected_releasable) <= 0.01e18

    # Claim half
    tx = VESTING_CONTRACT.releaseSpecificSchedules([0], False, {"from": USER1})

    # Releasable should now be zero
    releasable = VESTING_CONTRACT.releasableAmount(USER1.address)
    assert releasable == 0

    # Fast forward to end of vesting
    chain.sleep(duration//2)
    chain.mine()

    # Releasable should now be half again (500)
    released = tx.events["TokensReleased"]["netAmount"]
    releasable = VESTING_CONTRACT.releasableAmount(USER1.address)
    assert abs(released + releasable  - amount ) <= 0


def test_rescue_tokens(VESTING_CONTRACT, SOPHTOKEN, ADMIN, USER1):
    # Transfer some tokens to the vesting contract
    SOPHTOKEN.mint(VESTING_CONTRACT.address, 500 * 10 ** 18, {"from": ADMIN})

    # Rescue tokens as admin
    VESTING_CONTRACT.rescue(SOPHTOKEN.address, USER1.address, {"from": ADMIN})
    assert SOPHTOKEN.balanceOf(USER1.address) == 500 * 10 ** 18
    assert SOPHTOKEN.balanceOf(VESTING_CONTRACT.address) == 0

    # Attempt to rescue from non-admin account
    with pytest.raises(exceptions.VirtualMachineError, match="AccessControlUnauthorizedAccount"):
        VESTING_CONTRACT.rescue(SOPHTOKEN.address, USER1.address, {"from": accounts[9]})

    # Attempt to rescue to zero address
    with pytest.raises(exceptions.VirtualMachineError, match="InvalidRecipientAddress"):
        VESTING_CONTRACT.rescue(SOPHTOKEN.address, "0x0000000000000000000000000000000000000000", {"from": ADMIN})


def test_transfer_vesting_schedules(VESTING_CONTRACT, ADMIN, SOPHTOKEN, USER1, USER2, chain):
    # Add vesting schedule to USER1
    SOPHTOKEN.mint(VESTING_CONTRACT.address, 2000 * 10 ** 18, {"from": ADMIN})

    start_date = chain.time() - 500
    duration = 1000
    amount = 1000 * 10 ** 18

    VESTING_CONTRACT.addVestingSchedule(USER1.address, amount, duration, start_date, {"from": ADMIN})

    # Admin transfers beneficiary from USER1 to USER2
    VESTING_CONTRACT.adminTransfer(USER1.address, USER2.address, {"from": ADMIN})

    # Verify vesting schedules are transferred to USER2
    schedules_user2 = VESTING_CONTRACT.getVestingSchedules(USER2.address)
    assert len(schedules_user2) == 1
    assert schedules_user2[0][0] == amount
    assert schedules_user2[0][1] == 0
    assert schedules_user2[0][2] == duration

    # Verify that USER1 no longer has the vesting schedule
    schedules_user1 = VESTING_CONTRACT.getVestingSchedules(USER1.address)
    assert len(schedules_user1) == 0

    # Check vSOPH balance transferred
    vsoph_balance_user1 = VESTING_CONTRACT.balanceOf(USER1.address)
    vsoph_balance_user2 = VESTING_CONTRACT.balanceOf(USER2.address)
    assert vsoph_balance_user1 == 0
    assert vsoph_balance_user2 == amount


def test_get_vesting_schedules_in_range(VESTING_CONTRACT, SCHEDULE_MANAGER, ADMIN, SOPHTOKEN, USER1, chain):
    # Add multiple vesting schedules
    SOPHTOKEN.mint(VESTING_CONTRACT.address, 5000 * 10 ** 18, {"from": ADMIN})

    start_date = chain.time()
    duration = 1000
    amount = 1000 * 10 ** 18

    # Add multiple schedules
    for _ in range(5):
        VESTING_CONTRACT.addVestingSchedule(USER1.address, amount, duration, start_date, {"from": SCHEDULE_MANAGER})

    # Get schedules in range
    schedules = VESTING_CONTRACT.getVestingSchedulesInRange(USER1.address, 1, 4)
    assert len(schedules) == 3
    for schedule in schedules:
        assert schedule[0] == amount
        assert schedule[1] == 0
        assert schedule[2] == duration

    # Attempt to get schedules with invalid range
    with pytest.raises(exceptions.VirtualMachineError, match="InvalidRange"):
        VESTING_CONTRACT.getVestingSchedulesInRange(USER1.address, 4, 2)

    with pytest.raises(exceptions.VirtualMachineError, match="InvalidRange"):
        VESTING_CONTRACT.getVestingSchedulesInRange(USER1.address, 0, 10)


def test_claim_multiple_schedules(VESTING_CONTRACT, SCHEDULE_MANAGER, ADMIN, SOPHTOKEN, USER1, chain):
    # Add multiple vesting schedules
    SOPHTOKEN.mint(VESTING_CONTRACT.address, 50000 * 10 ** 18, {"from": ADMIN})

    start_date = chain.time() - 1000
    duration = 2000
    amount = 2000 * 10 ** 18

    # Add multiple schedules
    for _ in range(3):
        VESTING_CONTRACT.addVestingSchedule(USER1.address, amount, duration, start_date, {"from": SCHEDULE_MANAGER})

    # Fast forward time
    chain.sleep(3000)
    chain.mine()

    # USER1 claims multiple schedules
    initial_balance = SOPHTOKEN.balanceOf(USER1.address)
    initial_vsoph = VESTING_CONTRACT.balanceOf(USER1.address)

    # Calculate expected releasable: (2000 * 1000) / 2000 = 1000 per schedule
    expected_releasable = amount * 3

    tx = VESTING_CONTRACT.releaseSpecificSchedules([0, 1, 2], False, {"from": USER1})

    # Sum net amounts from events
    total_net_amount = sum(event["netAmount"] for event in tx.events["TokensReleased"])
    total_penalty_amount = sum(event["penaltyAmount"] for event in tx.events["TokensReleased"])

    assert total_net_amount == expected_releasable
    assert total_penalty_amount == 0

    # Check SOPH balance
    assert SOPHTOKEN.balanceOf(USER1.address) == initial_balance + expected_releasable

    # Check vSOPH balance
    assert VESTING_CONTRACT.balanceOf(USER1.address) == initial_vsoph - expected_releasable

    # Check released amounts in schedules
    schedules = VESTING_CONTRACT.getVestingSchedules(USER1.address)
    for schedule in schedules:
        assert schedule[1] ==  amount  # released


def test_claim_specific_schedules_with_penalty_multiple(VESTING_CONTRACT, SCHEDULE_MANAGER, ADMIN, SOPHTOKEN, PENALTY_RECIPIENT, USER1, chain):
    # Add multiple vesting schedules
    SOPHTOKEN.mint(VESTING_CONTRACT.address, 8000 * 10 ** 18, {"from": ADMIN})

    start_date = chain.time() - 1000
    duration = 2000
    amount = 2000 * 10 ** 18

    # Add multiple schedules
    for _ in range(4):
        VESTING_CONTRACT.addVestingSchedule(USER1.address, amount, duration, start_date, {"from": SCHEDULE_MANAGER})
        
    schedules = VESTING_CONTRACT.getVestingSchedules(USER1.address)
    start_date = schedules[0][3]
    # Fast forward time
    vesting_half_date = start_date + duration//2
    chain.sleep(vesting_half_date - chain.time() - 1)
    chain.mine()

    # USER1 claims specific schedules with penalty
    # Let's claim schedules 0 and 2
    initial_user_balance = SOPHTOKEN.balanceOf(USER1.address)
    initial_penalty_balance = SOPHTOKEN.balanceOf(PENALTY_RECIPIENT.address)
    initial_vsoph = VESTING_CONTRACT.balanceOf(USER1.address)

    tx = VESTING_CONTRACT.releaseSpecificSchedules([0, 2], True, {"from": USER1})

    # Sum net amounts and penalties from events
    total_net_amount = sum(event["netAmount"] for event in tx.events["TokensReleased"])
    total_penalty_amount = sum(event["penaltyAmount"] for event in tx.events["TokensReleased"])

    assert total_net_amount == 3000 * 10 ** 18
    assert total_penalty_amount == 1000 * 10 ** 18

    # Check SOPH balance
    assert SOPHTOKEN.balanceOf(USER1.address) == initial_user_balance + total_net_amount
    assert SOPHTOKEN.balanceOf(PENALTY_RECIPIENT.address) == initial_penalty_balance + total_penalty_amount

    # Check vSOPH balance
    assert VESTING_CONTRACT.balanceOf(USER1.address) == initial_vsoph - (total_net_amount + total_penalty_amount)

    # Check released amounts in schedules
    schedules = VESTING_CONTRACT.getVestingSchedules(USER1.address)
    for i, schedule in enumerate(schedules):
        if i in [0, 2]:
            assert schedule[1] == 2000 * 10 ** 18  # Entire amount released
        else:
            # Since we didn't claim schedules 1 and 3, their released amount should remain at vested amount
            assert schedule[1] == 0

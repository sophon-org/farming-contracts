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
    return MockERC20.deploy("Mock SOPH Token", "MockeSOPH", 18, {"from": ADMIN})


@pytest.fixture
def VESTING_CONTRACT(ADMIN, SOPHTOKEN, PENALTY_RECIPIENT, LinearVestingWithPenalty, chain):
    vSOPH =  LinearVestingWithPenalty.deploy({"from": ADMIN})
    vSOPH.initialize( 
        SOPHTOKEN.address,
        ADMIN.address,
        PENALTY_RECIPIENT.address,
        50,  # 50% penalty
        {"from": ADMIN}
    )
    vSOPH.setVestingStartDate(chain.time()+100, {"from": ADMIN})
    
    return vSOPH

@pytest.fixture
def VESTING_CONTRACT_WITHOUT_START_DATE(ADMIN, SOPHTOKEN, PENALTY_RECIPIENT, LinearVestingWithPenalty, chain):
    vSOPH =  LinearVestingWithPenalty.deploy({"from": ADMIN})
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

@pytest.fixture(autouse=True)
def inject_chain(chain):
    # Any setup code if needed
    yield chain
    
# @pytest.fixture(autouse=True)
# def DEPLOY_VESTING_SCHEDULE(ADMIN, SCHEDULE_MANAGER, VESTING_CONTRACT, SOPHTOKEN, USER1, chain):
#     # Mint SOPH tokens to the vesting contract
#     SOPHTOKEN.mint(VESTING_CONTRACT.address, 10_000 * 10 ** 18, {"from": ADMIN})

#     # Add a vesting schedule for USER1
#     start_date = chain.time() + 100  # Vesting starts in 100 seconds
#     VESTING_CONTRACT.addVestingSchedule(
#         USER1.address, 1000 * 10 ** 18, 1000, start_date, {"from": SCHEDULE_MANAGER}
#     )
#     return


def test_initialization(VESTING_CONTRACT, SOPHTOKEN, ADMIN, PENALTY_RECIPIENT, SCHEDULE_MANAGER, UPGRADER):
    assert VESTING_CONTRACT.sophtoken() == SOPHTOKEN.address
    assert VESTING_CONTRACT.penaltyRecipient() == PENALTY_RECIPIENT.address
    assert VESTING_CONTRACT.penaltyPercentage() == 50

    # Check roles
    assert VESTING_CONTRACT.hasRole(VESTING_CONTRACT.DEFAULT_ADMIN_ROLE(), ADMIN.address)
    assert VESTING_CONTRACT.hasRole(VESTING_CONTRACT.ADMIN_ROLE(), ADMIN.address)
    assert VESTING_CONTRACT.hasRole(VESTING_CONTRACT.SCHEDULE_MANAGER_ROLE(), SCHEDULE_MANAGER.address)
    assert VESTING_CONTRACT.hasRole(VESTING_CONTRACT.UPGRADER_ROLE(), UPGRADER.address)


def test_access_control_set_penalty_recipient(VESTING_CONTRACT, ADMIN, PENALTY_RECIPIENT, USER1):
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
    with pytest.raises(exceptions.VirtualMachineError, match="AccessControlUnauthorizedAccoun"):
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

@pytest.mark.order(1)
def test_add_vesting_schedule_invalid_inputs(VESTING_CONTRACT_WITHOUT_START_DATE, ADMIN, SOPHTOKEN, chain):
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

@pytest.mark.order(-1)
def test_set_vesting_start_date(VESTING_CONTRACT_WITHOUT_START_DATE, ADMIN, chain):
    new_start_date = chain.time() + 2000

    # Set vesting start date
    VESTING_CONTRACT_WITHOUT_START_DATE.setVestingStartDate(new_start_date, {"from": ADMIN})
    assert VESTING_CONTRACT_WITHOUT_START_DATE.vestingStartDate() == new_start_date

    # Attempt to set vesting start date again
    with pytest.raises(exceptions.VirtualMachineError, match="VestingStartDateAlreadySet"):
        VESTING_CONTRACT_WITHOUT_START_DATE.setVestingStartDate(new_start_date + 1000, {"from": ADMIN})

    # Attempt to set vesting start date in the past
    with pytest.raises(exceptions.VirtualMachineError, match="VestingStartDateCannotBeInThePast"):
        VESTING_CONTRACT_WITHOUT_START_DATE.setVestingStartDate(chain.time() - 100, {"from": ADMIN})

    # Attempt to set vesting start date from non-schedule_manager account
    with pytest.raises(exceptions.VirtualMachineError, match="AccessControl"):
        VESTING_CONTRACT_WITHOUT_START_DATE.setVestingStartDate(chain.time() + 3000, {"from": accounts[4]})


def test_claim_vested_tokens(VESTING_CONTRACT, SCHEDULE_MANAGER, ADMIN, SOPHTOKEN, USER1, chain):
    # Grant roles and add vesting schedule
    VESTING_CONTRACT.grantRole(
        VESTING_CONTRACT.SCHEDULE_MANAGER_ROLE(), SCHEDULE_MANAGER.address, {"from": ADMIN}
    )
    SOPHTOKEN.mint(VESTING_CONTRACT.address, 10_000 * 10 ** 18, {"from": ADMIN})

    start_date = chain.time()
    duration = 6050000  # seconds - ~10 week
    amount = 1000 * 10 ** 18

    VESTING_CONTRACT.addVestingSchedule(USER1.address, amount, duration, start_date, {"from": SCHEDULE_MANAGER})
    schedule = VESTING_CONTRACT.getVestingSchedules(USER1.address)
    start_date = VESTING_CONTRACT.getVestingSchedules(USER1.address)[0][3]
    
    # Mint enough SOPH tokens to the contract for transfer
    SOPHTOKEN.mint(VESTING_CONTRACT.address, 1000 * 10 ** 18, {"from": ADMIN})
    
    
    b = chain.time()
    # Fast forward sleep half the time
    d = int(duration /2)
    d1 = start_date+int(duration/2) - chain.time()
    chain.sleep(d1)
    chain.mine()

    # Expected vested amount: half in half time
    expected_vested = int(amount/2)

    

    # USER1 claims tokens
    initial_balance = SOPHTOKEN.balanceOf(USER1.address)
    initial_vsoph = VESTING_CONTRACT.balanceOf(USER1.address)

    r = VESTING_CONTRACT.releasableAmount(USER1.address)
    ct = chain.time()
    tx = VESTING_CONTRACT.releaseSpecificSchedules([0], False, {"from": USER1})
    
    assert "TokensReleased" in tx.events
    assert tx.events["TokensReleased"]["beneficiary"] == USER1.address
    assert abs(tx.events["TokensReleased"]["netAmount"] - expected_vested) < 0.01e18
    assert tx.events["TokensReleased"]["penaltyAmount"] == 0

    # Check SOPH balance
    assert abs(SOPHTOKEN.balanceOf(USER1.address) - (initial_balance + expected_vested)) < 0.01e18

    # Check vSOPH balance
    assert abs(VESTING_CONTRACT.balanceOf(USER1.address) - (initial_vsoph - expected_vested))< 0.01e18

    # Check released amount in schedule
    schedules = VESTING_CONTRACT.getVestingSchedules(USER1.address)
    assert abs(schedules[0][1] - expected_vested) < 0.01e18


def test_claim_before_vesting_start(VESTING_CONTRACT, SCHEDULE_MANAGER, ADMIN, SOPHTOKEN, USER1, chain):
    # Grant roles and add vesting schedule with future start date
    VESTING_CONTRACT.grantRole(
        VESTING_CONTRACT.SCHEDULE_MANAGER_ROLE(), SCHEDULE_MANAGER.address, {"from": ADMIN}
    )
    SOPHTOKEN.mint(VESTING_CONTRACT.address, 1000 * 10 ** 18, {"from": ADMIN})

    start_date = chain.time() + 1000  # Vesting starts in the future
    duration = 1000
    amount = 1000 * 10 ** 18

    VESTING_CONTRACT.addVestingSchedule(USER1.address, amount, duration, start_date, {"from": SCHEDULE_MANAGER})

    # Attempt to claim before vesting start
    with pytest.raises(exceptions.VirtualMachineError, match="VestingHasNotStartedYet"):
        VESTING_CONTRACT.releaseSpecificSchedules([0], True, {"from": USER1})


def test_claim_no_releasable_tokens(VESTING_CONTRACT, SCHEDULE_MANAGER, ADMIN, SOPHTOKEN, USER1, chain):
    # Grant roles and add vesting schedule
    VESTING_CONTRACT.grantRole(
        VESTING_CONTRACT.SCHEDULE_MANAGER_ROLE(), SCHEDULE_MANAGER.address, {"from": ADMIN}
    )
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
    assert tx.events["TokensReleased"]["netAmount"] == amount
    assert tx.events["TokensReleased"]["penaltyAmount"] == 0

    # Attempt to claim again should fail
    with pytest.raises(exceptions.VirtualMachineError, match="NoTokensToRelease"):
        VESTING_CONTRACT.releaseSpecificSchedules([0], True, {"from": USER1})


def test_claim_with_penalty(VESTING_CONTRACT, SCHEDULE_MANAGER, ADMIN, SOPHTOKEN, PENALTY_RECIPIENT, USER1, chain):
    # Grant roles and add vesting schedule

    SOPHTOKEN.mint(VESTING_CONTRACT.address, 2000 * 10 ** 18, {"from": ADMIN})

    start_date = chain.time() - 500  # Vesting started 500 seconds ago
    duration = 1000  # seconds
    amount = 1000 * 10 ** 18

    VESTING_CONTRACT.addVestingSchedule(USER1.address, amount, duration, start_date, {"from": SCHEDULE_MANAGER})
    start_date = VESTING_CONTRACT.getVestingSchedules(USER1.address)[0][3]
    ate = VESTING_CONTRACT.getVestingSchedules(USER1.address)[0][3]+duration/2
    sc = VESTING_CONTRACT.getVestingSchedules(USER1.address)
    # Fast forward time by 500 seconds
    chain.mine()
    chain.sleep(ate-chain.time()-1)

    chain.mine()

    # USER1 claims with penalty
    initial_user_balance = SOPHTOKEN.balanceOf(USER1.address)
    initial_penalty_balance = SOPHTOKEN.balanceOf(PENALTY_RECIPIENT.address)
    initial_vsoph = VESTING_CONTRACT.balanceOf(USER1.address)

    at = chain.time()
    tx = VESTING_CONTRACT.releaseSpecificSchedules([0], True, {"from": USER1})
    assert "TokensReleased" in tx.events
    assert tx.events["TokensReleased"]["beneficiary"] == USER1.address

    # Calculate expected values
    # Vested: (1000 * 500) / 1000 = 500
    # Unvested: 1000 - 500 = 500
    # Penalty: 50% of 500 = 250
    # Net to user: 500 + (500 - 250) = 750
    # Penalty sent: 250
    assert tx.events["TokensReleased"]["netAmount"] == 750 * 10 ** 18
    assert tx.events["TokensReleased"]["penaltyAmount"] == 250 * 10 ** 18
    assert "PenaltyPaid" in tx.events
    assert tx.events["PenaltyPaid"]["beneficiary"] == USER1.address
    assert tx.events["PenaltyPaid"]["penaltyAmount"] == 250 * 10 ** 18

    # Check SOPH balance
    assert SOPHTOKEN.balanceOf(USER1.address) == initial_user_balance + 750 * 10 ** 18
    assert SOPHTOKEN.balanceOf(PENALTY_RECIPIENT.address) == initial_penalty_balance + 250 * 10 ** 18

    # Check vSOPH balance
    assert VESTING_CONTRACT.balanceOf(USER1.address) == initial_vsoph - (750 + 250) * 10 ** 18

    # Check released amount in schedule
    schedules = VESTING_CONTRACT.getVestingSchedules(USER1.address)
    assert schedules[0][1] == 1000 * 10 ** 18  # Entire amount released


def test_set_penalty_recipient(VESTING_CONTRACT, ADMIN, USER1, chain):
    new_recipient = USER1
    VESTING_CONTRACT.setPenaltyRecipient(new_recipient.address, {"from": ADMIN})
    assert VESTING_CONTRACT.penaltyRecipient() == new_recipient.address

    # Attempt to set penalty recipient to zero address
    with pytest.raises(exceptions.VirtualMachineError, match="InvalidRecipientAddress"):
        VESTING_CONTRACT.setPenaltyRecipient("0x0000000000000000000000000000000000000000", {"from": ADMIN})


def test_set_penalty_percentage(VESTING_CONTRACT, ADMIN, chain):
    VESTING_CONTRACT.setPenaltyPercentage(30, {"from": ADMIN})
    assert VESTING_CONTRACT.penaltyPercentage() == 30

    # Attempt to set penalty percentage above 100%
    with pytest.raises(exceptions.VirtualMachineError, match="PenaltyMustBeLessThanOrEqualTo100Percent"):
        VESTING_CONTRACT.setPenaltyPercentage(150, {"from": ADMIN})


def test_vested_amount_calculation(VESTING_CONTRACT, SCHEDULE_MANAGER, ADMIN, SOPHTOKEN, USER1, chain):
    # Grant roles and add vesting schedule
    VESTING_CONTRACT.grantRole(
        VESTING_CONTRACT.SCHEDULE_MANAGER_ROLE(), SCHEDULE_MANAGER.address, {"from": ADMIN}
    )
    SOPHTOKEN.mint(VESTING_CONTRACT.address, 3000 * 10 ** 18, {"from": ADMIN})

    start_date = chain.time()
    duration = 2000  # seconds
    amount = 2000 * 10 ** 18

    VESTING_CONTRACT.addVestingSchedule(USER1.address, amount, duration, start_date, {"from": SCHEDULE_MANAGER})

    # Check vested amount at different times
    # Immediately after vesting start
    vested = VESTING_CONTRACT.vestedAmount(USER1.address)
    expected_vested = 0
    assert vested == expected_vested


    # Fast forward to end of vesting
    s = (start_date+duration/2) - chain.time()
    d = chain.time()
    chain.sleep(int(start_date+duration/2) - chain.time())
    
    chain.mine()
    b = chain.time()
    a = VESTING_CONTRACT.getVestingSchedules(USER1.address)[0][3] - chain.time()
    vested = VESTING_CONTRACT.vestedAmount(USER1.address)
    assert abs(vested - amount/2) < 0
    
    
    chain.sleep(1000)
    chain.mine()
    vested = VESTING_CONTRACT.vestedAmount(USER1.address)
    assert abs(vested - amount) < 0


def test_releasable_amount_calculation(VESTING_CONTRACT, SCHEDULE_MANAGER, ADMIN, SOPHTOKEN, USER1, chain):
    # Grant roles and add vesting schedule
    VESTING_CONTRACT.grantRole(
        VESTING_CONTRACT.SCHEDULE_MANAGER_ROLE(), SCHEDULE_MANAGER.address, {"from": ADMIN}
    )
    SOPHTOKEN.mint(VESTING_CONTRACT.address, 3000 * 10 ** 18, {"from": ADMIN})
    
    start_date = chain.time()  # Vesting started 500 seconds ago
    duration = 1000  # seconds
    amount = 1000 * 10 ** 18

    
    tx = VESTING_CONTRACT.addVestingSchedule(USER1.address, amount, duration, start_date, {"from": SCHEDULE_MANAGER})
    start_date = VESTING_CONTRACT.getVestingSchedules(USER1.address)[0][3]
    ate = start_date+int(duration/2)- chain.time()
    chain.sleep(ate-1) 
    chain.mine()
    at = chain.time()
    atec = VESTING_CONTRACT.getTime()
    attx = VESTING_CONTRACT.vv(USER1.address, {"from": USER1.address})
    # Check releasable amount
    releasable = VESTING_CONTRACT.releasableAmount(USER1.address)
    expected_releasable = int(amount /2)
    assert abs(releasable - expected_releasable) <= 0

    # Claim half
    SOPHTOKEN.mint(VESTING_CONTRACT.address, 1000 * 10 ** 18, {"from": ADMIN})
    VESTING_CONTRACT.releaseSpecificSchedules([0], False, {"from": USER1})

    # Releasable should now be zero
    releasable = VESTING_CONTRACT.releasableAmount(USER1.address)
    assert releasable == 0

    # Fast forward to end of vesting
    chain.sleep(600)
    chain.mine()

    # Releasable should now be half again (500)
    releasable = VESTING_CONTRACT.releasableAmount(USER1.address)
    assert abs(releasable - int(amount/2)) <= 0


def test_rescue_tokens(VESTING_CONTRACT, SOPHTOKEN, ADMIN, USER1, chain):
    # Transfer some tokens to the vesting contract
    SOPHTOKEN.mint(VESTING_CONTRACT.address, 500 * 10 ** 18, {"from": ADMIN})

    # Rescue tokens as admin
    VESTING_CONTRACT.rescue(SOPHTOKEN.address, USER1.address, {"from": ADMIN})
    assert SOPHTOKEN.balanceOf(USER1.address) == 500 * 10 ** 18
    assert SOPHTOKEN.balanceOf(VESTING_CONTRACT.address) == 0

    # Attempt to rescue from non-admin account
    with reverts("AccessControl"):
        VESTING_CONTRACT.rescue(SOPHTOKEN.address, USER1.address, {"from": accounts[4]})

    # Attempt to rescue to zero address
    with reverts("InvalidRecipientAddress"):
        VESTING_CONTRACT.rescue(SOPHTOKEN.address, "0x0000000000000000000000000000000000000000", {"from": ADMIN})


def test_upgradeability_preserve_state(VESTING_CONTRACT, UPGRADER, ADMIN, SOPHTOKEN, USER1, chain):
    # Grant roles and add a vesting schedule
    VESTING_CONTRACT.grantRole(
        VESTING_CONTRACT.SCHEDULE_MANAGER_ROLE(), ADMIN.address, {"from": ADMIN}
    )
    SOPHTOKEN.mint(VESTING_CONTRACT.address, 1000 * 10 ** 18, {"from": ADMIN})

    start_date = chain.time() - 500
    duration = 1000
    amount = 1000 * 10 ** 18

    VESTING_CONTRACT.addVestingSchedule(USER1.address, amount, duration, start_date, {"from": ADMIN})

    # Deploy new implementation
    new_impl = LinearVestingWithPenaltyV2.deploy({"from": UPGRADER})

    # Upgrade the contract
    VESTING_CONTRACT.upgradeTo(new_impl.address, {"from": UPGRADER})

    # Verify state is preserved
    schedules = VESTING_CONTRACT.getVestingSchedules(USER1.address)
    assert len(schedules) == 1
    assert schedules[0][0] == amount
    assert schedules[0][1] == 0
    assert schedules[0][2] == duration
    assert schedules[0][3] == start_date

    # Verify new function in V2
    version = VESTING_CONTRACT.getVersion()
    assert version == 2


def test_transfer_vesting_schedules(VESTING_CONTRACT, SCHEDULE_MANAGER, ADMIN, SOPHTOKEN, USER1, USER2, chain):
    # Grant roles and add vesting schedule to USER1
    VESTING_CONTRACT.grantRole(
        VESTING_CONTRACT.SCHEDULE_MANAGER_ROLE(), SCHEDULE_MANAGER.address, {"from": ADMIN}
    )
    SOPHTOKEN.mint(VESTING_CONTRACT.address, 2000 * 10 ** 18, {"from": ADMIN})

    start_date = chain.time() - 500
    duration = 1000
    amount = 1000 * 10 ** 18

    VESTING_CONTRACT.addVestingSchedule(USER1.address, amount, duration, start_date, {"from": SCHEDULE_MANAGER})

    # Mint vSOPH tokens to USER1
    VESTING_CONTRACT.mint(USER1.address, 1000 * 10 ** 18, {"from": ADMIN})

    # USER1 transfers vSOPH tokens to USER2
    VESTING_CONTRACT.transfer(USER2.address, 500 * 10 ** 18, {"from": USER1})

    # Verify vesting schedules are transferred to USER2
    schedules_user2 = VESTING_CONTRACT.getVestingSchedules(USER2.address)
    assert len(schedules_user2) == 1
    assert schedules_user2[0][0] == amount
    assert schedules_user2[0][1] == 0
    assert schedules_user2[0][2] == duration
    assert schedules_user2[0][3] == start_date

    # Verify that USER1 no longer has the vesting schedule
    schedules_user1 = VESTING_CONTRACT.getVestingSchedules(USER1.address)
    assert len(schedules_user1) == 0


def test_get_unclaimed_schedules_in_range(VESTING_CONTRACT, SCHEDULE_MANAGER, ADMIN, SOPHTOKEN, USER1, chain):
    # Grant roles and add multiple vesting schedules
    VESTING_CONTRACT.grantRole(
        VESTING_CONTRACT.SCHEDULE_MANAGER_ROLE(), SCHEDULE_MANAGER.address, {"from": ADMIN}
    )
    SOPHTOKEN.mint(VESTING_CONTRACT.address, 5000 * 10 ** 18, {"from": ADMIN})

    start_date = chain.time() - 1000
    duration = 2000
    amount = 1000 * 10 ** 18

    # Add multiple schedules
    for _ in range(5):
        VESTING_CONTRACT.addVestingSchedule(USER1.address, amount, duration, start_date, {"from": SCHEDULE_MANAGER})

    # Fast forward time
    chain.sleep(1000)
    chain.mine()

    # Get unclaimed schedules in range
    indexes, amounts = VESTING_CONTRACT.getUnclaimedSchedulesInRange(USER1.address, 1, 4)
    assert len(indexes) == 3
    assert len(amounts) == 3
    for idx, amt in zip(indexes, amounts):
        assert amt == (amount * 1000) // duration  # Vested amount per schedule


def test_get_vesting_schedules_in_range(VESTING_CONTRACT, SCHEDULE_MANAGER, ADMIN, SOPHTOKEN, USER1, chain):
    # Grant roles and add multiple vesting schedules
    VESTING_CONTRACT.grantRole(
        VESTING_CONTRACT.SCHEDULE_MANAGER_ROLE(), SCHEDULE_MANAGER.address, {"from": ADMIN}
    )
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
        assert schedule[3] == start_date

    # Attempt to get schedules with invalid range
    with pytest.raises(exceptions.VirtualMachineError, match="InvalidRange"):
        VESTING_CONTRACT.getVestingSchedulesInRange(USER1.address, 4, 2)

    with pytest.raises(exceptions.VirtualMachineError, match="InvalidRange"):
        VESTING_CONTRACT.getVestingSchedulesInRange(USER1.address, 0, 10)


def test_rescue_non_sophtoken(VESTING_CONTRACT, ADMIN, USER1, chain):
    # Deploy another mock token
    another_token = MockERC20.deploy("Another Token", "ATKN", 18, {"from": ADMIN})

    # Transfer some tokens to the vesting contract
    another_token.transfer(VESTING_CONTRACT.address, 1000 * 10 ** 18, {"from": ADMIN})

    # Rescue tokens as admin
    VESTING_CONTRACT.rescue(another_token.address, USER1.address, {"from": ADMIN})
    assert another_token.balanceOf(USER1.address) == 1000 * 10 ** 18
    assert another_token.balanceOf(VESTING_CONTRACT.address) == 0


def test_upgradeability_preserve_state(VESTING_CONTRACT, UPGRADER, ADMIN, SOPHTOKEN, USER1, chain):
    # Grant roles and add a vesting schedule
    VESTING_CONTRACT.grantRole(
        VESTING_CONTRACT.SCHEDULE_MANAGER_ROLE(), ADMIN.address, {"from": ADMIN}
    )
    SOPHTOKEN.mint(VESTING_CONTRACT.address, 1000 * 10 ** 18, {"from": ADMIN})

    start_date = chain.time() - 500
    duration = 1000
    amount = 1000 * 10 ** 18

    VESTING_CONTRACT.addVestingSchedule(USER1.address, amount, duration, start_date, {"from": ADMIN})

    # Deploy new implementation
    new_impl = LinearVestingWithPenaltyV2.deploy({"from": UPGRADER})

    # Upgrade the contract
    VESTING_CONTRACT.upgradeTo(new_impl.address, {"from": UPGRADER})

    # Verify state is preserved
    schedules = VESTING_CONTRACT.getVestingSchedules(USER1.address)
    assert len(schedules) == 1
    assert schedules[0][0] == amount
    assert schedules[0][1] == 0
    assert schedules[0][2] == duration
    assert schedules[0][3] == start_date

    # Verify new function in V2
    version = VESTING_CONTRACT.getVersion()
    assert version == 2


def test_claim_multiple_schedules(VESTING_CONTRACT, SCHEDULE_MANAGER, ADMIN, SOPHTOKEN, USER1, chain):
    # Grant roles and add multiple vesting schedules
    VESTING_CONTRACT.grantRole(
        VESTING_CONTRACT.SCHEDULE_MANAGER_ROLE(), SCHEDULE_MANAGER.address, {"from": ADMIN}
    )
    SOPHTOKEN.mint(VESTING_CONTRACT.address, 5000 * 10 ** 18, {"from": ADMIN})

    start_date = chain.time() - 1000
    duration = 2000
    amount = 2000 * 10 ** 18

    # Add multiple schedules
    for _ in range(3):
        VESTING_CONTRACT.addVestingSchedule(USER1.address, amount, duration, start_date, {"from": SCHEDULE_MANAGER})

    # Fast forward time
    chain.sleep(1000)
    chain.mine()

    # Mint SOPH tokens for claiming
    SOPHTOKEN.mint(VESTING_CONTRACT.address, 6000 * 10 ** 18, {"from": ADMIN})

    # USER1 claims multiple schedules
    initial_balance = SOPHTOKEN.balanceOf(USER1.address)
    initial_vsoph = VESTING_CONTRACT.balanceOf(USER1.address)

    # Calculate expected releasable: (2000 * 1000) / 2000 = 1000 per schedule
    expected_releasable = 1000 * 3 * 10 ** 18

    tx = VESTING_CONTRACT.releaseSpecificSchedules([0, 1, 2], {"from": USER1})
    assert "TokensReleased" in tx.events
    assert tx.events["TokensReleased"]["beneficiary"] == USER1.address
    assert tx.events["TokensReleased"]["netAmount"] == expected_releasable
    assert tx.events["TokensReleased"]["penaltyAmount"] == 0

    # Check SOPH balance
    assert SOPHTOKEN.balanceOf(USER1.address) == initial_balance + expected_releasable

    # Check vSOPH balance
    assert VESTING_CONTRACT.balanceOf(USER1.address) == initial_vsoph - expected_releasable

    # Check released amounts in schedules
    schedules = VESTING_CONTRACT.getVestingSchedules(USER1.address)
    for schedule in schedules:
        assert schedule[1] == 1000 * 10 ** 18  # released


def test_claim_specific_schedules_with_penalty_multiple(VESTING_CONTRACT, SCHEDULE_MANAGER, ADMIN, SOPHTOKEN, PENALTY_RECIPIENT, USER1, chain):
    # Grant roles and add multiple vesting schedules
    VESTING_CONTRACT.grantRole(
        VESTING_CONTRACT.SCHEDULE_MANAGER_ROLE(), SCHEDULE_MANAGER.address, {"from": ADMIN}
    )
    SOPHTOKEN.mint(VESTING_CONTRACT.address, 8000 * 10 ** 18, {"from": ADMIN})

    start_date = chain.time() - 1000
    duration = 2000
    amount = 2000 * 10 ** 18

    # Add multiple schedules
    for _ in range(4):
        VESTING_CONTRACT.addVestingSchedule(USER1.address, amount, duration, start_date, {"from": SCHEDULE_MANAGER})

    # Fast forward time
    chain.sleep(1000)
    chain.mine()

    # Mint SOPH tokens for claiming
    SOPHTOKEN.mint(VESTING_CONTRACT.address, 8000 * 10 ** 18, {"from": ADMIN})

    # USER1 claims specific schedules with penalty
    # Let's claim schedules 0 and 2
    # Each schedule has vested = 1000, unvested = 1000
    # Penalty: 50% of 1000 = 500 per schedule
    # Net to user: 1000 + (1000 - 500) = 1500 per schedule
    # Total net = 3000
    # Total penalty = 1000

    initial_user_balance = SOPHTOKEN.balanceOf(USER1.address)
    initial_penalty_balance = SOPHTOKEN.balanceOf(PENALTY_RECIPIENT.address)
    initial_vsoph = VESTING_CONTRACT.balanceOf(USER1.address)

    tx = VESTING_CONTRACT.claimSpecificSchedulesWithPenalty([0, 2], {"from": USER1})
    assert "TokensReleased" in tx.events
    assert tx.events["TokensReleased"]["beneficiary"] == USER1.address
    assert tx.events["TokensReleased"]["netAmount"] == 3000 * 10 ** 18
    assert tx.events["TokensReleased"]["penaltyAmount"] == 1000 * 10 ** 18
    assert "PenaltyPaid" in tx.events
    assert tx.events["PenaltyPaid"]["beneficiary"] == USER1.address
    assert tx.events["PenaltyPaid"]["penaltyAmount"] == 1000 * 10 ** 18

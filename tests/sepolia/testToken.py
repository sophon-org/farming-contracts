import pytest
from brownie import accounts, reverts

# Define a fixture to deploy the token contract
@pytest.fixture(scope="module")
def token(SophonToken):
    return accounts[0].deploy(SophonToken)

def test_total_supply(token):
    assert token.totalSupply() == 10_000_000_000 * 10**18

def test_initial_balance(token):
    assert token.balanceOf(accounts[0]) == 10_000_000_000 * 10**18

def test_transfer(token):
    initial_balance_account_0 = token.balanceOf(accounts[0])
    token.transfer(accounts[1], 1000 * 10**18, {'from': accounts[0]})
    assert token.balanceOf(accounts[0]) == initial_balance_account_0 - 1000 * 10**18
    assert token.balanceOf(accounts[1]) == 1000 * 10**18

def test_approve_and_transfer_from(token):
    initial_balance_account_0 = token.balanceOf(accounts[0])
    token.approve(accounts[1], 500 * 10**18, {'from': accounts[0]})
    assert token.allowance(accounts[0], accounts[1]) == 500 * 10**18

    initial_balance_account_2 = token.balanceOf(accounts[2])
    token.transferFrom(accounts[0], accounts[2], 500 * 10**18, {'from': accounts[1]})

    assert token.balanceOf(accounts[0]) == initial_balance_account_0 - 500 * 10**18
    assert token.balanceOf(accounts[2]) == initial_balance_account_2 + 500 * 10**18

def test_transfer_from_insufficient_allowance(token):
    token.approve(accounts[1], 500 * 10**18, {'from': accounts[0]})
    with reverts():
        token.transferFrom(accounts[0], accounts[2], 1000 * 10**18, {'from': accounts[1]})

def test_transfer_insufficient_balance(token):
    with reverts():
        token.transfer(accounts[1], 20_000_000_000 * 10**18, {'from': accounts[0]})

def test_approve(token):
    token.approve(accounts[1], 500 * 10**18, {'from': accounts[0]})
    assert token.allowance(accounts[0], accounts[1]) == 500 * 10**18

def test_decrease_allowance(token):
    token.approve(accounts[1], 500 * 10**18, {'from': accounts[0]})
    token.approve(accounts[1], 300 * 10**18, {'from': accounts[0]})
    assert token.allowance(accounts[0], accounts[1]) == 300 * 10**18

def test_decrease_allowance_below_zero(token):
    token.approve(accounts[1], 500 * 10**18, {'from': accounts[0]})
    token.approve(accounts[1], 0, {'from': accounts[0]})
    assert token.allowance(accounts[0], accounts[1]) == 0


def test_decrease_allowance_below_zero(token):
    token.approve(accounts[1], 500 * 10**18, {'from': accounts[0]})
    token.approve(accounts[1], 0, {'from': accounts[0]})
    assert token.allowance(accounts[0], accounts[1]) == 0
    
def test_rescue(token, MockERC20):
    dummy_token = accounts[0].deploy(MockERC20, "DummyToken", "DUM", 18)
    dummy_token.mint(accounts[0], 1000 * 10**18, {'from': accounts[0]})
    dummy_token.transfer(token.address, 100 * 10**18, {'from': accounts[0]})

    assert dummy_token.balanceOf(token.address) == 100 * 10**18

    token.rescue(dummy_token.address, {'from': accounts[0]})

    assert dummy_token.balanceOf(token.address) == 0
    assert dummy_token.balanceOf(accounts[0]) == 1000 * 10**18

def test_token_is_receiver_error(token):
    with reverts("TokenIsReceiver: "):
        token.transfer(token.address, 1000 * 10**18, {'from': accounts[0]})



def test_transfer_to_zero_address(token):
    with reverts():
        token.transfer('0x0000000000000000000000000000000000000000', 1000 * 10**18, {'from': accounts[0]})



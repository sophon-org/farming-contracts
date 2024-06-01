#!/usr/bin/python3

import pytest
from brownie import network, Contract, reverts, chain

@pytest.fixture(scope="function", autouse=True)
def isolate(fn_isolation):
    pass

@pytest.fixture(scope="module")
def DAI(interface):
    return interface.IERC20("0x6B175474E89094C44Da98b954EedeAC495271d0F")

@pytest.fixture(scope="module")
def sDAI(interface):
    return interface.IERC20("0x83F20F44975D03b1b09e64809B757c47f942BEeA")

@pytest.fixture(scope="module")
def WETH(interface):
    return interface.IERC20("0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2")

@pytest.fixture(scope="module")
def stETH(interface):
    return interface.IERC20("0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84")

@pytest.fixture(scope="module")
def wstETH(interface):
    return interface.IERC20("0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0")

@pytest.fixture(scope="module")
def eETH(interface):
    return interface.IERC20("0x35fA164735182de50811E8e2E824cFb9B6118ac2")

@pytest.fixture(scope="module")
def weETH(interface):
    return interface.IERC20("0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee")

@pytest.fixture(scope="module")
def USDC(interface):
    return interface.IERC20("0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48")



@pytest.fixture(scope="module")
def SF(accounts, chain, SophonFarming, SophonFarmingProxy, interface):
    deployer = accounts[0]

    weth                = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
    stETH               = "0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84"
    wstETH              = "0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0"
    wstETHAllocPoint    = 20000
    eETH                = "0x35fA164735182de50811E8e2E824cFb9B6118ac2"
    eETHLiquidityPool   = "0x308861A430be4cce5502d0A12724771Fc6DaF216"
    weETH               = "0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee"
    dai                 = "0x6B175474E89094C44Da98b954EedeAC495271d0F"
    sDAI                = "0x83F20F44975D03b1b09e64809B757c47f942BEeA"
    sDAIAllocPoint      = 20000
    pointsPerBlock      = pointsPerBlock = 25*10**18
    startBlock          = chain.height + 1000 # in the future
    boosterMultiplier   = 2e18




    args = [
        dai,
        sDAI,
        weth,
        stETH,
        wstETH,
        eETH,
        eETHLiquidityPool,
        weETH
    ]

    SFImpl = SophonFarming.deploy(args, {'from': deployer})

    SFProxy = SophonFarmingProxy.deploy(SFImpl, {"from": deployer})

    SF1 = interface.ISophonFarming(SFProxy)

    SF1.initialize(wstETHAllocPoint, wstETHAllocPoint, sDAIAllocPoint, pointsPerBlock, startBlock, boosterMultiplier, {'from': deployer})
    SF1.setEndBlock(chain.height+10000, 2000, {"from": deployer})


    # # testing rsETH
    # rsETH = interface.IERC20("0xa1290d69c65a6fe4df752f95823fae25cb99e5a7")
    # SF1.add(10000, rsETH, "rsETH", "rsETH description", True, {"from": deployer})
    return SF1


class PredefinedPool:
    sDAI = 0
    wstETH = 1
    weETH = 2


def test_SF_early_deposit(SF, accounts, wstETH, stETH, eETH, weETH, interface):
    
    from collections import namedtuple
    UserInfo = namedtuple('UserInfo', ['amount', 'boostAmount', 'depositAmount', 'rewardSettled', 'rewardDebt'])


    user1 = accounts[5]
    user2 = accounts[6]
    
    amount = 10e18
    acc1startblock = chain.height
    user1.transfer(SF, amount)
    userInfo1 = SF.userInfo(PredefinedPool.wstETH, user1)
    userInfo1 = UserInfo._make(userInfo1)
    
    chain.mine(10)

    assert SF.pendingPoints(PredefinedPool.wstETH, user1) == 0
    
    chain.mine(SF.startBlock()- chain.height)
    
    assert SF.pendingPoints(PredefinedPool.wstETH, user1) == 0
    
    chain.mine()
    
    assert SF.pendingPoints(PredefinedPool.wstETH, user1) >0
    
    assert True
    
    
    
    
    # ompare USDC pool with DAI pool point emission
def test_SF_deposit_USDC_non18_decimal(SF, eETH, weETH, accounts, USDC, DAI, sDAI, interface):
        
        
    usdcAllocationPoint = 20000
    SF.add(usdcAllocationPoint, USDC, "USDC", {"from": accounts[0]})
    
    
    holdersDAI = "0x6337f2366E6f47FB26Ec08293867a607BCc7A0dB"
    user1 = accounts[1]
    amount = 10000e18
    sDAI.transfer(user1, amount, {"from": holdersDAI})
    sDAI.approve(SF, 2**256-1, {"from": user1})
    
    PID = 0
    SF.deposit(PID, amount, 0, {"from": user1})
    
    holderUSDC = "0x4B16c5dE96EB2117bBE5fd171E4d203624B014aa"
    user1 = accounts[1]
    amount = 10000e6
    USDC.transfer(user1, amount, {"from": holderUSDC})
    USDC.approve(SF, 2**256-1, {"from": user1})
    PID = 3
    SF.deposit(PID, amount, 0, {"from": user1})
    
    
    
    # wait farming start   
    chain.mine(SF.startBlock()- chain.height)

        
    chain.mine()
    
    # points are flowing same speed in both pools
    assert SF.pendingPoints(0, user1) == SF.pendingPoints(3, user1)
    
    chain.mine(1000)
    assert SF.pendingPoints(0, user1) == SF.pendingPoints(3, user1)
    
    # TODO compare no boost emission stop
    #
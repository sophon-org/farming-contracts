#!/usr/bin/python3

import pytest
from brownie import network, Contract, reverts, chain

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
    startBlock          = chain.height
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

    SF1.initialize(wstETHAllocPoint, sDAIAllocPoint, pointsPerBlock, startBlock, boosterMultiplier, {'from': deployer})
    SF1.setEndBlock(chain.height+10000, 2000, {"from": deployer})


    # # testing rsETH
    # rsETH = interface.IERC20("0xa1290d69c65a6fe4df752f95823fae25cb99e5a7")
    # SF1.add(10000, rsETH, "rsETH", "rsETH description", True, {"from": deployer})
    return SF1




def test_SF_deposit_DAI(SF, DAI, sDAI, accounts, interface):
    holder = "0x47ac0Fb4F2D84898e4D9E7b4DaB3C24507a6D503"
    user1 = accounts[1]
    amount = 10000e18
    DAI.transfer(user1, amount, {"from": holder})
    DAI.approve(SF, 2**256-1, {"from": user1})
    
    with reverts("SavingsDai/insufficient-balance"):
        SF.deposit(0, amount, 0, {"from": user1})
        
    SF.depositDai(amount, 0, {"from": user1})
    userInfo = SF.userInfo(0, user1)
    SF.withdraw(0, userInfo[0], {"from": user1})
    
    interface.IsDAI(sDAI).redeem(sDAI.balanceOf(user1), user1, user1, {"from": user1})
    assert DAI.balanceOf(user1) > amount # due to interest rate on sDAI
    assert True

def test_SF_deposits_sDAI(SF, DAI, sDAI, accounts, interface):
    holder = "0xDEC53aa5b5B6ec2518814061B1EC72f6A26bB5b8"
    user1 = accounts[1]
    amount = 10000e18

    sDAI.transfer(user1, amount, {"from": holder})
    sDAI.approve(SF, 2**256-1, {"from": user1})
    
    SF.deposit(PredefinedPool.sDAI, amount, 0, {"from": user1})
    userInfo = SF.userInfo(0, user1)
    SF.withdraw(0, userInfo[0], {"from": user1})
    interface.IsDAI(sDAI).redeem(sDAI.balanceOf(user1), user1, user1, {"from": user1})
    assert DAI.balanceOf(user1) > amount # due to interest rate on sDAI
    
    assert True

class PredefinedPool:
    sDAI = 0
    wstETH = 1
    weETH = 2



def test_SF_deposit_WETH_wstETH(SF, WETH, wstETH, stETH, accounts, interface, chain):
    holder = "0x8EB8a3b98659Cce290402893d0123abb75E3ab28"
    user1 = accounts[1]
    amount = 100e18
    WETH.transfer(user1, amount, {"from": holder})
    WETH.approve(SF, 2**256-1, {"from": user1})

    SF.depositWeth(amount, 0, PredefinedPool.wstETH, {"from": user1})
    userInfo = SF.userInfo(PredefinedPool.wstETH, user1)
    assert wstETH.balanceOf(SF) == userInfo[0]

    SF.withdraw(PredefinedPool.wstETH, userInfo[0], {"from": user1})
    assert wstETH.balanceOf(SF) == 0

    interface.IwstETH(wstETH).unwrap(wstETH.balanceOf(user1), {"from": user1})

    assert stETH.balanceOf(user1) >  (int(amount) - 6) # due to interest rate on wstETH, also 1-2 wei bug
    
    assert True
    
def test_SF_deposit_WETH_eeETH(SF, WETH, wstETH, stETH, weETH, eETH, accounts, interface, chain):
    holder = "0x8EB8a3b98659Cce290402893d0123abb75E3ab28"
    user1 = accounts[1]
    amount = 100e18
    WETH.transfer(user1, amount, {"from": holder})
    WETH.approve(SF, 2**256-1, {"from": user1})

    SF.depositWeth(amount, 0, PredefinedPool.weETH, {"from": user1})
    userInfo = SF.userInfo(PredefinedPool.weETH, user1)
    assert weETH.balanceOf(SF) == userInfo[0]

    SF.withdraw(PredefinedPool.weETH, userInfo[0], {"from": user1})
    assert weETH.balanceOf(SF) == 0

    interface.IwstETH(weETH).unwrap(weETH.balanceOf(user1), {"from": user1})
    
    
    assert True
    
def test_SF_deposit_stETH(SF, WETH, wstETH, stETH, accounts, interface, chain):
    holder = "0x18709E89BD403F470088aBDAcEbE86CC60dda12e"
    user1 = accounts[1]
    amount = 100e18
    stETH.transfer(user1, amount, {"from": holder})
    stETH.approve(SF, 2**256-1, {"from": user1})

    SF.depositStEth(amount, 0, {"from": user1})
    userInfo = SF.userInfo(PredefinedPool.wstETH, user1)
    assert wstETH.balanceOf(SF) == userInfo[0]

    SF.withdraw(PredefinedPool.wstETH, userInfo[0], {"from": user1})
    assert wstETH.balanceOf(SF) == 0

    interface.IwstETH(wstETH).unwrap(wstETH.balanceOf(user1), {"from": user1})

    assert stETH.balanceOf(user1) >  (int(amount) - 6) # due to interest rate on wstETH, also 1-2 wei bug
    
    assert True
    
def test_SF_deposit_eETH(SF, eETH, weETH, accounts, interface):
    
    holder = "0xDdE0d6e90bfB74f1dC8ea070cFd0c0180C03Ad16"
    user1 = accounts[1]
    amount = 100e18
    eETH.transfer(user1, amount, {"from": holder})
    eETH.approve(SF, 2**256-1, {"from": user1})

    SF.depositeEth(amount, 0, {"from": user1})
    userInfo = SF.userInfo(PredefinedPool.weETH, user1)
    assert weETH.balanceOf(SF) == userInfo[0]

    SF.withdraw(PredefinedPool.weETH, userInfo[0], {"from": user1})
    assert weETH.balanceOf(SF) == 0

    interface.IwstETH(weETH).unwrap(weETH.balanceOf(user1), {"from": user1})

    assert eETH.balanceOf(user1) >  (int(amount) - 6) # due to interest rate on wstETH, also 1-2 wei bug
    
    assert True
    

def test_SF_deposit_ETH_weETH(SF, weETH, accounts, interface):
    user1 = accounts[1]
    amount = 10e18
    SF.depositEth(0, PredefinedPool.weETH, {"from": user1, "value": amount})
    userInfo = SF.userInfo(PredefinedPool.weETH, user1)
    assert weETH.balanceOf(SF) == userInfo[0]

    SF.withdraw(PredefinedPool.weETH, userInfo[0], {"from": user1})
    assert weETH.balanceOf(SF) == 0

    interface.IwstETH(weETH).unwrap(weETH.balanceOf(user1), {"from": user1})

    assert True
    
def test_SF_deposit_ETH_wstETH(SF, wstETH, stETH, accounts, interface):
    user1 = accounts[1]
    amount = 10e18
    SF.depositEth(0, PredefinedPool.wstETH, {"from": user1, "value": amount})
    
    userInfo = SF.userInfo(PredefinedPool.wstETH, user1)
    assert wstETH.balanceOf(SF) == userInfo[0]

    SF.withdraw(PredefinedPool.wstETH, userInfo[0], {"from": user1})
    assert wstETH.balanceOf(SF) == 0

    interface.IwstETH(wstETH).unwrap(wstETH.balanceOf(user1), {"from": user1})

    assert stETH.balanceOf(user1) >  (int(amount) - 6) # due to interest rate on wstETH, also 1-2 wei bug
    
    assert True

def test_SF_deposit_transfer(SF, wstETH, stETH, accounts, interface):
    user1 = accounts[1]
    amount = 10e18
    user1.transfer(SF, amount)
    userInfo = SF.userInfo(PredefinedPool.wstETH, user1)
    assert wstETH.balanceOf(SF) == userInfo[0]

    SF.withdraw(PredefinedPool.wstETH, userInfo[0], {"from": user1})
    assert wstETH.balanceOf(SF) == 0

    interface.IwstETH(wstETH).unwrap(wstETH.balanceOf(user1), {"from": user1})

    assert stETH.balanceOf(user1) >  (int(amount) - 6) # due to interest rate on wstETH, also 1-2 wei bug
    
    assert True

def test_SF_upgrade(SF, SophonFarming, accounts, interface):
    
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
    
    SF.replaceImplementation(SFImpl, {'from': deployer})
    SFImpl.becomeImplementation(SF, {'from': deployer})
    
    
    assert True
    
def test_SF_reward_logic(SF, accounts, interface):
    
    user1 = accounts[1]
    user2 = accounts[2]
    amount = 10e18
    user1.transfer(SF, amount)
    user2.transfer(SF, amount)
    userInfo1 = SF.userInfo(PredefinedPool.wstETH, user1)
    userInfo2 = SF.userInfo(PredefinedPool.wstETH, user2)
    
    chain.mine(SF.endBlock()-chain.height)
    
    assert False
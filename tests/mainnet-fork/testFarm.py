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
def PEPE(interface):
    return interface.IERC20("0x6982508145454Ce325dDbE47a25d4ec3d2311933")


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

    SF1.initialize(wstETHAllocPoint, wstETHAllocPoint, sDAIAllocPoint, pointsPerBlock, startBlock, boosterMultiplier, {'from': deployer})
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
    holder = "0x75e34757ce4e9C733f3B025690402a700B18f2F5"
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
    assert wstETH.balanceOf(SF) == 0 or wstETH.balanceOf(SF) == 1
    assert stETH.balanceOf(SF) == 0 or stETH.balanceOf(SF) == 1

    interface.IwstETH(wstETH).unwrap(wstETH.balanceOf(user1), {"from": user1})

    assert stETH.balanceOf(user1) >  (int(amount) - 6) # due to interest rate on wstETH, also 1-2 wei bug
    
    # check for leak
    # assert stETH.balanceOf(SF) == 0
    
def test_SF_deposit_eETH(SF, eETH, weETH, accounts, interface):
    holder = "0x3d320286E014C3e1ce99Af6d6B00f0C1D63E3000"
    user1 = accounts[1]
    amount = 100e18
    boostAmount = 0
    user1.transfer(holder, 1e18)
    eETH.transfer(user1, amount, {"from": holder})
    eETH.approve(SF, 2**256-1, {"from": user1})

    SF.depositeEth(amount, boostAmount, {"from": user1})
   
    userInfo = SF.userInfo(PredefinedPool.weETH, user1)
    assert weETH.balanceOf(SF) - userInfo[0] <= 1

    SF.withdraw(PredefinedPool.weETH, userInfo[0], {"from": user1})
    assert weETH.balanceOf(SF) == 0

    interface.IwstETH(weETH).unwrap(weETH.balanceOf(user1), {"from": user1})

    assert eETH.balanceOf(user1) >  (int(amount) - 6) # due to interest rate on wstETH, also 1-2 wei bug
    
    assert True
    

def test_SF_deposit_ETH_weETH(SF, weETH, eETH, accounts, interface):
    user1 = accounts[1]
    amount = 10e18
    boostAmount = 0
    SF.depositEth(0, PredefinedPool.weETH, {"from": user1, "value": amount})
    userInfo = SF.userInfo(PredefinedPool.weETH, user1)
    assert abs(weETH.balanceOf(SF) - userInfo[0]) <= 1

    SF.withdraw(PredefinedPool.weETH, userInfo[0], {"from": user1})
    assert weETH.balanceOf(SF) == 0

    interface.IwstETH(weETH).unwrap(weETH.balanceOf(user1), {"from": user1})

    assert True

def test_SF_deposit_ETH_weETH_eETH_leak(SF, weETH, eETH, accounts, interface):
    user1 = accounts[1]
    amount = 10e18
    SF.depositEth(0, PredefinedPool.weETH, {"from": user1, "value": amount})
    userInfo = SF.userInfo(PredefinedPool.weETH, user1)
    assert abs(weETH.balanceOf(SF) - userInfo[0]) <= 1

    SF.withdraw(PredefinedPool.weETH, userInfo[0], {"from": user1})
    assert weETH.balanceOf(SF) == 0

    interface.IwstETH(weETH).unwrap(weETH.balanceOf(user1), {"from": user1})

    assert eETH.balanceOf(SF) == 0 or eETH.balanceOf(SF) == 1
    
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



     
def test_SF_reward_logic_fairness(SF, accounts, wstETH, stETH, eETH, weETH, interface):
    
    from collections import namedtuple
    UserInfo = namedtuple('UserInfo', ['amount', 'boostAmount', 'depositAmount', 'rewardSettled', 'rewardDebt'])


    user1 = accounts[3]
    user2 = accounts[4]
    
    amount = 10e18
    acc1startblock = chain.height
    user1.transfer(SF, amount)
    userInfo1 = SF.userInfo(PredefinedPool.wstETH, user1)
    userInfo1 = UserInfo._make(userInfo1)
    
    chain.mine(100)

    SF.withdraw(PredefinedPool.wstETH, userInfo1.depositAmount, {"from": user1})
    acc1endblock = chain.height
    
    
    # part 2
    acc2startblock = chain.height
    user2.transfer(SF, amount)
    userInfo2 = SF.userInfo(PredefinedPool.wstETH, user2)
    userInfo2 = UserInfo._make(userInfo2)
    
    chain.mine(100)

    SF.withdraw(PredefinedPool.wstETH, userInfo2.depositAmount, {"from": user2})
    acc2endblock = chain.height
    
    chain.mine(SF.endBlock()-chain.height)
    
    assert abs(SF.pendingPoints(PredefinedPool.wstETH, user1) - SF.pendingPoints(PredefinedPool.wstETH, user2)) <= 1

def test_SF_reward_logic_fairness2(SF, accounts, wstETH, stETH, eETH, weETH, interface):
    
    from collections import namedtuple
    UserInfo = namedtuple('UserInfo', ['amount', 'boostAmount', 'depositAmount', 'rewardSettled', 'rewardDebt'])


    user1 = accounts[5]
    user2 = accounts[6]
    
    amount = 10e18
    acc1startblock = chain.height
    user1.transfer(SF, amount)
    userInfo1 = SF.userInfo(PredefinedPool.wstETH, user1)
    userInfo1 = UserInfo._make(userInfo1)
    
    chain.mine(100)
    
    acc2startblock = chain.height
    user2.transfer(SF, amount)


    chain.mine(1000)
    SF.withdraw(PredefinedPool.wstETH, userInfo1.depositAmount, {"from": user1})
    acc1endblock = chain.height

    
    # part 2

    userInfo2 = SF.userInfo(PredefinedPool.wstETH, user2)
    userInfo2 = UserInfo._make(userInfo2)
    
    chain.mine(100)

    SF.withdraw(PredefinedPool.wstETH, userInfo2.depositAmount, {"from": user2})
    acc2endblock = chain.height
    
    chain.mine(SF.endBlock()-chain.height)
    
    assert abs(SF.pendingPoints(PredefinedPool.wstETH, user1) - SF.pendingPoints(PredefinedPool.wstETH, user2)) <= 1
    assert True
    


def test_SF_deposit_eETH_withBoost(SF, eETH, weETH, accounts, interface):
    holder = "0x3d320286E014C3e1ce99Af6d6B00f0C1D63E3000"
    user1 = accounts[1]
    amount = 100e18
    boostAmount = 1e18
    user1.transfer(holder, 1e18)
    eETH.transfer(user1, amount, {"from": holder})
    eETH.approve(SF, 2**256-1, {"from": user1})

    SF.depositeEth(amount, boostAmount, {"from": user1})
   
    userInfo = SF.userInfo(PredefinedPool.weETH, user1)
    
    from collections import namedtuple
    UserInfo = namedtuple('UserInfo', ['amount', 'boostAmount', 'depositAmount', 'rewardSettled', 'rewardDebt'])
    userInfo = UserInfo._make(userInfo)
    
    assert weETH.balanceOf(SF) - userInfo[0] <= 1

    balanceBefore = weETH.balanceOf(user1)
    SF.withdraw(PredefinedPool.weETH, userInfo.depositAmount, {"from": user1})
    
    balanceAfter = weETH.balanceOf(user1)
    assert balanceAfter - balanceBefore == userInfo.depositAmount


    chain.mine()
    
    userInfoAfter = SF.userInfo(PredefinedPool.weETH, user1)
    userInfoAfter = UserInfo._make(userInfoAfter)
    
    assert userInfoAfter.depositAmount == 0
    assert weETH.balanceOf(SF) == SF.heldProceeds(PredefinedPool.weETH)
    a = SF.pendingPoints(PredefinedPool.weETH, user1)
    chain.mine()
    b = SF.pendingPoints(PredefinedPool.weETH, user1)
    assert b > a # acruing poins continue due to boost

    interface.IwstETH(weETH).unwrap(weETH.balanceOf(user1), {"from": user1})

    assert abs(eETH.balanceOf(user1) - (int(amount) - 6 - boostAmount)) <= 6 # due to interest rate on wstETH, also 1-2 wei bug
    
    assert True
    


def test_SF_deposit_eETH_withoutBoost(SF, eETH, weETH, accounts, interface):
    holder = "0x3d320286E014C3e1ce99Af6d6B00f0C1D63E3000"
    user1 = accounts[1]
    amount = 100e18
    boostAmount = 0
    user1.transfer(holder, 1e18)
    eETH.transfer(user1, amount, {"from": holder})
    eETH.approve(SF, 2**256-1, {"from": user1})

    SF.depositeEth(amount, boostAmount, {"from": user1})
   
    userInfo = SF.userInfo(PredefinedPool.weETH, user1)
    
    from collections import namedtuple
    UserInfo = namedtuple('UserInfo', ['amount', 'boostAmount', 'depositAmount', 'rewardSettled', 'rewardDebt'])
    userInfo = UserInfo._make(userInfo)
    
    assert weETH.balanceOf(SF) - userInfo[0] <= 1

    balanceBefore = weETH.balanceOf(user1)
    SF.withdraw(PredefinedPool.weETH, userInfo.depositAmount, {"from": user1})
    
    balanceAfter = weETH.balanceOf(user1)
    assert balanceAfter - balanceBefore == userInfo.depositAmount
    chain.mine()
    
    userInfoAfter = SF.userInfo(PredefinedPool.weETH, user1)
    userInfoAfter = UserInfo._make(userInfoAfter)
    
    assert userInfoAfter.depositAmount == 0
    assert weETH.balanceOf(SF) == SF.heldProceeds(PredefinedPool.weETH)
    a = SF.pendingPoints(PredefinedPool.weETH, user1)
    chain.mine()
    b = SF.pendingPoints(PredefinedPool.weETH, user1)
    assert b == a # acruing poins continue due to boost

    interface.IwstETH(weETH).unwrap(weETH.balanceOf(user1), {"from": user1})

    assert abs(eETH.balanceOf(user1) - (int(amount) - 6 - boostAmount)) <= 6 # due to interest rate on wstETH, also 1-2 wei bug
    
    assert True

def test_SF_deposit_WETH_wstETH_manipulate_distribution_points(SF, WETH, wstETH, stETH, accounts, interface, chain):
    holder = "0x5fEC2f34D80ED82370F733043B6A536d7e9D7f8d"
    user1 = accounts[1]
    user2 = accounts[2]
    amount1 = 1
    amount2 = 1e18
    
    user1.transfer(holder, 1e18)
    wstETH.transfer(user1, amount1, {"from": holder})
    wstETH.approve(SF, 2**256-1, {"from": user1})
    
    wstETH.transfer(user2, amount2, {"from": holder})
    wstETH.approve(SF, 2**256-1, {"from": user2})

    SF.deposit(PredefinedPool.wstETH, amount1, 0, {"from": user1})
    
    poolInfo = SF.getPoolInfo()
    wstETHPoolInfo = poolInfo[1]
    chain.mine()

    
    SF.deposit(PredefinedPool.wstETH, amount2, 0, {"from": user2})
    
    chain.mine()
    chain.mine()
    
    assert abs(SF.pendingPoints(1, user1) - SF.pendingPoints(1, user2)) < 100

def test_SF_transferPointFunction(SF, eETH, weETH, accounts, interface):
    
    
    holder = "0x3d320286E014C3e1ce99Af6d6B00f0C1D63E3000"
    user1 = accounts[1]
    user2 = accounts[2]
    user3 = accounts[3]
    user4 = accounts[4]
    user5 = accounts[5]
    
    amount = 100e18
    boostAmount = 0
    user1.transfer(holder, 1e18)
    eETH.transfer(user1, amount, {"from": holder})
    eETH.approve(SF, 2**256-1, {"from": user1})

    SF.depositeEth(amount, boostAmount, {"from": user1})
   

    chain.mine(10)
    userInfo = SF.userInfo(PredefinedPool.weETH, user1)
    pendingPoints = SF.pendingPoints(PredefinedPool.weETH, user1)
    
    SF.setUsersWhitelisted(user2, [user1], True, {"from": accounts[0]})
    
    # transfer everything
    SF.transferPoints(PredefinedPool.weETH, user1, user3, 2**256-1, {"from": user2})
    
    # since I transfered everything. user3 has to have more than user1 in new block
    user3Points = SF.pendingPoints(PredefinedPool.weETH, user3)
    assert SF.pendingPoints(PredefinedPool.weETH, user1) < user3Points
    
    SF.setUsersWhitelisted(user4, [user3], True, {"from": accounts[0]})
    SF.transferPoints(PredefinedPool.weETH, user3, user4, 2**256-1, {"from": user4})
    
    assert SF.pendingPoints(PredefinedPool.weETH, user3) == 0
    # all points were transfered
    assert SF.pendingPoints(PredefinedPool.weETH, user4) == user3Points
    
    
    SF.withdraw(PredefinedPool.weETH, SF.userInfo(PredefinedPool.weETH, user1)[0], {"from": user1})
    
    
    
    amount = 100e18
    boostAmount = 50E18
    user5.transfer(holder, 1e18)
    eETH.transfer(user5, amount, {"from": holder})
    eETH.approve(SF, 2**256-1, {"from": user5})
    SF.depositeEth(amount, boostAmount, {"from": user5})
    
    SF.setUsersWhitelisted(user3, [user5], True, {"from": accounts[0]})
    
    SF.transferPoints(PredefinedPool.weETH, user5, user3, 2**256-1, {"from": user3})
    
    assert SF.pendingPoints(PredefinedPool.weETH, user5) == 0
    chain.mine()
    assert SF.pendingPoints(PredefinedPool.weETH, user5) > 0
    assert True
    


def test_SF_pointAllocation(SF, eETH, weETH, accounts, interface):
    
    
    holder = "0x3d320286E014C3e1ce99Af6d6B00f0C1D63E3000"
    user1 = accounts[1]
    user2 = accounts[2]
    user3 = accounts[3]
    amount = 100e18
    boostAmount = 0
    user1.transfer(holder, 1e18)
    eETH.transfer(user1, amount, {"from": holder})
    eETH.approve(SF, 2**256-1, {"from": user1})

    SF.depositeEth(amount, boostAmount, {"from": user1})
    
    numberOfBlocks = 10
    poolInfo = SF.getPoolInfo()
    poolAllocPoint = poolInfo[2][5]
    chain.mine(numberOfBlocks)
    
    from decimal import Decimal, getcontext
    # since user is the single staker of this pool he should get all the points
    assert SF.pendingPoints(PredefinedPool.weETH, user1) == int(SF.pointsPerBlock() * poolAllocPoint * numberOfBlocks / Decimal(SF.totalAllocPoint())) 
    assert True
    


def test_SF_overflow_accPointsPerShare(SF, eETH, weETH, DAI, sDAI, accounts, interface):
    holder = "0x75e34757ce4e9C733f3B025690402a700B18f2F5"
    user1 = accounts[1]
    user2 = accounts[2]
    amount = 1
    amount2 = 1000000e18

    sDAI.transfer(user1, amount, {"from": holder})
    sDAI.approve(SF, 2**256-1, {"from": user1})
    
    sDAI.transfer(user2, amount2, {"from": holder})
    sDAI.approve(SF, 2**256-1, {"from": user2})
    
    SF.deposit(PredefinedPool.sDAI, amount, 0, {"from": user1})
    
    SF.updatePool(PredefinedPool.sDAI, {"from": user1})
    
    SF.deposit(PredefinedPool.sDAI, amount2, 0, {"from": user2})
    assert True
    
    
    
def test_SF_overflow_accPointsPerShare1(SF, eETH, weETH, DAI, sDAI, accounts, USDC, interface): 
    
    holder = "0x4B16c5dE96EB2117bBE5fd171E4d203624B014aa"
    SF.add(60000, USDC.address, "USDC description", chain.height, 0, {"from": accounts[0]})
    
    user1 = accounts[1]
    amount = 1
    
    USDC.transfer(user1, amount, {"from": holder})
    USDC.approve(SF, 2**256-1, {"from": user1})
    
    SF.deposit(3, amount, 0, {"from": user1})
    
    SF.updatePool(3, {"from": user1})
    
    
    user2 = accounts[2]
    amount2 = 1e6*1e6
    
    USDC.transfer(user2, amount2, {"from": holder})
    USDC.approve(SF, 2**256-1, {"from": user2})
    
    SF.deposit(3, amount2, 0, {"from": user2})
    
    
    
    user3 = accounts[3]
    amount3 = 990000000*1e6
        
    USDC.transfer(user3, amount3, {"from": holder})
    USDC.approve(SF, 2**256-1, {"from": user3})
        
    SF.deposit(3, amount3, 0, {"from": user3})
    
    assert True
    
    
   
def test_SF_overflow_PEPE(SF, PEPE, eETH, weETH, DAI, sDAI, accounts, USDC, interface): 
    
    holder = "0xF977814e90dA44bFA03b6295A0616a897441aceC"
    SF.add(60000, PEPE.address, "PEPE description", chain.height + 1, {"from": accounts[0]})
    
    user1 = accounts[1]
    amount = 1
    
    PEPE.transfer(user1, amount, {"from": holder})
    PEPE.approve(SF, 2**256-1, {"from": user1})
    
    SF.deposit(3, amount, 0, {"from": user1})
    
    SF.updatePool(3, {"from": user1})
    
    
    
    user2 = accounts[2]
    amount2 = 1e12 * 1e18 # trillion 11 zeros. 10T here
    
    PEPE.transfer(user2, amount2, {"from": holder})
    PEPE.approve(SF, 2**256-1, {"from": user2})
    
    SF.deposit(3, amount2, 0, {"from": user2})
    
    SF.updatePool(3, {"from": user2})
    
    assert True
    
    
def test_SF_reward_endBlock(SF, accounts, wstETH, stETH, eETH, weETH, interface):
    
    user1 = accounts[1]
    user2 = accounts[2]
    
    amount = 10e18
    acc1startblock = chain.height
    user1.transfer(SF, amount)
    
    
    chain.mine(SF.endBlock()-chain.height)
    
    chain.mine(10)
    points = SF.pendingPoints(PredefinedPool.wstETH, user1)
    SF.updatePool(PredefinedPool.wstETH, {"from": user1})
    assert points == SF.pendingPoints(PredefinedPool.wstETH, user1)



def test_SF_overflow_PEPE(SF, PEPE, eETH, weETH, DAI, sDAI, accounts, USDC, interface): 
    
    holder = "0xF977814e90dA44bFA03b6295A0616a897441aceC"
    SF.add(60000, PEPE.address, "PEPE description", chain.height + 1, 0, {"from": accounts[0]})
    
    user1 = accounts[1]
    amount = 1
    
    PEPE.transfer(user1, amount, {"from": holder})
    PEPE.approve(SF, 2**256-1, {"from": user1})
    
    SF.deposit(3, amount, 0, {"from": user1})
    
    SF.updatePool(3, {"from": user1})
    
    
    
    user2 = accounts[2]
    amount2 = 1e12 * 1e18 # trillion 11 zeros. 10T here
    
    PEPE.transfer(user2, amount2, {"from": holder})
    PEPE.approve(SF, 2**256-1, {"from": user2})
    
    SF.deposit(3, amount2, 0, {"from": user2})
    
    SF.updatePool(3, {"from": user2})
    SF.pendingPoints(3, user2)
    assert True
    
def test_SF_overflow_pending(SF, PEPE, eETH, weETH, DAI, sDAI, accounts, USDC, interface, MockERC20): 
    
    deployer = accounts[0]
    usdc = MockERC20.deploy("Mock USDC Token", "MockUSDC", 18, {"from": deployer})
    
    usdc.mint(deployer, 10000e18)
    
    usdcId = SF.add(60000, usdc, "usdc", chain.height, 0, {"from": deployer})
    usdcId = 3
    
    usdc.approve(SF, 10000e18)
    
    SF.deposit(usdcId, 1, 0, {"from": deployer})
    chain.mine()
    SF.updatePool(usdcId, {"from": deployer})
    
    from decimal import Decimal, getcontext
    SF.deposit(usdcId, int(Decimal(10000e18) - 1), 0, {"from": deployer})
    
    chain.mine()
    
    SF.updatePool(usdcId, {"from": deployer})
    
    SF.pendingPoints(usdcId, deployer)
    
    assert False
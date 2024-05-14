#!/usr/bin/python3

import pytest
from brownie import network, Contract, reverts

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
    SF1.setEndBlocks(chain.height+10000, 2000, {"from": deployer})


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
    assert False

def test_SF_deposits_sDAI(SF, sDAI, accounts, interface):
    assert False

def test_SF_deposit_WETH(SF, WETH, accounts, interface):
    assert False
    
def test_SF_deposit_stETH(SF, stETH, accounts, interface):
    assert False

def test_SF_deposit_wstETH(SF, wstETH, accounts, interface):
    assert False

def test_SF_deposit_eETH(SF, eETH, accounts, interface):
    assert False
    
def test_SF_deposit_weETH(SF, weETH, accounts, interface):
    assert False
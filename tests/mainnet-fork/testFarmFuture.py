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
def BEAM(interface):
    return interface.IERC20("0x62D0A8458eD7719FDAF978fe5929C6D342B0bFcE")

@pytest.fixture(scope="module")
def BEAM_ETH_UNIV2(interface):
    return interface.IERC20("0x180EFC1349A69390aDE25667487a826164C9c6E4")


@pytest.fixture(scope="module")
def SF(accounts, chain, SophonFarming, SophonFarmingProxy, interface):
    return interface.ISophonFarming("0xEfF8E65aC06D7FE70842A4d54959e8692d6AE064")



class PredefinedPool:
    sDAI = 0
    wstETH = 1
    weETH = 2
    BEAM = 3
    BEAM_ETH = 4

def test_SF(SF, DAI, sDAI, BEAM, accounts, interface, BEAM_ETH_UNIV2):
    
    poolInfo = SF.getPoolInfo()
    BEAM_ETH_pool = poolInfo[PredefinedPool.BEAM_ETH]
    startBlock = BEAM_ETH_pool[6]
    allocPoint = BEAM_ETH_pool[5]
    
    # waiting farming start
    chain.mine(startBlock - chain.height)
    chain.mine()
    assert abs(SF.pointsPerBlock() - (SF.pendingPoints(PredefinedPool.BEAM_ETH, SF.owner()) + SF.pendingPoints(PredefinedPool.BEAM, SF.owner()))) < 100
    assert False

def test_SF_new_deposits(SF, DAI, sDAI, BEAM, accounts, interface, BEAM_ETH_UNIV2):
    beam_holder = "0xA99F29A2fBdCaFbf057b3D8eFC47cfCEe670Bb43"
    user1 = accounts[1]
    amount = 1e6*1e18
    BEAM.transfer(user1, amount, {"from": beam_holder})
    BEAM.approve(SF, 2**256-1, {"from": user1})
    
    poolInfo = SF.getPoolInfo()
    BEAM_pool = poolInfo[PredefinedPool.BEAM]
    startBlock = BEAM_pool[6]
    allocPoint = BEAM_pool[5]
    # waiting farming start
    chain.mine(startBlock - chain.height)
    chain.mine()
    
    SF.deposit(PredefinedPool.BEAM, amount, 0, {"from": user1})
    
    SF.updatePool(PredefinedPool.BEAM, {"from": user1})
    
    SF.withdraw(PredefinedPool.BEAM, amount, {"from": user1})
    assert BEAM.balanceOf(user1) == amount

    
    # WIP
    assert True
from brownie import *
import secrets, pickledb, random
import sys, os, re, csv, json, shutil
from pprint import pprint
import time

from brownie.network import gas_price, gas_limit
from brownie.network.gas.strategies import LinearScalingStrategy
gas_strategy = LinearScalingStrategy("2 gwei", "5 gwei", 1.1)
gas_price(gas_strategy) ## gas_price(20e9)
gas_limit(5000000)

ZERO_ADDRESS = "0x0000000000000000000000000000000000000000"

NETWORK = network.show_active()

if NETWORK == "development" or NETWORK == "anvil":
    NETWORK = "development"
    acct = accounts[0]
else:
    acct = accounts.load("soph")

## https://patx.github.io/pickledb/commands.html
def dbDelete():
    db = pickledb.load('contracts_'+NETWORK+'.db', False)
    db.deldb()
    db.dump() 
def dbSet(key, val):
    db = pickledb.load('contracts_'+NETWORK+'.db', False)
    db.set(key, val)
    db.dump()
def dbGet(key):
    currentNetwork = NETWORK
    #currentNetwork = currentNetwork.replace("-tenderly", "")
    #currentNetwork = currentNetwork.replace("-fork", "")
    db = pickledb.load('contracts_'+currentNetwork+'.db', False)
    return db.get(key)

def getFarm():
    return Contract.from_abi("farm", dbGet("farm"), SophonFarming.abi)
def getMocks(): ## acct, acct1, acct2, farm, mock0, mock1, weth, stETH, wstETH, dai, sDAI = run("deploy", "getMocks")
    farm = getFarm()

    mock0 = Contract.from_abi("mock0", dbGet("mock_0"), MockERC20.abi)
    mock1 = Contract.from_abi("mock1", dbGet("mock_1"), MockERC20.abi)

    weth = Contract.from_abi("mock0", "0xDc1808F3994912DB7c9448aF227de231c5251216", interface.IWeth.abi)
    stETH = Contract.from_abi("stETH", dbGet("mock_steth"), MockStETH.abi)
    wstETH = Contract.from_abi("wstETH", dbGet("mock_wsteth"), MockWstETH.abi)
    dai = Contract.from_abi("dai", dbGet("mock_dai"), MockERC20.abi)
    sDAI = Contract.from_abi("sDAI", dbGet("mock_sdai"), MockSDAI.abi)

    if NETWORK == "development":
        acct1 = accounts[1]
        acct2 = accounts[2]
    else:
        acct1 = acct
        acct2 = acct

    return acct, acct1, acct2, farm, mock0, mock1, weth, stETH, wstETH, dai, sDAI

def createMockSetup():
    global acct

    createMockToken(0, True)
    createMockToken(1, True)

    ## Sepolia
    weth = Contract.from_abi("weth", "0xDc1808F3994912DB7c9448aF227de231c5251216", interface.IWeth.abi)

    ## mock stEth
    stETH = MockStETH.deploy({"from": acct})
    dbSet("mock_steth", stETH.address)

    ## mock wstEth
    wstETH = MockWstETH.deploy(stETH, {"from": acct})
    dbSet("mock_wsteth", wstETH.address)
    wstETHAllocPoint = 20000

    ## mock DAI
    dai = MockERC20.deploy("Mock Dai Token", "MockDAI", 18, {"from": acct})
    dai.mint(acct, 1000000e18, {"from": acct})
    dbSet("mock_dai", dai.address)

    ## mock sDAI
    sDAI = MockSDAI.deploy(dai, {"from": acct})
    dbSet("mock_sdai", sDAI.address)
    sDAIAllocPoint = 20000

    pointsPerBlock = 25*10**18
    startBlock = chain.height

    createFarm(weth, stETH, wstETH, wstETHAllocPoint, dai, sDAI, sDAIAllocPoint, pointsPerBlock, startBlock)

    acct, acct1, acct2, farm, mock0, mock1, weth, stETH, wstETH, dai, sDAI = getMocks()

    farm.add(10000, mock0, "mock0", True, {"from": acct})
    farm.add(30000, mock1, "mock1", True, {"from": acct})

    ## Approvals
    mock0.approve(farm, 2**256-1, {"from": acct})
    mock1.approve(farm, 2**256-1, {"from": acct})
    weth.approve(farm, 2**256-1, {"from": acct})
    stETH.approve(farm, 2**256-1, {"from": acct})
    wstETH.approve(farm, 2**256-1, {"from": acct})
    dai.approve(farm, 2**256-1, {"from": acct})
    sDAI.approve(farm, 2**256-1, {"from": acct})
    stETH.approve(wstETH, 2**256-1, {"from": acct})
    dai.approve(sDAI, 2**256-1, {"from": acct})

    ## Mint some of all the assets
    mock0.mint(acct, 1000e18, {"from": acct})
    mock1.mint(acct, 1000e18, {"from": acct})
    weth.deposit({"from": acct, "value": 0.01e18})
    stETH.submit(farm, {"from": acct, "value": 0.02e18})
    wstETH.wrap(stETH.balanceOf(acct) / 2, {"from": acct})
    dai.mint(acct, 1000e18, {"from": acct})
    sDAI.deposit(dai.balanceOf(acct) / 2, acct, {"from": acct})

    ## Deposit ETH
    farm.depositEth(0.01e18 * 0.02, {"from": acct, "value": 0.01e18})

    ## Deposit Weth
    farm.depositWeth(weth.balanceOf(acct), weth.balanceOf(acct) * 0.05, {"from": acct})

    ## Deposit stEth
    farm.depositStEth(stETH.balanceOf(acct), 0, {"from": acct})

    ## Deposit DAI
    farm.depositDai(dai.balanceOf(acct), dai.balanceOf(acct) * 0.1, {"from": acct})

    ## Deposit Mock0
    farm.deposit(2, 1000e18, 1000e18 * 0.01, {"from": acct})

    ## Deposit Mock1
    farm.deposit(3, 1000e18, 0, {"from": acct})

    return getMocks()

def createMockToken(count=0, force=False):
    global acct

    if dbGet("mock_"+str(count)) != False:
        if force == False:
            print("mock_"+str(count)+" already exists! Exiting.")
            return
        else:
            print("mock_"+str(count)+" already exists! Overriding.")

    mock = MockERC20.deploy("Mock Token "+str(count), "MOCK"+(str(count)), 18, {"from": acct})
    mock.mint(acct, 1000000e18, {"from": acct})
    dbSet("mock_"+str(count), mock.address)

    return mock

def createFarm(weth, stETH, wstETH, wstETHAllocPoint, dai, sDAI, sDAIAllocPoint, pointsPerBlock, startBlock):
    global acct

    impl = SophonFarming.deploy(weth, stETH, wstETH, dai, sDAI, {'from': acct})
    dbSet("farmLastImpl", impl.address)

    proxy = SophonFarmingProxy.deploy(impl, {'from': acct})
    farm = Contract.from_abi("farm", proxy.address, SophonFarming.abi)
    dbSet("farm", farm.address)

    farm.initialize(wstETHAllocPoint, sDAIAllocPoint, pointsPerBlock, startBlock, {'from': acct})

    return farm

def upgradeFarm():
    acct, acct1, acct2, farm, mock0, mock1, weth, stETH, wstETH, dai, sDAI = getMocks()

    impl = SophonFarming.deploy(weth, stETH, wstETH, dai, sDAI, {'from': acct})
    dbSet("farmLastImpl", impl.address)

    Contract.from_abi("proxy", farm, SophonFarmingProxy.abi).replaceImplementation(impl, {'from': acct})
    Contract.from_abi("impl", impl, SophonFarming.abi).becomeImplementation(farm, {'from': acct})

    return farm

def setLastImpl():
    global acct

    farm = getFarm()

    Contract.from_abi("proxy", farm, SophonFarmingProxy.abi).replaceImplementation(dbGet("farmLastImpl"), {'from': acct})
    Contract.from_abi("impl", dbGet("farmLastImpl"), SophonFarming.abi).becomeImplementation(farm, {'from': acct})

    return farm

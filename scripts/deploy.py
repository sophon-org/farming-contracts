from brownie import *
from brownie.network.state import _add_contract
import secrets, pickledb, random
import sys, os, re, csv, json, shutil
from pprint import pprint

from brownie.network import gas_price
from brownie.network.gas.strategies import LinearScalingStrategy
gas_strategy = LinearScalingStrategy("30 gwei", "120 gwei", 1.1)

gas_price(gas_strategy) ## gas_price(20e9)

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
    currentNetwork = currentNetwork.replace("-tenderly", "")
    currentNetwork = currentNetwork.replace("-fork", "")
    db = pickledb.load('contracts_'+currentNetwork+'.db', False)
    return db.get(key)

def getFarm():
    return Contract.from_abi("farm", dbGet("farm"), SophonFarming.abi)
def getMocks(): ## acct, farm, mock0, mock1, mock2, mocknft0, mocknft1, mocknft2 = run("deploy", "getMocks")
    farm = getFarm()
    mock0 = Contract.from_abi("mock0", dbGet("mock_0"), MockERC20.abi)
    mock1 = Contract.from_abi("mock1", dbGet("mock_1"), MockERC20.abi)
    mock2 = Contract.from_abi("mock2", dbGet("mock_2"), MockERC20.abi)
    mocknft0 = Contract.from_abi("mockNft0", dbGet("mocknft_0"), MockERC721.abi)
    mocknft1 = Contract.from_abi("mockNft1", dbGet("mocknft_1"), MockERC721.abi)
    mocknft2 = Contract.from_abi("mockNft2", dbGet("mocknft_2"), MockERC721.abi)

    return acct, farm, mock0, mock1, mock2, mocknft0, mocknft1, mocknft2

def createMockSetup():

    createMockToken(0, True)
    createMockToken(1, True)
    createMockToken(2, True)
    createMockNft(0, True)
    createMockNft(1, True)
    createMockNft(2, True)
    createFarm()

    acct, farm, mock0, mock1, mock2, mocknft0, mocknft1, mocknft2 = getMocks()

    pointsPerBlock = 25*10**18
    startBlock = chain.height
    bonusEndBlock = chain.height + 400000
    farm.initialize(pointsPerBlock, startBlock, bonusEndBlock, {"from": acct})

    farm.add(10000, mock0, 1, {"from": acct})
    farm.add(11000, mock1, 1, {"from": acct})
    farm.add(12000, mock2, 1, {"from": acct})
    farm.add(20000, mocknft0, 1, {"from": acct})
    farm.add(21000, mocknft1, 1, {"from": acct})
    farm.add(22000, mocknft2, 1, {"from": acct})

    mock0.approve(farm, 2**256-1, {"from": acct})
    mock1.approve(farm, 2**256-1, {"from": acct})
    mock2.approve(farm, 2**256-1, {"from": acct})
    mocknft0.setApprovalForAll(farm, True, {"from": acct})
    mocknft1.setApprovalForAll(farm, True, {"from": acct})
    mocknft2.setApprovalForAll(farm, True, {"from": acct})

    farm.deposit(0, 1000e18, {"from": acct})
    farm.deposit(1, 1000e18, {"from": acct})
    farm.deposit(2, 1000e18, {"from": acct})
    farm.depositNFTs(3, [0, 1, 2], {"from": acct})
    farm.depositNFTs(4, [3, 4, 5], {"from": acct})
    farm.depositNFTs(5, [6, 7, 8], {"from": acct})

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

def createMockNft(count=0, force=False):
    global acct

    if dbGet("mocknft_"+str(count)) != False:
        if force == False:
            print("mocknft_"+str(count)+" already exists! Exiting.")
            return
        else:
            print("mocknft_"+str(count)+" already exists! Overriding.")

    mock = MockERC721.deploy("Mock NFT "+str(count), "MOCKNFT"+(str(count)), {"from": acct})
    mock.mint(acct, 10, {"from": acct})
    dbSet("mocknft_"+str(count), mock.address)

    return mock

def createFarm():
    global acct

    impl = SophonFarming.deploy({'from': acct})
    dbSet("farmLastImpl", impl.address)

    proxy = SophonFarmingProxy.deploy(impl, {'from': acct})
    farm = Contract.from_abi("farm", proxy.address, SophonFarming.abi)
    _add_contract(farm)
    dbSet("farm", farm.address)

    return farm

def upgradeFarm():
    global acct

    farm = getFarm()

    impl = SophonFarming.deploy({'from': acct})
    dbSet("farmLastImpl", impl.address)

    Contract.from_abi("proxy", farm, SophonFarmingProxy.abi).replaceImplementation(impl, {'from': acct})

    return farm

def setLastImpl():
    global acct

    farm = getFarm()

    Contract.from_abi("proxy", farm, SophonFarmingProxy.abi).replaceImplementation(dbGet("farmLastImpl"), {'from': acct})

    return farm

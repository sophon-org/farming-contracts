'''
    // Mainnet ->
    // weth: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
    // stETH: 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84
    // wstETH: 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0

    // ether.fi ETH (eETH): 0x35fA164735182de50811E8e2E824cFb9B6118ac2
    // ether.fi Liquidity Pool: 0x308861A430be4cce5502d0A12724771Fc6DaF216
    // ether.fi Wrapped eETH (weETH): 0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee
    // Renzo ezETH (Renzo Restaked ETH): 0xbf5495Efe5DB9ce00f80364C8B423567e58d2110
    // Kelp Dao rsETH (rsETH): 0xA1290d69c65A6Fe4DF752f95823fae25cB99e5A7
    // Swell rswETH (rswETH): 0xFAe103DC9cf190eD75350761e95403b7b8aFa6c0
    // Bedrock uniETH (Universal ETH): 0xF1376bceF0f78459C0Ed0ba5ddce976F1ddF51F4
    // Puffer pufETH (pufETH): 0xD9A442856C234a39a81a089C06451EBAa4306a72

    // DAI: 0x6B175474E89094C44Da98b954EedeAC495271d0F
    // sDAI: 0x83F20F44975D03b1b09e64809B757c47f942BEeA
'''


from brownie import *
import secrets, pickledb, random
import sys, os, re, csv, json, shutil
from pprint import pprint
import time

from brownie.network import gas_price, gas_limit

NETWORK = network.show_active()

if "fork" not in NETWORK:
    from brownie.network.gas.strategies import LinearScalingStrategy
    gas_strategy = LinearScalingStrategy("5 gwei", "50 gwei", 1.1)
    gas_price(gas_strategy) ## gas_price(20e9)

gas_limit(5000000)

ZERO_ADDRESS = "0x0000000000000000000000000000000000000000"

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
    if "fork" in NETWORK:
        SophonContract = SophonFarmingFork
    else:
        SophonContract = SophonFarming

    return Contract.from_abi("farm", dbGet("farm"), SophonContract.abi)
def getMocks(): ## acct, acct1, acct2, farm, mock0, mock1, weth, stETH, wstETH, eETH, eETHLiquidityPool, weETH, dai, sDAI = run("deploy", "getMocks")
    farm = getFarm()

    mock0 = Contract.from_abi("mock0", dbGet("mock_0"), MockERC20.abi)
    mock1 = Contract.from_abi("mock1", dbGet("mock_1"), MockERC20.abi)

    weth = Contract.from_abi("WETH", dbGet("mock_weth"), MockWETH.abi)
    stETH = Contract.from_abi("stETH", dbGet("mock_steth"), MockStETH.abi)
    wstETH = Contract.from_abi("wstETH", dbGet("mock_wsteth"), MockWstETH.abi)
    eETH = Contract.from_abi("eETH", dbGet("mock_eETH"), MockERC20.abi)
    eETHLiquidityPool = Contract.from_abi("eETHLiquidityPool", dbGet("mock_eETHLiquidityPool"), MockeETHLiquidityPool.abi)
    weETH = Contract.from_abi("weETH", dbGet("mock_weETH"), MockWeETH.abi)

    dai = Contract.from_abi("dai", dbGet("mock_dai"), MockERC20.abi)
    sDAI = Contract.from_abi("sDAI", dbGet("mock_sdai"), MockSDAI.abi)

    if NETWORK == "development":
        acct1 = accounts[1]
        acct2 = accounts[2]
    else:
        acct1 = acct
        acct2 = acct

    return acct, acct1, acct2, farm, mock0, mock1, weth, stETH, wstETH, eETH, eETHLiquidityPool, weETH, dai, sDAI

def createMockSetup(deployTokens = False):
    global acct

    if deployTokens == False:
        acct, acct1, acct2, farm, mock0, mock1, weth, stETH, wstETH, eETH, eETHLiquidityPool, weETH, dai, sDAI = getMocks()

    if deployTokens == True:
        createMockToken(0, True)
        createMockToken(1, True)

    ## mock weth
    if deployTokens == True:
        weth = MockWETH.deploy({"from": acct})
        dbSet("mock_weth", weth.address)

    ## mock stEth
    if deployTokens == True:
        stETH = MockStETH.deploy({"from": acct})
        dbSet("mock_steth", stETH.address)

    ## mock wstEth
    if deployTokens == True:
        wstETH = MockWstETH.deploy(stETH, {"from": acct})
        dbSet("mock_wsteth", wstETH.address)
    wstEthAllocPoint = 20000

    ## mock eETH
    if deployTokens == True:
        eETH = MockERC20.deploy("Mock eETH Token", "MockeETH", 18, {"from": acct})
        dbSet("mock_eETH", eETH.address)

    ## mock eETHLiquidityPool
    if deployTokens == True:
        eETHLiquidityPool = MockeETHLiquidityPool.deploy(eETH, {"from": acct})
        dbSet("mock_eETHLiquidityPool", eETHLiquidityPool.address)

    ## mock weETH
    if deployTokens == True:
        weETH = MockWeETH.deploy(eETH, {"from": acct})
        dbSet("mock_weETH", weETH.address)
    weEthAllocPoint = 20000

    ## mock DAI
    if deployTokens == True:
        dai = MockERC20.deploy("Mock Dai Token", "MockDAI", 18, {"from": acct})
        dai.mint(acct, 1000000e18, {"from": acct})
    dbSet("mock_dai", dai.address)

    ## mock sDAI
    if deployTokens == True:
        sDAI = MockSDAI.deploy(dai, {"from": acct})
        dbSet("mock_sdai", sDAI.address)
    sDAIAllocPoint = 20000

    pointsPerBlock = 100*10**18
    startBlock = chain.height
    boosterMultiplier = 2e18

    createFarm(weth, stETH, wstETH, wstEthAllocPoint, eETH, eETHLiquidityPool, weETH, weEthAllocPoint, dai, sDAI, sDAIAllocPoint, pointsPerBlock, startBlock, boosterMultiplier)

    acct, acct1, acct2, farm, mock0, mock1, weth, stETH, wstETH, eETH, eETHLiquidityPool, weETH, dai, sDAI = getMocks()

    farm.add(10000, mock0, "mock0", {"from": acct})
    farm.add(30000, mock1, "mock1", {"from": acct})


    ## Approvals
    mock0.approve(farm, 2**256-1, {"from": acct})
    mock1.approve(farm, 2**256-1, {"from": acct})
    weth.approve(farm, 2**256-1, {"from": acct})
    stETH.approve(farm, 2**256-1, {"from": acct})
    wstETH.approve(farm, 2**256-1, {"from": acct})
    eETH.approve(farm, 2**256-1, {"from": acct})
    weETH.approve(farm, 2**256-1, {"from": acct})
    dai.approve(farm, 2**256-1, {"from": acct})
    sDAI.approve(farm, 2**256-1, {"from": acct})
    stETH.approve(wstETH, 2**256-1, {"from": acct})
    eETH.approve(weETH, 2**256-1, {"from": acct})
    dai.approve(sDAI, 2**256-1, {"from": acct})

    ## Mint some of all the assets
    mock0.mint(acct, 1000e18, {"from": acct})
    mock1.mint(acct, 1000e18, {"from": acct})
    weth.deposit({"from": acct, "value": 0.01e18})
    stETH.submit(farm, {"from": acct, "value": 0.02e18})
    wstETH.wrap(stETH.balanceOf(acct) / 2, {"from": acct})
    eETHLiquidityPool.deposit(farm, {"from": acct, "value": 0.03e18})
    weETH.wrap(eETH.balanceOf(acct) / 2, {"from": acct})
    dai.mint(acct, 1000e18, {"from": acct})
    sDAI.deposit(dai.balanceOf(acct) / 2, acct, {"from": acct})

    ## Deposit ETH to Lido
    farm.depositEth(0.01e18 * 0.02, 1, {"from": acct, "value": 0.01e18})

    ## Deposit ETH to Ether.fi
    farm.depositEth(0, 2, {"from": acct, "value": 0.02e18})

    ## Deposit ETH Directly
    acct.transfer(to=farm.address, amount=0.01e18)

    ## Deposit Weth to Lido
    farm.depositWeth(weth.balanceOf(acct) / 2, weth.balanceOf(acct) / 2 * 0.05, 1, {"from": acct})

    ## Deposit Weth to Ether.fi
    farm.depositWeth(weth.balanceOf(acct), 0, 2, {"from": acct})

    ## Deposit stEth
    farm.depositStEth(stETH.balanceOf(acct), 0, {"from": acct})

    ## Deposit eEth
    farm.depositeEth(eETH.balanceOf(acct), 0, {"from": acct})

    ## Deposit DAI
    farm.depositDai(dai.balanceOf(acct), dai.balanceOf(acct) * 0.1, {"from": acct})

    ## Deposit Mock0
    farm.deposit(3, 1000e18, 1000e18 * 0.01, {"from": acct})

    ## Deposit Mock1
    farm.deposit(4, 1000e18, 0, {"from": acct})

    if "fork" in NETWORK:
        farm.addBlocks(50, {"from": acct})

    return getMocks()


def testMainnetOnFork():
    global acct

    if "fork" not in NETWORK or "mainnet" not in NETWORK:
        print("Not a mainnet fork!")
        return

    createMockToken(0, True)
    createMockToken(1, True)

    weth = Contract.from_abi("weth", "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2", interface.IWeth.abi)
    dbSet("mock_weth", weth.address)
    acctWeth = accounts.at(weth, force=True)
    acctWeth.transfer(to=acct.address, amount=100e18)

    stETH = Contract.from_abi("stETH", "0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84", MockStETH.abi)
    dbSet("mock_steth", stETH.address)

    wstETH = Contract.from_abi("wstETH", "0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0", MockWstETH.abi)
    dbSet("mock_wsteth", wstETH.address)

    eETH = Contract.from_abi("eETH", "0x35fA164735182de50811E8e2E824cFb9B6118ac2", MockERC20.abi)
    dbSet("mock_eETH", eETH.address)

    eETHLiquidityPool = Contract.from_abi("eETHLiquidityPool", "0x308861A430be4cce5502d0A12724771Fc6DaF216", MockeETHLiquidityPool.abi)
    dbSet("mock_eETHLiquidityPool", eETHLiquidityPool.address)

    weETH = Contract.from_abi("weETH", "0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee", MockWeETH.abi)
    dbSet("mock_weETH", weETH.address)

    dai = Contract.from_abi("dai", "0x6B175474E89094C44Da98b954EedeAC495271d0F", MockERC20.abi)
    dbSet("mock_dai", dai.address)

    sDAI = Contract.from_abi("sDAI", "0x83F20F44975D03b1b09e64809B757c47f942BEeA", MockSDAI.abi)
    dbSet("mock_sdai", sDAI.address)

    wstEthAllocPoint = 20000
    weEthAllocPoint = 20000
    sDAIAllocPoint = 20000
    pointsPerBlock = 25*10**18
    startBlock = chain.height
    boosterMultiplier = 2e18

    createFarm(weth, stETH, wstETH, wstEthAllocPoint, eETH, eETHLiquidityPool, weETH, weEthAllocPoint, dai, sDAI, sDAIAllocPoint, pointsPerBlock, startBlock, boosterMultiplier)

    acct, acct1, acct2, farm, mock0, mock1, weth, stETH, wstETH, eETH, eETHLiquidityPool, weETH, dai, sDAI = getMocks()

    farm.add(10000, mock0, "mock0", {"from": acct})
    farm.add(30000, mock1, "mock1", {"from": acct})


    ## Approvals
    mock0.approve(farm, 2**256-1, {"from": acct})
    mock1.approve(farm, 2**256-1, {"from": acct})
    weth.approve(farm, 2**256-1, {"from": acct})
    stETH.approve(farm, 2**256-1, {"from": acct})
    wstETH.approve(farm, 2**256-1, {"from": acct})
    eETH.approve(farm, 2**256-1, {"from": acct})
    weETH.approve(farm, 2**256-1, {"from": acct})
    dai.approve(farm, 2**256-1, {"from": acct})
    sDAI.approve(farm, 2**256-1, {"from": acct})
    stETH.approve(wstETH, 2**256-1, {"from": acct})
    eETH.approve(weETH, 2**256-1, {"from": acct})
    dai.approve(sDAI, 2**256-1, {"from": acct})

    ## Mint some of all the assets
    mock0.mint(acct, 1000e18, {"from": acct})
    mock1.mint(acct, 1000e18, {"from": acct})
    weth.deposit({"from": acct, "value": 0.01e18})
    stETH.submit(farm, {"from": acct, "value": 0.02e18})
    wstETH.wrap(stETH.balanceOf(acct) / 2, {"from": acct})
    eETHLiquidityPool.deposit(farm, {"from": acct, "value": 0.03e18})
    weETH.wrap(eETH.balanceOf(acct) / 2, {"from": acct})
    dai.transfer(acct, 1000e18, {"from": "0x40ec5B33f54e0E8A33A975908C5BA1c14e5BbbDf"}) ## transfer from Polygon bridge
    sDAI.deposit(dai.balanceOf(acct) / 2, acct, {"from": acct})

    ## Deposit ETH to Lido
    farm.depositEth(0.01e18 * 0.02, 1, {"from": acct, "value": 0.01e18})

    ## Deposit ETH to Ether.fi
    farm.depositEth(0, 2, {"from": acct, "value": 0.02e18})

    ## Deposit ETH Directly
    acct.transfer(to=farm.address, amount=0.01e18)

    ## Deposit Weth to Lido
    farm.depositWeth(weth.balanceOf(acct) / 2, weth.balanceOf(acct) / 2 * 0.05, 1, {"from": acct})

    ## Deposit Weth to Ether.fi
    farm.depositWeth(weth.balanceOf(acct), 0, 2, {"from": acct})

    ## Deposit stEth
    farm.depositStEth(stETH.balanceOf(acct), 0, {"from": acct})

    ## Deposit eEth
    farm.depositeEth(eETH.balanceOf(acct), 0, {"from": acct})

    ## Deposit DAI
    farm.depositDai(dai.balanceOf(acct), dai.balanceOf(acct) * 0.1, {"from": acct})

    ## Deposit Mock0
    farm.deposit(3, 1000e18, 1000e18 * 0.01, {"from": acct})

    ## Deposit Mock1
    farm.deposit(4, 1000e18, 0, {"from": acct})

    if "fork" in NETWORK:
        farm.addBlocks(50, {"from": acct})

    return getMocks()

def sendTestTokens(receiver_list):
    global acct

    acct, acct1, acct2, farm, mock0, mock1, weth, stETH, wstETH, eETH, eETHLiquidityPool, weETH, dai, sDAI = getMocks()

    user_count = len(receiver_list)

    weth.deposit({"from": acct, "value": 0.01e18 * user_count})
    stETH.submit(acct, {"from": acct, "value": 0.01e18 * user_count})
    eETHLiquidityPool.deposit(acct, {"from": acct, "value": 0.01e18 * user_count})
    dai.mint(acct, 1000e18 * user_count, {"from": acct})

    wstETH.wrap(stETH.balanceOf(acct) // 2, {"from": acct})
    weETH.wrap(eETH.balanceOf(acct) // 2, {"from": acct})
    sDAI.deposit(dai.balanceOf(acct) // 2, acct, {"from": acct})

    weth_amount = weth.balanceOf(acct) // user_count
    stETH_amount = stETH.balanceOf(acct) // user_count
    wstETH_amount = wstETH.balanceOf(acct) // user_count
    eETH_amount = eETH.balanceOf(acct) // user_count
    weETH_amount = weETH.balanceOf(acct) // user_count
    dai_amount = dai.balanceOf(acct) // user_count
    sDAI_amount = sDAI.balanceOf(acct) // user_count

    for receiver in receiver_list:
        print("Distributing to:", receiver)
        mock0.mint(receiver, 1000e18, {"from": acct})
        mock1.mint(receiver, 1000e18, {"from": acct})
        if receiver != acct.address:
            weth.transfer(receiver, weth_amount, {"from": acct})
            stETH.transfer(receiver, stETH_amount, {"from": acct})
            wstETH.transfer(receiver, wstETH_amount, {"from": acct})
            eETH.transfer(receiver, eETH_amount, {"from": acct})
            weETH.transfer(receiver, weETH_amount, {"from": acct})
            dai.transfer(receiver, dai_amount, {"from": acct})
            sDAI.transfer(receiver, sDAI_amount, {"from": acct})

    return acct, acct1, acct2, farm, mock0, mock1, weth, stETH, wstETH, eETH, eETHLiquidityPool, weETH, dai, sDAI

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

def createFarm(weth, stETH, wstETH, wstEthAllocPoint, eETH, eETHLiquidityPool, weETH, weEthAllocPoint, dai, sDAI, sDAIAllocPoint, pointsPerBlock, startBlock, boosterMultiplier):
    global acct

    if "fork" in NETWORK:
        SophonContract = SophonFarmingFork
    else:
        SophonContract = SophonFarming

    impl = SophonContract.deploy([
        dai,
        sDAI,
        weth,
        stETH,
        wstETH,
        eETH,
        eETHLiquidityPool,
        weETH
    ], {'from': acct, "gas_limit": 10000000})
    dbSet("farmLastImpl", impl.address)

    proxy = SophonFarmingProxy.deploy(impl, {'from': acct})
    farm = Contract.from_abi("farm", proxy.address, SophonContract.abi)
    dbSet("farm", farm.address)

    farm.initialize(wstEthAllocPoint, weEthAllocPoint, sDAIAllocPoint, pointsPerBlock, startBlock, boosterMultiplier, {'from': acct})

    return farm

def upgradeFarm():
    acct, acct1, acct2, farm, mock0, mock1, weth, stETH, wstETH, eETH, eETHLiquidityPool, weETH, dai, sDAI = getMocks()

    if "fork" in NETWORK:
        SophonContract = SophonFarmingFork
    else:
        SophonContract = SophonFarming

    impl = SophonContract.deploy([
        dai,
        sDAI,
        weth,
        stETH,
        wstETH,
        eETH,
        eETHLiquidityPool,
        weETH
    ], {'from': acct, "gas_limit": 10000000})
    dbSet("farmLastImpl", impl.address)

    Contract.from_abi("proxy", farm, SophonFarmingProxy.abi).replaceImplementation(impl, {'from': acct})
    Contract.from_abi("impl", impl, SophonContract.abi).becomeImplementation(farm, {'from': acct})

    return farm

def setLastImpl():
    global acct

    farm = getFarm()

    Contract.from_abi("proxy", farm, SophonFarmingProxy.abi).replaceImplementation(dbGet("farmLastImpl"), {'from': acct})
    Contract.from_abi("impl", dbGet("farmLastImpl"), SophonFarming.abi).becomeImplementation(farm, {'from': acct})

    return farm

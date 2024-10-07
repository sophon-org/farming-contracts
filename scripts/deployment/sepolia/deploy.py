from brownie import network, web3



# deployer = accounts[0]
deployer = accounts.load("sophon_sepolia")



# # below is just global gas setup to fast transaction mining
# from web3.gas_strategies.time_based import fast_gas_price_strategy
# web3.eth.set_gas_price_strategy(fast_gas_price_strategy)


# Define the fixed gas price (in wei)
FIXED_GAS_PRICE = web3.to_wei(100, 'gwei')

# Custom gas price strategy function
def fixed_gas_price_strategy(web3, transaction_params=None):
    return FIXED_GAS_PRICE

web3.eth.set_gas_price_strategy(fixed_gas_price_strategy)


weth = MockWETH.deploy({"from": deployer})
stETH = MockStETH.deploy({"from": deployer})
wstETH = MockWstETH.deploy(stETH, {"from": deployer})
eETH = MockERC20.deploy("Mock eETH Token", "MockeETH", 18, {"from": deployer})
eETHLiquidityPool = MockeETHLiquidityPool.deploy(eETH, {"from": deployer})
weETH = MockWeETH.deploy(eETH, {"from": deployer})
dai = MockERC20.deploy("Mock Dai Token", "MockDAI", 18, {"from": deployer})
sDAI = MockSDAI.deploy(dai, {"from": deployer})


pointsPerBlock = 10*10**18
startBlock = chain.height + 100
boosterMultiplier = 5e18
wstETHAllocPoint = 0
sDAIAllocPoint = 0
weEthAllocPoint = 0

args = [
    dai.address,
    sDAI.address,
    weth.address,
    stETH.address,
    wstETH.address,
    eETH.address,
    eETHLiquidityPool.address,
    weETH.address
]

SFImpl = SophonFarming.deploy(args, {'from': deployer})

SFProxy = SophonFarmingProxy.deploy(SFImpl, {"from": deployer})

SF = interface.ISophonFarming(SFProxy)

SF.initialize(wstETHAllocPoint, weEthAllocPoint, sDAIAllocPoint, pointsPerBlock, startBlock, boosterMultiplier, {'from': deployer})
SF.setEndBlock(chain.height+10000, 2000, {"from": deployer})


BEAM = MockERC20.deploy("Mock BEAM Token", "MockBEAM", 18, {"from": deployer})
SF.add(20000, BEAM, "BEAM description", chain.height, 0, {"from": deployer})



 
FACTORY = interface.IUniswapV2Factory("0x734583f62Bb6ACe3c9bA9bd5A53143CA2Ce8C55A") # sepolia
# FACTORY = interface.IUniswapV2Factory("0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac") # mainnet

FACTORY.createPair(BEAM, weth, {"from": deployer})
pair = FACTORY.getPair(BEAM, weth)


SF.add(80000, pair, "BEAM_LP description", chain.height, 0, {"from": deployer})




stZENT = MockERC20.deploy("Mock ZENT Token", "MockeZENT", 18, {"from": deployer})

SF.add(60000, ZENT, "ZENT description", chain.height, 0, {"from": deployer})


 ## wstETH
SF.set(1, 100000, chain.height, 0, {"from": deployer})

## weETH
SF.set(2, 50000, chain.height, 25e18, {"from": deployer}) ## note: updating pointsPerBlock!

print("SF", SF)
print("WETH", weth)
print("DAI", dai)
print("sDAI", sDAI)
print("wstETH", wstETH)
print("weETH", weETH)
print("BEAM", BEAM)
print("stZENT", stZENT)

# SF 0xe80f651aCCb1574DD2D84021cf1d27862363E390
# WETH 0x01cB5735e54F69739e8917c709fa0B4a9E95ACc6
# DAI 0xd7D2ae4Fb61a0bd126Bd865a68A238d7d81DC641
# sDAI 0x64555DD79DA6Bd9E9293d630AbAE7C1f8FAC1Dd7
# wstETH 0xCdB9b24fe84448175b8Ab821E4c42d7Db176C732
# weETH 0x1ac4090094F44cfb41417D8772500DB051D32b32
# BEAM 0x2E8F9867d1b3e5e94Cd86D3924419767A243e15C


# test tokens
testWallets = [
    "0xe749b7469A9911E451600CB31B5Ca180743183cE",
    "0x75e529F523E41623F45d794eF1C023caF6E2d295",
    "0x3c902069BE2eAfB251102446b22D1b054013B998",
    "0xfBAb39445f51C123194eeD79894D5847Fd794Aa8",
    "0x1c9Ff39402b15e9A7C67ffd1A260d04d852F5DFe",
    "0x3D2758B432327E3631b023AA4a0511c5308e4BFC",
    "0x78Ae12562527B865DD1a06784a2b06dbe1A3C7AF",
    "0xe5b06bfd663C94005B8b159Cd320Fd7976549f9b",
    "0x81B76cDeE6217545Bdc860fC1379eC23888BeA9a",
    "0x4bC73dCc4c296d744C7E0E215B309Fd5304a6094"
]


for wallet in testWallets:
    dai.mint(wallet, 100000e18, {"from": deployer, "gas_limit": 1000000})
    BEAM.mint(wallet, 100000e18, {"from": deployer, "gas_limit": 1000000})
    stZENT.mint(wallet, 100000e18, {"from": deployer, "gas_limit": 1000000})
    
    

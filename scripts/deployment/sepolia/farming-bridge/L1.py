# This script is is the proof of concept that shows everythign you need to do
# to bridge funds to L2.

# prerequisites address of deployed SF-L2
SF_L2 = "0x4c98cB92EF417DC278cAe17faee647ca43f53301"
# this is to be run on SEPOLIA

# I am going to use existing deployments for sepolia tokens. however new SF contract

exec(open("./scripts/env/sepolia.py").read())

FIXED_GAS_PRICE = web3.to_wei(30, 'gwei')

# Custom gas price strategy function
def fixed_gas_price_strategy(web3, transaction_params=None):
    return FIXED_GAS_PRICE

web3.eth.set_gas_price_strategy(fixed_gas_price_strategy)

# deploy SF. I don't wanna mess with testnet deployment
deployer = accounts.load("sophon_sepolia")
user1 = accounts.load("0xe749b7469A9911E451600CB31B5Ca180743183cE")

args = [
        DAI.address,
        sDAI.address,
        "0x01cB5735e54F69739e8917c709fa0B4a9E95ACc6", # weth
        stETH.address,
        wstETH.address,
        eETH.address,
        SF.eETHLiquidityPool(),
        weETH.address,
    ]

SFImpl = SophonFarming.deploy(args, SOPHON_CHAIN_ID, {'from': deployer})

SFProxy = SophonFarmingProxy.deploy(SFImpl, {"from": deployer})

SF_L1 = interface.ISophonFarming(SFProxy)

wstETHAllocPoint = 20000
wstETHAllocPoint = 20000
sDAIAllocPoint = 20000
pointsPerBlock      = 25e18
startBlock          = 0  ## will be set to current block in initialize
boosterMultiplier   = 3e18

SF_L1.initialize(wstETHAllocPoint, wstETHAllocPoint, sDAIAllocPoint, pointsPerBlock, startBlock, boosterMultiplier, {'from': deployer})
SF_L1.setEndBlock(chain.height+100000, 2000, {"from": deployer})



SF_L1.set(PredefinedPool.sDAI, 20000, chain.height, 0, {"from": deployer})

SF_L1.set(PredefinedPool.wstETH, 20000, chain.height, 0, {"from": deployer})


# TEST MAke some users


DAI.mint(user1, 1e6*1e18, {"from": user1})
DAI.approve(sDAI, 2**256-1, {"from": user1})

sDAI.deposit(1e6*1e18, user1, {"from": user1})
sDAI.approve(SF_L1, 2**256-1, {"from": user1})

SF_L1.deposit(0, sDAI.balanceOf(user1), 0, {"from": user1})

# END FARMING

# chain.mine(SF_L1.endBlock() - chain.height)
# chain.mine()

# or setEndBlock 

SF_L1.setEndBlock(chain.height+1, 1, {"from": deployer})

# set bridge
SF_L1.setBridge(BRIDGEHUB, {"from": deployer})

# poolInfo = SF_L1.getPoolInfo()
# for index, fruit in enumerate(poolInfo):
#     SF_L1.setL2Farm(index, SF_L2, {"from": deployer})
#     SF_L1.bridgePool(index, 1000000, 800, {'from': deployer,"value": Wei("0.1 ether")})


# testing only 1 pool bridge
SF_L1.setL2Farm(0, SF_L2, {"from": deployer})
# chainId = 0 # filled by the contract
mintValue = 100e18 # SOPH transaction cost

SOPH.transfer(user1, 100e18, {"from": deployer})
SOPH.approve(SF_L1, 2**256-1, {"from": user1})
SF_L1.bridgePool(0, mintValue, SOPH, {"from": user1}) 

# <ISophonFarming Contract '0x36DA750Ad20566Ad5197C255DaFB69f129Cfd6F5'>
SF_L1 = interface.ISophonFarming("0x36DA750Ad20566Ad5197C255DaFB69f129Cfd6F5")

# >>> SF_L1.getPoolInfo()
# (('0x64555DD79DA6Bd9E9293d630AbAE7C1f8FAC1Dd7', '0x4c98cB92EF417DC278cAe17faee647ca43f53301', 1879452157034848486000000, 0, 1879452157034848486000000, 20000, 6493475, 4433916182511, 8333333333333333333, 'sDAI'), 
#  ('0xCdB9b24fe84448175b8Ab821E4c42d7Db176C732', '0x0000000000000000000000000000000000000000', 0, 0, 0, 20000, 6493470, 0, 0, 'wstETH'), ('0x1ac4090094F44cfb41417D8772500DB051D32b32', '0x0000000000000000000000000000000000000000', 0, 0, 0, 20000, 6493470, 0, 0, 'weETH')

# >>> SF_L1.userInfo(0, user1)
# (1879452157034848486000000, 0, 1879452157034848486000000, 0, 0)
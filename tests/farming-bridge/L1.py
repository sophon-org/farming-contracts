# This script is is the proof of concept that shows everythign you need to do
# to bridge funds to L2.

# prerequisites address of deployed SF-L2
SF_L2 = "0x17cA6CfB56fE7105ED1eE58ed572Fa902Dec8182"
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

args = [
        DAI.address,
        sDAI.address,
        "0x01cB5735e54F69739e8917c709fa0B4a9E95ACc6", # weth
        stETH.address,
        wstETH.address,
        eETH.address,
        SF.eETHLiquidityPool(),
        weETH.address
    ]

SFImpl = SophonFarming.deploy(args, {'from': deployer})

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
user1 = accounts.load("0xe749b7469A9911E451600CB31B5Ca180743183cE")

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
SF_L1.setBridge("0x2Ae09702F77a4940621572fBcDAe2382D44a2cbA", {"from": deployer})

# poolInfo = SF_L1.getPoolInfo()
# for index, fruit in enumerate(poolInfo):
#     SF_L1.setL2Farm(index, SF_L2, {"from": deployer})
#     SF_L1.bridgePool(index, 1000000, 800, {'from': deployer,"value": Wei("0.1 ether")})


# testing only 1 pool bridge
SF_L1.setL2Farm(0, SF_L2, {"from": deployer})
SF_L1.bridgePool(0, 2000000, 800, {"from": deployer, "value": Wei("0.1 ether")}) # fyi 800 is hard coded constant.


# <ISophonFarming Contract '0x49e7a74efb1149824972fdd4E18D47Ac9B90A910'> SF_L1
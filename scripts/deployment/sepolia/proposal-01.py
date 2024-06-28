from brownie_safe import BrownieSafe
from brownie import *
from gnosis.safe.enums import SafeOperationEnum

exec(open("./scripts/env/sepolia.py").read())
deployer = accounts.load("sophon_sepolia")

# testnet only. create tokens

# stAethir - 50000
# PEPE - 40000
# USDC - 60000
# sDAI - 60000

newPointsPerBlock = 46e18
USDC = MockERC20.deploy("Mock USDC Token", "MockUSDC", 6, {"from": deployer})
PEPE = MockERC20.deploy("Mock PEPE Token", "MockPEPE", 18, {"from": deployer})
stAethir = MockERC20.deploy("Mock stAethir Token", "MockstAethir", 18, {"from": deployer})

SF.set(PredefinedPool.sDAI, 60000, chain.height, 0, {"from": deployer})
SF.add(60000, USDC, "USDC", chain.height, 0, {"from": deployer})
SF.add(50000, stAethir, "stAethir", chain.height, 0, {"from": deployer})
SF.add(40000, PEPE, "PEPE", chain.height, newPointsPerBlock, {"from": deployer})




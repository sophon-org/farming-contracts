from brownie_safe import BrownieSafe
from brownie import *
from gnosis.safe.enums import SafeOperationEnum

exec(open("./scripts/env/sepolia.py").read())
deployer = accounts.load("sophon_sepolia")

# testnet only. 
# 1. this deploys AZUR and stAZUR mocks.
# 2. add AZUR to the SF
# 3. migrates AZUR to stAZUR

# stAethir - 50000
# PEPE - 40000
# USDC - 60000
# sDAI - 60000

AZURPoints = 60000

newPointsPerBlock = SF.pointsPerBlock() + (AZURPoints) *1e14


AZUR = MockAZUR.deploy("Mock AZUR Token", "MockAZUR", 18, {"from": deployer})
stAZUR = MockstAZUR.deploy("Mock stAZUR Token", "MockstAZUR", 18, {"from": deployer})

SF.add(AZURPoints, AZUR, "AZUR", chain.height, newPointsPerBlock, {"from": deployer})





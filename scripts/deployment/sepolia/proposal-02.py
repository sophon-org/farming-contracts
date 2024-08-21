from brownie_safe import BrownieSafe
from brownie import *
from gnosis.safe.enums import SafeOperationEnum

exec(open("./scripts/env/sepolia.py").read())
deployer = accounts.load("sophon_sepolia")

# testnet only. 
# 1. this deploys AZUR and stAZUR mocks.
# 2. add AZUR to the SF



AZURPoints = 20000

newPointsPerBlock = SF.pointsPerBlock() + (AZURPoints) *1e14


AZUR = MockAZUR.deploy("Mock AZUR Token", "MockAZUR", 18, {"from": deployer})
stAZUR = MockstAZUR.deploy(AZUR, "Mock stAZUR Token", "MockstAZUR", {"from": deployer})

SF.add(AZURPoints, AZUR, "AZUR", chain.height, newPointsPerBlock, {"from": deployer})




testWallets = [
    "0xe749b7469A9911E451600CB31B5Ca180743183cE",
    "0x75e529F523E41623F45d794eF1C023caF6E2d295",
    "0x3c902069BE2eAfB251102446b22D1b054013B998",
    "0xfBAb39445f51C123194eeD79894D5847Fd794Aa8"
]

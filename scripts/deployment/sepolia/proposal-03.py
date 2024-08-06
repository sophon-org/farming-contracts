from brownie_safe import BrownieSafe
from brownie import *
from gnosis.safe.enums import SafeOperationEnum

exec(open("./scripts/env/sepolia.py").read())
deployer = accounts.load("sophon_sepolia")

# testnet only. 
# 1. upgrade SophonFarming
# 2. migrates AZUR to stAZUR

args = [
    DAI,
    sDAI,
    WETH,
    stETH,
    wstETH,
    eETH,
    SF.eETHLiquidityPool(),
    weETH
]

SFImpl = SophonFarmingFork.deploy(args, {'from': deployer})
SF.replaceImplementation(SFImpl, {'from': deployer})
SFImpl.becomeImplementation(SF, {'from': deployer})

# testing
# user = accounts.at("0xe749b7469A9911E451600CB31B5Ca180743183cE", True)
# AZUR.approve(SF, 2**256-1, {"from": user})
# SF.deposit(12, AZUR.balanceOf(user), 0, {"from": user})

SF.migrateAzur(stAZUR, 12, {"from": deployer})
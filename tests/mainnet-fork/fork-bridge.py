exec(open("./scripts/env/sepolia.py").read())
deployer = accounts.load("sophon_sepolia")

BEAM.mint(deployer, 1000e18, {"from": deployer})
BEAM.approve(SF, 2**256-1, {"from": deployer})
SF.deposit(PredefinedPool.BEAM, 1000e18, 0 , {"from": deployer})

bridgeL1 = interface.IL1ERC20Bridge("0x2Ae09702F77a4940621572fBcDAe2382D44a2cbA")
SF.setBridge(bridgeL1, {"from": deployer})

args = [
    SF.dai(),
    SF.sDAI(),
    SF.weth(),
    SF.stETH(),
    SF.wstETH(),
    SF.eETH(),
    SF.eETHLiquidityPool(),
    SF.weETH()
]
SFImpl = SophonFarmingFork.deploy(args, {'from': deployer})

SF.replaceImplementation(SFImpl, {'from': deployer})
SFImpl.becomeImplementation(SF, {'from': deployer})
SFF = SophonFarmingFork.at(SF)

SFF.setEndBlockForWithdrawals(chain.height, {"from": deployer})

SFF.setL2Farm(PredefinedPool.BEAM, deployer, {"from": deployer})





SF.bridgePool(PredefinedPool.BEAM, 1000000, 800, {'from': deployer,"value": Wei("0.1 ether")})
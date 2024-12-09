deployer = accounts.load("sophon_sepolia")

SFImpl = SophonFarmingL2.deploy({'from': deployer})

SFProxy = SophonFarmingProxy.deploy(SFImpl, {"from": deployer})

SF_L2 = interface.ISophonFarming(SFProxy)

SF_L2.setEndBlock(chain.height+10000, 2000, {"from": deployer})


# sophon-testnet
# <SophonFarmingProxy Contract '0x4c98cB92EF417DC278cAe17faee647ca43f53301'>

SF_L2 = interface.ISophonFarming("0x4c98cB92EF417DC278cAe17faee647ca43f53301")
sDAI = interface.IERC20Metadata("0xE70a7d8563074D6510F550Ba547874C3C2a6F81F")

deployer = accounts.load("sophon_sepolia")

SFImpl = SophonFarmingL2.deploy({'from': deployer})

SFProxy = SophonFarmingProxy.deploy(SFImpl, {"from": deployer})

SF_L2 = interface.ISophonFarming(SFProxy)

SF_L2.setEndBlock(chain.height+10000, 2000, {"from": deployer})

# 0xA77588ebf19bD40a93927fFA50e1D298076E00A7 https://sepolia.era.zksync.dev

# zksync
# <SophonFarmingL2 Contract '0x4c98cB92EF417DC278cAe17faee647ca43f53301'>
# <SophonFarmingProxy Contract '0x17cA6CfB56fE7105ED1eE58ed572Fa902Dec8182'>

# SF_L2 = interface.ISophonFarming(SFProxy)
SF_L2 = interface.ISophonFarming("0x17cA6CfB56fE7105ED1eE58ed572Fa902Dec8182")

# >>> SF_L1.pendingPoints(0, user1)
# 8333333333332959618
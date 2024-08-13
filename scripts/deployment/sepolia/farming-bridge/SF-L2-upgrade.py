
deployer = accounts.load("sophon_sepolia")
SF_L2 = interface.ISophonFarming("0x17cA6CfB56fE7105ED1eE58ed572Fa902Dec8182")

SFImpl = SophonFarmingL2.deploy({'from': deployer})

SF_L2.replaceImplementation(SFImpl, {'from': deployer})
SFImpl.becomeImplementation(SF_L2, {'from': deployer})
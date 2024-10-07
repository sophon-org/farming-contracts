
deployer = accounts.load("sophon_sepolia")
SF_L2 = interface.ISophonFarming("0x4c98cB92EF417DC278cAe17faee647ca43f53301")

SFImpl = SophonFarmingL2.deploy({'from': deployer})

SF_L2.replaceImplementation(SFImpl, {'from': deployer})
SFImpl.becomeImplementation(SF_L2, {'from': deployer})
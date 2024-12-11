
deployer = accounts.load("sophon_sepolia")
exec(open("./scripts/env/sophon-testnet.py").read())

SFImpl = SophonFarmingL2.deploy(MA.address, STORK.address, {'from': deployer})

SF_L2.replaceImplementation(SFImpl, {'from': deployer})
SFImpl.becomeImplementation(SF_L2, {'from': deployer})
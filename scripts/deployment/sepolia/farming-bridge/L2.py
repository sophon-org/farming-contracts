# this file show proof of concept on how to set everything on L2 for farming to start for the users
# this is to be run on ZK-SYNC ERA
SF_L2 = interface.ISophonFarming("0x4c98cB92EF417DC278cAe17faee647ca43f53301")
SF_L2 = SophonFarmingL2.at("0x4c98cB92EF417DC278cAe17faee647ca43f53301")

sDAI = interface.IERC20Metadata("0x97EE70aBf079767B243368Fd4765aaDf9C10c9B3") # Mock Savings Dai 

deployer = accounts.load("sophon_sepolia")
user1 = accounts.load("0xe749b7469A9911E451600CB31B5Ca180743183cE")


SF_L2.addPool(sDAI, ZERO_ADDRESS, 1879452157034848486000000, 0, 1879452157034848486000000, 20000, 6493475, 4433916182511, 8333333333333333333, 'sDAI', {"from": deployer})
merkleProof = "262cb7884ca368153e85da84ed74a9bf258830d22b5527a9c1a71d4f406e74c3"
SF_L2.setMerkleRoot(merkleProof, {"from": deployer})

userInfo = (1879452157034848486000000, 0, 1879452157034848486000000, 0, 0) # from L1
userInfo2 = (2000, 200, 1800, 1000, 400)

proofs = [ 'a4b20e3e86473994a32ea5ac362de701dc31b155f689b374a375416d15a45620' ]
SF_L2.verifyProof(merkleProof, proofs, user1, userInfo2, 0)
 

SF_L2.claim(2, user1, userInfo, 0, [ 'a4b20e3e86473994a32ea5ac362de701dc31b155f689b374a375416d15a45620' ], {"from": user1})
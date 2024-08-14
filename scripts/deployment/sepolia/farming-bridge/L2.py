# this file show proof of concept on how to set everything on L2 for farming to start for the users
# this is to be run on ZK-SYNC ERA
SF_L2 = interface.ISophonFarming("0x4c98cB92EF417DC278cAe17faee647ca43f53301")
SF_L2 = SophonFarmingL2.at("0x4c98cB92EF417DC278cAe17faee647ca43f53301")

sDAI = interface.IERC20Metadata("0x97EE70aBf079767B243368Fd4765aaDf9C10c9B3") # Mock Savings Dai 

deployer = accounts.load("sophon_sepolia")
user1 = accounts.load("0xe749b7469A9911E451600CB31B5Ca180743183cE")


SF_L2.addPool(sDAI, ZERO_ADDRESS, 1879452157034848486000000, 0, 1879452157034848486000000, 20000, 6493475, 4433916182511, 8333333333333333333, 'sDAI', {"from": deployer})
merkleProof = "0x39cc287dd9487dd02b255be5fa1bead67ce6441262d4aec83c97b2438b709136"
SF_L2.setMerkleRoot(merkleProof, {"from": deployer})

userInfo = (1879452157034848486000000, 0, 1879452157034848486000000, 0, 0) # from L1
userInfo2 = (2000, 200, 1800, 1000, 400)

proofs = [ '0xcf1194336ad6101f790bf8428ba6ad13a1f6fbd67392bdc843800eb313b0c6bc' ]
SF_L2.verifyProof(merkleProof, proofs, 2, user1, userInfo2, 0)
 

SF_L2.claim(2, user1, userInfo, 0, [ '0xa4b20e3e86473994a32ea5ac362de701dc31b155f689b374a375416d15a45620' ], {"from": user1})
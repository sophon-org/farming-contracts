
deployer = accounts.load("sophon_sepolia")
exec(open("./scripts/env/sophon-testnet.py").read())

SFImpl = SophonFarmingL2.deploy(MA.address, PF.address, {'from': deployer, 'paymaster_address': "0x98546B226dbbA8230cf620635a1e4ab01F6A99B2"})

SF_L2.replaceImplementation(SFImpl, {'from': deployer, 'paymaster_address': "0x98546B226dbbA8230cf620635a1e4ab01F6A99B2"})
SFImpl.becomeImplementation(SF_L2, {'from': deployer})



# PFProxy = SophonFarmingProxy.at(PF)
PFImpl = PriceFeeds.deploy(STORK.address, {'from': deployer})
PF.replaceImplementation(PFImpl, {'from': deployer})
PFImpl.becomeImplementation(PF.address, {'from': deployer})
# PFProxy = SophonFarmingProxy.deploy(PFImpl.address, {"from": deployer})


MAImpl = MerkleAirdrop.deploy({"from": deployer, 'paymaster_address': "0x98546B226dbbA8230cf620635a1e4ab01F6A99B2"})
MA.upgradeToAndCall(MAImpl, b'', {"from": deployer, 'paymaster_address': "0x98546B226dbbA8230cf620635a1e4ab01F6A99B2"})



import json
file_path = ('./scripts/merkle-l2/output/5-proof.json')
with open(file_path, 'r', encoding='utf-8') as file:
    data = json.load(file)
    claims = data.get('claims', [])
    user = claims["0x3c902069be2eafb251102446b22d1b054013b998"]
    pids = []
    userInfos = []
    proofs = []
    
    for pid, pool in enumerate(user):
        # pids.append(pool["pid"])
        # userInfos.append((pool["amount"], pool["boostAmount"], pool["depositAmount"], pool["rewardSettled"], pool["rewardDebt"]))
        # proofs.append(pool["proof"])
        print(pool)
        # MA.claim.transact(user["user"], 
        #                   user["pid"], 
        #                   (user["amount"], user["boostAmount"], user["depositAmount"], user["rewardSettled"], user["rewardDebt"]), 
        #                   user["proof"], 
        #                   {"from": a, 'paymaster_address': "0x98546B226dbbA8230cf620635a1e4ab01F6A99B2"})
        # MA.unclaim("0xe749b7469A9911E451600CB31B5Ca180743183cE", pool["pid"], 
        #            {"from": deployer, 'paymaster_address': "0x98546B226dbbA8230cf620635a1e4ab01F6A99B2"})
        # SF_L2.updateUserInfo1(a.address, pool["pid"], (0,0,0,0,0), 
        #                       {"from": deployer, 'paymaster_address': "0x98546B226dbbA8230cf620635a1e4ab01F6A99B2"});

    # MA.claimMultiple(a, pids, userInfos, proofs, {"from": a, 'paymaster_address': "0x98546B226dbbA8230cf620635a1e4ab01F6A99B2"})


arr = [
"ZeroAddress()",
"CountMismatch()",
"InvalidCall()",
"InvalidType()",
"TypeMismatch()",
"InvalidStaleSeconds()",
]
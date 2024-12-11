
deployer = accounts.load("sophon_sepolia")
exec(open("./scripts/env/sophon-testnet.py").read())

SFImpl = SophonFarmingL2.deploy(MA.address, STORK.address, {'from': deployer, 'paymaster_address': "0x98546B226dbbA8230cf620635a1e4ab01F6A99B2"})

SF_L2.replaceImplementation(SFImpl, {'from': deployer, 'paymaster_address': "0x98546B226dbbA8230cf620635a1e4ab01F6A99B2"})
SFImpl.becomeImplementation(SF_L2, {'from': deployer})


MAImpl = MerkleAirdrop.deploy({"from": deployer, 'paymaster_address': "0x98546B226dbbA8230cf620635a1e4ab01F6A99B2"})
MA.upgradeToAndCall(MAImpl, b'', {"from": deployer, 'paymaster_address': "0x98546B226dbbA8230cf620635a1e4ab01F6A99B2"})



import json
file_path = ('./scripts/merkle-l2/output/5-proof.json')
with open(file_path, 'r', encoding='utf-8') as file:
    data = json.load(file)
    claims = data.get('claims', [])
    user = claims["0xe749b7469a9911e451600cb31b5ca180743183ce"]
    pids = []
    userInfos = []
    proofs = []
    
    for pid, pool in enumerate(user):
        # pids.append(pool["pid"])
        # userInfos.append((pool["amount"], pool["boostAmount"], pool["depositAmount"], pool["rewardSettled"], pool["rewardDebt"]))
        # proofs.append(pool["proof"])
        print(pool)
        MA.claim.transact(pool["user"], 
                          pool["pid"], 
                          (pool["amount"], pool["boostAmount"], pool["depositAmount"], pool["rewardSettled"], pool["rewardDebt"]), 
                          pool["proof"], 
                          {"from": a, 'paymaster_address': "0x98546B226dbbA8230cf620635a1e4ab01F6A99B2"})
        # MA.unclaim("0xe749b7469A9911E451600CB31B5Ca180743183cE", pool["pid"], 
        #            {"from": deployer, 'paymaster_address': "0x98546B226dbbA8230cf620635a1e4ab01F6A99B2"})
        # SF_L2.updateUserInfo1(a.address, pool["pid"], (0,0,0,0,0), 
        #                       {"from": deployer, 'paymaster_address': "0x98546B226dbbA8230cf620635a1e4ab01F6A99B2"});

    # MA.claimMultiple(a, pids, userInfos, proofs, {"from": a, 'paymaster_address': "0x98546B226dbbA8230cf620635a1e4ab01F6A99B2"})

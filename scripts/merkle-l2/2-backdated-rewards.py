import json
from decimal import Decimal
file_path = ('./scripts/merkle-l2/output/1-userinfo-poolinfo.json')


total_amount = 0
total_boost_amount = 0
total_deposit_amount = 0

l1_end_block = 722631; # SF.endBlock()
l2_start_block = 723631; # just guessing for now 1000 blocks
l1_pool_pointsPerBlock = 71000000000000000000 #SF.pointsPerBlock()
blockMultiplier = (l2_start_block - l1_end_block) * 1e18;
l1_totalAllocPoint = 770000 # SF.totalAllocPoint()ss

global_accPointsPerShare  = {}

with open(file_path, 'r', encoding='utf-8') as file:
    data = json.load(file)
    users = data.get('users', [])
    pools = data.get('pools', [])
    
    
    for index, pool in enumerate(pools):
        l1_allocPoint = int(pool["allocPoint"])
        l1_totalAllocPoint = int(pool["accPointsPerShare"])
        l1_pool_amount = int(pool["amount"])
        accPointsPerShare = 0
        if l1_pool_amount > 0: # skip empty pools
            pointReward = blockMultiplier * l1_pool_pointsPerBlock * l1_allocPoint / l1_totalAllocPoint
            accPointsPerShare = pointReward / l1_pool_amount
        else:
            pointReward = 0
        
        pool["new_accPointsPerShare"] = accPointsPerShare
        global_accPointsPerShare[str(index)] = accPointsPerShare
        
	
    for user in users:
        print(user)
        l1_user_amount = int(user["userInfo"]["amount"])
        pid = user["pid"]
        rewardSettled = l1_user_amount * global_accPointsPerShare[pid] / 1e18;
        user["userInfo"]["new_rewardSettled"] = str(int(rewardSettled))
        
    data = {
        "pools": pools,
        "users": users
    }
    
    
json_data = json.dumps(data, indent=4)
filename = "./scripts/merkle-l2/output/2-backdated-rewards.json"

# Open the file in write mode and use json.dump() to write the data
with open(filename, 'w') as file:
    json.dump(data, file, indent=4)

# Optionally, print a confirmation
print(f"Data has been dumped into {filename}")
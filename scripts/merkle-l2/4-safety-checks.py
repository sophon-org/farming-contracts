import json
from decimal import Decimal
file_path = ('./scripts/merkle-l2/output/2-backdated-rewards.json')


# there are couple of rules to verify
# user.amount = user.boostAmount + user.depositAmount
# pool.amount = pool.boostAmount + pool.depositAmount
# pool.heldAmount = pool.boostAmount / 5 - boosterMultiplier that wasn't changed from the begining



total_amount = 0
total_boost_amount = 0
total_deposit_amount = 0

with open(file_path, 'r', encoding='utf-8') as file:
    data = json.load(file)
    users = data.get('users', [])
    pools = data.get('pools', [])
    
    
    for pool in pools:
        pool['total_amount'] = 0
        pool['total_boost_amount'] = 0
        pool['total_deposit_amount'] = 0
        pool['total_total_rewards'] = 0
    
    for index, user in enumerate(users):
        amount = int(user['userInfo']['amount'])
        boost_amount = int(user['userInfo']['boostAmount'])
        deposit_amount = int(user['userInfo']['depositAmount'])
        new_total_rewards = int(user['userInfo']['new_rewardSettled'])
        assert amount == boost_amount + deposit_amount
            
        pools[int(user.get('pid'))]["total_amount"] += amount
        pools[int(user.get('pid'))]["total_boost_amount"] += boost_amount
        pools[int(user.get('pid'))]["total_deposit_amount"] += deposit_amount
        pools[int(user.get('pid'))]["total_total_rewards"] += new_total_rewards
        
        
    for index, pool in enumerate(pools):
        assert int(pool["amount"]) == int(pool["boostAmount"]) + int(pool["depositAmount"])
        assert int(pool["heldProceeds"]) * 5 - int(pool["boostAmount"]) < 100
        
        if (index == 9):
            assert int(pool["amount"]) == (pool['total_amount'] + 22304710348921155929767724) # PENDLE
        else:
            assert int(pool["amount"]) == pool['total_amount']
            
        assert int(pool["boostAmount"]) == pool['total_boost_amount']
        if (index == 9):
            assert int(pool["depositAmount"]) == (pool['total_deposit_amount'] + 22304710348921155929767724)
        else:
            assert int(pool["depositAmount"]) == pool['total_deposit_amount']
        
        if (index == 9):
            assert int(pool["new_total_rewards"]) == pool['total_total_rewards']
        else:
            assert int(pool["new_total_rewards"]) == pool['total_total_rewards']
        
    print("all tests passed")
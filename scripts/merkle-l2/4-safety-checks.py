import json
from decimal import Decimal
file_path = ('./scripts/merkle-l2/output/3-update-user-info.json')

BEAM_LP_PID = 4
BEAM_LP_RATIO_PER_USER = {}
BEAM_PID = 3
WST_ETH_PID = 1
# TODO define below constants before running script
# those values are the result of remove_liquidity
BEAM_LP_BEAM_AMNT = 338772070642810842922352640
BEAM_LP_WETH_AMNT = 1790561714199384555520


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
    
    for index, user in enumerate(users):
        amount = int(user['userInfo']['amount'])
        boost_amount = int(user['userInfo']['boostAmount'])
        deposit_amount = int(user['userInfo']['depositAmount'])
        assert amount == boost_amount + deposit_amount
            
        pools[int(user.get('pid'))]["total_amount"] += amount
        pools[int(user.get('pid'))]["total_boost_amount"] += boost_amount
        pools[int(user.get('pid'))]["total_deposit_amount"] += deposit_amount
        
        
    for index, pool in enumerate(pools):
        assert int(pool["amount"]) == int(pool["boostAmount"]) + int(pool["depositAmount"])
        assert int(pool["heldProceeds"]) * 5 - int(pool["boostAmount"]) < 100
        
        assert int(pool["amount"]) == pool['total_amount']
        assert int(pool["boostAmount"]) == pool['total_boost_amount']
        assert int(pool["depositAmount"]) == pool['total_deposit_amount']
        
    print("all tests passed")
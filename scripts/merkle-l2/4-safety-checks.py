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


# there are couple of rules for users
# user.amount = user.boostAmount + user.depositAmount

# there are couple of rules for pools


with open(file_path, 'r', encoding='utf-8') as file:
    data = json.load(file)
    users = data.get('users', [])
    pools = data.get('pools', [])
    beam_lp_raitio_per_user = data.get('beam_lp_raitio_per_user', [])
    
    for index, user in enumerate(users):
        print(index, int(user["userInfo"]["amount"]) , int(user["userInfo"]["boostAmount"]) , int(user["userInfo"]["depositAmount"]))
        assert int(user["userInfo"]["amount"]) == int(user["userInfo"]["boostAmount"]) + int(user["userInfo"]["depositAmount"])
            
            
import json
from decimal import Decimal
file_path = ('./scripts/merkle-l2/output/2-withratios-userinfo-poolinfo.json')

BEAM_LP_PID = 4
BEAM_LP_RATIO_PER_USER = {}
BEAM_PID = 3
WST_ETH_PID = 1
# TODO define below constants before running script
# those values are the result of remove_liquidity
BEAM_LP_BEAM_AMNT = 338772070642810842922352640
BEAM_LP_WETH_AMNT = 1790561714199384555520

BEAM_LP_BEAM_AMOUNT = 0
BEAM_LP_BEAM_BOOST_AMOUNT = 0
BEAM_LP_BEAM_DEPOSIT_AMOUNT = 0
BEAM_LP_BEAM_HELD_AMOUNT = 0
with open(file_path, 'r', encoding='utf-8') as file:
    data = json.load(file)
    users = data.get('users', [])
    pools = data.get('pools', [])
    beam_lp_raitio_per_user = data.get('beam_lp_raitio_per_user', [])
    
    
    BEAM_LP_BOOST_TO_DEPOSIT_RATIO = int(pools[4]["heldProceeds"]) / int(pools[BEAM_LP_PID]["depositAmount"])
    
    # calculating proportionally BEAM pool amounts to add
    BEAM_LP_BEAM_HELD_AMOUNT = int(BEAM_LP_BEAM_AMNT * BEAM_LP_BOOST_TO_DEPOSIT_RATIO)
    BEAM_LP_BEAM_DEPOSIT_AMOUNT = BEAM_LP_BEAM_AMNT - BEAM_LP_BEAM_HELD_AMOUNT
    BEAM_LP_BEAM_BOOST_AMOUNT = BEAM_LP_BEAM_HELD_AMOUNT * 5 # boosterMultiplier
    BEAM_LP_BEAM_AMOUNT = BEAM_LP_BEAM_BOOST_AMOUNT + BEAM_LP_BEAM_DEPOSIT_AMOUNT
    
    # calculating proportionally WETH pool amounts to add
    BEAM_LP_WETH_HELD_AMOUNT = int(BEAM_LP_WETH_AMNT * BEAM_LP_BOOST_TO_DEPOSIT_RATIO)
    BEAM_LP_WETH_DEPOSIT_AMOUNT = BEAM_LP_WETH_AMNT - BEAM_LP_WETH_HELD_AMOUNT
    BEAM_LP_WETH_BOOST_AMOUNT = BEAM_LP_WETH_HELD_AMOUNT * 5 # boosterMultiplier
    BEAM_LP_WETH_AMOUNT = BEAM_LP_WETH_BOOST_AMOUNT + BEAM_LP_WETH_DEPOSIT_AMOUNT
    
    
    for index, user in enumerate(users):
        
        if user.get('pid') == str(BEAM_PID) or user.get('pid') == str(WST_ETH_PID):
            
            if user.get('pid') == str(BEAM_PID):
                total_amount = BEAM_LP_BEAM_AMOUNT
                total_boost_amount = BEAM_LP_BEAM_BOOST_AMOUNT
                total_deposit_amount = BEAM_LP_BEAM_DEPOSIT_AMOUNT
            
            if user.get('pid') == str(WST_ETH_PID):
                total_amount = BEAM_LP_WETH_AMOUNT
                total_boost_amount = BEAM_LP_WETH_BOOST_AMOUNT
                total_deposit_amount = BEAM_LP_WETH_DEPOSIT_AMOUNT
            
            assert total_amount != 0
            assert total_boost_amount != 0
            assert total_deposit_amount != 0
            
            if user["user"] in beam_lp_raitio_per_user: # this means this user had staked BEAM_LP
                
                #  We should simulate depositing to new pools with boost
                amount = int(total_amount * Decimal(beam_lp_raitio_per_user[user["user"]]["amountRatio"]))
                boost_amount = int(total_boost_amount * Decimal(beam_lp_raitio_per_user[user["user"]]["boostAmountRatio"]))
                deposit_amount = int(total_deposit_amount * Decimal(beam_lp_raitio_per_user[user["user"]]["depositAmountRatio"]))
                
                # saving original balances for checkup
                user['userInfo']['OLD_amount'] = user['userInfo']['amount']
                user['userInfo']['OLD_boostAmount'] = user['userInfo']['boostAmount']
                user['userInfo']['OLD_depositAmount'] = user['uspauseerInfo']['depositAmount']
                user['userInfo']['OLD_rewardDebt'] = user['userInfo']['rewardDebt']
                user['userInfo']['OLD_rewardSettled'] = user['userInfo']['rewardSettled']
                
                # here adding user calculated new balances to existing user balances
                user['userInfo']['amount'] = str(int(user['userInfo']['amount']) + int(amount))
                user['userInfo']['boostAmount'] = str(int(user['userInfo']['boostAmount']) + int(boost_amount))
                user['userInfo']['depositAmount'] = str(int(user['userInfo']['depositAmount']) + int(deposit_amount))
                
                if user["user"] == "0x04c97baa42c66a2bbe7c57f50d384e0aa108c288":
                    print("pause")
                    break; 
                    
                # TODO simulate deposit rewardDebth and rewardSettled
            
    
            
    data = {
        "pools": pools,
        "beam_lp_raitio_per_user" : beam_lp_raitio_per_user,
        "users": users
    }
    

    


json_data = json.dumps(data, indent=4)
filename = "./scripts/merkle-l2/output/3-update-user-info.json"

# Open the file in write mode and use json.dump() to write the data
with open(filename, 'w') as file:
    json.dump(data, file, indent=4)

# Optionally, prDecimal a confirmation
print(f"Data has been dumped print {filename}")
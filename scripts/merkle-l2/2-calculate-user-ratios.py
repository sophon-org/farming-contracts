import json
from decimal import Decimal
file_path = ('./scripts/merkle-l2/output/1-userinfo-poolinfo.json')

BEAM_LP_PID = 4
BEAM_LP_RATIO_PER_USER = {}

total_amount_ratio = 0
total_boost_amount_ratio = 0
total_deposit_amount_ratio = 0

total_amount = 0
total_boost_amount = 0
total_deposit_amount = 0

with open(file_path, 'r', encoding='utf-8') as file:
    data = json.load(file)
    users = data.get('users', [])
    pools = data.get('pools', [])

    for index, user in enumerate(users):
        
        if user.get('pid') == str(BEAM_LP_PID):
            amount = Decimal(user['userInfo']['amount'])
            boost_amount = Decimal(user['userInfo']['boostAmount'])
            deposit_amount = Decimal(user['userInfo']['depositAmount'])
                        
            # below is userAmount / totalAmount in pool to find ratio
            amount_ratio = amount / Decimal(pools[BEAM_LP_PID]['amount'])
            boost_amount_ratio = boost_amount / Decimal(pools[BEAM_LP_PID]['boostAmount'])
            deposit_amount_ratio = deposit_amount / Decimal(pools[BEAM_LP_PID]['depositAmount'])
            print("amount_ratio", amount_ratio)
            BEAM_LP_RATIO_PER_USER[user['user']] = {
                "amountRatio": str(amount_ratio),
                "boostAmountRatio": str(boost_amount_ratio),
                "depositAmountRatio": str(deposit_amount_ratio)
            }


            user['userInfo']["OLD_rewardSettled"] = user['userInfo']["rewardSettled"]
            user['userInfo']["OLD_rewardDebt"] = user['userInfo']["rewardDebt"]
            user['userInfo']["OLD_amount"] = user['userInfo']["amount"]
            user['userInfo']["OLD_boostAmount"] = user['userInfo']["boostAmount"]
            user['userInfo']["OLD_depositAmount"] = user['userInfo']["depositAmount"]


            # simulate user withdrwaing recalculating user.rewardDebth and user.rewardSettled
            user['userInfo']["rewardSettled"] = str(int(Decimal(user['userInfo']["amount"]) * Decimal(pools[4]["accPointsPerShare"]) / Decimal(1e18) + Decimal(user['userInfo']["rewardSettled"]) - Decimal(user['userInfo']["rewardDebt"])))
            user['userInfo']["rewardDebt"] = str(int(Decimal(user['userInfo']["amount"]) *Decimal(pools[4]["accPointsPerShare"]) / Decimal(1e18)))
            user['userInfo']["amount"] = str(0)
            user['userInfo']["boostAmount"] = str(0)
            user['userInfo']["depositAmount"] = str(0)
            # print("index", index, user["user"])
                
            total_amount_ratio += amount_ratio
            total_boost_amount_ratio += boost_amount_ratio
            total_deposit_amount_ratio += deposit_amount_ratio
            
            # Accumulate totals
            total_amount += amount
            total_boost_amount += boost_amount
            total_deposit_amount += deposit_amount
            
    
    # sanity check 
    print(f"Total Amount Ratio for all users: {total_amount_ratio}")
    print(f"Total Boost Amount Ratio for all users: {total_boost_amount_ratio}")
    print(f"Total Deposit Amount Ratio for all users: {total_deposit_amount_ratio}")
    # print summed totals
    print(f"Total Amount for all users: {total_amount}")
    print(f"Total Boost Amount for all users: {total_boost_amount}")
    print(f"Total Deposit Amount for all users: {total_deposit_amount}")
    
    assert total_amount == Decimal(pools[BEAM_LP_PID]["amount"])
    assert total_boost_amount == Decimal(pools[BEAM_LP_PID]["boostAmount"])
    assert total_deposit_amount == Decimal(pools[BEAM_LP_PID]["depositAmount"])
    assert total_amount == total_boost_amount + total_deposit_amount
    print("Checks passed")
    data = {
        "pools": pools,
        "beam_lp_raitio_per_user" : BEAM_LP_RATIO_PER_USER,
        "users": users
    }
    

    


json_data = json.dumps(data, indent=4)
filename = "./scripts/merkle-l2/output/2-withratios-userinfo-poolinfo.json"

# Open the file in write mode and use json.dump() to write the data
with open(filename, 'w') as file:
    json.dump(data, file, indent=4)

# Optionally, prDecimal a confirmation
print(f"Data has been dumped into {filename}")
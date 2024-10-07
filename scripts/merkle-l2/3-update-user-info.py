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
BEAM_LP_wstETH_AMNT = 1790561714199384555520 # wstETH


TOTALS = { "1" : {"total_amount": 0, "total_boost_amount": 0, "total_deposit_amount": 0},
           "3" : {"total_amount": 0, "total_boost_amount": 0, "total_deposit_amount": 0}
          }
error = True
with open(file_path, 'r', encoding='utf-8') as file:
    data = json.load(file)
    users = data.get('users', [])
    pools = data.get('pools', [])
    beam_lp_raitio_per_user = data.get('beam_lp_raitio_per_user', [])
    
    
    BEAM_LP_BOOST_TO_BALANCE_RATIO = Decimal(pools[BEAM_LP_PID]["heldProceeds"]) / (Decimal(pools[BEAM_LP_PID]["heldProceeds"]) + Decimal(pools[BEAM_LP_PID]["depositAmount"]))
    
    # calculating proportionally BEAM pool amounts to add
    BEAM_LP_BEAM_HELD_AMOUNT = BEAM_LP_BEAM_AMNT * BEAM_LP_BOOST_TO_BALANCE_RATIO
    BEAM_LP_BEAM_DEPOSIT_AMOUNT = BEAM_LP_BEAM_AMNT - BEAM_LP_BEAM_HELD_AMOUNT
    BEAM_LP_BEAM_BOOST_AMOUNT = BEAM_LP_BEAM_HELD_AMOUNT * 5 # boosterMultiplier
    BEAM_LP_BEAM_AMOUNT = BEAM_LP_BEAM_BOOST_AMOUNT + BEAM_LP_BEAM_DEPOSIT_AMOUNT
    
    assert BEAM_LP_BEAM_AMOUNT == BEAM_LP_BEAM_BOOST_AMOUNT + BEAM_LP_BEAM_DEPOSIT_AMOUNT
    
    # calculating proportionally WETH pool amounts to add
    BEAM_LP_WETH_HELD_AMOUNT = BEAM_LP_wstETH_AMNT * BEAM_LP_BOOST_TO_BALANCE_RATIO
    BEAM_LP_WETH_DEPOSIT_AMOUNT = BEAM_LP_wstETH_AMNT - BEAM_LP_WETH_HELD_AMOUNT
    BEAM_LP_WETH_BOOST_AMOUNT = BEAM_LP_WETH_HELD_AMOUNT * 5 # boosterMultiplier
    BEAM_LP_WETH_AMOUNT = BEAM_LP_WETH_BOOST_AMOUNT + BEAM_LP_WETH_DEPOSIT_AMOUNT
    
    assert BEAM_LP_WETH_AMOUNT == BEAM_LP_WETH_DEPOSIT_AMOUNT + BEAM_LP_WETH_BOOST_AMOUNT
    
    for index, user_wallet in enumerate(beam_lp_raitio_per_user): # for each user that had BEAM_WETH_LP
        
        for pid in [WST_ETH_PID, BEAM_PID]: # for each BEAM and WETH pools
   
            if pid == BEAM_PID:
                total_amount = BEAM_LP_BEAM_AMOUNT
                total_boost_amount = BEAM_LP_BEAM_BOOST_AMOUNT
                total_deposit_amount = BEAM_LP_BEAM_DEPOSIT_AMOUNT
            
            if pid == WST_ETH_PID:
                total_amount = BEAM_LP_WETH_AMOUNT
                total_boost_amount = BEAM_LP_WETH_BOOST_AMOUNT
                total_deposit_amount = BEAM_LP_WETH_DEPOSIT_AMOUNT
            
            assert total_amount != 0
            assert total_boost_amount != 0
            assert total_deposit_amount != 0
                
            #  We should simulate depositing to new pools with boost
            amount = int(total_amount * Decimal(beam_lp_raitio_per_user[user_wallet]["amountRatio"]))
            boost_amount = int(total_boost_amount * Decimal(beam_lp_raitio_per_user[user_wallet]["boostAmountRatio"]))
            deposit_amount = int(total_deposit_amount * Decimal(beam_lp_raitio_per_user[user_wallet]["depositAmountRatio"]))
            
            
            matching_users = [u for u in users if u["user"] == user_wallet and u["pid"] == str(pid)]

            assert len(matching_users) == 1 or len(matching_users) == 0 # there should be only one entry or none

            if matching_users:
                print("Matching users found:", user_wallet)
                user = matching_users[0]
            else:
                print("User didn't have staked", pid, user_wallet)
                user = {
                    "user": user_wallet,
                    "pid": str(pid),
                    "userInfo": {
                        "amount": 0,
                        "boostAmount": 0,
                        "depositAmount": 0,
                        "rewardSettled": 0,
                        "rewardDebt": 0
                    }
                }
                users.append(user)
            
                
                
            # making sure before I modify anything balances match exactly
            assert int(user['userInfo']['amount']) == int(user['userInfo']['boostAmount']) + int(user['userInfo']['depositAmount'])

            # saving original balances for checkup
            user['userInfo']['OLD_amount'] = user['userInfo']['amount']
            user['userInfo']['OLD_boostAmount'] = user['userInfo']['boostAmount']
            user['userInfo']['OLD_depositAmount'] = user['userInfo']['depositAmount']
            user['userInfo']['OLD_rewardDebt'] = user['userInfo']['rewardDebt']
            user['userInfo']['OLD_rewardSettled'] = user['userInfo']['rewardSettled']
            
            
            precision_loss = amount - (boost_amount + deposit_amount)
            assert precision_loss == 1 or precision_loss == 0
            
            if precision_loss == 1:
                # we need exact balances match
                amount = amount - precision_loss
            
            # # verifying exact balance match
            assert amount == boost_amount + deposit_amount
            
            TOTALS[str(pid)]["total_amount"] += amount
            TOTALS[str(pid)]["total_boost_amount"] += boost_amount
            TOTALS[str(pid)]["total_deposit_amount"] += deposit_amount
            
            # here adding user calculated new balances to existing user balances
            user['userInfo']['amount'] = str(int(user['userInfo']['amount']) + amount)
            user['userInfo']['boostAmount'] = str(int(user['userInfo']['boostAmount']) + boost_amount)
            user['userInfo']['depositAmount'] = str(int(user['userInfo']['depositAmount']) + deposit_amount)

            # re-verifying final result
            assert int(user['userInfo']['amount']) == int(user['userInfo']['boostAmount'])+ int(user['userInfo']['depositAmount'])
            
                
            # simulate deposit rewardDebth and rewardSettled. same formula as in SophonFarming
            user['userInfo']["rewardSettled"] = str(int(Decimal(user['userInfo']["amount"]) * Decimal(pools[pid]["accPointsPerShare"]) / Decimal(1e18) 
                                                        + Decimal(user['userInfo']["rewardSettled"]) - Decimal(user['userInfo']["rewardDebt"])))
            user['userInfo']["rewardDebt"] = str(int(Decimal(user['userInfo']["amount"]) * Decimal(pools[pid]["accPointsPerShare"]) / Decimal(1e18)))
         
         
    BEAM_LP_WETH_AMOUNT = int(BEAM_LP_WETH_AMOUNT)
    BEAM_LP_WETH_BOOST_AMOUNT = int(BEAM_LP_WETH_BOOST_AMOUNT)
    BEAM_LP_WETH_DEPOSIT_AMOUNT = int(BEAM_LP_WETH_DEPOSIT_AMOUNT)
    BEAM_LP_WETH_HELD_AMOUNT = int(BEAM_LP_WETH_HELD_AMOUNT)
    
    BEAM_LP_BEAM_AMOUNT = int(BEAM_LP_BEAM_AMOUNT)
    BEAM_LP_BEAM_BOOST_AMOUNT = int(BEAM_LP_BEAM_BOOST_AMOUNT)
    BEAM_LP_BEAM_DEPOSIT_AMOUNT = int(BEAM_LP_BEAM_DEPOSIT_AMOUNT)
    BEAM_LP_BEAM_HELD_AMOUNT = int(BEAM_LP_BEAM_HELD_AMOUNT)
    
    # adding/modifying balances to POOLS
    pools[BEAM_LP_PID]["OLD_amount"] = pools[BEAM_PID]["amount"]
    pools[BEAM_LP_PID]["OLD_boostAmount"] = pools[BEAM_PID]["boostAmount"]
    pools[BEAM_LP_PID]["OLD_depositAmount"] = pools[BEAM_PID]["depositAmount"]
    pools[BEAM_LP_PID]["OLD_heldProceeds"] = pools[BEAM_PID]["heldProceeds"]
    
    pools[BEAM_LP_PID]["amount"] = str(0)
    pools[BEAM_LP_PID]["boostAmount"] = str(0)
    pools[BEAM_LP_PID]["depositAmount"] = str(0)
    pools[BEAM_LP_PID]["heldProceeds"] = str(0)

    accumulatedError = 200
    # our totals( TOTALS) are always less than we actually got (BEAM_LP_*)
    assert BEAM_LP_WETH_AMOUNT - TOTALS[str(WST_ETH_PID)]["total_amount"] < accumulatedError
    assert BEAM_LP_WETH_BOOST_AMOUNT - TOTALS[str(WST_ETH_PID)]["total_boost_amount"] < accumulatedError
    assert BEAM_LP_WETH_DEPOSIT_AMOUNT - TOTALS[str(WST_ETH_PID)]["total_deposit_amount"] < accumulatedError
    assert BEAM_LP_BEAM_AMOUNT - TOTALS[str(BEAM_PID)]["total_amount"] < accumulatedError
    assert BEAM_LP_BEAM_BOOST_AMOUNT - TOTALS[str(BEAM_PID)]["total_boost_amount"] < accumulatedError
    assert BEAM_LP_BEAM_DEPOSIT_AMOUNT - TOTALS[str(BEAM_PID)]["total_deposit_amount"] < accumulatedError


    # fixing error
    BEAM_LP_WETH_AMOUNT = TOTALS[str(WST_ETH_PID)]["total_amount"]
    BEAM_LP_WETH_BOOST_AMOUNT = TOTALS[str(WST_ETH_PID)]["total_boost_amount"]
    BEAM_LP_WETH_DEPOSIT_AMOUNT = TOTALS[str(WST_ETH_PID)]["total_deposit_amount"]
    BEAM_LP_BEAM_AMOUNT = TOTALS[str(BEAM_PID)]["total_amount"]
    BEAM_LP_BEAM_BOOST_AMOUNT = TOTALS[str(BEAM_PID)]["total_boost_amount"]
    BEAM_LP_BEAM_DEPOSIT_AMOUNT = TOTALS[str(BEAM_PID)]["total_deposit_amount"]

    assert BEAM_LP_WETH_AMOUNT == BEAM_LP_WETH_BOOST_AMOUNT + BEAM_LP_WETH_DEPOSIT_AMOUNT
    assert BEAM_LP_BEAM_AMOUNT == BEAM_LP_BEAM_BOOST_AMOUNT + BEAM_LP_BEAM_DEPOSIT_AMOUNT
         
    pools[WST_ETH_PID]["OLD_amount"] = pools[WST_ETH_PID]["amount"]
    pools[WST_ETH_PID]["OLD_boostAmount"] = pools[WST_ETH_PID]["boostAmount"]
    pools[WST_ETH_PID]["OLD_depositAmount"] = pools[WST_ETH_PID]["depositAmount"]
    pools[WST_ETH_PID]["OLD_heldProceeds"] = pools[WST_ETH_PID]["heldProceeds"]
    pools[WST_ETH_PID]["amount"] = str(int(pools[WST_ETH_PID]["amount"]) + BEAM_LP_WETH_AMOUNT)
    pools[WST_ETH_PID]["boostAmount"] = str(int(pools[WST_ETH_PID]["boostAmount"]) + BEAM_LP_WETH_BOOST_AMOUNT)
    pools[WST_ETH_PID]["depositAmount"] = str(int(pools[WST_ETH_PID]["depositAmount"]) + BEAM_LP_WETH_DEPOSIT_AMOUNT)
    pools[WST_ETH_PID]["heldProceeds"] = str(int(pools[WST_ETH_PID]["heldProceeds"]) + int(BEAM_LP_WETH_HELD_AMOUNT))
    
    
    pools[BEAM_PID]["OLD_amount"] = pools[BEAM_PID]["amount"]
    pools[BEAM_PID]["OLD_boostAmount"] = pools[BEAM_PID]["boostAmount"]
    pools[BEAM_PID]["OLD_depositAmount"] = pools[BEAM_PID]["depositAmount"]
    pools[BEAM_PID]["OLD_heldProceeds"] = pools[BEAM_PID]["heldProceeds"]
    pools[BEAM_PID]["amount"] = str(int(pools[BEAM_PID]["amount"]) + BEAM_LP_BEAM_AMOUNT)
    pools[BEAM_PID]["boostAmount"] = str(int(pools[BEAM_PID]["boostAmount"]) + BEAM_LP_BEAM_BOOST_AMOUNT)
    pools[BEAM_PID]["depositAmount"] = str(int(pools[BEAM_PID]["depositAmount"]) + BEAM_LP_BEAM_DEPOSIT_AMOUNT)
    pools[BEAM_PID]["heldProceeds"] = str(int(pools[BEAM_PID]["heldProceeds"]) + int(BEAM_LP_BEAM_HELD_AMOUNT))
       
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
print(f"Data has been dumped into {filename}")
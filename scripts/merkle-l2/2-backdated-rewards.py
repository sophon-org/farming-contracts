import json
from decimal import Decimal
file_path = ('./scripts/merkle-l2/output/1-userinfo-poolinfo.json')


total_amount = 0
total_boost_amount = 0
total_deposit_amount = 0

l1_end_block = 21440000; # SF.endBlock() 21440000 Dec-19-2024 11:58:11 PM +UTC
# L2 https://sophscan.xyz/block/162751 Dec-19-2024 11:58:11 PM +UTC
l2_start_block = 21504400; #  https://sophscan.xyz/block/countdown/929314
l1_pool_pointsPerBlock = 76000000000000000000 #SF.pointsPerBlock()
blockMultiplier = (l2_start_block - l1_end_block) * 1e18;
l1_totalAllocPoint = 770000 # SF.totalAllocPoint()
PENDLE_EXCEPTION = "0x065347C1Dd7A23Aa043e3844B4D0746ff7715246".lower()
replacements = dict([
    #L1 wallet                                     L2 wallet
    ["0x065347C1Dd7A23Aa043e3844B4D0746ff7715246","0x176447C1DD7A23Aa043E3844b4d0746fF7716357"],
    ["0x0d783443b3410b32b12d8F2b8bb7dD52D67Bf5b6","0xAbC727Edf2aD943498C2175dD7e422a2d5C13703"],
    ["0x171DA5406CB7aC9CcC7F3459Be13b35a86A0766f","0x282ea5406CB7aC9CcC7f3459bE13b35a86A08780"],
    ["0x2b588AE07afBA4b78FCE248b86960E556f27c74b","0x4bC1AF5F0Cfee11E5B991e90E1542436eBfD8Bba"],
    ["0x3d8330369F7efE5Feb8062fcE54D7B466492f3D3","0x4e9430369f7eFe5feb8062FcE54d7B46649304e4"],
    ["0xB76bC830f183293c368b439B56B40dc58b4E2C7F","0xC87CC830f183293c368b439B56B40dC58B4E3d90"],
    ["0xB96707B852A399041f074da9C8858A5AF4912674","0xcA7807B852a399041F074Da9C8858A5af4913785"],
    ["0xd2AE2440cd0703Df2d545028799eF1C42Db403e9","0xe3bF2440cD0703Df2d545028799Ef1c42db414Fa"],
])
replacements = {k.lower(): v.lower() for k, v in replacements.items()}

global_accPointsPerShare  = {}


with open(file_path, 'r', encoding='utf-8') as file:
    data = json.load(file)
    users = data.get('users', [])
    pools = data.get('pools', [])
    accPointsPerShares = [pool['accPointsPerShare'] for pool in pools]
    totalRewards = [pool['totalRewards'] for pool in pools]
    
    for index, pool in enumerate(pools):
        l1_allocPoint = int(pool["allocPoint"])
        l1_pool_amount = int(pool["amount"])
        accPointsPerShare = 0
        if l1_pool_amount > 0: # skip empty pools
            pointReward = blockMultiplier * l1_pool_pointsPerBlock * l1_allocPoint / l1_totalAllocPoint
            accPointsPerShare = pointReward / l1_pool_amount
        else:
            pointReward = 0
        
        pool["new_accPointsPerShare"] = int(accPointsPerShare)
        ## global_accPointsPerShare[str(index)] = accPointsPerShare <-- delete
    
    new_accPointsPerShare = [pool['new_accPointsPerShare'] for pool in pools]
    new_TotalRewards = [0] * len(pools)

    for user in users:
        print(user)
        # zero out pendle before total rewards calc
        if user["user"].lower() == PENDLE_EXCEPTION:
        # ZERO OUT PENDLE POOL
            user["userInfo"] = {
                        'amount': "0",
                        'boostAmount': "0",
                        'depositAmount': "0",
                        'new_rewardSettled': "0",
                        'rewardDebt': "0",
                        'rewardSettled': "0"
                    }
        l1_user_amount = int(user["userInfo"]["amount"])
        rewardSettled = int(user["userInfo"]["rewardSettled"])
        rewardDebt = int(user["userInfo"]["rewardDebt"])
        pid = user["pid"]
        rewardSettled_latest_from_L1 = l1_user_amount * int(accPointsPerShares[int(pid)]) / 1e18 + rewardSettled - rewardDebt;

        ### Backdating section ###
        rewardSettled_backdated = l1_user_amount * int(new_accPointsPerShare[int(pid)]) / 1e18
        ### End backdating ###

        # rewardSettled = rewardSettled_latest_from_L1 + rewardSettled_backdated
        rewardSettled = rewardSettled_backdated # on L2 we pass only backdated rewards

        new_TotalRewards[int(pid)] += int(rewardSettled)


        # user.rewardSettled =
        #     user.amount *
        #     pool.accPointsPerShare /
        #     1e18 +
        #     user.rewardSettled -
        #     user.rewardDebt;
        #          int(82630000 * 1106695059245760088814745713292 / 1e18 + 0 - 77360583371057891283)
        # 14085629374419271680
        # SF.pendingPoints(12, "0xfffba048296609a129d384b2ebb75941f2d63e0c")
        # 14085629374419264855
        user["userInfo"]["new_rewardSettled"] = str(int(rewardSettled))
        user["userInfo"]["new_rewardDebt"] = "0"
        new_user = replacements.get(user["user"].lower())
        if new_user is None:
            user["new_user"] = user["user"]
        else:
            user["new_user"] = new_user
            

            
    
    for i, pool in enumerate(pools):
        pool['new_total_rewards'] = new_TotalRewards[i]    

    excluded_users = [
    user["user"] for user in users
    if {
        key: value for key, value in user["userInfo"].items() if key != "rewardSettled"
    } == {
        'amount': "0",
        'boostAmount': "0",
        'depositAmount': "0",
        'new_rewardSettled': "0",
        'rewardDebt': "0",
        'new_rewardDebt': '0'
    }
]

    for excluded_user in excluded_users:
        print("Excluded user:", excluded_user)

    # Filter out the excluded users from the original list
    users = [
        user for user in users
        if {
            key: value for key, value in user["userInfo"].items() if key != "rewardSettled"
        } != {
            'amount': "0",
            'boostAmount': "0",
            'depositAmount': "0",
            'new_rewardSettled': "0",
            'rewardDebt': "0"
        }
    ]
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
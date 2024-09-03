exec(open("./scripts/env/eth.py").read())

from subgrounds import Subgrounds
import concurrent.futures

import time

sg = Subgrounds()
api_key = 'a5004bf85784712fbda24f94c724a4f9'
url = "https://gateway.thegraph.com/api/" + api_key + "/subgraphs/id/GYJVGvEKEwLMLmFjq8LGoCACDT4FHKCvk16BZMMB5Zje"

# Load the subgraph
subgraph = sg.load_subgraph(url)

balances_query = subgraph.Query.balances(
    first=5000000000,
    id=True
)
result = sg.query(balances_query)

user_data_list = []
# Function to get user info
def get_user_info(p):
    print(p)
    user, pid = p.split(":")
    user_info = SF.userInfo(pid, user)
    return {
        "user": user,
        "pid": pid,
        "userInfo": {
            "amount": str(user_info[0]),
            "boostAmount": str(user_info[1]),
            "depositAmount": str(user_info[2]),
            "rewardSettled": str(user_info[3]),
            "rewardDebt": str(user_info[4])
        }
    }

max_parallel_requests = 50
user_data_list = []
with concurrent.futures.ThreadPoolExecutor(max_workers=max_parallel_requests) as executor:
    # Submit tasks
    future_to_p = {executor.submit(get_user_info, p): p for p in result[0]}
    
    # Process completed futures
    for future in concurrent.futures.as_completed(future_to_p):
        try:
            user_data = future.result()
            user_data_list.append(user_data)
        except Exception as exc:
            print(f'Generated an exception: {exc}')

pool_info_list = []
poolInfo = SF.getPoolInfo()
for pool in poolInfo:
    pool_info_list.append({
        "lpToken" : pool[0],
        "l2Farm" : pool[1],
        "amount" : pool[2],
        "boostAmount" : pool[3],
        "depositAmount" : pool[4],
        "allocPoint" : pool[5],
        "lastRewardBlock" : pool[6],
        "accPointsPerShare" : pool[7],
        "totalRewards" : pool[8],
        "description" : pool[9],
    })

data = {
    "pools": pool_info_list,
    "users": user_data_list
}

import json
json_data = json.dumps(data, indent=4)
filename = "./scripts/merkle-l2/output/userinfo-poolinfo.json"

# Open the file in write mode and use json.dump() to write the data
with open(filename, 'w') as file:
    json.dump(data, file, indent=4)

# Optionally, print a confirmation
print(f"Data has been dumped into {filename}")
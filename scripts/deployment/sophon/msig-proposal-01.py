from brownie_safe import BrownieSafe
from safe_eth.safe.enums import SafeOperationEnum
import json

SEND_TO_MAINNET = False
LAST_REWARD_BLOCK = 934000

<<<<<<< Updated upstream
OWNER_MULTISIG = "0xe52757064e04bB7ec756C3e91aAa3acA1fD88b08"
SAFE = BrownieSafe(OWNER_MULTISIG)
=======
TECH_MULTISIG = "0xe52757064e04bB7ec756C3e91aAa3acA1fD88b08"
SAFE = BrownieSafe(TECH_MULTISIG)
>>>>>>> Stashed changes
exec(open("./scripts/env/sophon-mainnet.py").read())

tx_list = []

farmingpools = [
    sDAI,
    wstETH,
    weETH,
    BEAM,
    BEAM_ETH_LP,
    ZERO_ADDRESS, # ZENT
    stZENT,
    USDC,
    stATH,
    PEPE,
    WBTC,
    stAZURO,
    USDT,
    stAVAIL,
    OPN, # OPN
]



file_path = ('./scripts/merkle-l2/output/2-backdated-rewards.json')
payloads = []
with open(file_path, 'r', encoding='utf-8') as file:
   data = json.load(file)
   pools = data.get('pools', [])
   for pid, pool in enumerate(pools):
       lrb = LAST_REWARD_BLOCK
       if farmingpools[pid] == BEAM_ETH_LP or farmingpools[pid] == ZERO_ADDRESS or farmingpools[pid] == OPN:
           lrb = lrb + 10000000000
       print(pool, lrb)
       payload = SF_L2.addPool.encode_input(
                pid,
                farmingpools[pid],
                ZERO_ADDRESS,
                int(pool["amount"]),
                int(pool["boostAmount"]),
                int(pool["depositAmount"]),
                0,
                lrb,
                0,
                int(pool["new_total_rewards"]),
                pool["description"],
                int(pool["heldProceeds"])
            )
       tx_list.append([SF_L2.address, payload])


if SEND_TO_MAINNET:
    # signtature = SAFE.sign_with_frame(safe_tx)
    # SAFE.post_transaction(safe_tx)
    # SAFE.post_signature(safe_tx, signtature)
    for tx in tx_list[9:]:
        sTxn = SAFE.build_multisig_tx(tx[0], 0, tx[1], SafeOperationEnum.CALL.value, safe_nonce=SAFE.pending_nonce())
        SAFE.sign_with_frame(sTxn)
        SAFE.post_transaction(sTxn)

pending = SAFE.pending_transactions
for index, p in enumerate(pending):
    print(SF_L2.decode_input(p.data))
    print(SF_L2.decode_input(tx_list[index][1]))
    print()
    



exec(open("./scripts/env/sophon-mainnet.py").read())
poolInfo = SF_L2.getPoolInfo()

for pid, p in enumerate(poolInfo):
    lpToken = p[0]
    l2Farm = p[1]
    amount = p[2]
    boostAmount = p[3]
    depositAmount = p[4]
    allocPoint = p[5]
    lastRewardBlock = p[6]
    accPointsPerShare = p[7]
    totalRewards = p[8]
    description = p[9]
    heldProceeds = SF_L2.heldProceeds(pid)
    SF_L2.addPool(
        pid,
        lpToken,
        l2Farm,
        amount,
        boostAmount,
        depositAmount,
        allocPoint,
        lastRewardBlock,
        accPointsPerShare,
        totalRewards,
        description,
        heldProceeds,
        {"from": SF_L2.owner(), 
        "gas_price": Wei("4000 gwei"),
        "gas_limit": 1125899906842624,
        'paymaster_address': "0x98546B226dbbA8230cf620635a1e4ab01F6A99B2"})
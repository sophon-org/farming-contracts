from brownie_safe import BrownieSafe
from safe_eth.safe.enums import SafeOperationEnum
import json

SEND_TO_MAINNET = False
LAST_REWARD_BLOCK = 934000

OWNER_MULTISIG = "0xe52757064e04bB7ec756C3e91aAa3acA1fD88b08"
SAFE = BrownieSafe(OWNER_MULTISIG)
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
    for tx in tx_list:
        sTxn = SAFE.build_multisig_tx(tx[0].address, 0, tx[1], SafeOperationEnum.CALL.value, safe_nonce=safe.pending_nonce())
        safe.sign_with_frame(sTxn)
        safe.post_transaction(sTxn)

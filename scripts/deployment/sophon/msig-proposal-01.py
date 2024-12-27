from brownie_safe import BrownieSafe
from safe_eth.safe.enums import SafeOperationEnum
import json

SEND_TO_MAINNET = False
LAST_REWARD_BLOCK = 21504400

TECH_MULTISIG = "0x902767c9e11188C985eB3494ee469E53f1b6de53"
SAFE = BrownieSafe(TECH_MULTISIG)
exec(open("./scripts/env/sophon-mainnet.py").read())

tx_list = []

farmingpools = [
    sDAI,
    wstETH,
    weETH,
    BEAM,
    ZERO_ADDRESS, # BEAM_ETH_LP,
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
       print(pool)
       payload = SF_L2.addPool.encode_input(
                pid,
                farmingpools[pid],
                pool["l2Farm"],
                int(pool["amount"]),
                int(pool["boostAmount"]),
                int(pool["depositAmount"]),
                int(pool["allocPoint"]),
                LAST_REWARD_BLOCK, # this will start farming right immediately.
                int(pool["accPointsPerShare"]),
                int(pool["totalRewards"]),
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

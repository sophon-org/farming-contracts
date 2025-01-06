from brownie_safe import BrownieSafe
from safe_eth.safe.enums import SafeOperationEnum
import json

SEND_TO_MAINNET = False
LAST_REWARD_BLOCK = 934000

TECH_MULTISIG = "0xe52757064e04bB7ec756C3e91aAa3acA1fD88b08"
SAFE = BrownieSafe(TECH_MULTISIG)
exec(open("./scripts/env/sophon-mainnet.py").read())

tx_list = []

poolInfo = SF_L2.getPoolInfo()
for index, p in enumerate(poolInfo):
    payload = SF_L2.setEmissionsMultiplier.encode_input(index, 1e18)
    tx_list.append([SF_L2.address, payload])

nonce = 24
for tx in tx_list:
    sTxn = SAFE.build_multisig_tx(tx[0], 0, tx[1], SafeOperationEnum.CALL.value, safe_nonce=nonce)
    nonce = nonce + 1
    SAFE.sign_with_frame(sTxn)
    SAFE.post_transaction(sTxn)

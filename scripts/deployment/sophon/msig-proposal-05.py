from brownie_safe import BrownieSafe
from safe_eth.safe.enums import SafeOperationEnum
import json

SEND_TO_MAINNET = False
LAST_REWARD_BLOCK = 934000

TECH_MULTISIG = "0x902767c9e11188C985eB3494ee469E53f1b6de53"
SAFE = BrownieSafe(TECH_MULTISIG)
exec(open("./scripts/env/sophon-mainnet.py").read())

tx_list = []
BEAMETH_LP = "0x20da5bf55630b3ec058e0f7699785944ec7c295c2da2f5e365100a973a36cdd9"
OPNUSD = "0x342465e620fad2d7c1b50727b893a6f91dc420cf7ec5c5f862d53e4fa8cd9418"

poolDatas = [
    (BEAMETH_LP, 3600, 1),
    (OPNUSD, 3600, 1),
]
poolTokens = [BEAM_ETH_LP, OPN]

payload = PF.setStorkFeedsData.encode_input(SF_L2, poolTokens, poolDatas)
tx_list.append((PF.address, payload))


for tx in tx_list:
    sTxn = SAFE.build_multisig_tx(tx[0], 0, tx[1], SafeOperationEnum.CALL.value, safe_nonce=SAFE.pending_nonce())
    SAFE.sign_with_frame(sTxn)
    SAFE.post_transaction(sTxn)

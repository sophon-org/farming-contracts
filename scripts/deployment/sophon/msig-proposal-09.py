
from brownie_safe import BrownieSafe
from safe_eth.safe.enums import SafeOperationEnum
from brownie import Contract
from eth_utils import to_bytes

exec(open("./scripts/env/sophon-mainnet.py").read())

abbi = [{"inputs":[{"internalType":"bytes","name":"transactions","type":"bytes"}],"name":"multiSend","outputs":[],"stateMutability":"payable","type":"function"}]
MULTICALL = "0x0408EF011960d02349d50286D20531229BCef773"
MULTICALL = Contract.from_abi("M", MULTICALL, abi = abbi)

SEND_TO_MAINNET = False
TECH_MULTISIG = "0x902767c9e11188C985eB3494ee469E53f1b6de53"
SAFE = BrownieSafe(TECH_MULTISIG, multisend=MULTICALL.address)



tx_list = []

USDT_USN_LP = "0x0Cdb3454293FDfa187B14025F29cdA3319fcd3B5"
SUSN_USN_LP = "0x9116a0E6C8d04E82397B64E72D26d14D290b42eF"

USDT_USN_LP_FEED = "TODO"
SUSN_USN_LP_FEED = "TODO"


poolDatas = [
    (USDT_USN_LP_FEED, 3600, 1),
    (SUSN_USN_LP_FEED, 3600, 1),
]

poolTokens = [
    USDT_USN_LP,
    SUSN_USN_LP,
    ]

payload = PF.setStorkFeedsData.encode_input(SF_L2, poolTokens, poolDatas)
tx_list.append((PF.address, payload))


transactions = []
for tx in tx_list:
    transactions.append({ 
        "operation": 0, # CALL = 0
        "to": tx[0],
        "value": 0,
        "data": tx[1]
    })
    
payload = encode_transactions(transactions)
msig_payload = MULTICALL.multiSend.encode_input(payload)
if SEND_TO_MAINNET:
    sTxn = SAFE.build_multisig_tx(MULTICALL.address, 0, msig_payload, SafeOperationEnum.DELEGATE_CALL.value, safe_nonce=SAFE.pending_nonce())
    SAFE.sign_with_frame(sTxn)
    SAFE.post_transaction(sTxn)

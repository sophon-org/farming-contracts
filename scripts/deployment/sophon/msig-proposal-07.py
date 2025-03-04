from brownie_safe import BrownieSafe
from safe_eth.safe.enums import SafeOperationEnum
import json

SEND_TO_MAINNET = False
tx_list = []

exec(open("./scripts/env/sophon-mainnet.py").read())

ROLLUP_CHAIN_MS_MULTISIG = "0xa3b1f968b608642dD16d7Fd31bEc0B2c915908dB"
SAFE = BrownieSafe(ROLLUP_CHAIN_MS_MULTISIG)
MULTICALL = "0x0408EF011960d02349d50286D20531229BCef773"

tx_list = []

NEW_POINTS_PER_BLOCL = 0

MUPETH_LP = ""
SOPHETH_LP = ""
ETHUSDC_LP = ""
ETHUSDT_LP = ""
ATHETH_LP = ""
OPNETH_LP = ""
USDCUSDT_LP = ""
NUTZETH_LP = ""
PETETH_LP = ""

MUPETH_LP_DESCRIPTION = "MUPETH_LP"
SOPHETH_DESCRIPTION = "SOPHETH_LP"
ETHUSDC_DESCRIPTION = "ETHUSDC_LP"
ETHUSDT_DESCRIPTION = "ETHUSDT_LP"
ATHETH_DESCRIPTION = "ATHETH_LP"
OPNETH_DESCRIPTION = "OPNETH_LP"
USDCUSDT_DESCRIPTION = "USDCUSDT_LP"
NUTZETH_DESCRIPTION = "NUTZETH_LP"
PETETH_DESCRIPTION = "PETETH_LP"

MUPETH_LP_MULTIPLIER = 1e18
SOPHETH_LP_MULTIPLIER = 1e18
ETHUSDC_LP_MULTIPLIER = 1e18
ETHUSDT_LP_MULTIPLIER = 1e18
ATHETH_LP_MULTIPLIER = 1e18
OPNETH_LP_MULTIPLIER = 1e18
USDCUSDT_LP_MULTIPLIER = 1e18
NUTZETH_LP_MULTIPLIER = 1e18
PETETH_LP_MULTIPLIER = 1e18

MUPETH_LP_FEED = ""
SOPHETH_LP_FEED = ""
ETHUSDC_LP_FEED = ""
ETHUSDT_LP_FEED = ""
ATHETH_LP_FEED = ""
OPNETH_LP_FEED = ""
USDCUSDT_LP_FEED = ""
NUTZETH_LP_FEED = ""
PETETH_LP_FEED = ""


poolDatas = [
    (MUPETH_LP_FEED, 3600, 1),
    (SOPHETH_LP_FEED, 3600, 1),
    (ETHUSDC_LP_FEED, 3600, 1),
    (ETHUSDT_LP_FEED, 3600, 1),
    (ATHETH_LP_FEED, 3600, 1),
    (OPNETH_LP_FEED, 3600, 1),
    (USDCUSDT_LP_FEED, 3600, 1),
    (NUTZETH_LP_FEED, 3600, 1),
    (PETETH_LP_FEED, 3600, 1),
]
poolTokens = [
    MUPETH_LP_FEED,
    SOPHETH_LP_FEED,
    ETHUSDC_LP_FEED,
    ETHUSDT_LP_FEED,
    ATHETH_LP_FEED,
    OPNETH_LP_FEED,
    USDCUSDT_LP_FEED,
    NUTZETH_LP_FEED,
    PETETH_LP_FEED
    ]

payload = PF.setStorkFeedsData.encode_input(SF_L2, poolTokens, poolDatas)
tx_list.append((PF.address, payload))

currentBlock = chain.height

tx_list.append((SF_L2.address, SF_L2.add.encode_input(MUPETH_LP, MUPETH_LP_MULTIPLIER, MUPETH_LP_DESCRIPTION, currentBlock, 0))
tx_list.append((SF_L2.address, SF_L2.add.encode_input(SOPHETH_LP, SOPHETH_LP_MULTIPLIER, SOPHETH_DESCRIPTION, currentBlock, 0))
tx_list.append((SF_L2.address, SF_L2.add.encode_input(ETHUSDC_LP, ETHUSDC_LP_MULTIPLIER, ETHUSDC_DESCRIPTION, currentBlock, 0))
tx_list.append((SF_L2.address, SF_L2.add.encode_input(ETHUSDT_LP, ETHUSDT_LP_MULTIPLIER, ETHUSDT_DESCRIPTION, currentBlock, 0))
tx_list.append((SF_L2.address, SF_L2.add.encode_input(ATHETH_LP, ATHETH_LP_MULTIPLIER, ATHETH_DESCRIPTION, currentBlock, 0))
tx_list.append((SF_L2.address, SF_L2.add.encode_input(OPNETH_LP, OPNETH_LP_MULTIPLIER, OPNETH_DESCRIPTION, currentBlock, 0))
tx_list.append((SF_L2.address, SF_L2.add.encode_input(USDCUSDT_LP, USDCUSDT_LP_MULTIPLIER, USDCUSDT_DESCRIPTION, currentBlock, 0))
tx_list.append((SF_L2.address, SF_L2.add.encode_input(NUTZETH_LP, NUTZETH_LP_MULTIPLIER, NUTZETH_DESCRIPTION, currentBlock, 0))
tx_list.append((SF_L2.address, SF_L2.add.encode_input(PETETH_LP, PETETH_LP_MULTIPLIER, PETETH_DESCRIPTION, currentBlock, NEW_POINTS_PER_BLOCL))




for tx in parts_as_lists:
    payload = "TODO"
    tx_list.append((MULTICALL, payload))


if SEND_TO_MAINNET:
    for tx in tx_list:
        sTxn = SAFE.build_multisig_tx(tx[0], 0, tx[1], SafeOperationEnum.CALL.value, safe_nonce=SAFE.pending_nonce())
        SAFE.sign_with_frame(sTxn)
        SAFE.post_transaction(sTxn)

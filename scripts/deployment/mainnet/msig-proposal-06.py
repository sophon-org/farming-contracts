from brownie_safe import BrownieSafe
from gnosis.safe.enums import SafeOperationEnum
from brownie import *

exec(open("./scripts/env/eth.py").read())

SEND_TO_MAINNET = False

OWNER = "0x3b181838Ae9DB831C17237FAbD7c10801Dd49fcD"
SAFE = BrownieSafe(OWNER)

stAVAIL = interface.IERC20("0x3742f3fcc56b2d46c7b8ca77c23be60cd43ca80a")
stAVAILPoints = 50000

# https://etherscan.io/block/countdown/21115250
# Estimated Target Date
# Mon Nov 04 2024 16:00:00
stAVAILEnableBlock = 21115250

#newPointsPerBlock = SF.pointsPerBlock() + (stAVAILPoints) * 1e14
newPointsPerBlock = 66e18

SF.add(stAVAILPoints, stAVAIL, "stAVAIL", stAVAILEnableBlock, newPointsPerBlock, {"from": OWNER})

safe_tx = SAFE.multisend_from_receipts()
SAFE.preview(safe_tx, call_trace=True)

SAFE.pending_transactions
SAFE.preview_pending()

if SEND_TO_MAINNET:
    signtature = SAFE.sign_with_frame(safe_tx)
    SAFE.post_transaction(safe_tx)
    SAFE.post_signature(safe_tx, signtature)

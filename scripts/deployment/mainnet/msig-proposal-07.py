from brownie_safe import BrownieSafe
from brownie import *

exec(open("./scripts/env/eth.py").read())

SEND_TO_MAINNET = False

OWNER = "0x3b181838Ae9DB831C17237FAbD7c10801Dd49fcD"
SAFE = BrownieSafe(OWNER)

OPN = interface.IERC20("0xc28eb2250d1AE32c7E74CFb6d6b86afC9BEb6509")
OPNPoints = 50000

# https://etherscan.io/block/countdown/21272866
# Estimated Target Date
# Tuesday, November 26, 2024 4:00:00 PM
OPNEnableBlock = 21115250

#newPointsPerBlock = SF.pointsPerBlock() + (OPNPoints) * 1e14
newPointsPerBlock = 66e18

SF.add(OPNPoints, OPN, "OPN", OPNEnableBlock, newPointsPerBlock, {"from": OWNER})

safe_tx = SAFE.multisend_from_receipts()
SAFE.preview(safe_tx, call_trace=True)

SAFE.pending_transactions
SAFE.preview_pending()

if SEND_TO_MAINNET:
    signtature = SAFE.sign_with_frame(safe_tx)
    SAFE.post_transaction(safe_tx)
    SAFE.post_signature(safe_tx, signtature)

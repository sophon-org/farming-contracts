from brownie_safe import BrownieSafe
from gnosis.safe.enums import SafeOperationEnum
from brownie import *

exec(open("./scripts/env/eth.py").read())


# this propoposal is supposed to enable transfering of points of specific addresses for Pendle
#  please help to whitelist point transferring for these two contracts:
# - caller 0x74c5a0D5DFcC6D4527c849F09eCC360c5345D986, source 0x065347C1Dd7A23Aa043e3844B4D0746ff7715246
# - caller 0x74c5a0D5DFcC6D4527c849F09eCC360c5345D986, source 0x74c5a0D5DFcC6D4527c849F09eCC360c5345D986


SEND_TO_MAINNET = False

OWNER = "0x3b181838Ae9DB831C17237FAbD7c10801Dd49fcD"
safe = BrownieSafe(OWNER)

POINT_MANAGER = "0x74c5a0D5DFcC6D4527c849F09eCC360c5345D986"
USERS = ["0x065347C1Dd7A23Aa043e3844B4D0746ff7715246", "0x74c5a0D5DFcC6D4527c849F09eCC360c5345D986"]

SF.setUsersWhitelisted(POINT_MANAGER, USERS, True, {"from": OWNER})


safe_tx = safe.multisend_from_receipts()
safe.preview(safe_tx, call_trace=True)

safe.pending_transactions
safe.preview_pending()

if SEND_TO_MAINNET:
    signtature = safe.sign_with_frame(safe_tx)
    safe.post_transaction(safe_tx)
    safe.post_signature(safe_tx, signtature)



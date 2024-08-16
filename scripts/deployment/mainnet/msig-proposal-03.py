from brownie_safe import BrownieSafe
from gnosis.safe.enums import SafeOperationEnum
from brownie import *

exec(open("./scripts/env/eth.py").read())


# this propoposal is supposed to staked AZUR that are on the farming contract to stAZUR. it will be done in one multisig transaction
# 1 create a small contract with only functions needed for migration
# 2 upgrade the proxy to new contract for migration
# 3 migrate
# 4 upgrade the proxy to old implementation

SEND_TO_MAINNET = False

OWNER = "0x3b181838Ae9DB831C17237FAbD7c10801Dd49fcD"
safe = BrownieSafe(OWNER)


# TODO WIP actual transaction to upgrade stAZUR

stAZUR = ZERO_ADDRESS # TODO
deployer = accounts[0]
SFImpl = SFAzurUpgrade.deploy({'from': deployer})
SF.replaceImplementation(SFImpl, {'from': OWNER})
SFImpl.becomeImplementation(SF, {'from': OWNER})

SF.migrateAzur()

safe_tx = safe.multisend_from_receipts()
safe.preview(safe_tx, call_trace=True)

safe.pending_transactions
safe.preview_pending()

if SEND_TO_MAINNET:
    signtature = safe.sign_with_frame(safe_tx)
    safe.post_transaction(safe_tx)
    safe.post_signature(safe_tx, signtature)



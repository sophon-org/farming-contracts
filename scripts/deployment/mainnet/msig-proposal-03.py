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


stAZUR = interface.IERC20Metadata("0x67f3228fD58f5A26D93a5dd0c6989b69c95618eB")
AZUR = interface.IERC20Metadata("0x9E6be44cC1236eEf7e1f197418592D363BedCd5A")
AZUR_PID = 11


balanceBefore = AZUR.balanceOf(SF)
deployer = accounts[0]
oldImplementation = SF.implementation()
SFImpl = SFAzurUpgrade.deploy({'from': OWNER})
receipt1 = SF.replaceImplementation(SFImpl, {'from': OWNER})
receipt2 = SFImpl.becomeImplementation(SF, {'from': OWNER})

receipt3 = SF.migrateAzur(stAZUR, AZUR_PID, {'from': OWNER})

receipt4 = SF.replaceImplementation(oldImplementation, {'from': OWNER})
receipt5 = interface.ISophonFarming(oldImplementation).becomeImplementation(SF, {'from': OWNER})

balanceAfter = stAZUR.balanceOf(SF)
assert balanceBefore == balanceAfter

safe_tx = safe.multisend_from_receipts()
safe.preview(safe_tx, call_trace=True)

safe.pending_transactions
safe.preview_pending()

if SEND_TO_MAINNET:
    signtature = safe.sign_with_frame(safe_tx)
    safe.post_transaction(safe_tx)
    safe.post_signature(safe_tx, signtature)



from brownie_safe import BrownieSafe
from gnosis.safe.enums import SafeOperationEnum
from brownie import *

exec(open("./scripts/env/eth.py").read())

SEND_TO_MAINNET = False

OWNER = "0x3b181838Ae9DB831C17237FAbD7c10801Dd49fcD"
safe = BrownieSafe(OWNER)


wBTC = interface.IERC20("0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599")
Azuro = interface.IERC20("0x9E6be44cC1236eEf7e1f197418592D363BedCd5A")
USDT = interface.IERC20("0xdAC17F958D2ee523a2206206994597C13D831ec7")


wBTCPoints = 40000
AzuroPoints = 50000
USDTPoints = 40000


wBTCEnableBlock = 20369980
AzuroEnableBlock = 20369980
USDTEnableBlock = 20369980



#newPointsPerBlock = SF.pointsPerBlock() + (wBTCPoints + AzuroPoints + USDTPoints) * 1e14
newPointsPerBlock = 55e18

print(wBTCPoints, wBTC, "wBTC", wBTCEnableBlock, 0)
SF.add(wBTCPoints, wBTC, "wBTC", wBTCEnableBlock, 0, {"from": OWNER})

print(AzuroPoints, Azuro, "Azuro", AzuroEnableBlock, 0)
SF.add(AzuroPoints, Azuro, "Azuro", AzuroEnableBlock, 0, {"from": OWNER})

print(USDTPoints, USDT, "USDT", USDTEnableBlock, newPointsPerBlock)
SF.add(USDTPoints, USDT, "USDT", USDTEnableBlock, newPointsPerBlock, {"from": OWNER})


safe_tx = safe.multisend_from_receipts()

safe.preview(safe_tx, call_trace=True)

# you need frame installed
signtature = safe.sign_with_frame(safe_tx)

if SEND_TO_MAINNET:
    safe.post_transaction(safe_tx)
    safe.post_signature(safe_tx, signtature)

safe.pending_transactions


safe.preview_pending()


'''network.priority_fee('2 gwei')
signer = safe.get_signer('any walet with eth')

for tx in safe.pending_transactions:
    receipt = safe.execute_transaction(safe_tx, signer)
    receipt.info()
'''
from brownie_safe import BrownieSafe
from gnosis.safe.enums import SafeOperationEnum

exec(open("./scripts/env/eth.py").read())

safe = BrownieSafe(OWNER)


sDAI = interface.IERC20("0x83F20F44975D03b1b09e64809B757c47f942BEeA")
USDC = interface.IERC20("0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48")
PEPE = interface.IERC20("0x6982508145454Ce325dDbE47a25d4ec3d2311933")
stAethir = interface.IERC20("0xc96Aa65F31E41b4Ca6924B86D93e25686019E59C")


sDAIPoints = 60000
USDCPoints = 60000
PEPEPoints = 50000
stAethirPoints = 40000


sDAIEnableBlock = chain.height # TODO
USDCEnableBlock = chain.height # TODO
PEPEEnableBlock = chain.height # TODO
stAethirEnableBlock = chain.height # TODO



newPointsPerBlock = SF.pointsPerBlock() + (sDAIPoints+ USDCPoints + PEPEPoints + stAethirPoints) *1e14

SF.set(PredefinedPool.sDAI, 60000, sDAIEnableBlock, 0, {"from": OWNER})
SF.add(60000, USDC, "USDC", USDCEnableBlock, 0, {"from": OWNER})
SF.add(50000, stAethir, "stAethir", PEPEEnableBlock, 0, {"from": OWNER})
SF.add(40000, PEPE, "PEPE", stAethirEnableBlock, newPointsPerBlock, {"from": OWNER})


safe_tx = safe.multisend_from_receipts()

safe.preview(safe_tx, call_trace=True)

# you need frame installed
signtature = safe.sign_with_frame(safe_tx)

safe.pending_transactions


safe.preview_pending()


network.priority_fee('2 gwei')
signer = safe.get_signer('any walet with eth')

for tx in safe.pending_transactions:
    receipt = safe.execute_transaction(safe_tx, signer)
    receipt.info()
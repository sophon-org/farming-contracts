from brownie_safe import BrownieSafe
from gnosis.safe.enums import SafeOperationEnum

exec(open("./scripts/env/eth.py").read())

safe = BrownieSafe(OWNER)

USDT = safe.contract('0xdAC17F958D2ee523a2206206994597C13D831ec7')

tx_list = []


tx_list.append([SF, SF.add.encode_input(10000, USDT.address, "USDT", chain.height, 0)])


safe_tx = safe.multisend_from_receipts()



    


# Post it to the transaction service
# Prompts for a signature if needed
for tx in tx_list:
    sTxn = safe.build_multisig_tx(tx[0].address, 0, tx[1], SafeOperationEnum.DELEGATE_CALL.value, safe_nonce=safe.pending_nonce())
    safe.sign_with_frame(sTxn)
    safe.post_transaction(sTxn)

# Retrieve pending transactions from the transaction service
safe.pending_transactions

# Preview the side effects of all pending transactions
safe.preview_pending()


# Execute the transactions with enough signatures
network.priority_fee('2 gwei')

# stored in .brownie/accounts/TODO.json
signer = safe.get_signer('TODO')

for tx in safe.pending_transactions:
    # below if you have local brownie acc with private key safed. good to have one for execution only.
    # receipt = safe.execute_transaction(safe_tx, signer)
    
    # or execute with frame
    receipt = safe.execute_transaction_with_frame(tx)
    receipt.info()
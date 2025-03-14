
from brownie_safe import BrownieSafe
from safe_eth.safe.enums import SafeOperationEnum
from brownie import Contract
from eth_utils import to_bytes

exec(open("./scripts/env/sophon-mainnet.py").read())

SEND_TO_MAINNET = False
ROLLUP_CHAIN_MS_MULTISIG = "0xa3b1f968b608642dD16d7Fd31bEc0B2c915908dB"
SAFE = BrownieSafe(ROLLUP_CHAIN_MS_MULTISIG)

abbi = [{"inputs":[{"internalType":"bytes","name":"transactions","type":"bytes"}],"name":"multiSend","outputs":[],"stateMutability":"payable","type":"function"}]
MULTICALL = "0x0408EF011960d02349d50286D20531229BCef773"
MULTICALL = Contract.from_abi("M", MULTICALL, abi = abbi)

tx_list = []

def encode_transactions(transactions):
    """
    Encode multiple transactions into a single hex string payload for multiSend.

    Args:
        transactions (list[dict]): A list of transactions, where each transaction is a dictionary with:
            - "operation" (int): 0 for `call`, 1 for `delegatecall`.
            - "to" (str): The target address (hex string with `0x` prefix).
            - "value" (int): The value (in Wei) to send.
            - "data" (str): The data to send (hex string with `0x` prefix).

    Returns:
        str: The encoded transactions as a single hex string (prefixed with "0x").
    """
    encoded_payload = b""

    for tx in transactions:
        # Extract transaction fields
        operation = tx["operation"]
        to = tx["to"]
        value = tx["value"]
        data = tx["data"]

        # Ensure the address is 20 bytes
        to_bytes_address = to_bytes(hexstr=to)

        # Convert data from a hex string to bytes
        # (strip "0x" before converting)
        data_bytes = bytes.fromhex(data[2:]) if data.startswith("0x") else bytes.fromhex(data)

        # Encode each part
        operation_bytes = bytes([operation])  # 1 byte for operation
        value_bytes = value.to_bytes(32, byteorder="big")  # 32 bytes for value
        data_length_bytes = len(data_bytes).to_bytes(32, byteorder="big")  # 32 bytes for data length

        # Pack the transaction
        encoded_transaction = (
            operation_bytes +
            to_bytes_address.rjust(20, b'\x00') +  # Address (20 bytes)
            value_bytes +                           # Value (32 bytes)
            data_length_bytes +                     # Data Length (32 bytes)
            data_bytes                              # Data (variable length)
        )

        # Append the encoded transaction to the payload
        encoded_payload += encoded_transaction

    # Return the final payload as a hex string prefixed with "0x"
    return "0x" + encoded_payload.hex()


def decode_transactions_from_string(payload: str):
    """
    Decode the transactions payload (hex string) into its individual components.

    Args:
        payload (str): The encoded transactions payload as a hex string.

    Returns:
        List[dict]: A list of decoded transactions with their components.
    """
    # Convert the hex string to bytes
    payload_bytes = bytes.fromhex(payload.replace("0x", ""))
    decoded_transactions = []
    i = 0

    while i < len(payload_bytes):
        # Decode operation (1 byte)
        operation = payload_bytes[i]
        i += 1

        # Decode `to` address (20 bytes)
        to = "0x" + payload_bytes[i:i + 20].hex()
        i += 20

        # Decode `value` (32 bytes)
        value = int.from_bytes(payload_bytes[i:i + 32], byteorder="big")
        i += 32

        # Decode `data length` (32 bytes)
        data_length = int.from_bytes(payload_bytes[i:i + 32], byteorder="big")
        i += 32

        # Decode `data` (variable length)
        data = payload_bytes[i:i + data_length]
        i += data_length

        # Append the decoded transaction to the list
        decoded_transactions.append({
            "operation": operation,
            "to": to,
            "value": value,
            "data_length": data_length,
            "data": data.hex()  # Represent `data` as a hex string
        })

    return decoded_transactions

tx_list = []

NEW_POINTS_PER_BLOCL = 0


USDT_USN_LP = "0x353B35a3362Dff8174cd9679BC4a46365CcD4dA7"
SUSN_USN_LP = "0x51d4C0A6E552A0C5c0C0FB2047D413963314B3F4"


USDT_USN_LP_DESCRIPTION = "USDT_USN_LP"
SUSN_USN_LP_DESCRIPTION = "SUSN_USN_LP"


# USDT_USN_lp = 3x
# SUSN_USN_lp = 3x


USDT_USN_LP_MULTIPLIER = 3e18
SUSN_USN_LP_MULTIPLIER = 3e18



currentBlock = 0 # 0 means use block.number

tx_list.append((SF_L2.address, SF_L2.add.encode_input(USDT_USN_LP, USDT_USN_LP_MULTIPLIER, USDT_USN_LP_DESCRIPTION, currentBlock, 0)))
tx_list.append((SF_L2.address, SF_L2.add.encode_input(SUSN_USN_LP, SUSN_USN_LP_MULTIPLIER, SUSN_USN_LP_DESCRIPTION, currentBlock, 0)))

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
# test on fork
# MULTICALL.multiSend(payload, {'from': ROLLUP_CHAIN_MS_MULTISIG, 'paymaster_address': "0x98546B226dbbA8230cf620635a1e4ab01F6A99B2"})


if SEND_TO_MAINNET:
    for tx in tx_list:
        sTxn = SAFE.build_multisig_tx(MULTICALL.address, 0, msig_payload, SafeOperationEnum.DELEGATE_CALL.value, safe_nonce=SAFE.pending_nonce())
        SAFE.sign_with_frame(sTxn)
        SAFE.post_transaction(sTxn)

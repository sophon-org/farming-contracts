
# from brownie_safe import BrownieSafe
# from safe_eth.safe.enums import SafeOperationEnum

exec(open("./scripts/env/sophon-mainnet.py").read())

ROLLUP_CHAIN_MS_MULTISIG = "0xa3b1f968b608642dD16d7Fd31bEc0B2c915908dB"
# SAFE = BrownieSafe(ROLLUP_CHAIN_MS_MULTISIG)
abbi = [{"inputs":[{"internalType":"bytes","name":"transactions","type":"bytes"}],"name":"multiSend","outputs":[],"stateMutability":"payable","type":"function"}
]
MULTICALL = Contract.from_abi("M", MULTICALL, abi = abbi)
SEND_TO_MAINNET = False

from eth_utils import to_bytes

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


ETHUSDC_LP = "0x353B35a3362Dff8174cd9679BC4a46365CcD4dA7"
ETHUSDT_LP = "0x51d4C0A6E552A0C5c0C0FB2047D413963314B3F4"
ATHETH_LP = "0x131bCf81e9cedF0c8ebE607BA07ab3DCF9C52Ee6"
OPNETH_LP = "0x4C0819fD1Cc1f4Ab423b375736a0bE404fAf739D"
BEAMETH_LP = "0x0110EB76B1Fcc94ae4687dDdB2552121373C036B"
USDCUSDT_LP = "0x61a87fa6Dd89a23c78F0754EF3372d35ccde5935"
MUPETH_LP = "0xBeF8358ab02b1af3b9d8af97E8963e9cA4f92727"
SUSNUSD = "0xb87DbE27Db932baCAAA96478443b6519D52C5004"
USNUSD = "0xC1AA99c3881B26901aF70738A7C217dc32536d36"


ETHUSDC_LP_DESCRIPTION = "ETHUSDC_LP"
ETHUSDT_LP_DESCRIPTION = "ETHUSDT_LP"
ATHETH_LP_DESCRIPTION = "ATHETH_LP"
OPNETH_LP_DESCRIPTION = "OPNETH_LP"
BEAMETH_LP_DESCRIPTION = "BEAMETH_LP"
USDCUSDT_LP_DESCRIPTION = "USDCUSDT_LP"
MUPETH_LP_DESCRIPTION = "MUPETH_LP"
SUSNUSD_DESCRIPTION = "SUSNUSD"
USNUSD_DESCRIPTION = "USNUSD"

# ethusdc_lp = 3x
# ethusdt_lp = 3x
# atheth_lp = 3x
# opneth_lp = 3x
# usdcusdt_lp = 3x
# mupeth_lp = 4x

ETHUSDC_LP_MULTIPLIER = 3e18
ETHUSDT_LP_MULTIPLIER = 3e18
ATHETH_LP_MULTIPLIER = 3e18
OPNETH_LP_MULTIPLIER = 3e18
BEAMETH_LP_MULTIPLIER = 3e18
USDCUSDT_LP_MULTIPLIER = 3e18
MUPETH_LP_MULTIPLIER = 4e18
SUSNUSD_MULTIPLIER = 1e18
USNUSD_MULTIPLIER = 1e18



ETHUSDC_LP_FEED = "0x3da283a4802e929149eee1ff019fce5ee9d2b24cbe5703e93002e71a45f3f429"
ETHUSDT_LP_FEED = "0xcdc1993935960e37c7f6c70d53f2b56ff03451d173236e2926590529f5f85616"
ATHETH_LP_FEED = "0xefae7a66a7b4145a593f5727d5184b3e8b5f2e59481546be4e3042b0cce18438"
OPNETH_LP_FEED = "0x9129972d100fbceb8e8a711ed60d8ccc6fa973b8b2ef09f2e5af0fe99bda8afb"
BEAMETH_LP_FEED = "0x20da5bf55630b3ec058e0f7699785944ec7c295c2da2f5e365100a973a36cdd9"
USDCUSDT_LP_FEED = "0xbd1aeb1a5cc49062a0bba944d52a39e637564b9519de9da0dab01f8b6078c219"
MUPETH_LP_FEED = "0x37a45a3f9614725f5c0eb5df5f281aba3ac248dcf9044e0d141230bb944bc88b"
SUSNUSD_FEED = "0x4fad14ab0b3793942fa6b796f40b263f0bb67815685625f9061f804cc4f7968f"
USNUSD_FEED = "0x810c0f50dc3af1ab1f99a766364531d36ec597530fe669bd313f8e1799afea99"


currentBlock = 0 # 0 means use block.number

tx_list.append((SF_L2.address, SF_L2.add.encode_input(ETHUSDC_LP, ETHUSDC_LP_MULTIPLIER, ETHUSDC_LP_DESCRIPTION, currentBlock, 0)))
tx_list.append((SF_L2.address, SF_L2.add.encode_input(ETHUSDT_LP, ETHUSDT_LP_MULTIPLIER, ETHUSDT_LP_DESCRIPTION, currentBlock, 0)))
tx_list.append((SF_L2.address, SF_L2.add.encode_input(ATHETH_LP, ATHETH_LP_MULTIPLIER, ATHETH_LP_DESCRIPTION, currentBlock, 0)))
tx_list.append((SF_L2.address, SF_L2.add.encode_input(OPNETH_LP, OPNETH_LP_MULTIPLIER, OPNETH_LP_DESCRIPTION, currentBlock, 0)))
tx_list.append((SF_L2.address, SF_L2.add.encode_input(BEAMETH_LP, BEAMETH_LP_MULTIPLIER, BEAMETH_LP_DESCRIPTION, currentBlock, 0)))
tx_list.append((SF_L2.address, SF_L2.add.encode_input(USDCUSDT_LP, USDCUSDT_LP_MULTIPLIER, USDCUSDT_LP_DESCRIPTION, currentBlock, 0)))
tx_list.append((SF_L2.address, SF_L2.add.encode_input(MUPETH_LP, MUPETH_LP_MULTIPLIER, MUPETH_LP_DESCRIPTION, currentBlock, 0)))
tx_list.append((SF_L2.address, SF_L2.add.encode_input(SUSNUSD, SUSNUSD_MULTIPLIER, SUSNUSD_DESCRIPTION, currentBlock, 0)))
tx_list.append((SF_L2.address, SF_L2.add.encode_input(USNUSD, USNUSD_MULTIPLIER, USNUSD_DESCRIPTION, currentBlock, NEW_POINTS_PER_BLOCL)))


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


# if SEND_TO_MAINNET:
#     for tx in tx_list:
#         sTxn = SAFE.build_multisig_tx(MULTICALL.address, 0, msig_payload, SafeOperationEnum.DELEGATE_CALL.value, safe_nonce=SAFE.pending_nonce())
#         SAFE.sign_with_frame(sTxn)
#         SAFE.post_transaction(sTxn)

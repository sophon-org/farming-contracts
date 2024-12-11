exec(open("./scripts/env/sepolia.py").read())

from eth_abi import encode
user1 = accounts.load("0xe749b7469A9911E451600CB31B5Ca180743183cE")

depositAmount = 100 * 10 **18
chainId = 531050104
mintValue = 100e18 # SOPH
l2Value = 0
l2GasLimit = 2000000
l2GasPerPubdataByteLimit = 800
refundRecipient = user1
secondBridgeAddress = SHAREDBRIDGE
secondBridgeValue = 0
# (address _l1Token, uint256 _depositAmount, address _l2Receiver)
secondBridgeCalldata = encode(
        ["address", "uint256", "address"],
        [DAI.address, depositAmount, user1.address]
    ).hex()
    # return Web3.keccak(hexstr=text.hex())

request = (
    chainId,
    mintValue,
    l2Value,
    l2GasLimit,
    l2GasPerPubdataByteLimit,
    refundRecipient,
    secondBridgeAddress,
    secondBridgeValue,
    secondBridgeCalldata
)


BRIDGEHUB.requestL2TransactionTwoBridges(request, {"from": user1, "value": 0, "gas_price": Wei("50 gwei")})


from web3 import Web3
asdf = 777
asdfs = "0xe749b7469A9911E451600CB31B5Ca180743183cE"

hashed = encode(
        ["address", "uint256"],
        [asdfs, asdf]
    )

Web3.solidity_keccak(["address", "uint256"],
        [asdfs, asdf])
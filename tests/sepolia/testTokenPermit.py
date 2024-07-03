import pytest
from eth_account import Account
from eth_account.messages import encode_defunct
from eth_abi import encode
from web3 import Web3
from brownie import accounts, chain, SophonToken

# Define constants

VERSION = "1"


@pytest.fixture(scope="module")
def token(SophonToken):
    return SophonToken.deploy({'from': accounts[0]})

def get_domain_separator(token):
    chain_id = chain.id  # Set your chain ID here
    text =  encode(
        ["bytes32", "bytes32", "bytes32", "uint256", "address"],
        [
            Web3.solidity_keccak(["string"], ["EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"]),
            Web3.solidity_keccak(["string"], [token.name()]),
            Web3.solidity_keccak(["string"], [VERSION]),
            chain_id,
            token.address
        ]
    )
    return Web3.keccak(hexstr=text.hex())

def get_struct_hash(owner, spender, value, nonce, deadline):
    permit_typehash = Web3.solidity_keccak(
        ["string"],
        ["Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"]
    )
    text =  encode(
        ["bytes32", "address", "address", "uint256", "uint256", "uint256"],
        [permit_typehash, owner, spender, value, nonce, deadline]
    )
    return Web3.keccak(hexstr=text.hex())

def get_message_hash(domain_separator, struct_hash):
    prefix = b'\x19\x01'
    return Web3.solidity_keccak(
        ["bytes", "bytes32", "bytes32"],
        [
            prefix,
            domain_separator,
            struct_hash
        ]
    )

def sign_message(message_hash, private_key):
    account = Account.from_key(private_key)
    signature = account.signHash(message_hash)
    return signature.v, signature.r, signature.s

def test_permit(token):
    # def test_permit(token):
    owner = accounts[0]
    spender = accounts[1]
    value = 1000 * 10**18
    nonce = token.nonces(owner.address)
    deadline = chain.time() + 100000  # 100k seconds in the future

    domain_separator = get_domain_separator(token)
    assert domain_separator == token.DOMAIN_SEPARATOR()
    struct_hash = get_struct_hash(owner.address, spender.address, value, nonce, deadline)
    message_hash = get_message_hash(domain_separator, struct_hash)

    v, r, s = sign_message(message_hash, "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80")

    # Now you can use the permit function with the signature
    token.permit(owner.address, spender.address, value, deadline, v, r, s, {"from": owner})

    # Verify the allowance has been set correctly
    assert token.allowance(owner.address, spender.address) == value
    assert token.nonces(owner.address) == nonce + 1


def test_permit_expired_signature(token):
    
        # def test_permit(token):
    owner = accounts[0]
    spender = accounts[1]
    value = 1000 * 10**18
    nonce = token.nonces(owner.address)
    deadline = chain.time() - 3000  # in the past

    domain_separator = get_domain_separator(token)
    assert domain_separator == token.DOMAIN_SEPARATOR()
    struct_hash = get_struct_hash(owner.address, spender.address, value, nonce, deadline)
    message_hash = get_message_hash(domain_separator, struct_hash)

    v, r, s = sign_message(message_hash, "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80")

    # Now you can use the permit function with the signature
    with pytest.raises(Exception, match="revert: ERC2612ExpiredSignature: " + str(deadline)):
        token.permit(owner.address, spender.address, value, deadline, v, r, s, {"from": owner})


def test_permit_incorrect_nonce(token):
    owner = accounts[0]
    spender = accounts[1]
    value = 1000 * 10**18
    nonce = token.nonces(owner.address) + 1 # INCORRECT
    deadline = chain.time() + 3000  # in the past
    domain_separator = get_domain_separator(token)
    assert domain_separator == token.DOMAIN_SEPARATOR()
    struct_hash = get_struct_hash(owner.address, spender.address, value, nonce, deadline)
    message_hash = get_message_hash(domain_separator, struct_hash)
    v, r, s = sign_message(message_hash, "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff81")
    with pytest.raises(Exception, match="revert: ERC2612InvalidSigner: "):
        token.permit(owner.address, spender.address, value, deadline, v, r, s, {'from': owner})
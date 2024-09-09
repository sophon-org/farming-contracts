import hashlib
# from eth_utils import encode_hex, to_bytes
from eth_abi import encode
from merkletree import MerkleTree
from web3 import Web3

# Define a function to encode the data similar to abi.encodePacked
def encode_packed(index, account, pid, amount, boost_amount, deposit_amount, reward_settled, reward_debt):
    account_bytes = bytes.fromhex(account[2:])  # Remove '0x' prefix and convert to bytes
    return to_bytes(index) + account_bytes + to_bytes(pid) + to_bytes(amount) + to_bytes(boost_amount) + to_bytes(deposit_amount) + to_bytes(reward_settled) + to_bytes(reward_debt)

# Define userInfos in Python
userInfos = [
    { 'account': '0x0000000000000000000000000000000000000001', 'pid': 0, 'amount': 1000, 'boostAmount': 100, 'depositAmount': 900, 'rewardSettled': 500, 'rewardDebt': 200 },
    { 'account': '0x0000000000000000000000000000000000000002', 'pid': 0, 'amount': 2000, 'boostAmount': 200, 'depositAmount': 1800, 'rewardSettled': 1000, 'rewardDebt': 400 },
    { 'account': '0xe749b7469A9911E451600CB31B5Ca180743183cE', 'pid': 0, 'amount': 1879452157034848486000000, 'boostAmount': 0, 'depositAmount': 1879452157034848486000000, 'rewardSettled': 0, 'rewardDebt': 0 },
]

# Initialize Merkle Tree
# mt = MerkleTree()

# Generate leaves by encoding userInfos
leaves = []
for i, user in enumerate(userInfos):
    leaf = keccak(encode_packed(i, user['account'], user['pid'], user['amount'], user['boostAmount'], user['depositAmount'], user['rewardSettled'], user['rewardDebt']))
    leaves.append(leaf)
    # mt.add_leaf(encode_hex(leaf))

mt = MerkleTree(leaves)
# Build the Merkle tree
mt.make_tree()

# Get the Merkle root
merkle_root = mt.get_merkle_root()

# Generate and print proofs for each leaf
proofs = []
for i in range(len(leaves)):
    proof = mt.get_proof(i)
    proofs.append(proof)
    print("Proof for leaf i: proof", i, proof)

print("Merkle Root:", merkle_root)

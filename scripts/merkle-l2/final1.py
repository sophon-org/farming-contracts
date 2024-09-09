# from pymerkle import MerkleTree
from pymerkle import InmemoryTree as MerkleTree
from web3 import Web3

# Initialize the Merkle Tree
tree = MerkleTree(algorithm='keccak_256')
userInfos = [
    { 'account': '0x0000000000000000000000000000000000000001', 'pid': 0, 'amount': '1000', 'boostAmount': '100', 'depositAmount': '900', 'rewardSettled': '500', 'rewardDebt': '200' },
    { 'account': '0x0000000000000000000000000000000000000002', 'pid': 0, 'amount': '2000', 'boostAmount': '200', 'depositAmount': '1800', 'rewardSettled': '1000', 'rewardDebt': '400' },
    { 'account': '0xe749b7469A9911E451600CB31B5Ca180743183cE', 'pid': 0, 'amount': '1879452157034848486000000', 'boostAmount': '0', 'depositAmount': '1879452157034848486000000', 'rewardSettled': '0', 'rewardDebt': '0' },
    # { 'account': '0xe749b7469A9911E451600CB31B5Ca180743183cE', 'pid': 0, 'amount': 1879452157034848486000001, 'boostAmount': 0, 'depositAmount': 1879452157034848486000000, 'rewardSettled': 0, 'rewardDebt': 0 },
    # { 'account': '0xe749b7469A9911E451600CB31B5Ca180743183cE', 'pid': 0, 'amount': 1879452157034848486000002, 'boostAmount': 0, 'depositAmount': 1879452157034848486000000, 'rewardSettled': 0, 'rewardDebt': 0 },
    # { 'account': '0xe749b7469A9911E451600CB31B5Ca180743183cE', 'pid': 0, 'amount': 1879452157034848486000003, 'boostAmount': 0, 'depositAmount': 1879452157034848486000000, 'rewardSettled': 0, 'rewardDebt': 0 },
    # { 'account': '0xe749b7469A9911E451600CB31B5Ca180743183cE', 'pid': 0, 'amount': 1879452157034848486000004, 'boostAmount': 0, 'depositAmount': 1879452157034848486000000, 'rewardSettled': 0, 'rewardDebt': 0 },
]
# Add leaves to the tree
leaves = []
for userInfo in userInfos:
    # leaf = keccak(text=f"{userInfo['account']},{userInfo['pid']},{userInfo['amount']},{userInfo['boostAmount']},{userInfo['depositAmount']},{userInfo['rewardSettled']},{userInfo['rewardDebt']}")
    
    leaf = Web3.solidity_keccak(["address", "uint256", "uint256", "uint256", "uint256", "uint256", "uint256"],
            [userInfo['account'], 
             int(userInfo['pid']), 
             int(userInfo['amount']), 
             int(userInfo['boostAmount']), 
             int(userInfo['depositAmount']), 
             int(userInfo['rewardSettled']), 
             int(userInfo['rewardDebt'])])
    leaves.append(leaf)
    tree.append_entry(leaf)

# Finalize the tree
# tree.finalize()
print("leaves", leaves)
print("root", tree.root.digest.hex())
# Generate proof for a specific leaf
# proof = tree.generate_audit_proof(0)  # Proof for the first leaf
# print(proof)

proofs = []
for i in range(len(leaves)):
    proof = tree.get_proof(i)
    proofs.append(proof)
    print("Proof for leaf i: proof", i, proof)

print("Merkle Root:", tree.root.digest.hex())

a = Web3.solidity_keccak(["address", "uint256", "uint256", "uint256", "uint256", "uint256", "uint256"],
            [userInfos[2]['account'], 
             int(userInfos[2]['pid']), 
             int(userInfos[2]['amount']), 
             int(userInfos[2]['boostAmount']), 
             int(userInfos[2]['depositAmount']), 
             int(userInfos[2]['rewardSettled']), 
             int(userInfos[2]['rewardDebt'])
            ])
print("a", a.hex())
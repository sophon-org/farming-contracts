from brownie_safe import BrownieSafe
from safe_eth.safe.enums import SafeOperationEnum
import json

SEND_TO_MAINNET = False
LAST_REWARD_BLOCK = 934000

TECH_MULTISIG = "0xe52757064e04bB7ec756C3e91aAa3acA1fD88b08"
SAFE = BrownieSafe(TECH_MULTISIG)
exec(open("./scripts/env/sophon-mainnet.py").read())

replacements = dict([
    ["0xe3bF2440cD0703Df2d545028799Ef1c42db414Fa",	"0x4bEb6B5deF547bb51a420F32C2D50C383F2D9887"],
])

tx_list = []
# _claim(
    # address _user, 
    # address _customReceiver, 
    # uint256 _pid, 
    # ISophonFarming.UserInfo memory _userInfo, 
    # bytes32[] calldata _merkleProof) 

file_path = ('./scripts/merkle-l2/output/5-proof.json')
with open(file_path, 'r', encoding='utf-8') as file:
    data = json.load(file)
    claims = data.get('claims', [])
    for r in replacements:
        claim = claims[r.lower()]
        print(len(claim))
        
        for c in claim:
            user = c["user"]
            customReceiver = replacements[r]
            pid = c["pid"]
            userInfo = (
                c["amount"],
                c["boostAmount"],
                c["depositAmount"],
                c["rewardSettled"],
                c["rewardDebt"],
            )
            proof = c["proof"]
            print(user, pid)
            payload = MA.claim.encode_input(user, customReceiver, pid, userInfo, proof)
            tx_list.append((MA.address, payload))
            
        

# for tx in tx_list:
#     sTxn = SAFE.build_multisig_tx(tx[0], 0, tx[1], SafeOperationEnum.CALL.value, safe_nonce=SAFE.pending_nonce())
#     SAFE.sign_with_frame(sTxn)
#     SAFE.post_transaction(sTxn)

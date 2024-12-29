from brownie_safe import BrownieSafe
from safe_eth.safe.enums import SafeOperationEnum
import json

SEND_TO_MAINNET = False
LAST_REWARD_BLOCK = 934000

TECH_MULTISIG = "0xe52757064e04bB7ec756C3e91aAa3acA1fD88b08"
SAFE = BrownieSafe(TECH_MULTISIG)
exec(open("./scripts/env/sophon-mainnet.py").read())

replacements = dict([
    ["0x1c6ac2177798fe78109818a9d5bb48d9161e70cb",	"0x6d4af8c9676596e7e5534898c622efc4b2140097"],
    ["0x13E0eeD7663957b18D28b08f90835C7fd5bBA053",	"0xF6C2E2e7556077B7F8376A1140E83EaDFa534E56"],
    ["0x6014bbf466f1119d5af48f8af9b711deb14683cf",	"0x8cfddf8b09f1e1bf0b52c7ca360a1e1a6676a002"],
    ["0xdd6d32875b7ce1b3da2d273dccfdb30d4055fefa",	"0xe04267d13a59ddd7163b3f8ae889cd66fb758d42"],
    ["0xeff0e3108f2c00ab7852248bc3887964e243c9e8",	"0xC890d1Bf02E1358D906C76CEfF3aE757FeA548Bc"],
    ["0xf4aeda8e3f72102bd6745ea6f749f01a7021ad39",	"0xfebb27f132a94c5dbfd9b04b7199224cb9db4092"],
    ["0xcdeaafc4ae84e619f0c4c86cbeb32a7436ff46ca",	"0xc5a8e9caee1490696ff670dee3c3fb8b2a55a2d8"],
    ["0x3F0520847C52988A1b555690C2852c9B71Aee8eC",	"0x25AA769F8c8712EF917CF06D98bbb9b904A4f2c7"],
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
                c["rewardDebt"],
                c["rewardSettled"],
            )
            proof = c["proof"]
            print(user, pid)
            payload = MA.claim.encode_input(user, customReceiver, pid, userInfo, proof)
            tx_list.append(MA.address, payload)
            
        

for tx in tx_list:
    sTxn = SAFE.build_multisig_tx(tx[0], 0, tx[1], SafeOperationEnum.CALL.value, safe_nonce=SAFE.pending_nonce())
    SAFE.sign_with_frame(sTxn)
    SAFE.post_transaction(sTxn)

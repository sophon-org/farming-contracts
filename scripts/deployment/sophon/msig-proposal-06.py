from brownie_safe import BrownieSafe
from safe_eth.safe.enums import SafeOperationEnum
import json

SEND_TO_MAINNET = False
tx_list = []

exec(open("./scripts/env/sophon-mainnet.py").read())

TECH_MULTISIG = "0x902767c9e11188C985eB3494ee469E53f1b6de53"
SAFE = BrownieSafe(TECH_MULTISIG)

MULTICALL = "0x0408EF011960d02349d50286D20531229BCef773"
compromisedWallets =  dict([
    ["0xcce7f482ffdbf4b7017c7b3a25707497e5c49d22",	"0x1671b500ee76f1b6d4db0128e47675603f0b4686"],
    ["0x1c6ac2177798fe78109818a9d5bb48d9161e70cb",	"0x6d4af8c9676596e7e5534898c622efc4b2140097"],
    ["0x13E0eeD7663957b18D28b08f90835C7fd5bBA053",	"0xF6C2E2e7556077B7F8376A1140E83EaDFa534E56"],
    ["0x227c80ffefbe803270a5c0df0f80e4838cefda85",	"0x573bffafd8f277e4058ba801674249515c8c0e26"],
    ["0x79aad4051cd2d6247021fb7e5de6381379a3a030",	"0xC1f7818AbFb76D5c2F793457EbfA80Dfbe66a48c"],
    ["0xb4329a5e9c01801fb7743fde69be1e5412d05f22",	"0x35fb691390120568c05a9979a068b66ba62c0b7c"],
    ["0x6014bbf466f1119d5af48f8af9b711deb14683cf",	"0x8cfddf8b09f1e1bf0b52c7ca360a1e1a6676a002"],
    ["0xdd6d32875b7ce1b3da2d273dccfdb30d4055fefa",	"0xe04267d13a59ddd7163b3f8ae889cd66fb758d42"],
    ["0xeff0e3108f2c00ab7852248bc3887964e243c9e8",	"0xC890d1Bf02E1358D906C76CEfF3aE757FeA548Bc"],
    ["0x8Da3418582cAb80c4c034E898FB6d789cfEaB771",	"0xa9a4b6bb71fda523505769f4e98d7c853779dc4c"],
    ["0xf4aeda8e3f72102bd6745ea6f749f01a7021ad39",	"0xfebb27f132a94c5dbfd9b04b7199224cb9db4092"],
    ["0x71784a8b738a340c433c48cce913c1f633869830",	"0x7c727a58f99fa59b59851703784a79f77a53291d"],
    ["0xa10d11eb58c417b639fa977c297275e6db6acfcf",	"0x38474fab5fbcc6338ae741f4aedd6a9f568859ee"],
    ["0xcdeaafc4ae84e619f0c4c86cbeb32a7436ff46ca",	"0xc5a8e9caee1490696ff670dee3c3fb8b2a55a2d8"],
    ["0xc0a7fb8d87e7522db0bb540b586fbfe731b8e04c",	"0xd7450d16f3cf70bae78994ce61133f5134206859"],
    ["0x5887ce1f3ec4e802b959d2ce2a6895cbd85b72c1",	"0x58d39460e92978f2247726e5765a991d8e751ce1"],
    ["0xdb874f638bacc20cb2e00d2eeedff10eddc2fd1f",	"0x5f7f93c3ae7132f54ac12391fffc45b1f82ef10e"],
    ["0x3F0520847C52988A1b555690C2852c9B71Aee8eC",	"0x25AA769F8c8712EF917CF06D98bbb9b904A4f2c7"],
    ["0x8D901Ae4C6B730e5Dad1E4fF7837013E024A8999",	"0xecb73c18557a392199c02b84a5bf116bb955b991"],
])

file_path = ('./scripts/merkle-l2/output/5-proof.json')
with open(file_path, 'r', encoding='utf-8') as file:
    data = json.load(file)
    claims = data.get('claims', [])
    for w in compromisedWallets:
        if w.lower() in claims:
            claim = claims[w.lower()]
            # print(len(claim))
            
            for c in claim:
                user = c["user"]
                customReceiver = compromisedWallets[w]
                pid = c["pid"]
                userInfo = (
                    c["amount"],
                    c["boostAmount"],
                    c["depositAmount"],
                    c["rewardSettled"],
                    c["rewardDebt"],
                )
                proof = c["proof"]
                
                hasClaimed = MA.hasClaimed(w, pid)
                if not (hasClaimed):
                    print("to claim", user, pid, hasClaimed)
                    payload = MA.claim.encode_input(user, customReceiver, pid, userInfo, proof)
                    tx_list.append((MA.address, payload))
                else:
                    print("user claimed", user, pid)
        else:
            print("user has nothing to claim", w.lower())
# for w in compromisedWallets:
#     for index, pool in enumerate(poolInfo):
#         hasClaimed = MA.hasClaimed(w[0], index)
#         if (hasClaimed):
#             print(w[0], index, hasClaimed)

# safe_tx = SAFE.multisend_from_receipts()

# SAFE.preview(safe_tx, call_trace=True)

if SEND_TO_MAINNET:
    for tx in tx_list:
        sTxn = SAFE.build_multisig_tx(tx[0], 0, tx[1], SafeOperationEnum.CALL.value, safe_nonce=SAFE.pending_nonce())
        SAFE.sign_with_frame(sTxn)
        SAFE.post_transaction(sTxn)

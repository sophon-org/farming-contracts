exec(open("./scripts/env/sepolia.py").read())
deployer = accounts.load("sophon_sepolia")

# testnet only. 
# 1. send test tokens to users

# user wallets
testWallets = [
    "0xe749b7469A9911E451600CB31B5Ca180743183cE",
    "0x75e529F523E41623F45d794eF1C023caF6E2d295",
    "0x3c902069BE2eAfB251102446b22D1b054013B998",
    "0xfBAb39445f51C123194eeD79894D5847Fd794Aa8",
    "0x1c9Ff39402b15e9A7C67ffd1A260d04d852F5DFe",
    "0x3D2758B432327E3631b023AA4a0511c5308e4BFC",
    "0x78Ae12562527B865DD1a06784a2b06dbe1A3C7AF",
    "0xe5b06bfd663C94005B8b159Cd320Fd7976549f9b",
    "0x81B76cDeE6217545Bdc860fC1379eC23888BeA9a",
    "0x4bC73dCc4c296d744C7E0E215B309Fd5304a6094"
]

tokens = [
    DAI,
    sDAI,
    # wstETH,
    # weETH,
    BEAM,
    stZENT,
    AZUR,
    stAZUR,
    # WETH,
    # stETH,
    # eETH ,
]

FIXED_GAS_PRICE = web3.to_wei(30, 'gwei')

# Custom gas price strategy function
def fixed_gas_price_strategy(web3, transaction_params=None):
    return FIXED_GAS_PRICE

web3.eth.set_gas_price_strategy(fixed_gas_price_strategy)

import time
# for t in tokens:
for wallet in testWallets:
    try:
        print(wallet)
        # a = t.mint(wallet, 1e6*1e18, {"from": deployer, "gas_price": Wei("15 gwei"), "gas_limit": 1000000, "required_conf": 1})
        # a = PEPE.mint(wallet, 1e6*1e18, {"from": deployer, "gas_price": Wei("15 gwei"), "gas_limit": 1000000, "required_conf": 1})
        a = USDT.mint(wallet, 1e6*1e18, {"from": deployer, "gas_price": Wei("30 gwei"), "gas_limit": 1000000, "required_conf": 1})
        # stAZUR.transfer(wallet, 1e6*1e18, {"from": deployer, "gas_price": Wei("15 gwei"), "gas_limit": 1000000, "required_conf": 1})
        # deployer.transfer(to=wallet, amount=Wei("0.1 ether"), gas_limit=100000, gas_price=Wei("15 gwei"))
        time.sleep(20)
    except Exception as e:
        time.sleep(20)
        print(e)
    
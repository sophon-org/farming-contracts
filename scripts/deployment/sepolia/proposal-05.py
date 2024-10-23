exec(open("./scripts/env/sepolia.py").read())
deployer = accounts.load("sophon_sepolia")

OWNER = deployer

stAVAIL = MockERC20.deploy("Mock USDC stAVAIL", "MockUSDC", 18, {"from": deployer})
stAVAILPoints = 50000

# https://etherscan.io/block/countdown/21040373
# Fri Oct 25 2024 04:45:03
# UTC
stAVAILEnableBlock = 21040373 

newPointsPerBlock = SF.pointsPerBlock() + (stAVAILPoints) * 1e14

SF.add(stAVAILPoints, stAVAIL, "stAVAIL", stAVAILEnableBlock, newPointsPerBlock, {"from": OWNER})


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


for wallet in testWallets:
    try:
        print(wallet)
        a = stAVAIL.mint(wallet, 1e18*1e18, {"from": deployer})
        
    except Exception as e:
        import time
        time.sleep(20)
        print(e)
deployer = accounts[0]

weth                = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
stETH               = "0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84"
wstETH              = "0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0"
wstETHAllocPoint    = 20000
eETH                = "0x35fA164735182de50811E8e2E824cFb9B6118ac2"
eETHLiquidityPool   = "0x308861A430be4cce5502d0A12724771Fc6DaF216"
weETH               = "0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee"
dai                 = "0x6B175474E89094C44Da98b954EedeAC495271d0F"
sDAI                = "0x83F20F44975D03b1b09e64809B757c47f942BEeA"
sDAIAllocPoint      = 20000
pointsPerBlock      = pointsPerBlock = 25*10**18
startBlock          = chain.height
boosterMultiplier   = 2e18




args = [
    dai,
    sDAI,
    weth,
    stETH,
    wstETH,
    eETH,
    eETHLiquidityPool,
    weETH
]

SFImpl = SophonFarming.deploy(args, {'from': deployer, "gas_limit": 10000000})

SFProxy = SophonFarmingProxy.deploy(SFImpl, {"from": deployer})

SF = interface.ISophonFarming(SFProxy)

SF.initialize(wstETHAllocPoint, sDAIAllocPoint, pointsPerBlock, startBlock, boosterMultiplier, {'from': deployer})



# testing rsETH
rsETH = interface.IERC20("0xa1290d69c65a6fe4df752f95823fae25cb99e5a7")
SF.add(10000, rsETH, "rsETH", "rsETH description", True, {"from": deployer})

rsETH_holder = "0x22162DbBa43fE0477cdC5234E248264eC7C6EA7c"

user1 = accounts[1]
user2 = accounts[2]

rsETH.transfer(user1, 100e18, {"from": rsETH_holder})

rsETH.approve(SF, 2**256-1, {"from": user1})
SF.deposit(3, rsETH.balanceOf(user1), 0, {"from": user1})

poolShare_rsETH = interface.IERC20(SF.getPoolInfo()[3][8])

 
SF.setEndBlocks(chain.height+1000, 2000, {"from": deployer})


chain.mine(1010)
assert False
poolShare_rsETH.transfer(user2, poolShare_rsETH.balanceOf(user1), {"from": user1})
SF.exit(3, {"from": user2})

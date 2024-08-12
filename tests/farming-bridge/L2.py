# this file show proof of concept on how to set everything on L2 for farming to start for the users
# this is to be run on ZK-SYNC ERA
SF_L2 = interface.ISophonFarming("0x17cA6CfB56fE7105ED1eE58ed572Fa902Dec8182")
SF_L2 = SophonFarmingL2.at("0x17cA6CfB56fE7105ED1eE58ed572Fa902Dec8182")

sDAI = interface.IERC20Metadata("0xeE56823BBE21A15a855A2f34231c7d5B93C10eD2") # Mock Savings Dai 

deployer = accounts.load("sophon_sepolia")
user1 = accounts.load("0xe749b7469A9911E451600CB31B5Ca180743183cE")


SF_L2.addPool(sDAI, ZERO_ADDRESS,  939726078517424243000000, 0, 939726078517424243000000, 20000, 6467585, 8867832365023, 8333333333333333333, 'sDAI', {"from": deployer})

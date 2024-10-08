SF = interface.ISophonFarming("0xe80f651aCCb1574DD2D84021cf1d27862363E390")
# SFImpl = interface.ISophonFarming("")
OWNER = "0xE0486B081dAcC8e6af7f204abF508Ecc044B48A6"


# Tokens

# WETH = interface.IERC20("0x01cB5735e54F69739e8917c709fa0B4a9E95ACc6")
DAI = MockERC20.at("0xd7D2ae4Fb61a0bd126Bd865a68A238d7d81DC641")
sDAI = interface.IERC20("0x64555DD79DA6Bd9E9293d630AbAE7C1f8FAC1Dd7")
wstETH = interface.IERC20("0xCdB9b24fe84448175b8Ab821E4c42d7Db176C732")
weETH = interface.IERC20("0x1ac4090094F44cfb41417D8772500DB051D32b32")
BEAM = MockERC20.at("0x2E8F9867d1b3e5e94Cd86D3924419767A243e15C")
stZENT = MockERC20.at("0xb4681a78200235A4131b9C5F07F7c48ff2D98dF7")
AZUR = MockAZUR.at("0x6898CE3ED25F9ef4AF68C3f61E29C00E21264B73")
stAZUR = MockstAZUR.at("0x28772832E5a5C4a617bC0772A9F47ce52C47C8b9")
WETH = MockWETH.at("0x01cB5735e54F69739e8917c709fa0B4a9E95ACc6")
stETH = MockERC20.at("0xA77588ebf19bD40a93927fFA50e1D298076E00A7")
eETH = MockERC20.at("0x730be55B37FA8fcD9d8321931892B829d05620ac")

class PredefinedPool:
    sDAI = 0
    wstETH = 1
    weETH = 2
    BEAM = 3
    BEAM_ETH = 4
    stZENT = 5





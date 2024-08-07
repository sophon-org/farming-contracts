SF = interface.ISophonFarming("0xEfF8E65aC06D7FE70842A4d54959e8692d6AE064")
SFImpl = interface.ISophonFarming("0x78910E1DFE6Df94ea7EeC54b25921673db0e2a06")
OWNER = "0x3b181838Ae9DB831C17237FAbD7c10801Dd49fcD"

BEAM_ETH_UNIV2 = interface.IERC20("0x180EFC1349A69390aDE25667487a826164C9c6E4")
BEAM = interface.IERC20("0x62D0A8458eD7719FDAF978fe5929C6D342B0bFcE")


class PredefinedPool:
    sDAI = 0
    wstETH = 1
    weETH = 2
    BEAM = 3
    BEAM_ETH = 4
    ZENT = 5
    stZENT = 6
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {SophonFarming} from "../contracts/farm/SophonFarming.sol";
import {SophonFarmingState, BridgeLike} from "./../contracts/farm/SophonFarmingState.sol";
import {SophonFarmingProxy} from "./../contracts/proxies/SophonFarmingProxy.sol";
import {Proxy} from "./../contracts/proxies/Proxy.sol";
import {SophonFarmingHarness} from "./utils/SophonFarmingHarness.sol";
import {MockERC20} from "./../contracts/mocks/MockERC20.sol";
import {MockWETH} from "./../contracts/mocks//MockWETH.sol";
import {MockStETH} from "./../contracts/mocks/MockStETH.sol";
import {MockWstETH} from "./../contracts/mocks/MockWstETH.sol";
import {MockeETHLiquidityPool} from "./../contracts/mocks/MockeETHLiquidityPool.sol";
import {MockWeETH} from "./../contracts/mocks/MockweETH.sol";
import {MockSDAI} from "./../contracts/mocks/MockSDAI.sol";
import {MockBridge} from "./../contracts/mocks/MockBridge.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Azur
import {SFAzurUpgrade} from "./../contracts/farm/SFAzurUpgrade.sol";
import {MockAZUR} from "./../contracts/mocks/MockAZUR.sol";
import {MockstAZUR} from "./../contracts/mocks/MockStAZUR.sol";

contract SFAzurUpgradeTest is Test {
    address internal azur = 0x9E6be44cC1236eEf7e1f197418592D363BedCd5A;
    address internal stAzur = 0x67f3228fD58f5A26D93a5dd0c6989b69c95618eB;
    address internal msig = 0x3b181838Ae9DB831C17237FAbD7c10801Dd49fcD;
    uint256 internal azurPid = 11;

    address internal farm = 0xEfF8E65aC06D7FE70842A4d54959e8692d6AE064;
    SophonFarmingProxy internal farmProxy = SophonFarmingProxy(payable(farm));

    address internal oldImplementation = 0x78910E1DFE6Df94ea7EeC54b25921673db0e2a06;

    string internal ENV_MAINNET_API_KEY = vm.envString("MAINNET_API_KEY");
    string internal MAINNET_RPC_URL = string.concat("https://eth-mainnet.g.alchemy.com/v2/", ENV_MAINNET_API_KEY);
    uint256 internal mainnetFork;

    function setUp() public {
        mainnetFork = vm.createSelectFork(MAINNET_RPC_URL);
    }

    function testCanSetForkBlockNumber() public {
        assertEq(vm.activeFork(), mainnetFork);
        assertGt(block.number, 1_337_000);
    }

    function testSeparateTxs() public {
        // Assume everything is done by the multisig
        vm.startPrank(msig);

        // Deploy new implementation
        address newImplementation = address(new SFAzurUpgrade());

        // Upgrade to new implementation
        farmProxy.replaceImplementation(newImplementation);
        assertEq(farmProxy.pendingImplementation(), newImplementation);
        SophonFarming(payable(newImplementation)).becomeImplementation(farmProxy);
        assertEq(farmProxy.implementation(), newImplementation);

        // Migrate
        uint256 startAzurBalance = IERC20(azur).balanceOf(address(farm));
        uint256 startStAzurBalance = IERC20(stAzur).balanceOf(address(farm));
        assertGt(startAzurBalance, 0);
        assertEq(startStAzurBalance, 0);

        SFAzurUpgrade(farm).migrateAzur(stAzur, azurPid);

        uint256 endAzurBalance = IERC20(azur).balanceOf(address(farm));
        uint256 endStAzurBalance = IERC20(stAzur).balanceOf(address(farm));
        assertEq(endAzurBalance, 0);
        assertGt(endStAzurBalance, 0);

        assertEq(startAzurBalance, endStAzurBalance);
        assertEq(startStAzurBalance, endAzurBalance);

        // Upgrade to old implementation
        farmProxy.replaceImplementation(oldImplementation);
        assertEq(farmProxy.pendingImplementation(), oldImplementation);
        SophonFarming(payable(oldImplementation)).becomeImplementation(farmProxy);
        assertEq(farmProxy.implementation(), oldImplementation);
    }

    function testSafeTx() public {
        // TODO: Test with Safe transaction
    }
}
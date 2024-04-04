// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {SophonFarming} from "../contracts/farm/SophonFarming.sol";
import {SophonFarmingProxy} from "./../contracts/proxies/SophonFarmingProxy.sol";
import {MockERC20} from "./../contracts/mocks/MockERC20.sol";
import {MockWETH} from "./../contracts/mocks//MockWETH.sol";
import {MockStETH} from "./../contracts/mocks/MockStETH.sol";
import {MockWstETH} from "./../contracts/mocks/MockWstETH.sol";
import {MockSDAI} from "./../contracts/mocks/MockSDAI.sol";

contract SophonFarmingTest is Test {
    string internal mnemonic = "test test test test test test test test test test test junk";
    string internal envMnemonicKey = "MNEMONIC";

    address internal deployer;

    SophonFarmingProxy public sophonFarmingProxy;
    SophonFarming public sophonFarming;
    address public implementation;
    
    MockERC20 internal mock0;
    MockERC20 internal mock1;

    MockWETH internal weth;
    MockStETH internal stETH;
    MockWstETH internal wstETH;
    MockERC20 internal dai;
    MockSDAI internal sDAI;

    uint256 internal wstETHAllocPoint;
    uint256 internal sDAIAllocPoint;
    uint256 internal pointsPerBlock;
    uint256 internal startBlock;
    uint256 internal boosterMultiplier;

    uint256 maxUint = type(uint256).max;

    function setUp() public {
        string memory envMnemonic = vm.envString(envMnemonicKey);
        if (keccak256(abi.encode(envMnemonic)) != keccak256(abi.encode(""))) {
            mnemonic = envMnemonic;
        }

        deployer = vm.addr(vm.deriveKey(mnemonic, 0));

        // Deal and start prank
        vm.deal(deployer, 1000000e18);
        vm.startPrank(deployer);

        // Deploy mock tokens
        mock0 = new MockERC20("Mock0", "M0", 18);
        mock0.mint(address(this), 1000000e18);
        mock1 = new MockERC20("Mock1", "M1", 18);
        mock1.mint(address(this), 1000000e18);

        // mock WETH
        weth = new MockWETH();

        // mock stETH
        stETH = new MockStETH();

        // mock wstETH
        wstETH = new MockWstETH(stETH);
        wstETHAllocPoint = 20000;

        // mock DAI
        dai = new MockERC20("Mock Dai Token", "MockDAI", 18);
        dai.mint(address(this), 1000000e18);
        
        // mock sDAI
        sDAI = new MockSDAI(dai);
        sDAIAllocPoint = 20000;

        // Set up for SophonFarming
        pointsPerBlock = 25e18;
        startBlock = block.number;
        boosterMultiplier = 2e18;

        // Deploy implementation
        implementation = address(new SophonFarming(
            address(weth),
            address(stETH),
            address(wstETH),
            address(dai),
            address(sDAI)
        ));

        // Deploy proxy
        sophonFarmingProxy = new SophonFarmingProxy(implementation);

        // Grant the implementation interface to the proxy
        sophonFarming = SophonFarming(payable(address(implementation)));

        // Initialize SophonFarming
        sophonFarming.initialize(
            wstETHAllocPoint,
            sDAIAllocPoint,
            pointsPerBlock,
            startBlock,
            boosterMultiplier
        );

        // Add mock tokens
        sophonFarming.add(10000, address(mock0), "mock0", true);
        sophonFarming.add(30000, address(mock1), "mock1", true);

        // Set approvals
        mock0.approve(address(sophonFarming), maxUint);
        mock1.approve(address(sophonFarming), maxUint);
        weth.approve(address(sophonFarming), maxUint);
        stETH.approve(address(sophonFarming), maxUint);
        wstETH.approve(address(sophonFarming), maxUint);
        dai.approve(address(sophonFarming), maxUint);
        sDAI.approve(address(sophonFarming), maxUint);
        stETH.approve(address(wstETH), maxUint);
        dai.approve(address(sDAI), maxUint);

        // Mint some tokens
        mock0.mint(deployer, 1000e18);
        mock1.mint(deployer, 1000e18);
        weth.deposit{value: 0.01e18}();
        stETH.submit{value: 0.02e18}(address(sophonFarming));
        wstETH.wrap(stETH.balanceOf(deployer) / 2);
        dai.mint(deployer, 1000e18);
        sDAI.deposit(dai.balanceOf(deployer) / 2, deployer);

        // Deposit ETH
        sophonFarming.depositEth{value: 0.01e18}(0.01e18 * 2 / 100);
        
        // Deposit Weth
        // TODO: set when receive is implemented
        // sophonFarming.depositWeth(weth.balanceOf(deployer), weth.balanceOf(deployer) * 5 / 100);
        
        // Deposit stETH
        sophonFarming.depositStEth(stETH.balanceOf(deployer), 0);

        // Deposit wstETH
        sophonFarming.depositDai(dai.balanceOf(deployer), dai.balanceOf(deployer) * 1 / 10);

        // Deposit sDAI
        sophonFarming.deposit(2, 1000e18, 1000e18 * 1 / 100);

        // Deposit sDAI
        sophonFarming.deposit(3, 1000e18, 0);
    }

    function test_ConstructorParameters() public {
        assertEq(sophonFarming.weth(), address(weth));
        assertEq(sophonFarming.stETH(), address(stETH));
        assertEq(sophonFarming.wstETH(), address(wstETH));
        assertEq(sophonFarming.dai(), address(dai));
        assertEq(sophonFarming.sDAI(), address(sDAI));
    }

    function test_Initialize() public {
        (,,,,uint256 wstAllocPoint,,,) = sophonFarming.poolInfo(0);
        assertEq(wstAllocPoint, wstETHAllocPoint);

        (,,,,uint256 sDAIAllocPoint,,,) = sophonFarming.poolInfo(1);
        assertEq(sDAIAllocPoint, sDAIAllocPoint);

        assertEq(sophonFarming.startBlock(), startBlock);
        assertEq(sophonFarming.pointsPerBlock(), pointsPerBlock);
        assertEq(sophonFarming.boosterMultiplier(), boosterMultiplier);
    }
}

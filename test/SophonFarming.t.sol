// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {SophonFarming} from "../contracts/farm/SophonFarming.sol";
// import {PoolShareToken} from "./../contracts/farm/PoolShareToken.sol";
import {SophonFarmingState, BridgeLike} from "./../contracts/farm/SophonFarmingState.sol";
import {SophonFarmingProxy} from "./../contracts/proxies/SophonFarmingProxy.sol";
import {Proxy} from "./../contracts/proxies/Proxy.sol";
import {MockERC20} from "./../contracts/mocks/MockERC20.sol";
import {MockWETH} from "./../contracts/mocks//MockWETH.sol";
import {MockStETH} from "./../contracts/mocks/MockStETH.sol";
import {MockWstETH} from "./../contracts/mocks/MockWstETH.sol";
import {MockeETHLiquidityPool} from "./../contracts/mocks/MockeETHLiquidityPool.sol";
import {MockWeETH} from "./../contracts/mocks/MockweETH.sol";
import {MockSDAI} from "./../contracts/mocks/MockSDAI.sol";
import {MockBridge} from "./../contracts/mocks/MockBridge.sol";
// import {PermitTester} from "./utils/PermitTester.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SophonFarmingTest is Test {
    string internal mnemonic = "test test test test test test test test test test test junk";
    string internal envMnemonicKey = "MNEMONIC";

    address internal deployer;
    address internal account1 = address(0x1);
    address internal account2 = address(0x2);
    address internal account3 = address(0x3);
    uint256 internal permitUserPK = 0x0000000000000000000000000000000000000000000000000000000000000001;

    SophonFarmingProxy public sophonFarmingProxy;
    SophonFarming public sophonFarming;
    address public implementation;

    MockERC20 internal mock0;
    MockERC20 internal mock1;

    MockWETH internal weth;
    MockStETH internal stETH;
    MockWstETH internal wstETH;
    MockERC20 internal eETH;
    MockeETHLiquidityPool internal eETHLiquidityPool;
    MockWeETH internal weETH;
    MockERC20 internal dai;
    MockSDAI internal sDAI;

    uint256 internal wstETHAllocPoint;
    uint256 internal sDAIAllocPoint;
    uint256 internal pointsPerBlock;
    uint256 internal startBlock;
    uint256 internal boosterMultiplier;

    // PoolShareToken internal sDAIpoolShareToken;
    // PoolShareToken internal wstETHpoolShareToken;
    // PoolShareToken internal weETHpoolShareToken;

    uint256 maxUint = type(uint256).max;

    error Unauthorized();
    error OwnableUnauthorizedAccount(address account);
    error InsufficientBalance();

    // Helper functions
    function StETHRate(uint256 amount) internal pure returns (uint256) {
        return amount / 1001 * 1000;
    }

    function WstETHRate(uint256 amount) internal view returns (uint256) {
        return amount * wstETH.tokensPerStEth() / 1e18;
    }

    function eETHLPRate(uint256 amount) internal pure returns (uint256) {
        return amount / 1001 * 1000;
    }

    function WeETHRate(uint256 amount) internal view returns (uint256) {
        return amount * weETH.tokensPereETH() / 1e18;
    }

    // Setup
    function setUp() public {
        string memory envMnemonic = vm.envString(envMnemonicKey);
        if (keccak256(abi.encode(envMnemonic)) != keccak256(abi.encode(""))) {
            mnemonic = envMnemonic;
        }

        deployer = vm.addr(vm.deriveKey(mnemonic, 0));

        // Deal and start prank
        vm.deal(deployer, 1000000e18);
        vm.startPrank(deployer);

        // // Deploy mock tokens
        // mock0 = new MockERC20("Mock0", "M0", 18);
        // mock0.mint(address(this), 1000000e18);
        // mock1 = new MockERC20("Mock1", "M1", 18);
        // mock1.mint(address(this), 1000000e18);

        // mock WETH
        weth = new MockWETH();

        // mock stETH
        stETH = new MockStETH();

        // mock wstETH
        wstETH = new MockWstETH(stETH);
        wstETHAllocPoint = 20000;

        eETH = new MockERC20("Mock eETH Token", "MockeETH", 18);

        eETHLiquidityPool = new MockeETHLiquidityPool(eETH);

        weETH = new MockWeETH(eETH);

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
        implementation = address(
            new SophonFarming(
                [
                    address(dai),
                    address(sDAI),
                    address(weth),
                    address(stETH),
                    address(wstETH),
                    address(eETH),
                    address(eETHLiquidityPool),
                    address(weETH)
                    // address(0x13),
                    // address(0x14),
                    // address(0x15),
                    // address(0x16),
                    // address(0x17)
                ]
            )
        );

        // Deploy proxy
        sophonFarmingProxy = new SophonFarmingProxy(implementation);

        // Grant the implementation interface to the proxy
        sophonFarming = SophonFarming(payable(address(implementation)));

        // Initialize SophonFarming
        sophonFarming.initialize(wstETHAllocPoint, sDAIAllocPoint, pointsPerBlock, startBlock, boosterMultiplier);

        // Get lpToken addresses
        // SophonFarmingState.PoolInfo[] memory PoolInfo;

        // PoolInfo = sophonFarming.getPoolInfo();

        // sDAIpoolShareToken = PoolInfo[sophonFarming.typeToId(SophonFarmingState.PredefinedPool.sDAI)].poolShareToken;
        // wstETHpoolShareToken = PoolInfo[sophonFarming.typeToId(SophonFarmingState.PredefinedPool.wstETH)].poolShareToken;
        // weETHpoolShareToken = PoolInfo[sophonFarming.typeToId(SophonFarmingState.PredefinedPool.weETH)].poolShareToken;

        // // Add mock tokens
        // sophonFarming.add(10000, address(mock0), "mock0", true);
        // sophonFarming.add(30000, address(mock1), "mock1", true);

        // Set approvals
        // mock0.approve(address(sophonFarming), maxUint);
        // mock1.approve(address(sophonFarming), maxUint);
        weth.approve(address(sophonFarming), maxUint);
        stETH.approve(address(sophonFarming), maxUint);
        wstETH.approve(address(sophonFarming), maxUint);
        dai.approve(address(sophonFarming), maxUint);
        sDAI.approve(address(sophonFarming), maxUint);
        stETH.approve(address(wstETH), maxUint);
        dai.approve(address(sDAI), maxUint);

        // Mint some tokens
        // mock0.mint(deployer, 1000e18);
        // mock1.mint(deployer, 1000e18);
        weth.deposit{value: 0.01e18}();
        stETH.submit{value: 0.02e18}(address(sophonFarming));
        wstETH.wrap(stETH.balanceOf(deployer) / 2);
        dai.mint(deployer, 1000e18);
        sDAI.deposit(dai.balanceOf(deployer) / 2, deployer);

        // // Deposit ETH
        // sophonFarming.depositEth{value: 0.01e18}(0.01e18 * 2 / 100);

        // // Deposit Weth
        // sophonFarming.depositWeth(weth.balanceOf(deployer), weth.balanceOf(deployer) * 5 / 100);

        // // Deposit stETH
        // sophonFarming.depositStEth(stETH.balanceOf(deployer), 0);

        // // Deposit wstETH
        // sophonFarming.depositDai(dai.balanceOf(deployer), dai.balanceOf(deployer) * 1 / 10);

        // // Deposit sDAI
        // sophonFarming.deposit(2, 1000e18, 1000e18 * 1 / 100);

        // // Deposit sDAI
        // sophonFarming.deposit(3, 1000e18, 0);

        sophonFarming.setEndBlocks(maxUint - 1000, 1000);

        vm.stopPrank();
    }

    // function setUser(address _user) internal {
    //     vm.stopPrank();
    //     vm.startPrank(deployer);

    //     // Fund user
    //     vm.deal(_user, 1000000e18);
    //     mock0.mint(_user, 1000000e18);
    //     mock1.mint(_user, 1000000e18);
    //     dai.mint(_user, 1000000e18);

    //     mock0.approve(address(sophonFarming), maxUint);
    //     mock1.approve(address(sophonFarming), maxUint);
    //     weth.approve(address(sophonFarming), maxUint);
    //     stETH.approve(address(sophonFarming), maxUint);
    //     wstETH.approve(address(sophonFarming), maxUint);
    //     dai.approve(address(sophonFarming), maxUint);
    //     sDAI.approve(address(sophonFarming), maxUint);
    //     stETH.approve(address(wstETH), maxUint);
    //     dai.approve(address(sDAI), maxUint);
    // }

    function setOneDepositorPerPool() public {
        vm.prank(deployer);
        // sophonFarming.setEndBlocks(block.number + 100, 50);

        uint256 amountToDeposit1 = 100e18;
        uint256 poolId1 = sophonFarming.typeToId(SophonFarmingState.PredefinedPool.wstETH);

        vm.startPrank(account1);
        deal(address(wstETH), account1, amountToDeposit1);

        wstETH.approve(address(sophonFarming), amountToDeposit1);
        sophonFarming.deposit(poolId1, amountToDeposit1, 0);
        vm.stopPrank();

        vm.startPrank(account2);
        deal(address(wstETH), account2, amountToDeposit1);

        wstETH.approve(address(sophonFarming), amountToDeposit1);
        sophonFarming.deposit(poolId1, amountToDeposit1, 0);
        vm.stopPrank();

        uint256 amountToDeposit2 = 10000e18;
        uint256 poolId2 = sophonFarming.typeToId(SophonFarmingState.PredefinedPool.sDAI);

        vm.startPrank(account2);
        deal(address(sDAI), account2, amountToDeposit2);

        sDAI.approve(address(sophonFarming), amountToDeposit2);
        sophonFarming.deposit(poolId2, amountToDeposit2, 0);
        vm.stopPrank();

        uint256 amountToDeposit3 = 10000e18;

        vm.startPrank(account3);
        deal(address(eETH), account3, amountToDeposit3);

        eETH.approve(address(sophonFarming), amountToDeposit3);
        sophonFarming.depositeEth(amountToDeposit3, 0);
        vm.stopPrank();
    }

    // UPGRADEABLE 2 STEP FUNCTIONS /////////////////////////////////////////////////////////////////
    function test_ReplaceImplementation() public {
        vm.startPrank(deployer);

        address newImplementation = address(
            new SophonFarming(
                [
                    address(dai),
                    address(sDAI),
                    address(weth),
                    address(stETH),
                    address(wstETH),
                    address(eETH),
                    address(eETHLiquidityPool),
                    address(weETH)
                    // address(0x13),
                    // address(0x14),
                    // address(0x15),
                    // address(0x16),
                    // address(0x17)
                ]
            )
        );

        sophonFarmingProxy.replaceImplementation(newImplementation);
        assertEq(sophonFarmingProxy.pendingImplementation(), newImplementation);
    }

    function test_BecomeImplementation() public {
        vm.startPrank(deployer);

        address newImplementation = address(
            new SophonFarming(
                [
                    address(dai),
                    address(sDAI),
                    address(weth),
                    address(stETH),
                    address(wstETH),
                    address(eETH),
                    address(eETHLiquidityPool),
                    address(weETH)
                    // address(0x13),
                    // address(0x14),
                    // address(0x15),
                    // address(0x16),
                    // address(0x17)
                ]
            )
        );

        sophonFarmingProxy.replaceImplementation(newImplementation);

        SophonFarming(payable(newImplementation)).becomeImplementation(sophonFarmingProxy);

        assertEq(sophonFarmingProxy.implementation(), newImplementation);
    }

    function test_BecomeImplementation_RevertWhen_Unauthorized() public {
        vm.startPrank(deployer);

        address newImplementation = address(
            new SophonFarming(
                [
                    address(dai),
                    address(sDAI),
                    address(weth),
                    address(stETH),
                    address(wstETH),
                    address(eETH),
                    address(eETHLiquidityPool),
                    address(weETH)
                    // address(0x13),
                    // address(0x14),
                    // address(0x15),
                    // address(0x16),
                    // address(0x17)
                ]
            )
        );

        sophonFarmingProxy.replaceImplementation(newImplementation);

        vm.stopPrank();
        vm.startPrank(account1);
        vm.expectRevert(Unauthorized.selector);
        SophonFarming(payable(newImplementation)).becomeImplementation(sophonFarmingProxy);
    }

    function test_BecomeImplementation_RevertWhen_OwnableUnauthorizedAccount() public {
        vm.startPrank(deployer);

        address newImplementation = address(
            new SophonFarming(
                [
                    address(dai),
                    address(sDAI),
                    address(weth),
                    address(stETH),
                    address(wstETH),
                    address(eETH),
                    address(eETHLiquidityPool),
                    address(weETH)
                    // address(0x13),
                    // address(0x14),
                    // address(0x15),
                    // address(0x16),
                    // address(0x17)
                ]
            )
        );

        sophonFarmingProxy.replaceImplementation(account1);

        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, newImplementation));
        SophonFarming(payable(newImplementation)).becomeImplementation(sophonFarmingProxy);
    }

    // REPLACE_IMPLEMENTATION FUNCTION /////////////////////////////////////////////////////////////////
    function test_Proxy() public {
        vm.startPrank(deployer);

        Proxy proxy = new Proxy(implementation);
        assertEq(proxy.implementation(), implementation);

        address newImplementation = address(
            new SophonFarming(
                [
                    address(dai),
                    address(sDAI),
                    address(weth),
                    address(stETH),
                    address(wstETH),
                    address(eETH),
                    address(eETHLiquidityPool),
                    address(weETH)
                    // address(0x13),
                    // address(0x14),
                    // address(0x15),
                    // address(0x16),
                    // address(0x17)
                ]
            )
        );

        proxy.replaceImplementation(newImplementation);
        assertEq(proxy.implementation(), newImplementation);
    }

    // CONSTRUCTOR PARAMETERS /////////////////////////////////////////////////////////////////
    function test_ConstructorParameters() public view {
        assertEq(sophonFarming.weth(), address(weth));
        assertEq(sophonFarming.stETH(), address(stETH));
        assertEq(sophonFarming.wstETH(), address(wstETH));
        assertEq(sophonFarming.dai(), address(dai));
        assertEq(sophonFarming.sDAI(), address(sDAI));
    }

    // POOL_LENGTH FUNCTION /////////////////////////////////////////////////////////////////
    function test_PoolLength() public view {
        assertEq(sophonFarming.poolLength(), 3);
    }

    // INITIALIZE FUNCTION /////////////////////////////////////////////////////////////////
    function test_Initialize() public view {
        SophonFarmingState.PoolInfo[] memory PoolInfo;
        PoolInfo = sophonFarming.getPoolInfo();

        assertEq(PoolInfo[0].allocPoint, wstETHAllocPoint);

        assertEq(PoolInfo[1].allocPoint, sDAIAllocPoint);

        assertEq(sophonFarming.startBlock(), startBlock);
        assertEq(sophonFarming.pointsPerBlock(), pointsPerBlock);
        assertEq(sophonFarming.boosterMultiplier(), boosterMultiplier);

        assertEq(sophonFarming.poolExists(address(weth)), true);
        assertEq(sophonFarming.poolExists(address(stETH)), true);
        assertEq(sophonFarming.poolExists(address(dai)), true);

        assertEq(stETH.allowance(address(sophonFarming), address(wstETH)), maxUint);
        assertEq(dai.allowance(address(sophonFarming), address(sDAI)), maxUint);
    }

    function test_Initialize_RevertWhen_AlreadyInitialized() public {
        vm.startPrank(deployer);

        vm.expectRevert(SophonFarming.AlreadyInitialized.selector);
        sophonFarming.initialize(0, 0, 0, 0, 0);
    }

    function test_Initialize_RevertWhen_InvalidStartBlock() public {
        vm.startPrank(deployer);

        address _implementation = address(
            new SophonFarming(
                [
                    address(dai),
                    address(sDAI),
                    address(weth),
                    address(stETH),
                    address(wstETH),
                    address(eETH),
                    address(eETHLiquidityPool),
                    address(weETH)
                    // address(0x13),
                    // address(0x14),
                    // address(0x15),
                    // address(0x16),
                    // address(0x17)
                ]
            )
        );

        // Deploy proxy
        SophonFarmingProxy _sophonFarmingProxy = new SophonFarmingProxy(_implementation);
        (_sophonFarmingProxy);

        // Grant the implementation interface to the proxy
        SophonFarming _sophonFarming = SophonFarming(payable(address(_implementation)));

        vm.expectRevert(SophonFarming.InvalidStartBlock.selector);
        _sophonFarming.initialize(0, 0, 0, 0, 0);
    }

    // ADD FUNCTION /////////////////////////////////////////////////////////////////
    function testFuzz_Add(uint256 newAllocPoints) public {
        vm.assume(newAllocPoints > 0 && newAllocPoints <= 100000);
        vm.startPrank(deployer);

        MockERC20 mock = new MockERC20("Mock", "M", 18);
        uint256 startingAllocPoint = sophonFarming.totalAllocPoint();
        uint256 poolId = sophonFarming.add(newAllocPoints, address(mock), mock.name(), true);

        SophonFarmingState.PoolInfo[] memory PoolInfo;

        PoolInfo = sophonFarming.getPoolInfo();

        assertEq(address(PoolInfo[poolId].lpToken), address(mock));
        assertEq(PoolInfo[poolId].amount, 0);
        assertEq(PoolInfo[poolId].boostAmount, 0);
        assertEq(PoolInfo[poolId].depositAmount, 0);
        assertEq(PoolInfo[poolId].allocPoint, newAllocPoints);
        assertEq(PoolInfo[poolId].lastRewardBlock, startBlock);
        assertEq(PoolInfo[poolId].accPointsPerShare, 0);
        assertEq(abi.encode(PoolInfo[poolId].description), abi.encode(mock.name()));

        assertEq(startingAllocPoint + newAllocPoints, sophonFarming.totalAllocPoint());
    }

    function test_Add_RevertWhen_FarmingIsEnded() public {
        vm.startPrank(deployer);

        sophonFarming.setEndBlocks(block.number + 1, 1);
        vm.roll(block.number + 2);

        MockERC20 mock = new MockERC20("Mock", "M", 18);

        vm.expectRevert(SophonFarming.FarmingIsEnded.selector);
        sophonFarming.add(10000, address(mock), "Mock", true);
    }

    // SET FUNCTION /////////////////////////////////////////////////////////////////
    function testFuzz_SetFunction(uint256 newAllocPoints) public {
        vm.assume(newAllocPoints > 0 && newAllocPoints <= 100000);
        vm.startPrank(deployer);

        vm.roll(block.number - 1);

        uint256 poolId = sophonFarming.typeToId(SophonFarmingState.PredefinedPool.sDAI);
        uint256 startingTotalAllocPoint = sophonFarming.totalAllocPoint();

        SophonFarmingState.PoolInfo[] memory startingPoolInfo;
        startingPoolInfo = sophonFarming.getPoolInfo();

        sophonFarming.set(poolId, newAllocPoints, true);

        SophonFarmingState.PoolInfo[] memory finalPoolInfo;
        finalPoolInfo = sophonFarming.getPoolInfo();

        assertEq(finalPoolInfo[poolId].allocPoint, newAllocPoints);
        assertEq(
            sophonFarming.totalAllocPoint(),
            startingTotalAllocPoint - startingPoolInfo[poolId].allocPoint + newAllocPoints
        );
    }

    function test_Set_RevertWhen_FarmingIsEnded() public {
        vm.startPrank(deployer);

        sophonFarming.setEndBlocks(block.number + 1, 1);
        vm.roll(block.number + 2);

        uint256 poolId = sophonFarming.typeToId(SophonFarmingState.PredefinedPool.sDAI);

        vm.expectRevert(SophonFarming.FarmingIsEnded.selector);
        sophonFarming.set(poolId, 10000, true);
    }

    // IS_FARMING_ENDED FUNCTION /////////////////////////////////////////////////////////////////
    function test_IsFarmingEnded() public {
        vm.startPrank(deployer);

        assertEq(sophonFarming.isFarmingEnded(), false);

        sophonFarming.setEndBlocks(block.number + 10, 1);
        assertEq(sophonFarming.isFarmingEnded(), false);

        vm.roll(block.number + 20);
        assertEq(sophonFarming.isFarmingEnded(), true);
    }

    // SET_BRIDGE_FOR_POOL FUNCTION /////////////////////////////////////////////////////////////////
    function test_SetBridgeForPool() public {
        vm.startPrank(deployer);

        uint256 poolId = sophonFarming.typeToId(SophonFarmingState.PredefinedPool.wstETH);
        address bridge = address(0xB);

        sophonFarming.setBridgeForPool(poolId, bridge);

        SophonFarmingState.PoolInfo[] memory PoolInfo;

        PoolInfo = sophonFarming.getPoolInfo();

        assertEq(PoolInfo[poolId].l2Farm, bridge);
    }

    // SET_START_BLOCK FUNCTION /////////////////////////////////////////////////////////////////
    function testFuzz_SetStartBlock(uint256 newStartBlock) public {
        vm.assume(newStartBlock > block.number && newStartBlock <= block.number + 100000);
        vm.startPrank(deployer);

        sophonFarming.setStartBlock(newStartBlock);
        assertEq(sophonFarming.startBlock(), newStartBlock);
    }

    function test_SetStartBlock_RevertWhen_InvalidStartBlock() public {
        vm.startPrank(deployer);

        vm.expectRevert(SophonFarming.InvalidStartBlock.selector);
        sophonFarming.setStartBlock(0);

        sophonFarming.setEndBlocks(block.number + 9, 1);
        vm.expectRevert(SophonFarming.InvalidStartBlock.selector);
        sophonFarming.setStartBlock(block.number + 10);
    }

    function test_SetStartBlock_RevertWhen_FarmingIsStarted() public {
        vm.startPrank(deployer);

        vm.roll(block.number + 10);

        vm.expectRevert(SophonFarming.FarmingIsStarted.selector);
        sophonFarming.setStartBlock(block.number + 9);
    }

    // SET_END_BLOCK FUNCTION /////////////////////////////////////////////////////////////////
    function testFuzz_SetEndBlocks(uint256 newEndBlock) public {
        vm.assume(newEndBlock > block.number && newEndBlock <= block.number + 100000);
        vm.startPrank(deployer);

        newEndBlock = block.number + 10;
        sophonFarming.setEndBlocks(newEndBlock, 1);
        assertEq(sophonFarming.endBlock(), newEndBlock);

        newEndBlock = 0;
        sophonFarming.setEndBlocks(newEndBlock, 1);
        assertEq(sophonFarming.endBlock(), newEndBlock);
    }

    function test_SetEndBlock_RevertWhen_InvalidEndBlock() public {
        vm.startPrank(deployer);

        sophonFarming.setStartBlock(block.number + 10);
        vm.expectRevert(SophonFarming.InvalidEndBlock.selector);
        sophonFarming.setEndBlocks(block.number + 8, 1);

        vm.roll(block.number + 10);
        vm.expectRevert(SophonFarming.InvalidEndBlock.selector);
        sophonFarming.setEndBlocks(block.number, 1);
    }

    function test_SetEndBlock_RevertWhen_FarmingIsEnded() public {
        vm.startPrank(deployer);

        sophonFarming.setEndBlocks(block.number + 9, 1);
        vm.roll(block.number + 10);

        vm.expectRevert(SophonFarming.FarmingIsEnded.selector);
        sophonFarming.setEndBlocks(block.number + 15, 1);
    }

    // SET_POINTS_PER_BLOCK FUNCTION /////////////////////////////////////////////////////////////////
    function testFuzz_SetPointsPerBlock(uint256 newPointsPerBlock) public {
        vm.assume(newPointsPerBlock > 0 && newPointsPerBlock <= 100e18);
        vm.startPrank(deployer);

        sophonFarming.setPointsPerBlock(newPointsPerBlock);
        assertEq(sophonFarming.pointsPerBlock(), newPointsPerBlock);
    }

    function test_SetPointsPerBlock_RevertWhen_IsFarmingEnded() public {
        vm.startPrank(deployer);

        sophonFarming.setEndBlocks(block.number + 9, 1);
        vm.roll(block.number + 10);

        uint256 newPointsPerBlock = 50e18;
        vm.expectRevert(SophonFarming.FarmingIsEnded.selector);
        sophonFarming.setPointsPerBlock(newPointsPerBlock);
    }

    // SET_BOOSTER_MULTIPLIER FUNCTION /////////////////////////////////////////////////////////////////
    function testFuzz_SetBoosterMultiplier(uint256 newBoosterMultiplier) public {
        vm.assume(newBoosterMultiplier > 0 && newBoosterMultiplier <= 100e18);
        vm.startPrank(deployer);

        sophonFarming.setBoosterMultiplier(newBoosterMultiplier);
        assertEq(sophonFarming.boosterMultiplier(), newBoosterMultiplier);
    }

    function test_SetBoosterMultiplier_RevertWhen_IsFarmingEnded() public {
        vm.startPrank(deployer);

        sophonFarming.setEndBlocks(block.number + 9, 1);
        vm.roll(block.number + 10);

        uint256 newBoosterMultiplier = 3e18;
        vm.expectRevert(SophonFarming.FarmingIsEnded.selector);
        sophonFarming.setBoosterMultiplier(newBoosterMultiplier);
    }

    // GET_BLOCK_MULTIPLIER FUNCTION /////////////////////////////////////////////////////////////////
    function test_GetBlockMultiplier() public {
        vm.startPrank(deployer);
        uint256 newEndBlock = block.number + 100;
        sophonFarming.setEndBlocks(newEndBlock, 1);

        uint256 from = block.number;
        uint256 to = block.number + 10;

        assertEq(sophonFarming.getBlockMultiplier(from, to), (to - from) * 1e18);
        assertEq(sophonFarming.getBlockMultiplier(to, from), 0);

        to = block.number + 1000;
        assertEq(sophonFarming.getBlockMultiplier(from, to), (newEndBlock - from) * 1e18);
    }

    // MASS_UPDATE_POOLS FUNCTION /////////////////////////////////////////////////////////////////
    function test_MassUpdatePools() public {
        vm.startPrank(deployer);

        sophonFarming.setEndBlocks(block.number + 1, 1);
        vm.roll(block.number + 3);

        sophonFarming.massUpdatePools();

        SophonFarmingState.PoolInfo[] memory PoolInfo;

        PoolInfo = sophonFarming.getPoolInfo();

        for (uint256 i = 0; i < PoolInfo.length; i++) {
            assertEq(PoolInfo[i].lastRewardBlock, block.number);
        }
    }

    // UPDATE_POOL FUNCTION /////////////////////////////////////////////////////////////////
    function test_UpdatePool() public {
        vm.startPrank(deployer);

        sophonFarming.setEndBlocks(block.number + 1, 1);
        vm.roll(block.number + 3);

        uint256 poolId = sophonFarming.typeToId(SophonFarmingState.PredefinedPool.wstETH);
        sophonFarming.updatePool(poolId);

        SophonFarmingState.PoolInfo[] memory PoolInfo;

        PoolInfo = sophonFarming.getPoolInfo();

        assertEq(PoolInfo[poolId].lastRewardBlock, block.number);
    }

    // DEPOSIT_ETH FUNCTION /////////////////////////////////////////////////////////////////
    function testFuzz_DepositEth_NotBoosted(uint256 amountToDeposit) public {
        vm.assume(amountToDeposit > 1e6 && amountToDeposit <= 1_000_000_000e18);
        vm.deal(account1, amountToDeposit);
        vm.startPrank(account1);

        uint256 wsthDepositedAmount = WstETHRate(StETHRate(amountToDeposit));
        uint256 poolId = sophonFarming.typeToId(SophonFarmingState.PredefinedPool.wstETH);

        sophonFarming.depositEth{value: amountToDeposit}(0, SophonFarmingState.PredefinedPool.wstETH);
        assertEq(address(account1).balance, 0);

        SophonFarmingState.UserInfo memory userInfo;
        (userInfo.amount, userInfo.boostAmount, userInfo.depositAmount, userInfo.rewardSettled, userInfo.rewardDebt) =
            sophonFarming.userInfo(poolId, account1);

        assertEq(userInfo.amount, wsthDepositedAmount);
        assertEq(userInfo.boostAmount, 0);
        assertEq(userInfo.depositAmount, wsthDepositedAmount);
        assertEq(userInfo.rewardSettled, 0);
        assertEq(userInfo.rewardDebt, 0);
    }

    function testFuzz_DepositEth_MultipleNotBoosted(uint256 amountToDeposit, uint256 multipleDeposits) public {
        vm.assume(amountToDeposit > 1e6 && amountToDeposit <= 1_000_000_000e18);
        vm.assume(multipleDeposits > 0 && multipleDeposits <= 10);
        vm.deal(account1, amountToDeposit * multipleDeposits);
        vm.startPrank(account1);

        uint256 wsthDepositedAmount = WstETHRate(StETHRate(amountToDeposit));
        uint256 poolId = sophonFarming.typeToId(SophonFarmingState.PredefinedPool.wstETH);

        for (uint256 i = 0; i < multipleDeposits; i++) {
            sophonFarming.depositEth{value: amountToDeposit}(0, SophonFarmingState.PredefinedPool.wstETH);
        }
        assertEq(address(account1).balance, 0);

        SophonFarmingState.UserInfo memory userInfo;
        (userInfo.amount, userInfo.boostAmount, userInfo.depositAmount, userInfo.rewardSettled, userInfo.rewardDebt) =
            sophonFarming.userInfo(poolId, account1);

        assertEq(userInfo.amount, wsthDepositedAmount * multipleDeposits);
        assertEq(userInfo.boostAmount, 0);
        assertEq(userInfo.depositAmount, wsthDepositedAmount * multipleDeposits);
        assertEq(userInfo.rewardSettled, 0);
        assertEq(userInfo.rewardDebt, 0);
    }

    function testFuzz_DepositEth_Boosted(uint256 amountToDeposit, uint256 boostFraction) public {
        vm.assume(amountToDeposit > 1e6 && amountToDeposit <= 1_000_000_000e18);
        vm.assume(boostFraction > 0 && boostFraction <= 10);

        vm.deal(account1, amountToDeposit);
        vm.startPrank(account1);

        uint256 wsthDepositedAmount = WstETHRate(StETHRate(amountToDeposit));
        uint256 amountToBoost = amountToDeposit / boostFraction;
        uint256 boostAmount = amountToBoost * wsthDepositedAmount / amountToDeposit;
        uint256 finalBoostAmount = boostAmount * sophonFarming.boosterMultiplier() / 1e18;
        uint256 poolId = sophonFarming.typeToId(SophonFarmingState.PredefinedPool.wstETH);

        sophonFarming.depositEth{value: amountToDeposit}(amountToBoost, SophonFarmingState.PredefinedPool.wstETH);
        assertEq(address(account1).balance, 0);

        SophonFarmingState.UserInfo memory userInfo;
        (userInfo.amount, userInfo.boostAmount, userInfo.depositAmount, userInfo.rewardSettled, userInfo.rewardDebt) =
            sophonFarming.userInfo(poolId, account1);

        assertEq(userInfo.amount, wsthDepositedAmount - boostAmount + finalBoostAmount);
        assertEq(userInfo.boostAmount, finalBoostAmount);
        assertEq(userInfo.depositAmount, wsthDepositedAmount - boostAmount);
        assertEq(userInfo.rewardSettled, 0);
        assertEq(userInfo.rewardDebt, 0);
    }

    function testFuzz_DepositEth_RevertWhen_NoEthSent(uint256 amountToDeposit, uint256 boostFraction) public {
        vm.assume(amountToDeposit > 1e6 && amountToDeposit <= 1_000_000_000e18);
        vm.assume(boostFraction > 0 && boostFraction <= 10);

        vm.deal(account1, amountToDeposit);
        vm.startPrank(account1);

        uint256 amountToBoost = amountToDeposit / boostFraction;

        vm.expectRevert(SophonFarming.NoEthSent.selector);
        sophonFarming.depositEth{value: 0}(amountToBoost, SophonFarmingState.PredefinedPool.wstETH);
    }

    function testFuzz_DepositEth_RevertWhen_FarmingIsEnded(uint256 amountToDeposit, uint256 boostFraction) public {
        vm.assume(amountToDeposit > 1e6 && amountToDeposit <= 1_000_000_000e18);
        vm.assume(boostFraction > 0 && boostFraction <= 10);

        vm.prank(deployer);
        sophonFarming.setEndBlocks(block.number + 9, 1);
        vm.roll(block.number + 10);

        vm.deal(account1, amountToDeposit);
        vm.startPrank(account1);

        uint256 amountToBoost = amountToDeposit / boostFraction;

        vm.expectRevert(SophonFarming.FarmingIsEnded.selector);
        sophonFarming.depositEth{value: amountToDeposit}(amountToBoost, SophonFarmingState.PredefinedPool.wstETH);
    }

    function testFuzz_DepositEth_RevertWhen_InvalidDeposit(uint256 amountToDeposit, uint256 boostFraction) public {
        vm.assume(amountToDeposit > 0 && amountToDeposit < 1001);
        vm.assume(boostFraction > 0 && boostFraction <= 10);

        vm.deal(account1, amountToDeposit);
        vm.startPrank(account1);

        uint256 amountToBoost = amountToDeposit / boostFraction;

        vm.expectRevert(SophonFarming.InvalidDeposit.selector);
        sophonFarming.depositEth{value: amountToDeposit}(amountToBoost, SophonFarmingState.PredefinedPool.wstETH);
    }

    function testFuzz_DepositEth_RevertWhen_BoostTooHigh(uint256 amountToDeposit) public {
        vm.assume(amountToDeposit > 1e6 && amountToDeposit <= 1_000_000_000e18);

        vm.deal(account1, amountToDeposit);
        vm.startPrank(account1);

        uint256 wsthDepositedAmount = WstETHRate(StETHRate(amountToDeposit));
        uint256 amountToBoost = amountToDeposit * 2;

        vm.expectRevert(abi.encodeWithSelector(SophonFarming.BoostTooHigh.selector, wsthDepositedAmount));
        sophonFarming.depositEth{value: amountToDeposit}(amountToBoost, SophonFarmingState.PredefinedPool.wstETH);
    }

    function testFuzz_DepositEth_RevertWhen_InvalidDeposit(uint256 amountToDeposit) public {
        vm.assume(amountToDeposit > 1e6 && amountToDeposit <= 1_000_000_000e18);
        vm.deal(account1, amountToDeposit);
        vm.startPrank(account1);

        vm.expectRevert(SophonFarming.InvalidDeposit.selector);
        sophonFarming.depositEth{value: amountToDeposit}(0, SophonFarmingState.PredefinedPool.pufETH);
    }

    function testFuzz_DepositEthToWeETH_NotBoosted(uint256 amountToDeposit) public {
        vm.assume(amountToDeposit > 1e6 && amountToDeposit <= 1_000_000_000e18);
        vm.deal(account1, amountToDeposit);
        vm.startPrank(account1);

        uint256 weEthDepositedAmount = WeETHRate(eETHLPRate(amountToDeposit));
        uint256 poolId = sophonFarming.typeToId(SophonFarmingState.PredefinedPool.weETH);

        sophonFarming.depositEth{value: amountToDeposit}(0, SophonFarmingState.PredefinedPool.weETH);
        assertEq(address(account1).balance, 0);

        SophonFarmingState.UserInfo memory userInfo;
        (userInfo.amount, userInfo.boostAmount, userInfo.depositAmount, userInfo.rewardSettled, userInfo.rewardDebt) =
            sophonFarming.userInfo(poolId, account1);

        assertEq(userInfo.amount, weEthDepositedAmount);
        assertEq(userInfo.boostAmount, 0);
        assertEq(userInfo.depositAmount, weEthDepositedAmount);
        assertEq(userInfo.rewardSettled, 0);
        assertEq(userInfo.rewardDebt, 0);
    }

    // DEPOSIT_WETH FUNCTION /////////////////////////////////////////////////////////////////
    function testFuzz_DepositWeth_NotBoosted(uint256 amountToDeposit) public {
        vm.assume(amountToDeposit > 1e6 && amountToDeposit <= 1_000_000_000e18);

        uint256 wsthDepositedAmount = WstETHRate(StETHRate(amountToDeposit));
        uint256 poolId = sophonFarming.typeToId(SophonFarmingState.PredefinedPool.wstETH);

        vm.startPrank(account1);
        vm.deal(account1, amountToDeposit);
        weth.deposit{value: amountToDeposit}();
        assertEq(weth.balanceOf(account1), amountToDeposit);

        weth.approve(address(sophonFarming), amountToDeposit);
        sophonFarming.depositWeth(amountToDeposit, 0, SophonFarmingState.PredefinedPool.wstETH);
        assertEq(weth.balanceOf(account1), 0);

        SophonFarmingState.UserInfo memory userInfo;
        (userInfo.amount, userInfo.boostAmount, userInfo.depositAmount, userInfo.rewardSettled, userInfo.rewardDebt) =
            sophonFarming.userInfo(poolId, account1);

        assertEq(userInfo.amount, wsthDepositedAmount);
        assertEq(userInfo.boostAmount, 0);
        assertEq(userInfo.depositAmount, wsthDepositedAmount);
        assertEq(userInfo.rewardSettled, 0);
        assertEq(userInfo.rewardDebt, 0);
    }

    function testFuzz_DepositWeth_Boosted(uint256 amountToDeposit, uint256 boostFraction) public {
        vm.assume(amountToDeposit > 1e6 && amountToDeposit <= 1_000_000_000e18);
        vm.assume(boostFraction > 0 && boostFraction <= 10);

        uint256 wsthDepositedAmount = WstETHRate(StETHRate(amountToDeposit));
        uint256 amountToBoost = amountToDeposit / boostFraction;
        uint256 boostAmount = amountToBoost * wsthDepositedAmount / amountToDeposit;
        uint256 finalBoostAmount = boostAmount * sophonFarming.boosterMultiplier() / 1e18;
        uint256 poolId = sophonFarming.typeToId(SophonFarmingState.PredefinedPool.wstETH);

        vm.startPrank(account1);
        vm.deal(account1, amountToDeposit);
        weth.deposit{value: amountToDeposit}();
        assertEq(weth.balanceOf(account1), amountToDeposit);

        weth.approve(address(sophonFarming), amountToDeposit);
        sophonFarming.depositWeth(amountToDeposit, amountToBoost, SophonFarmingState.PredefinedPool.wstETH);
        assertEq(weth.balanceOf(account1), 0);

        SophonFarmingState.UserInfo memory userInfo;
        (userInfo.amount, userInfo.boostAmount, userInfo.depositAmount, userInfo.rewardSettled, userInfo.rewardDebt) =
            sophonFarming.userInfo(poolId, account1);

        assertEq(userInfo.amount, wsthDepositedAmount - boostAmount + finalBoostAmount);
        assertEq(userInfo.boostAmount, finalBoostAmount);
        assertEq(userInfo.depositAmount, wsthDepositedAmount - boostAmount);
        assertEq(userInfo.rewardSettled, 0);
        assertEq(userInfo.rewardDebt, 0);
    }

    function testFuzz_DepositWeth_RevertWhen_FarmingIsEnded(uint256 amountToDeposit, uint256 boostFraction) public {
        vm.assume(amountToDeposit > 1e6 && amountToDeposit <= 1_000_000_000e18);
        vm.assume(boostFraction > 0 && boostFraction <= 10);

        vm.prank(deployer);
        sophonFarming.setEndBlocks(block.number + 9, 1);
        vm.roll(block.number + 10);

        vm.startPrank(account1);
        vm.deal(account1, amountToDeposit);
        weth.deposit{value: amountToDeposit}();
        assertEq(weth.balanceOf(account1), amountToDeposit);

        uint256 amountToBoost = amountToDeposit / boostFraction;

        weth.approve(address(sophonFarming), amountToDeposit);
        vm.expectRevert(SophonFarming.FarmingIsEnded.selector);
        sophonFarming.depositWeth(amountToDeposit, amountToBoost, SophonFarmingState.PredefinedPool.wstETH);
    }

    function testFuzz_DepositWeth_RevertWhen_InvalidDeposit(uint256 amountToDeposit, uint256 boostFraction) public {
        vm.assume(amountToDeposit > 0 && amountToDeposit < 1001);
        vm.assume(boostFraction > 0 && boostFraction <= 10);

        vm.startPrank(account1);
        vm.deal(account1, amountToDeposit);
        weth.deposit{value: amountToDeposit}();
        assertEq(weth.balanceOf(account1), amountToDeposit);

        weth.approve(address(sophonFarming), amountToDeposit);
        vm.expectRevert(SophonFarming.InvalidDeposit.selector);
        sophonFarming.depositWeth(amountToDeposit, 0, SophonFarmingState.PredefinedPool.wstETH);
    }

    function testFuzz_DepositWeth_RevertWhen_BoostTooHigh(uint256 amountToDeposit) public {
        vm.assume(amountToDeposit > 1e6 && amountToDeposit <= 1_000_000_000e18);

        vm.startPrank(account1);
        vm.deal(account1, amountToDeposit);
        weth.deposit{value: amountToDeposit}();
        assertEq(weth.balanceOf(account1), amountToDeposit);

        uint256 wsthDepositedAmount = WstETHRate(StETHRate(amountToDeposit));
        uint256 amountToBoost = amountToDeposit * 2;

        weth.approve(address(sophonFarming), amountToDeposit);
        vm.expectRevert(abi.encodeWithSelector(SophonFarming.BoostTooHigh.selector, wsthDepositedAmount));
        sophonFarming.depositWeth(amountToDeposit, amountToBoost, SophonFarmingState.PredefinedPool.wstETH);
    }

    function testFuzz_DepositWethToWeETH_NotBoosted(uint256 amountToDeposit) public {
        vm.assume(amountToDeposit > 1e6 && amountToDeposit <= 1_000_000_000e18);

        uint256 weEthDepositedAmount = WeETHRate(eETHLPRate(amountToDeposit));
        uint256 poolId = sophonFarming.typeToId(SophonFarmingState.PredefinedPool.weETH);

        vm.startPrank(account1);
        vm.deal(account1, amountToDeposit);
        weth.deposit{value: amountToDeposit}();
        assertEq(weth.balanceOf(account1), amountToDeposit);

        weth.approve(address(sophonFarming), amountToDeposit);
        sophonFarming.depositWeth(amountToDeposit, 0, SophonFarmingState.PredefinedPool.weETH);
        assertEq(weth.balanceOf(account1), 0);

        SophonFarmingState.UserInfo memory userInfo;
        (userInfo.amount, userInfo.boostAmount, userInfo.depositAmount, userInfo.rewardSettled, userInfo.rewardDebt) =
            sophonFarming.userInfo(poolId, account1);

        assertEq(userInfo.amount, weEthDepositedAmount);
        assertEq(userInfo.boostAmount, 0);
        assertEq(userInfo.depositAmount, weEthDepositedAmount);
        assertEq(userInfo.rewardSettled, 0);
        assertEq(userInfo.rewardDebt, 0);
    }

    // DEPOSIT_EETH FUNCTION /////////////////////////////////////////////////////////////////
    function testFuzz_DepositEEth_NotBoosted(uint256 amountToDeposit) public {
        vm.assume(amountToDeposit > 1e6 && amountToDeposit <= 1_000_000_000e18);

        uint256 weEthDepositedAmount = WeETHRate(amountToDeposit);
        uint256 poolId = sophonFarming.typeToId(SophonFarmingState.PredefinedPool.weETH);

        vm.startPrank(account1);
        deal(address(eETH), account1, amountToDeposit);
        assertEq(eETH.balanceOf(account1), amountToDeposit);

        eETH.approve(address(sophonFarming), amountToDeposit);
        sophonFarming.depositeEth(amountToDeposit, 0);
        assertEq(eETH.balanceOf(account1), 0);

        SophonFarmingState.UserInfo memory userInfo;
        (userInfo.amount, userInfo.boostAmount, userInfo.depositAmount, userInfo.rewardSettled, userInfo.rewardDebt) =
            sophonFarming.userInfo(poolId, account1);

        assertEq(userInfo.amount, weEthDepositedAmount);
        assertEq(userInfo.boostAmount, 0);
        assertEq(userInfo.depositAmount, weEthDepositedAmount);
        assertEq(userInfo.rewardSettled, 0);
        assertEq(userInfo.rewardDebt, 0);
    }

    function testFuzz_DepositEEth_Boosted(uint256 amountToDeposit, uint256 boostFraction) public {
        vm.assume(amountToDeposit > 1e6 && amountToDeposit <= 1_000_000_000e18);
        vm.assume(boostFraction > 0 && boostFraction <= 10);

        uint256 weEthDepositedAmount = WeETHRate(amountToDeposit);
        uint256 amountToBoost = amountToDeposit / boostFraction;
        uint256 boostAmount = amountToBoost * weEthDepositedAmount / amountToDeposit;
        uint256 finalBoostAmount = boostAmount * sophonFarming.boosterMultiplier() / 1e18;
        uint256 poolId = sophonFarming.typeToId(SophonFarmingState.PredefinedPool.weETH);

        vm.startPrank(account1);
        deal(address(eETH), account1, amountToDeposit);
        assertEq(eETH.balanceOf(account1), amountToDeposit);

        eETH.approve(address(sophonFarming), amountToDeposit);
        sophonFarming.depositeEth(amountToDeposit, amountToBoost);
        assertEq(eETH.balanceOf(account1), 0);

        SophonFarmingState.UserInfo memory userInfo;
        (userInfo.amount, userInfo.boostAmount, userInfo.depositAmount, userInfo.rewardSettled, userInfo.rewardDebt) =
            sophonFarming.userInfo(poolId, account1);

        assertEq(userInfo.amount, weEthDepositedAmount - boostAmount + finalBoostAmount);
        assertEq(userInfo.boostAmount, finalBoostAmount);
        assertEq(userInfo.depositAmount, weEthDepositedAmount - boostAmount);
        assertEq(userInfo.rewardSettled, 0);
        assertEq(userInfo.rewardDebt, 0);
    }

    function testFuzz_DepositEEth_RevertWhen_FarmingIsEnded(uint256 amountToDeposit, uint256 boostFraction) public {
        vm.assume(amountToDeposit > 1e6 && amountToDeposit <= 1_000_000_000e18);
        vm.assume(boostFraction > 0 && boostFraction <= 10);

        vm.prank(deployer);
        sophonFarming.setEndBlocks(block.number + 9, 1);
        vm.roll(block.number + 10);

        vm.startPrank(account1);
        deal(address(eETH), account1, amountToDeposit);
        assertEq(eETH.balanceOf(account1), amountToDeposit);

        eETH.approve(address(sophonFarming), amountToDeposit);
        vm.expectRevert(SophonFarming.FarmingIsEnded.selector);
        sophonFarming.depositeEth(amountToDeposit, 0);
    }

    function testFuzz_DepositEEth_RevertWhen_InvalidDeposit() public {
        uint256 amountToDeposit = 1;

        vm.startPrank(account1);
        deal(address(eETH), account1, amountToDeposit);
        assertEq(eETH.balanceOf(account1), amountToDeposit);

        eETH.approve(address(sophonFarming), amountToDeposit);
        vm.expectRevert(SophonFarming.InvalidDeposit.selector);
        sophonFarming.depositeEth(amountToDeposit, 0);
    }

    function testFuzz_DepositEEth_RevertWhen_BoostTooHigh(uint256 amountToDeposit) public {
        vm.assume(amountToDeposit > 1e6 && amountToDeposit <= 1_000_000_000e18);

        vm.startPrank(account1);
        deal(address(eETH), account1, amountToDeposit);
        assertEq(eETH.balanceOf(account1), amountToDeposit);

        uint256 weEthDepositedAmount = WeETHRate(amountToDeposit);
        uint256 amountToBoost = amountToDeposit * 2;

        eETH.approve(address(sophonFarming), amountToDeposit);
        vm.expectRevert(abi.encodeWithSelector(SophonFarming.BoostTooHigh.selector, weEthDepositedAmount));
        sophonFarming.depositeEth(amountToDeposit, amountToBoost);
    }

    // DEPOSIT_STETH FUNCTION /////////////////////////////////////////////////////////////////
    function testFuzz_DepositStEth_NotBoosted(uint256 amountToDeposit) public {
        vm.assume(amountToDeposit > 1e6 && amountToDeposit <= 1_000_000_000e18);

        uint256 wsthDepositedAmount = WstETHRate(amountToDeposit);
        uint256 poolId = sophonFarming.typeToId(SophonFarmingState.PredefinedPool.wstETH);

        vm.startPrank(account1);
        deal(address(stETH), account1, amountToDeposit);
        assertEq(stETH.balanceOf(account1), amountToDeposit);

        stETH.approve(address(sophonFarming), amountToDeposit);
        sophonFarming.depositStEth(amountToDeposit, 0);
        assertEq(stETH.balanceOf(account1), 0);

        SophonFarmingState.UserInfo memory userInfo;
        (userInfo.amount, userInfo.boostAmount, userInfo.depositAmount, userInfo.rewardSettled, userInfo.rewardDebt) =
            sophonFarming.userInfo(poolId, account1);

        assertEq(userInfo.amount, wsthDepositedAmount);
        assertEq(userInfo.boostAmount, 0);
        assertEq(userInfo.depositAmount, wsthDepositedAmount);
        assertEq(userInfo.rewardSettled, 0);
        assertEq(userInfo.rewardDebt, 0);
    }

    function testFuzz_DepositStEth_Boosted(uint256 amountToDeposit, uint256 boostFraction) public {
        vm.assume(amountToDeposit > 1e6 && amountToDeposit <= 1_000_000_000e18);
        vm.assume(boostFraction > 0 && boostFraction <= 10);

        uint256 wsthDepositedAmount = WstETHRate(amountToDeposit);
        uint256 amountToBoost = amountToDeposit / boostFraction;
        uint256 boostAmount = amountToBoost * wsthDepositedAmount / amountToDeposit;
        uint256 finalBoostAmount = boostAmount * sophonFarming.boosterMultiplier() / 1e18;
        uint256 poolId = sophonFarming.typeToId(SophonFarmingState.PredefinedPool.wstETH);

        vm.startPrank(account1);
        deal(address(stETH), account1, amountToDeposit);
        assertEq(stETH.balanceOf(account1), amountToDeposit);

        stETH.approve(address(sophonFarming), amountToDeposit);
        sophonFarming.depositStEth(amountToDeposit, amountToBoost);
        assertEq(stETH.balanceOf(account1), 0);

        SophonFarmingState.UserInfo memory userInfo;
        (userInfo.amount, userInfo.boostAmount, userInfo.depositAmount, userInfo.rewardSettled, userInfo.rewardDebt) =
            sophonFarming.userInfo(poolId, account1);

        assertEq(userInfo.amount, wsthDepositedAmount - boostAmount + finalBoostAmount);
        assertEq(userInfo.boostAmount, finalBoostAmount);
        assertEq(userInfo.depositAmount, wsthDepositedAmount - boostAmount);
        assertEq(userInfo.rewardSettled, 0);
        assertEq(userInfo.rewardDebt, 0);
    }

    function testFuzz_DepositStEth_RevertWhen_FarmingIsEnded(uint256 amountToDeposit, uint256 boostFraction) public {
        vm.assume(amountToDeposit > 1e6 && amountToDeposit <= 1_000_000_000e18);
        vm.assume(boostFraction > 0 && boostFraction <= 10);

        vm.prank(deployer);
        sophonFarming.setEndBlocks(block.number + 9, 1);
        vm.roll(block.number + 10);

        vm.startPrank(account1);
        deal(address(stETH), account1, amountToDeposit);
        assertEq(stETH.balanceOf(account1), amountToDeposit);

        stETH.approve(address(sophonFarming), amountToDeposit);
        vm.expectRevert(SophonFarming.FarmingIsEnded.selector);
        sophonFarming.depositStEth(amountToDeposit, 0);
    }

    function testFuzz_DepositStEth_RevertWhen_InvalidDeposit() public {
        uint256 amountToDeposit = 1;

        vm.startPrank(account1);
        deal(address(stETH), account1, amountToDeposit);
        assertEq(stETH.balanceOf(account1), amountToDeposit);

        stETH.approve(address(sophonFarming), amountToDeposit);
        vm.expectRevert(SophonFarming.InvalidDeposit.selector);
        sophonFarming.depositStEth(amountToDeposit, 0);
    }

    function testFuzz_DepositStEth_RevertWhen_BoostTooHigh(uint256 amountToDeposit) public {
        vm.assume(amountToDeposit > 1e6 && amountToDeposit <= 1_000_000_000e18);

        vm.startPrank(account1);
        deal(address(stETH), account1, amountToDeposit);
        assertEq(stETH.balanceOf(account1), amountToDeposit);

        uint256 wsthDepositedAmount = WstETHRate(amountToDeposit);
        uint256 amountToBoost = amountToDeposit * 2;

        stETH.approve(address(sophonFarming), amountToDeposit);
        vm.expectRevert(abi.encodeWithSelector(SophonFarming.BoostTooHigh.selector, wsthDepositedAmount));
        sophonFarming.depositStEth(amountToDeposit, amountToBoost);
    }

    // DEPOSIT FUNCTION /////////////////////////////////////////////////////////////////
    function testFuzz_DepositWstEth_NotBoosted(uint256 amountToDeposit) public {
        vm.assume(amountToDeposit > 1e6 && amountToDeposit <= 1_000_000_000e18);

        uint256 wsthDepositedAmount = amountToDeposit;
        uint256 poolId = sophonFarming.typeToId(SophonFarmingState.PredefinedPool.wstETH);

        vm.startPrank(account1);
        deal(address(wstETH), account1, amountToDeposit);
        assertEq(wstETH.balanceOf(account1), amountToDeposit);

        wstETH.approve(address(sophonFarming), amountToDeposit);
        sophonFarming.deposit(poolId, amountToDeposit, 0);
        assertEq(wstETH.balanceOf(account1), 0);

        SophonFarmingState.UserInfo memory userInfo;
        (userInfo.amount, userInfo.boostAmount, userInfo.depositAmount, userInfo.rewardSettled, userInfo.rewardDebt) =
            sophonFarming.userInfo(poolId, account1);

        assertEq(userInfo.amount, wsthDepositedAmount);
        assertEq(userInfo.boostAmount, 0);
        assertEq(userInfo.depositAmount, wsthDepositedAmount);
        assertEq(userInfo.rewardSettled, 0);
        assertEq(userInfo.rewardDebt, 0);
    }

    function testFuzz_DepositWstEth_Boosted(uint256 amountToDeposit, uint256 boostFraction) public {
        vm.assume(amountToDeposit > 1e6 && amountToDeposit <= 1_000_000_000e18);
        vm.assume(boostFraction > 0 && boostFraction <= 10);

        uint256 wsthDepositedAmount = amountToDeposit;
        uint256 amountToBoost = amountToDeposit / boostFraction;
        uint256 boostAmount = amountToBoost * wsthDepositedAmount / amountToDeposit;
        uint256 finalBoostAmount = boostAmount * sophonFarming.boosterMultiplier() / 1e18;
        uint256 poolId = sophonFarming.typeToId(SophonFarmingState.PredefinedPool.wstETH);

        vm.startPrank(account1);
        deal(address(wstETH), account1, amountToDeposit);
        assertEq(wstETH.balanceOf(account1), amountToDeposit);

        wstETH.approve(address(sophonFarming), amountToDeposit);
        sophonFarming.deposit(poolId, amountToDeposit, amountToBoost);
        assertEq(wstETH.balanceOf(account1), 0);

        SophonFarmingState.UserInfo memory userInfo;
        (userInfo.amount, userInfo.boostAmount, userInfo.depositAmount, userInfo.rewardSettled, userInfo.rewardDebt) =
            sophonFarming.userInfo(poolId, account1);

        assertEq(userInfo.amount, wsthDepositedAmount - boostAmount + finalBoostAmount);
        assertEq(userInfo.boostAmount, finalBoostAmount);
        assertEq(userInfo.depositAmount, wsthDepositedAmount - boostAmount);
        assertEq(userInfo.rewardSettled, 0);
        assertEq(userInfo.rewardDebt, 0);
    }

    function testFuzz_DepositWstEth_RevertWhen_FarmingIsEnded(uint256 amountToDeposit, uint256 boostFraction) public {
        vm.assume(amountToDeposit > 1e6 && amountToDeposit <= 1_000_000_000e18);
        vm.assume(boostFraction > 0 && boostFraction <= 10);

        vm.prank(deployer);
        sophonFarming.setEndBlocks(block.number + 9, 1);
        vm.roll(block.number + 10);

        vm.startPrank(account1);
        deal(address(wstETH), account1, amountToDeposit);
        assertEq(wstETH.balanceOf(account1), amountToDeposit);

        uint256 amountToBoost = amountToDeposit / boostFraction;
        uint256 poolId = sophonFarming.typeToId(SophonFarmingState.PredefinedPool.wstETH);

        wstETH.approve(address(sophonFarming), amountToDeposit);
        vm.expectRevert(SophonFarming.FarmingIsEnded.selector);
        sophonFarming.deposit(poolId, amountToDeposit, amountToBoost);
    }

    function testFuzz_DepositWstEth_RevertWhen_InvalidDeposit() public {
        uint256 amountToDeposit = 0;

        vm.startPrank(account1);
        deal(address(wstETH), account1, amountToDeposit);
        assertEq(wstETH.balanceOf(account1), amountToDeposit);

        uint256 poolId = sophonFarming.typeToId(SophonFarmingState.PredefinedPool.wstETH);

        wstETH.approve(address(sophonFarming), amountToDeposit);
        vm.expectRevert(SophonFarming.InvalidDeposit.selector);
        sophonFarming.deposit(poolId, amountToDeposit, 0);
    }

    function testFuzz_DepositWstEth_RevertWhen_BoostTooHigh(uint256 amountToDeposit) public {
        vm.assume(amountToDeposit > 1e6 && amountToDeposit <= 1_000_000_000e18);

        vm.startPrank(account1);
        deal(address(wstETH), account1, amountToDeposit);
        assertEq(wstETH.balanceOf(account1), amountToDeposit);

        uint256 wsthDepositedAmount = amountToDeposit;
        uint256 amountToBoost = amountToDeposit * 2;
        uint256 poolId = sophonFarming.typeToId(SophonFarmingState.PredefinedPool.wstETH);

        wstETH.approve(address(sophonFarming), amountToDeposit);
        vm.expectRevert(abi.encodeWithSelector(SophonFarming.BoostTooHigh.selector, wsthDepositedAmount));
        sophonFarming.deposit(poolId, amountToDeposit, amountToBoost);
    }

    // DEPOSIT_DAI FUNCTION /////////////////////////////////////////////////////////////////
    function testFuzz_DepositDai_NotBoostedDeposit(uint256 amountToDeposit) public {
        vm.assume(amountToDeposit > 1e6 && amountToDeposit <= 1_000_000_000e18);

        deal(address(dai), account1, amountToDeposit);
        assertEq(dai.balanceOf(account1), amountToDeposit);

        uint256 poolId = sophonFarming.typeToId(SophonFarmingState.PredefinedPool.sDAI);

        vm.startPrank(account1);
        dai.approve(address(sophonFarming), amountToDeposit);
        sophonFarming.depositDai(amountToDeposit, 0);
        assertEq(dai.balanceOf(account1), 0);

        SophonFarmingState.UserInfo memory userInfo;
        (userInfo.amount, userInfo.boostAmount, userInfo.depositAmount, userInfo.rewardSettled, userInfo.rewardDebt) =
            sophonFarming.userInfo(poolId, account1);

        assertEq(userInfo.amount, sDAI.convertToShares(amountToDeposit));
        assertEq(userInfo.boostAmount, 0);
        assertEq(userInfo.depositAmount, sDAI.convertToShares(amountToDeposit));
        assertEq(userInfo.rewardSettled, 0);
        assertEq(userInfo.rewardDebt, 0);
    }

    function testFuzz_DepositDai_BoostedDeposit(uint256 amountToDeposit, uint256 boostFraction) public {
        vm.assume(amountToDeposit > 1e6 && amountToDeposit <= 1_000_000_000e18);
        vm.assume(boostFraction > 0 && boostFraction < 5);

        deal(address(dai), account1, amountToDeposit);
        assertEq(dai.balanceOf(account1), amountToDeposit);

        uint256 amountToDepositBoost = amountToDeposit / boostFraction;
        uint256 finalAmountToDepositBoost =
            amountToDepositBoost * sDAI.convertToShares(amountToDeposit) / amountToDeposit;
        uint256 poolId = sophonFarming.typeToId(SophonFarmingState.PredefinedPool.sDAI);

        vm.startPrank(account1);
        dai.approve(address(sophonFarming), amountToDeposit);
        sophonFarming.depositDai(amountToDeposit, amountToDepositBoost);
        assertEq(dai.balanceOf(account1), 0);

        SophonFarmingState.UserInfo memory userInfo;
        (userInfo.amount, userInfo.boostAmount, userInfo.depositAmount, userInfo.rewardSettled, userInfo.rewardDebt) =
            sophonFarming.userInfo(poolId, account1);

        // Can have 1 wei of difference cause of rounding
        assertApproxEqAbs(
            userInfo.amount,
            sDAI.convertToShares(amountToDeposit) - sDAI.convertToShares(amountToDepositBoost)
                + finalAmountToDepositBoost * sophonFarming.boosterMultiplier() / 1e18,
            1
        );
        assertEq(userInfo.boostAmount, finalAmountToDepositBoost * sophonFarming.boosterMultiplier() / 1e18);
        assertEq(
            userInfo.depositAmount, sDAI.convertToShares(amountToDeposit) - finalAmountToDepositBoost
        );
        assertEq(userInfo.rewardSettled, 0);
        assertEq(userInfo.rewardDebt, 0);
    }

    // WITHDRAW FUNCTION /////////////////////////////////////////////////////////////////
    function testFuzz_DepositDai_NotBoostedWithdraw(uint256 amountToDeposit, uint256 fractionToWithdraw) public {
        vm.assume(amountToDeposit > 1e6 && amountToDeposit <= 1_000_000_000e18);
        vm.assume(fractionToWithdraw > 0 && fractionToWithdraw <= 10);

        deal(address(dai), account1, amountToDeposit);
        assertEq(dai.balanceOf(account1), amountToDeposit);

        uint256 poolId = sophonFarming.typeToId(SophonFarmingState.PredefinedPool.sDAI);
        uint256 depositAmount = sDAI.convertToShares(amountToDeposit);
        uint256 withdrawAmount = depositAmount / fractionToWithdraw;
        uint256 blocks = 10;

        vm.startPrank(account1);
        dai.approve(address(sophonFarming), amountToDeposit);
        sophonFarming.depositDai(amountToDeposit, 0);
        assertEq(dai.balanceOf(account1), 0);
        vm.stopPrank();

        vm.prank(deployer);
        sophonFarming.setEndBlocks(block.number + blocks, 1);
        vm.roll(block.number + blocks + 1);

        address[] memory accounts = new address[](1);
        accounts[0] = account1;

        SophonFarmingState.UserInfo[][] memory userInfo =
            new SophonFarmingState.UserInfo[][](1);
        userInfo = sophonFarming.getUserInfo(accounts);

        vm.startPrank(account1);
        sophonFarming.withdraw(poolId, withdrawAmount);

        SophonFarmingState.UserInfo[][] memory finalUserInfo =
            new SophonFarmingState.UserInfo[][](1);
        finalUserInfo = sophonFarming.getUserInfo(accounts);

        SophonFarmingState.PoolInfo[] memory PoolInfo;
        PoolInfo = sophonFarming.getPoolInfo();

        uint256 rewardSettled = depositAmount * PoolInfo[poolId].accPointsPerShare / 1e18 * (depositAmount - withdrawAmount) / depositAmount;
        uint256 rewardDebt = depositAmount * (depositAmount - withdrawAmount) / depositAmount * PoolInfo[poolId].accPointsPerShare / 1e18;

        assertEq(finalUserInfo[0][poolId].amount, depositAmount - withdrawAmount);
        assertEq(finalUserInfo[0][poolId].boostAmount, 0);
        assertEq(finalUserInfo[0][poolId].depositAmount, depositAmount - withdrawAmount);
        assertEq(finalUserInfo[0][poolId].rewardSettled, rewardSettled);
        assertEq(finalUserInfo[0][poolId].rewardDebt, rewardDebt);

        assertEq(sDAI.balanceOf(account1), withdrawAmount);
    }

    function testFuzz_DepositDai_RevertWhen_NotBoostedWithdraw_InvalidWithdraw(uint256 amountToDeposit) public {
        vm.assume(amountToDeposit > 1e6 && amountToDeposit <= 1_000_000_000e18);

        deal(address(dai), account1, amountToDeposit);
        assertEq(dai.balanceOf(account1), amountToDeposit);

        uint256 poolId = sophonFarming.typeToId(SophonFarmingState.PredefinedPool.sDAI);

        vm.startPrank(account1);
        dai.approve(address(sophonFarming), amountToDeposit);
        sophonFarming.depositDai(amountToDeposit, 0);
        assertEq(dai.balanceOf(account1), 0);
        vm.stopPrank();

        vm.prank(deployer);
        sophonFarming.setEndBlocks(block.number + 10, 10);
        vm.roll(block.number + 20);

        vm.startPrank(account1);
        vm.expectRevert(SophonFarming.InvalidWithdraw.selector);
        sophonFarming.withdraw(poolId, 0);

        vm.roll(block.number + 22);
        vm.expectRevert(SophonFarming.InvalidWithdraw.selector);
        sophonFarming.withdraw(poolId, 1);
    }

    function testFuzz_DepositDai_BoostedWithdraw(uint256 amountToDeposit, uint256 boostFraction, uint256 fractionToWithdraw) public {
        amountToDeposit = bound(amountToDeposit, 1e6, 1_000_000_000e18);
        // Do not 100% of the deposit cause we need to withdraw, and boosted cannot be withdrawn.
        boostFraction = bound(boostFraction, 2, 10);
        fractionToWithdraw = bound(fractionToWithdraw, 2, 10);

        deal(address(dai), account1, amountToDeposit);
        assertEq(dai.balanceOf(account1), amountToDeposit);

        uint256 poolId = sophonFarming.typeToId(SophonFarmingState.PredefinedPool.sDAI);
        uint256 amountToDepositBoost = amountToDeposit / boostFraction;
        uint256 depositAmount = sDAI.convertToShares(amountToDeposit - amountToDepositBoost);
        uint256 withdrawAmount = depositAmount / fractionToWithdraw;
        uint256 finalAmountToDepositBoost =
            amountToDepositBoost * sDAI.convertToShares(amountToDeposit) / amountToDeposit;
        uint256 blocks = 10;

        vm.startPrank(account1);
        dai.approve(address(sophonFarming), amountToDeposit);
        sophonFarming.depositDai(amountToDeposit, amountToDepositBoost);
        assertEq(dai.balanceOf(account1), 0);

        vm.stopPrank();

        vm.prank(deployer);
        sophonFarming.setEndBlocks(block.number + blocks, 1);
        vm.roll(block.number + blocks + 1);

        address[] memory accounts = new address[](1);
        accounts[0] = account1;

        SophonFarmingState.UserInfo[][] memory userInfo =
            new SophonFarmingState.UserInfo[][](1);
        userInfo = sophonFarming.getUserInfo(accounts);

        vm.startPrank(account1);
        sophonFarming.withdraw(poolId, withdrawAmount);

        SophonFarmingState.UserInfo[][] memory finalUserInfo =
            new SophonFarmingState.UserInfo[][](1);
        finalUserInfo = sophonFarming.getUserInfo(accounts);

        SophonFarmingState.PoolInfo[] memory PoolInfo;
        PoolInfo = sophonFarming.getPoolInfo();

        uint256 rewardSettled = (userInfo[0][poolId].amount * PoolInfo[poolId].accPointsPerShare / 1e18) * (userInfo[0][poolId].depositAmount - withdrawAmount) / userInfo[0][poolId].depositAmount;
        uint256 rewardDebt = (userInfo[0][poolId].amount - withdrawAmount) * PoolInfo[poolId].accPointsPerShare / 1e18;

        assertApproxEqAbs(finalUserInfo[0][poolId].amount, depositAmount - withdrawAmount + finalAmountToDepositBoost * sophonFarming.boosterMultiplier() / 1e18, 1);
        assertEq(finalUserInfo[0][poolId].boostAmount, finalAmountToDepositBoost * sophonFarming.boosterMultiplier() / 1e18);
        assertApproxEqAbs(finalUserInfo[0][poolId].depositAmount, depositAmount - withdrawAmount, 1);
        assertEq(finalUserInfo[0][poolId].rewardSettled, rewardSettled);
        assertEq(finalUserInfo[0][poolId].rewardDebt, rewardDebt);

        assertEq(sDAI.balanceOf(account1), withdrawAmount);
    }

    function testFuzz_DepositDai_MaxWithdraw(uint256 amountToDeposit) public {
        vm.assume(amountToDeposit > 1e6 && amountToDeposit <= 1_000_000_000e18);

        deal(address(dai), account1, amountToDeposit);
        assertEq(dai.balanceOf(account1), amountToDeposit);

        uint256 poolId = sophonFarming.typeToId(SophonFarmingState.PredefinedPool.sDAI);
        uint256 depositAmount = sDAI.convertToShares(amountToDeposit);
        uint256 withdrawAmount = type(uint256).max;
        uint256 blocks = 10;

        vm.startPrank(account1);
        dai.approve(address(sophonFarming), amountToDeposit);
        sophonFarming.depositDai(amountToDeposit, 0);
        assertEq(dai.balanceOf(account1), 0);
        vm.stopPrank();

        vm.prank(deployer);
        sophonFarming.setEndBlocks(block.number + blocks, 1);
        vm.roll(block.number + blocks + 1);

        address[] memory accounts = new address[](1);
        accounts[0] = account1;

        SophonFarmingState.UserInfo[][] memory userInfo =
            new SophonFarmingState.UserInfo[][](1);
        userInfo = sophonFarming.getUserInfo(accounts);

        vm.startPrank(account1);
        sophonFarming.withdraw(poolId, withdrawAmount);

        SophonFarmingState.UserInfo[][] memory finalUserInfo =
            new SophonFarmingState.UserInfo[][](1);
        finalUserInfo = sophonFarming.getUserInfo(accounts);

        SophonFarmingState.PoolInfo[] memory PoolInfo;
        PoolInfo = sophonFarming.getPoolInfo();

        assertEq(finalUserInfo[0][poolId].amount, 0);
        assertEq(finalUserInfo[0][poolId].boostAmount, 0);
        assertEq(finalUserInfo[0][poolId].depositAmount, 0);
        assertEq(finalUserInfo[0][poolId].rewardSettled, 0);
        assertEq(finalUserInfo[0][poolId].rewardDebt, 0);

        assertEq(sDAI.balanceOf(account1), depositAmount);
    }

    function testFuzz_DepositDai_RevertWhen_WithdrawTooHigh(uint256 amountToDeposit) public {
        vm.assume(amountToDeposit > 1e6 && amountToDeposit <= 1_000_000_000e18);

        deal(address(dai), account1, amountToDeposit);
        assertEq(dai.balanceOf(account1), amountToDeposit);

        uint256 poolId = sophonFarming.typeToId(SophonFarmingState.PredefinedPool.sDAI);
        uint256 depositAmount = sDAI.convertToShares(amountToDeposit);
        uint256 withdrawAmount = type(uint256).max - 1;
        uint256 blocks = 10;

        vm.startPrank(account1);
        dai.approve(address(sophonFarming), amountToDeposit);
        sophonFarming.depositDai(amountToDeposit, 0);
        assertEq(dai.balanceOf(account1), 0);
        vm.stopPrank();

        vm.prank(deployer);
        sophonFarming.setEndBlocks(block.number + blocks, 1);
        vm.roll(block.number + blocks + 1);

        address[] memory accounts = new address[](1);
        accounts[0] = account1;

        SophonFarmingState.UserInfo[][] memory userInfo =
            new SophonFarmingState.UserInfo[][](1);
        userInfo = sophonFarming.getUserInfo(accounts);

        vm.startPrank(account1);
        vm.expectRevert(abi.encodeWithSelector(SophonFarming.WithdrawTooHigh.selector, depositAmount));
        sophonFarming.withdraw(poolId, withdrawAmount);
    }

    // IS_WITHDRAW_PERIOD_ENDED FUNCTION /////////////////////////////////////////////////////////////////
    function test_IsWithdrawPeriodEnded() public {
        vm.startPrank(deployer);

        sophonFarming.setEndBlocks(block.number + 10, 1);
        vm.roll(block.number + 12);

        assertEq(sophonFarming.isWithdrawPeriodEnded(), true);
    }

    // BRIDGE_POOL FUNCTION /////////////////////////////////////////////////////////////////
    function test_SetBridge() public {
        vm.startPrank(deployer);

        uint256 poolId = sophonFarming.typeToId(SophonFarmingState.PredefinedPool.wstETH);

        MockBridge bridge = new MockBridge();
        sophonFarming.setBridge(bridge);

        sophonFarming.setBridgeForPool(poolId, address(0xb));

        vm.stopPrank();
        vm.startPrank(account1);

        uint256 amountToDeposit = 1e18;
        vm.deal(account1, amountToDeposit);
        weth.deposit{value: amountToDeposit}();
        assertEq(weth.balanceOf(account1), amountToDeposit);

        weth.approve(address(sophonFarming), amountToDeposit);
        sophonFarming.depositWeth(amountToDeposit, 0, SophonFarmingState.PredefinedPool.wstETH);
        assertEq(weth.balanceOf(account1), 0);

        vm.stopPrank();
        vm.startPrank(deployer);

        sophonFarming.setEndBlocks(block.number + 10, 1);
        vm.roll(block.number + 12);

        sophonFarming.bridgePool(poolId);
    }

    function test_BridgePool_RevertWhen_Unauthorized() public {
        vm.startPrank(account1);

        uint256 poolId = sophonFarming.typeToId(SophonFarmingState.PredefinedPool.wstETH);

        vm.expectRevert(Unauthorized.selector);
        sophonFarming.bridgePool(poolId);
    }

    function test_BridgePool_RevertWhen_BridgeInvalid() public {
        vm.startPrank(deployer);

        sophonFarming.setEndBlocks(block.number + 10, 1);
        vm.roll(block.number + 12);

        uint256 poolId = sophonFarming.typeToId(SophonFarmingState.PredefinedPool.wstETH);

        vm.expectRevert(SophonFarming.BridgeInvalid.selector);
        sophonFarming.bridgePool(poolId);
    }

    // REVERT_FAILED_BRIDGE FUNCTION /////////////////////////////////////////////////////////////////
    function test_RevertFailedBridge() public {
        vm.startPrank(deployer);

        uint256 poolId = sophonFarming.typeToId(SophonFarmingState.PredefinedPool.wstETH);

        MockBridge bridge = new MockBridge();
        sophonFarming.setBridge(bridge);

        sophonFarming.setBridgeForPool(poolId, address(0xb));

        vm.stopPrank();
        vm.startPrank(account1);

        uint256 amountToDeposit = 1e18;
        vm.deal(account1, amountToDeposit);
        weth.deposit{value: amountToDeposit}();
        assertEq(weth.balanceOf(account1), amountToDeposit);

        weth.approve(address(sophonFarming), amountToDeposit);
        sophonFarming.depositWeth(amountToDeposit, 0, SophonFarmingState.PredefinedPool.wstETH);
        assertEq(weth.balanceOf(account1), 0);

        vm.stopPrank();
        vm.startPrank(deployer);

        sophonFarming.setEndBlocks(block.number + 10, 1);
        vm.roll(block.number + 12);

        sophonFarming.bridgePool(poolId);
        assertEq(sophonFarming.isBridged(poolId), true);

        sophonFarming.revertFailedBridge(poolId);
        assertEq(sophonFarming.isBridged(poolId), false);
    }

    // INCREASE_BOOST FUNCTION /////////////////////////////////////////////////////////////////
    function testFuzz_IncreaseBoost(uint256 amountToDeposit, uint256 boostFraction) public {
        vm.assume(amountToDeposit > 1e6 && amountToDeposit <= 1_000_000_000e18);
        vm.assume(boostFraction > 0 && boostFraction <= 10);
        boostFraction = 1;

        uint256 wsthDepositedAmount = amountToDeposit;
        uint256 poolId = sophonFarming.typeToId(SophonFarmingState.PredefinedPool.wstETH);

        vm.startPrank(account1);
        deal(address(wstETH), account1, amountToDeposit);
        assertEq(wstETH.balanceOf(account1), amountToDeposit);

        wstETH.approve(address(sophonFarming), amountToDeposit);
        sophonFarming.deposit(poolId, amountToDeposit, 0);
        assertEq(wstETH.balanceOf(account1), 0);

        SophonFarmingState.UserInfo memory userInfo;
        (userInfo.amount, userInfo.boostAmount, userInfo.depositAmount, userInfo.rewardSettled, userInfo.rewardDebt) =
            sophonFarming.userInfo(poolId, account1);

        sophonFarming.increaseBoost(poolId, amountToDeposit / boostFraction);

        (userInfo.amount, userInfo.boostAmount, userInfo.depositAmount, userInfo.rewardSettled, userInfo.rewardDebt) =
            sophonFarming.userInfo(poolId, account1);

        assertEq(
            userInfo.amount,
            wsthDepositedAmount - wsthDepositedAmount / boostFraction
                + wsthDepositedAmount / boostFraction * sophonFarming.boosterMultiplier() / 1e18
        );
        assertEq(userInfo.boostAmount, wsthDepositedAmount / boostFraction * sophonFarming.boosterMultiplier() / 1e18);
        assertEq(userInfo.depositAmount, wsthDepositedAmount - wsthDepositedAmount / boostFraction);
        assertEq(userInfo.rewardSettled, 0);
        assertEq(userInfo.rewardDebt, 0);
    }

    function test_IncreaseBoost_RevertWhen_FarmingIsEnded() public {
        vm.prank(deployer);
        sophonFarming.setEndBlocks(block.number + 9, 1);
        vm.roll(block.number + 10);

        vm.startPrank(account1);
        vm.expectRevert(SophonFarming.FarmingIsEnded.selector);
        sophonFarming.increaseBoost(0, 0);
    }

    function test_IncreaseBoost_RevertWhen_BoostIsZero() public {
        vm.startPrank(account1);
        vm.expectRevert(SophonFarming.BoostIsZero.selector);
        sophonFarming.increaseBoost(0, 0);
    }

    function testFuzz_IncreaseBoost_RevertWhen_BoostTooHigh(uint256 amountToDeposit) public {
        vm.assume(amountToDeposit > 1e6 && amountToDeposit <= 1_000_000_000e18);

        uint256 wsthDepositedAmount = amountToDeposit;
        uint256 poolId = sophonFarming.typeToId(SophonFarmingState.PredefinedPool.wstETH);

        vm.startPrank(account1);
        deal(address(wstETH), account1, amountToDeposit);
        assertEq(wstETH.balanceOf(account1), amountToDeposit);

        wstETH.approve(address(sophonFarming), amountToDeposit);
        sophonFarming.deposit(poolId, amountToDeposit, 0);
        assertEq(wstETH.balanceOf(account1), 0);

        SophonFarmingState.UserInfo memory userInfo;
        (userInfo.amount, userInfo.boostAmount, userInfo.depositAmount, userInfo.rewardSettled, userInfo.rewardDebt) =
            sophonFarming.userInfo(poolId, account1);

        assertEq(userInfo.amount, wsthDepositedAmount);
        assertEq(userInfo.boostAmount, 0);
        assertEq(userInfo.depositAmount, wsthDepositedAmount);
        assertEq(userInfo.rewardSettled, 0);
        assertEq(userInfo.rewardDebt, 0);

        vm.expectRevert(abi.encodeWithSelector(SophonFarming.BoostTooHigh.selector, wsthDepositedAmount));
        sophonFarming.increaseBoost(poolId, wsthDepositedAmount * 2);
    }

    // GET_MAX_ADDITIONAL_BOOST FUNCTION /////////////////////////////////////////////////////////////////
    function test_GetMaxAdditionalBoost(uint256 amountToDeposit) public {
        vm.assume(amountToDeposit > 1e6 && amountToDeposit <= 1_000_000_000e18);

        uint256 wsthDepositedAmount = amountToDeposit;
        uint256 poolId = sophonFarming.typeToId(SophonFarmingState.PredefinedPool.wstETH);

        vm.startPrank(account1);
        deal(address(wstETH), account1, amountToDeposit);
        assertEq(wstETH.balanceOf(account1), amountToDeposit);

        wstETH.approve(address(sophonFarming), amountToDeposit);
        sophonFarming.deposit(poolId, amountToDeposit, 0);
        assertEq(wstETH.balanceOf(account1), 0);

        assertEq(sophonFarming.getMaxAdditionalBoost(account1, poolId), wsthDepositedAmount);
    }

    // WITHDRAW_PROCEEDS FUNCTION /////////////////////////////////////////////////////////////////
    function testFuzz_WithdrawProceeds(uint256 amountToDeposit, uint256 boostFraction) public {
        vm.assume(amountToDeposit > 1e6 && amountToDeposit <= 1_000_000_000e18);
        vm.assume(boostFraction > 0 && boostFraction <= 10);

        amountToDeposit = 1e18;

        uint256 wsthDepositedAmount = amountToDeposit;
        uint256 amountToBoost = amountToDeposit / boostFraction;
        uint256 boostAmount = amountToBoost * wsthDepositedAmount / amountToDeposit;
        uint256 finalBoostAmount = boostAmount * sophonFarming.boosterMultiplier() / 1e18;
        uint256 poolId = sophonFarming.typeToId(SophonFarmingState.PredefinedPool.wstETH);
        uint256 startingDeployerBalance = wstETH.balanceOf(deployer);

        vm.startPrank(account1);
        deal(address(wstETH), account1, amountToDeposit);
        assertEq(wstETH.balanceOf(account1), amountToDeposit);

        wstETH.approve(address(sophonFarming), amountToDeposit);
        sophonFarming.deposit(poolId, amountToDeposit, amountToBoost);
        assertEq(wstETH.balanceOf(account1), 0);

        SophonFarmingState.UserInfo memory userInfo;
        (userInfo.amount, userInfo.boostAmount, userInfo.depositAmount, userInfo.rewardSettled, userInfo.rewardDebt) =
            sophonFarming.userInfo(poolId, account1);

        assertEq(userInfo.amount, wsthDepositedAmount - boostAmount + finalBoostAmount);
        assertEq(userInfo.boostAmount, finalBoostAmount);
        assertEq(userInfo.depositAmount, wsthDepositedAmount - boostAmount);
        assertEq(userInfo.rewardSettled, 0);
        assertEq(userInfo.rewardDebt, 0);

        vm.stopPrank();
        vm.startPrank(deployer);
        sophonFarming.withdrawProceeds(poolId);

        assertEq(wstETH.balanceOf(deployer), startingDeployerBalance + amountToBoost);
    }

    // GET_BLOCK_NUMBER FUNCTION /////////////////////////////////////////////////////////////////
    function test_GetBlockNumber() public {
        vm.roll(block.number + 100);
        assertEq(sophonFarming.getBlockNumber(), block.number);
    }

    // GET_POOL_INFO FUNCTION /////////////////////////////////////////////////////////////////
    function test_GetPoolInfo() public view {
        SophonFarmingState.PoolInfo[] memory PoolInfo;

        PoolInfo = sophonFarming.getPoolInfo();

        for (uint256 i = 0; i < PoolInfo.length; i++) {
            helperAssertPoolInfo(PoolInfo[i], i);
        }
    }

    function helperAssertPoolInfo(SophonFarmingState.PoolInfo memory PoolInfo, uint256 poolId) internal view {
        (
            IERC20 lpToken,
            address l2Farm,
            uint256 amount,
            uint256 boostAmount,
            uint256 depositAmount,
            uint256 allocPoint,
            uint256 lastRewardBlock,
            uint256 accPointsPerShare,
            string memory description
        ) = sophonFarming.poolInfo(poolId);

        assertEq(address(PoolInfo.lpToken), address(lpToken));
        assertEq(PoolInfo.l2Farm, l2Farm);
        assertEq(PoolInfo.amount, amount);
        assertEq(PoolInfo.boostAmount, boostAmount);
        assertEq(PoolInfo.depositAmount, depositAmount);
        assertEq(PoolInfo.allocPoint, allocPoint);
        assertEq(PoolInfo.lastRewardBlock, lastRewardBlock);
        assertEq(PoolInfo.accPointsPerShare, accPointsPerShare);
        assertEq(abi.encode(PoolInfo.description), abi.encode(description));
    }

    // MULTIPLE DEPOSITS AND POINT DISTRIBUTION /////////////////////////////////////////////////////////////////
    function test_MultipleDeposits(uint256 rollBlocks) public {
        vm.assume(rollBlocks > 0 && rollBlocks < 1e18);
        setOneDepositorPerPool();
        SophonFarmingState.UserInfo[][] memory userInfos =
            new SophonFarmingState.UserInfo[][](sophonFarming.getPoolInfo().length);

        address[] memory accounts = new address[](3);
        accounts[0] = account1;
        accounts[1] = account2;
        accounts[2] = account3;

        userInfos = sophonFarming.getUserInfo(accounts);

        uint256 poolsLength = sophonFarming.poolLength();

        vm.roll(block.number + rollBlocks);

        uint256[][] memory pendingPoints = new uint256[][](poolsLength);
        pendingPoints = sophonFarming.getPendingPoints(accounts);

        uint256[4][][] memory optimizedUserInfos = new uint256[4][][](2);
        optimizedUserInfos = sophonFarming.getOptimizedUserInfo(accounts);

        uint256 totalPoints;
        for (uint256 i = 0; i < accounts.length; i++) {
            for (uint256 j = 0; j < poolsLength; j++) {
                totalPoints += pendingPoints[i][j];
                console.log("pendingPoints[i][j]", pendingPoints[i][j]);

                assertEq(userInfos[i][j].amount, optimizedUserInfos[i][j][0]);
                assertEq(userInfos[i][j].boostAmount, optimizedUserInfos[i][j][1]);
                assertEq(userInfos[i][j].depositAmount, optimizedUserInfos[i][j][2]);
                assertEq(pendingPoints[i][j], optimizedUserInfos[i][j][3]);
                assertEq(pendingPoints[i][j], sophonFarming.pendingPoints(j, accounts[i]));
            }
        }

        // There are deposits in 2 of the 3 pools. Margin of error is 1 wei per user.
        assertApproxEqAbs(totalPoints, pointsPerBlock * rollBlocks, accounts.length);
    }
}

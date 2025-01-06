// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {SophonFarming} from "../contracts/farm/SophonFarming.sol";
import {SophonFarmingState} from "./../contracts/farm/SophonFarmingState.sol";
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
import {IBridgehub} from "./../contracts/farm/interfaces/bridge/IBridgehub.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SophonFarmingTest is Test {
    string internal mnemonic = "test test test test test test test test test test test junk";
    string internal envMnemonicKey = "MNEMONIC";

    address internal deployer;
    address internal account1 = address(0x1);
    address internal account2 = address(0x2);
    address internal account3 = address(0x3);
    address internal userAdmin = address(0xad);
    uint256 internal permitUserPK = 0x0000000000000000000000000000000000000000000000000000000000000001;

    SophonFarmingProxy public sophonFarmingProxy;
    SophonFarming public sophonFarming;
    address public implementation;
    SophonFarmingHarness public harnessImplementation;

    MockERC20 internal mock0;
    MockERC20 internal mock1;
    MockERC20 internal sophonToken;

    MockWETH internal weth;
    MockStETH internal stETH;
    MockWstETH internal wstETH;
    MockERC20 internal eETH;
    MockeETHLiquidityPool internal eETHLiquidityPool;
    MockWeETH internal weETH;
    MockERC20 internal dai;
    MockSDAI internal sDAI;

    uint256 internal wstETHAllocPoint;
    uint256 internal weETHAllocPoint;
    uint256 internal sDAIAllocPoint;
    uint256 internal pointsPerBlock;
    uint256 internal initialPoolStartBlock;
    uint256 internal boosterMultiplier;

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

    function getUserInfo(uint256 poolId, address user) internal view returns (SophonFarmingState.UserInfo memory) {
        SophonFarmingState.UserInfo memory userInfo;
        (userInfo.amount, userInfo.boostAmount, userInfo.depositAmount, userInfo.rewardSettled, userInfo.rewardDebt) =
            sophonFarming.userInfo(poolId, user);

        return userInfo;
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
        weETHAllocPoint = 20000;

        // mock DAI
        dai = new MockERC20("Mock Dai Token", "MockDAI", 18);
        dai.mint(address(this), 1000000e18);

        // mock sDAI
        sDAI = new MockSDAI(dai);
        sDAIAllocPoint = 20000;

        // mock SOPH
        sophonToken = new MockERC20("SOPHON", "SOPH", 18);
        sophonToken.mint(deployer, 1000000e18);

        // Set up for SophonFarming
        pointsPerBlock = 25e18;
        initialPoolStartBlock = block.number;
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
                ],
                block.chainid
            )
        );

        // Deploy proxy
        sophonFarmingProxy = new SophonFarmingProxy(implementation);

        // Grant the implementation interface to the proxy
        sophonFarming = SophonFarming(payable(address(sophonFarmingProxy)));

        // Initialize SophonFarming
        sophonFarming.initialize(wstETHAllocPoint, weETHAllocPoint, sDAIAllocPoint, pointsPerBlock, initialPoolStartBlock, boosterMultiplier);

        weth.approve(address(sophonFarming), maxUint);
        stETH.approve(address(sophonFarming), maxUint);
        wstETH.approve(address(sophonFarming), maxUint);
        dai.approve(address(sophonFarming), maxUint);
        sDAI.approve(address(sophonFarming), maxUint);
        stETH.approve(address(wstETH), maxUint);
        dai.approve(address(sDAI), maxUint);

        // Mint some tokens
        weth.deposit{value: 0.01e18}();
        stETH.submit{value: 0.02e18}(address(sophonFarming));
        wstETH.wrap(stETH.balanceOf(deployer) / 2);
        dai.mint(deployer, 1000e18);
        sDAI.deposit(dai.balanceOf(deployer) / 2, deployer);

        sophonFarming.setEndBlock(maxUint - 1000, 1000);

        // Deploy harness implementation
        harnessImplementation = new SophonFarmingHarness(
            [
                address(dai),
                address(sDAI),
                address(weth),
                address(stETH),
                address(wstETH),
                address(eETH),
                address(eETHLiquidityPool),
                address(weETH)
            ],
            block.chainid
        );

        harnessImplementation.setEndBlock(maxUint - 1000, 1000);

        vm.stopPrank();
    }

    function setOneDepositorPerPool() public {
        vm.prank(deployer);
        // sophonFarming.setEndBlock(block.number + 100, 50);

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
                ],
                block.chainid
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
                ],
                block.chainid
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
                ],
                block.chainid
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
                ],
                block.chainid
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
                ],
                block.chainid
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
        sophonFarming.initialize(0, 0, 0, 0, 0, 0);
    }

    function test_Initialize_RevertWhen_InvalidPointsPerBlock() public {
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
                ],
                block.chainid
            )
        );

        // Deploy proxy
        SophonFarmingProxy _sophonFarmingProxy = new SophonFarmingProxy(_implementation);
        (_sophonFarmingProxy);

        // Grant the implementation interface to the proxy
        SophonFarming _sophonFarming = SophonFarming(payable(address(_implementation)));

        vm.expectRevert(SophonFarming.InvalidPointsPerBlock.selector);
        _sophonFarming.initialize(0, 0, 0, 0, 0, 0);
    }

    function test_Initialize_RevertWhen_InvalidBooster() public {
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
                ],
                block.chainid
            )
        );

        vm.expectRevert(SophonFarming.InvalidBooster.selector);
        SophonFarming(payable(newImplementation)).initialize(
            wstETHAllocPoint, weETHAllocPoint, sDAIAllocPoint, pointsPerBlock, initialPoolStartBlock, 1
        );
    }

    // ADD FUNCTION /////////////////////////////////////////////////////////////////
    function testFuzz_Add(uint256 newAllocPoints) public {
        newAllocPoints = bound(newAllocPoints, 1, 100000);
        vm.startPrank(deployer);

        MockERC20 mock = new MockERC20("Mock", "M", 18);
        uint256 startingAllocPoint = sophonFarming.totalAllocPoint();
        uint256 poolId = sophonFarming.add(newAllocPoints, address(mock), mock.name(), 0, 0);

        SophonFarmingState.PoolInfo[] memory PoolInfo;

        PoolInfo = sophonFarming.getPoolInfo();

        assertEq(address(PoolInfo[poolId].lpToken), address(mock));
        assertEq(PoolInfo[poolId].amount, 0);
        assertEq(PoolInfo[poolId].boostAmount, 0);
        assertEq(PoolInfo[poolId].depositAmount, 0);
        assertEq(PoolInfo[poolId].allocPoint, newAllocPoints);
        assertEq(PoolInfo[poolId].lastRewardBlock, initialPoolStartBlock);
        assertEq(PoolInfo[poolId].accPointsPerShare, 0);
        assertEq(abi.encode(PoolInfo[poolId].description), abi.encode(mock.name()));

        assertEq(startingAllocPoint + newAllocPoints, sophonFarming.totalAllocPoint());
    }

    function testFuzz_Add_SetPointsPerBlock(uint256 newPointsPerBlock) public {
        newPointsPerBlock = bound(newPointsPerBlock, 1e18, 1000e18);
        vm.startPrank(deployer);

        MockERC20 mock = new MockERC20("Mock", "M", 18);
        uint256 startingAllocPoint = sophonFarming.totalAllocPoint();
        uint256 poolId = sophonFarming.add(2000, address(mock), mock.name(), 0, newPointsPerBlock);

        SophonFarmingState.PoolInfo[] memory PoolInfo;

        PoolInfo = sophonFarming.getPoolInfo();

        assertEq(address(PoolInfo[poolId].lpToken), address(mock));
        assertEq(PoolInfo[poolId].amount, 0);
        assertEq(PoolInfo[poolId].boostAmount, 0);
        assertEq(PoolInfo[poolId].depositAmount, 0);
        assertEq(PoolInfo[poolId].allocPoint, 2000);
        assertEq(PoolInfo[poolId].lastRewardBlock, initialPoolStartBlock);
        assertEq(PoolInfo[poolId].accPointsPerShare, 0);
        assertEq(abi.encode(PoolInfo[poolId].description), abi.encode(mock.name()));

        assertEq(startingAllocPoint + 2000, sophonFarming.totalAllocPoint());
        assertEq(sophonFarming.pointsPerBlock(), newPointsPerBlock);
    }

    function test_Add_RevertWhen_FarmingIsEnded() public {
        vm.startPrank(deployer);

        sophonFarming.setEndBlock(block.number + 1, 1);
        vm.roll(block.number + 2);

        MockERC20 mock = new MockERC20("Mock", "M", 18);

        vm.expectRevert(SophonFarming.FarmingIsEnded.selector);
        sophonFarming.add(10000, address(mock), "Mock",  0, 0);
    }

    function test_Add_RevertWhen_PoolExists() public {
        vm.startPrank(deployer);

        sophonFarming.setEndBlock(block.number + 1, 1);
        vm.roll(block.number + 2);

        vm.expectRevert(SophonFarming.PoolExists.selector);
        sophonFarming.add(sDAIAllocPoint, address(sDAI), "sDAI", 0, 0);
    }

    function test_Add_RevertWhen_ZeroAddress() public {
        vm.startPrank(deployer);

        sophonFarming.setEndBlock(block.number + 1, 1);
        vm.roll(block.number + 2);

        vm.expectRevert(SophonFarming.ZeroAddress.selector);
        sophonFarming.add(sDAIAllocPoint, address(0), "Zero", 0, 0);
    }

    // SET FUNCTION /////////////////////////////////////////////////////////////////
    function testFuzz_SetFunction(uint256 newAllocPoints) public {
        newAllocPoints = bound(newAllocPoints, 1, 100000);
        vm.startPrank(deployer);

        vm.roll(block.number - 1);

        uint256 poolId = sophonFarming.typeToId(SophonFarmingState.PredefinedPool.sDAI);
        uint256 startingTotalAllocPoint = sophonFarming.totalAllocPoint();

        SophonFarmingState.PoolInfo[] memory startingPoolInfo;
        startingPoolInfo = sophonFarming.getPoolInfo();

        sophonFarming.set(poolId, newAllocPoints, 0, 0);

        SophonFarmingState.PoolInfo[] memory finalPoolInfo;
        finalPoolInfo = sophonFarming.getPoolInfo();

        assertEq(finalPoolInfo[poolId].allocPoint, newAllocPoints);
        assertEq(
            sophonFarming.totalAllocPoint(),
            startingTotalAllocPoint - startingPoolInfo[poolId].allocPoint + newAllocPoints
        );
    }

    function testFuzz_SetFunction_SetPointsPerBlock(uint256 newPointsPerBlock) public {
        newPointsPerBlock = bound(newPointsPerBlock, 1e18, 1000e18);
        vm.startPrank(deployer);

        vm.roll(block.number - 1);

        uint256 poolId = sophonFarming.typeToId(SophonFarmingState.PredefinedPool.sDAI);
        uint256 startingTotalAllocPoint = sophonFarming.totalAllocPoint();

        SophonFarmingState.PoolInfo[] memory startingPoolInfo;
        startingPoolInfo = sophonFarming.getPoolInfo();

        sophonFarming.set(poolId, 2000, 0, newPointsPerBlock);

        SophonFarmingState.PoolInfo[] memory finalPoolInfo;
        finalPoolInfo = sophonFarming.getPoolInfo();

        assertEq(finalPoolInfo[poolId].allocPoint, 2000);
        assertEq(
            sophonFarming.totalAllocPoint(),
            startingTotalAllocPoint - startingPoolInfo[poolId].allocPoint + 2000
        );
        assertEq(sophonFarming.pointsPerBlock(), newPointsPerBlock);
    }

    function test_Set_RevertWhen_FarmingIsEnded() public {
        vm.startPrank(deployer);

        sophonFarming.setEndBlock(block.number + 1, 1);
        vm.roll(block.number + 2);

        uint256 poolId = sophonFarming.typeToId(SophonFarmingState.PredefinedPool.sDAI);

        vm.expectRevert(SophonFarming.FarmingIsEnded.selector);
        sophonFarming.set(poolId, 10000, 0, 0);
    }

    // IS_FARMING_ENDED FUNCTION /////////////////////////////////////////////////////////////////
    function test_IsFarmingEnded() public {
        vm.startPrank(deployer);

        assertEq(sophonFarming.isFarmingEnded(), false);

        sophonFarming.setEndBlock(block.number + 10, 1);
        assertEq(sophonFarming.isFarmingEnded(), false);

        vm.roll(block.number + 20);
        assertEq(sophonFarming.isFarmingEnded(), true);
    }

    // SET_BRIDGE FUNCTION /////////////////////////////////////////////////////////////////
    function test_SetBridge() public {
        vm.startPrank(deployer);

        MockBridge bridge = new MockBridge();

        sophonFarming.setBridge(address(bridge));

        assertEq(address(sophonFarming.bridge()), address(bridge));
    }

    function test_SetBridge_RevertWhen_ZeroAddress() public {
        vm.startPrank(deployer);

        vm.expectRevert(SophonFarming.ZeroAddress.selector);
        sophonFarming.setBridge(address(0));
    }

    // SET_L2_FARM_FOR_POOL FUNCTION /////////////////////////////////////////////////////////////////
    function test_SetL2FarmForPool() public {
        vm.startPrank(deployer);

        uint256 poolId = sophonFarming.typeToId(SophonFarmingState.PredefinedPool.wstETH);
        address l2Farm = address(0xF);

        sophonFarming.setL2FarmForPool(poolId, l2Farm);

        SophonFarmingState.PoolInfo[] memory PoolInfo;

        PoolInfo = sophonFarming.getPoolInfo();

        assertEq(PoolInfo[poolId].l2Farm, l2Farm);
    }

    function test_SetL2FarmForPool_RevertWhen_ZeroAddress() public {
        vm.startPrank(deployer);

        uint256 poolId = sophonFarming.typeToId(SophonFarmingState.PredefinedPool.wstETH);
        address l2Farm = address(0);

        vm.expectRevert(SophonFarming.ZeroAddress.selector);
        sophonFarming.setL2FarmForPool(poolId, l2Farm);
    }

    // SET_END_BLOCK FUNCTION /////////////////////////////////////////////////////////////////
    function testFuzz_SetEndBlock(uint256 newEndBlock) public {
        newEndBlock = bound(newEndBlock, block.number + 1, block.number + 100000);
        vm.startPrank(deployer);

        newEndBlock = block.number + 10;
        sophonFarming.setEndBlock(newEndBlock, 1);
        assertEq(sophonFarming.endBlock(), newEndBlock);

        newEndBlock = 0;
        sophonFarming.setEndBlock(newEndBlock, 1);
        assertEq(sophonFarming.endBlock(), newEndBlock);
    }

    function test_SetEndBlock_RevertWhen_InvalidEndBlock() public {
        vm.startPrank(deployer);

        vm.roll(block.number + 10);
        vm.expectRevert(SophonFarming.InvalidEndBlock.selector);
        sophonFarming.setEndBlock(1, 1);
    }

    function test_SetEndBlock_RevertWhen_FarmingIsEnded() public {
        vm.startPrank(deployer);

        sophonFarming.setEndBlock(block.number + 9, 1);
        vm.roll(block.number + 10);

        vm.expectRevert(SophonFarming.FarmingIsEnded.selector);
        sophonFarming.setEndBlock(block.number + 15, 1);
    }

    // SET_POINTS_PER_BLOCK FUNCTION /////////////////////////////////////////////////////////////////
    function testFuzz_SetPointsPerBlock(uint256 newPointsPerBlock) public {
        newPointsPerBlock = bound(newPointsPerBlock, 1e18, 1000e18);
        vm.startPrank(deployer);

        sophonFarming.setPointsPerBlock(newPointsPerBlock);
        assertEq(sophonFarming.pointsPerBlock(), newPointsPerBlock);
    }

    function test_SetPointsPerBlock_RevertWhen_IsFarmingEnded() public {
        vm.startPrank(deployer);

        sophonFarming.setEndBlock(block.number + 9, 1);
        vm.roll(block.number + 10);

        uint256 newPointsPerBlock = 50e18;
        vm.expectRevert(SophonFarming.FarmingIsEnded.selector);
        sophonFarming.setPointsPerBlock(newPointsPerBlock);
    }

    function test_SetPointsPerBlock_RevertWhen_InvalidPointsPerBlock() public {
        vm.startPrank(deployer);

        uint256 newPointsPerBlock = 1;
        vm.expectRevert(SophonFarming.InvalidPointsPerBlock.selector);
        sophonFarming.setPointsPerBlock(newPointsPerBlock);
    }

    // SET_BOOSTER_MULTIPLIER FUNCTION /////////////////////////////////////////////////////////////////
    function testFuzz_SetBoosterMultiplier(uint256 newBoosterMultiplier) public {
        newBoosterMultiplier = bound(newBoosterMultiplier, 1e18, 10e18);
        vm.startPrank(deployer);

        sophonFarming.setBoosterMultiplier(newBoosterMultiplier);
        assertEq(sophonFarming.boosterMultiplier(), newBoosterMultiplier);
    }

    function test_SetBoosterMultiplier_RevertWhen_IsFarmingEnded() public {
        vm.startPrank(deployer);

        sophonFarming.setEndBlock(block.number + 9, 1);
        vm.roll(block.number + 10);

        uint256 newBoosterMultiplier = 3e18;
        vm.expectRevert(SophonFarming.FarmingIsEnded.selector);
        sophonFarming.setBoosterMultiplier(newBoosterMultiplier);
    }

    function test_SetBoosterMultiplier_RevertWhen_InvalidBooster() public {
        vm.startPrank(deployer);

        sophonFarming.setEndBlock(block.number + 9, 1);
        vm.roll(block.number + 10);

        uint256 newBoosterMultiplier = 1;
        vm.expectRevert(SophonFarming.InvalidBooster.selector);
        sophonFarming.setBoosterMultiplier(newBoosterMultiplier);
    }

    // GET_BLOCK_MULTIPLIER FUNCTION /////////////////////////////////////////////////////////////////
    function test_GetBlockMultiplier() public {
        vm.startPrank(deployer);
        uint256 newEndBlock = block.number + 100;
        harnessImplementation.setEndBlock(newEndBlock, 1);
        assertEq(harnessImplementation.endBlock(), newEndBlock);

        uint256 from = block.number;
        uint256 to = block.number + 10;

        assertEq(harnessImplementation.getBlockMultiplier(from, to), (to - from) * 1e18);
        assertEq(harnessImplementation.getBlockMultiplier(to, from), 0);

        to = block.number + 1000;
        assertEq(harnessImplementation.getBlockMultiplier(from, to), (newEndBlock - from) * 1e18);
    }

    // SET_USERS_WHITELISTED FUNCTION /////////////////////////////////////////////////////////////////
    function testFuzz_SetUsersWhitelisted(uint256 accountAmount) public {
        accountAmount = bound(accountAmount, 1, 10);
        vm.startPrank(deployer);

        address[] memory accounts = new address[](accountAmount);

        for (uint256 i = 0; i < accountAmount; i++) {
            accounts[i] = address(uint160(i));
            assertEq(sophonFarming.whitelist(userAdmin, accounts[i]), false);
        }

        sophonFarming.setUsersWhitelisted(userAdmin, accounts, true);

        for (uint256 i = 0; i < accountAmount; i++) {
            assertEq(sophonFarming.whitelist(userAdmin, accounts[i]), true);
        }

        sophonFarming.setUsersWhitelisted(userAdmin, accounts, false);

        for (uint256 i = 0; i < accountAmount; i++) {
            assertEq(sophonFarming.whitelist(userAdmin, accounts[i]), false);
        }
    }

    // PENDING_POINTS FUNCTION /////////////////////////////////////////////////////////////////
    function testFuzz_PendingPoints(uint256 amountToDeposit, uint256 poolStartBlock, uint256 accruedBlocks) public {
        amountToDeposit = bound(amountToDeposit, 1e6, 1e27);
        poolStartBlock = bound(poolStartBlock, 10, 5e6);
        accruedBlocks = bound(accruedBlocks, 1, 5e6);

        vm.startPrank(deployer);

        SophonFarmingState.PoolInfo[] memory PoolInfo;
        PoolInfo = sophonFarming.getPoolInfo();

        uint256 wsthDepositedAmount = amountToDeposit;
        uint256 poolId = sophonFarming.typeToId(SophonFarmingState.PredefinedPool.wstETH);

        // Set block number lower than poolStartBlock to be able to update it
        vm.roll(0);
        sophonFarming.set(poolId, PoolInfo[poolId].allocPoint, poolStartBlock, 0);
        PoolInfo = sophonFarming.getPoolInfo();
        assertEq(PoolInfo[poolId].lastRewardBlock, poolStartBlock);
        vm.roll(1);

        vm.stopPrank();
        vm.startPrank(account1);
        deal(address(wstETH), account1, amountToDeposit * 2);

        wstETH.approve(address(sophonFarming), amountToDeposit * 2);
        sophonFarming.deposit(poolId, amountToDeposit, 0);

        vm.roll(poolStartBlock + accruedBlocks);

        uint256 pendingPoints = sophonFarming.pendingPoints(poolId, account1);

        sophonFarming.deposit(poolId, amountToDeposit, 0);
        PoolInfo = sophonFarming.getPoolInfo();

        SophonFarmingState.UserInfo memory userInfo;
        (userInfo.amount, userInfo.boostAmount, userInfo.depositAmount, userInfo.rewardSettled, userInfo.rewardDebt) =
            sophonFarming.userInfo(poolId, account1);

        uint256 pointReward = (accruedBlocks * 1e18) * sophonFarming.pointsPerBlock() * PoolInfo[poolId].allocPoint / sophonFarming.totalAllocPoint();
        uint256 accPointsPerShare = pointReward * 1e18 / (amountToDeposit);
        
        // precision loss related to deposited amount and blocks elapsed
        uint256 delta =  accruedBlocks * amountToDeposit / 1e18;
        assertApproxEqAbs(pendingPoints, amountToDeposit * accPointsPerShare / 1e36, delta);
        assertGt(pendingPoints, 0);
    }

    // MASS_UPDATE_POOLS FUNCTION /////////////////////////////////////////////////////////////////
    function test_MassUpdatePools() public {
        vm.startPrank(deployer);

        sophonFarming.setEndBlock(block.number + 1, 1);
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

        sophonFarming.setEndBlock(block.number + 1, 1);
        vm.roll(block.number + 3);

        uint256 poolId = sophonFarming.typeToId(SophonFarmingState.PredefinedPool.wstETH);
        sophonFarming.updatePool(poolId);

        SophonFarmingState.PoolInfo[] memory PoolInfo;

        PoolInfo = sophonFarming.getPoolInfo();

        assertEq(PoolInfo[poolId].lastRewardBlock, block.number);
    }

    // DEPOSIT_ETH FUNCTION /////////////////////////////////////////////////////////////////
    function testFuzz_DepositEth_NotBoosted(uint256 amountToDeposit) public {
        amountToDeposit = bound(amountToDeposit, 1e6, 1e27);
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
        amountToDeposit = bound(amountToDeposit, 1e6, 1e27);
        multipleDeposits = bound(multipleDeposits, 1, 10);
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
        amountToDeposit = bound(amountToDeposit, 1e6, 1e27);
        boostFraction = bound(boostFraction, 1, 10);

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
        amountToDeposit = bound(amountToDeposit, 1e6, 1e27);
        boostFraction = bound(boostFraction, 1, 10);

        vm.deal(account1, amountToDeposit);
        vm.startPrank(account1);

        uint256 amountToBoost = amountToDeposit / boostFraction;

        vm.expectRevert(SophonFarming.NoEthSent.selector);
        sophonFarming.depositEth{value: 0}(amountToBoost, SophonFarmingState.PredefinedPool.wstETH);
    }

    function testFuzz_DepositEth_RevertWhen_FarmingIsEnded(uint256 amountToDeposit, uint256 boostFraction) public {
        amountToDeposit = bound(amountToDeposit, 1e6, 1e27);
        boostFraction = bound(boostFraction, 1, 10);

        vm.prank(deployer);
        sophonFarming.setEndBlock(block.number + 9, 1);
        vm.roll(block.number + 10);

        vm.deal(account1, amountToDeposit);
        vm.startPrank(account1);

        uint256 amountToBoost = amountToDeposit / boostFraction;

        vm.expectRevert(SophonFarming.FarmingIsEnded.selector);
        sophonFarming.depositEth{value: amountToDeposit}(amountToBoost, SophonFarmingState.PredefinedPool.wstETH);
    }

    function testFuzz_DepositEth_RevertWhen_InvalidDeposit(uint256 amountToDeposit, uint256 boostFraction) public {
        amountToDeposit = bound(amountToDeposit, 1, 1000);
        boostFraction = bound(boostFraction, 1, 10);

        vm.deal(account1, amountToDeposit);
        vm.startPrank(account1);

        uint256 amountToBoost = amountToDeposit / boostFraction;

        vm.expectRevert(SophonFarming.InvalidDeposit.selector);
        sophonFarming.depositEth{value: amountToDeposit}(amountToBoost, SophonFarmingState.PredefinedPool.wstETH);
    }

    function testFuzz_DepositEth_RevertWhen_BoostTooHigh(uint256 amountToDeposit) public {
        amountToDeposit = bound(amountToDeposit, 1e6, 1e27);

        vm.deal(account1, amountToDeposit);
        vm.startPrank(account1);

        uint256 wsthDepositedAmount = WstETHRate(StETHRate(amountToDeposit));
        uint256 amountToBoost = amountToDeposit * 2;

        vm.expectRevert(abi.encodeWithSelector(SophonFarming.BoostTooHigh.selector, wsthDepositedAmount));
        sophonFarming.depositEth{value: amountToDeposit}(amountToBoost, SophonFarmingState.PredefinedPool.wstETH);
    }

    function testFuzz_DepositEthToWeETH_NotBoosted(uint256 amountToDeposit) public {
        amountToDeposit = bound(amountToDeposit, 1e6, 1e27);
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
        amountToDeposit = bound(amountToDeposit, 1e6, 1e27);

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
        amountToDeposit = bound(amountToDeposit, 1e6, 1e27);
        boostFraction = bound(boostFraction, 1, 10);

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
        amountToDeposit = bound(amountToDeposit, 1e6, 1e27);
        boostFraction = bound(boostFraction, 1, 10);

        vm.prank(deployer);
        sophonFarming.setEndBlock(block.number + 9, 1);
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
        amountToDeposit = bound(amountToDeposit, 1, 1000);
        boostFraction = bound(boostFraction, 1, 10);

        vm.startPrank(account1);
        vm.deal(account1, amountToDeposit);
        weth.deposit{value: amountToDeposit}();
        assertEq(weth.balanceOf(account1), amountToDeposit);

        weth.approve(address(sophonFarming), amountToDeposit);
        vm.expectRevert(SophonFarming.InvalidDeposit.selector);
        sophonFarming.depositWeth(amountToDeposit, 0, SophonFarmingState.PredefinedPool.wstETH);
    }

    function testFuzz_DepositWeth_RevertWhen_BoostTooHigh(uint256 amountToDeposit) public {
        amountToDeposit = bound(amountToDeposit, 1e6, 1e27);

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
        amountToDeposit = bound(amountToDeposit, 1e6, 1e27);

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
        amountToDeposit = bound(amountToDeposit, 1e6, 1e27);

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
        amountToDeposit = bound(amountToDeposit, 1e6, 1e27);
        boostFraction = bound(boostFraction, 1, 10);

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
        amountToDeposit = bound(amountToDeposit, 1e6, 1e27);
        boostFraction = bound(boostFraction, 1, 10);

        vm.prank(deployer);
        sophonFarming.setEndBlock(block.number + 9, 1);
        vm.roll(block.number + 10);

        vm.startPrank(account1);
        deal(address(eETH), account1, amountToDeposit);
        assertEq(eETH.balanceOf(account1), amountToDeposit);

        eETH.approve(address(sophonFarming), amountToDeposit);
        vm.expectRevert(SophonFarming.FarmingIsEnded.selector);
        sophonFarming.depositeEth(amountToDeposit, 0);
    }

    function test_DepositEEth_RevertWhen_InvalidDeposit() public {
        uint256 amountToDeposit = 1;

        vm.startPrank(account1);
        deal(address(eETH), account1, amountToDeposit);
        assertEq(eETH.balanceOf(account1), amountToDeposit);

        eETH.approve(address(sophonFarming), amountToDeposit);
        vm.expectRevert(SophonFarming.InvalidDeposit.selector);
        sophonFarming.depositeEth(amountToDeposit, 0);
    }

    function testFuzz_DepositEEth_RevertWhen_BoostTooHigh(uint256 amountToDeposit) public {
        amountToDeposit = bound(amountToDeposit, 1e6, 1e27);

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
        amountToDeposit = bound(amountToDeposit, 1e6, 1e27);

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
        amountToDeposit = bound(amountToDeposit, 1e6, 1e27);
        boostFraction = bound(boostFraction, 1, 10);

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
        amountToDeposit = bound(amountToDeposit, 1e6, 1e27);
        boostFraction = bound(boostFraction, 1, 10);

        vm.prank(deployer);
        sophonFarming.setEndBlock(block.number + 9, 1);
        vm.roll(block.number + 10);

        vm.startPrank(account1);
        deal(address(stETH), account1, amountToDeposit);
        assertEq(stETH.balanceOf(account1), amountToDeposit);

        stETH.approve(address(sophonFarming), amountToDeposit);
        vm.expectRevert(SophonFarming.FarmingIsEnded.selector);
        sophonFarming.depositStEth(amountToDeposit, 0);
    }

    function test_DepositStEth_RevertWhen_InvalidDeposit() public {
        uint256 amountToDeposit = 1;

        vm.startPrank(account1);
        deal(address(stETH), account1, amountToDeposit);
        assertEq(stETH.balanceOf(account1), amountToDeposit);

        stETH.approve(address(sophonFarming), amountToDeposit);
        vm.expectRevert(SophonFarming.InvalidDeposit.selector);
        sophonFarming.depositStEth(amountToDeposit, 0);
    }

    function testFuzz_DepositStEth_RevertWhen_BoostTooHigh(uint256 amountToDeposit) public {
        amountToDeposit = bound(amountToDeposit, 1e6, 1e27);

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
        amountToDeposit = bound(amountToDeposit, 1e6, 1e27);

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
        amountToDeposit = bound(amountToDeposit, 1e6, 1e27);
        boostFraction = bound(boostFraction, 1, 10);

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
        amountToDeposit = bound(amountToDeposit, 1e6, 1e27);
        boostFraction = bound(boostFraction, 1, 10);

        vm.prank(deployer);
        sophonFarming.setEndBlock(block.number + 9, 1);
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

    function test_DepositWstEth_RevertWhen_InvalidDeposit() public {
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
        amountToDeposit = bound(amountToDeposit, 1e6, 1e27);

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
        amountToDeposit = bound(amountToDeposit, 1e6, 1e27);

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
        amountToDeposit = bound(amountToDeposit, 1e6, 1e27);
        boostFraction = bound(boostFraction, 1, 5);

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
        assertEq(userInfo.depositAmount, sDAI.convertToShares(amountToDeposit) - finalAmountToDepositBoost);
        assertEq(userInfo.rewardSettled, 0);
        assertEq(userInfo.rewardDebt, 0);
    }

    // WITHDRAW FUNCTION /////////////////////////////////////////////////////////////////
    function testFuzz_DepositDai_NotBoostedWithdraw(uint256 amountToDeposit, uint256 fractionToWithdraw) public {
        amountToDeposit = bound(amountToDeposit, 1e6, 1e27);
        fractionToWithdraw = bound(fractionToWithdraw, 1, 10);

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
        sophonFarming.setEndBlock(block.number + blocks, 1);
        vm.roll(block.number + blocks + 1);

        address[] memory accounts = new address[](1);
        accounts[0] = account1;

        vm.startPrank(account1);
        sophonFarming.withdraw(poolId, withdrawAmount);

        SophonFarmingState.PoolInfo[] memory PoolInfo;
        PoolInfo = sophonFarming.getPoolInfo();

        SophonFarmingState.UserInfo memory finalUserInfo = getUserInfo(poolId, account1);

        uint256 rewardSettled = depositAmount * PoolInfo[poolId].accPointsPerShare / 1e18;
        uint256 rewardDebt =
            depositAmount * (depositAmount - withdrawAmount) / depositAmount * PoolInfo[poolId].accPointsPerShare / 1e18;

        assertEq(finalUserInfo.amount, depositAmount - withdrawAmount);
        assertEq(finalUserInfo.boostAmount, 0);
        assertEq(finalUserInfo.depositAmount, depositAmount - withdrawAmount);
        assertEq(finalUserInfo.rewardSettled, rewardSettled);
        assertEq(finalUserInfo.rewardDebt, rewardDebt);

        assertEq(sDAI.balanceOf(account1), withdrawAmount);
    }

    function testFuzz_DepositDai_RevertWhen_NotBoostedWithdraw_InvalidWithdraw(uint256 amountToDeposit) public {
        amountToDeposit = bound(amountToDeposit, 1e6, 1e27);

        deal(address(dai), account1, amountToDeposit);
        assertEq(dai.balanceOf(account1), amountToDeposit);

        uint256 poolId = sophonFarming.typeToId(SophonFarmingState.PredefinedPool.sDAI);

        vm.startPrank(account1);
        dai.approve(address(sophonFarming), amountToDeposit);
        sophonFarming.depositDai(amountToDeposit, 0);
        assertEq(dai.balanceOf(account1), 0);
        vm.stopPrank();

        vm.prank(deployer);
        sophonFarming.setEndBlock(block.number + 10, 10);
        vm.roll(block.number + 20);

        vm.startPrank(account1);
        vm.expectRevert(SophonFarming.WithdrawIsZero.selector);
        sophonFarming.withdraw(poolId, 0);

        vm.roll(block.number + 22);
        vm.expectRevert(SophonFarming.WithdrawNotAllowed.selector);
        sophonFarming.withdraw(poolId, 1);
    }

    function testFuzz_DepositDai_BoostedWithdraw(
        uint256 amountToDeposit,
        uint256 boostFraction,
        uint256 fractionToWithdraw
    ) public {
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
        sophonFarming.setEndBlock(block.number + blocks, 1);
        vm.roll(block.number + blocks + 1);

        SophonFarmingState.UserInfo memory userInfo = getUserInfo(poolId, account1);

        vm.startPrank(account1);
        sophonFarming.withdraw(poolId, withdrawAmount);

        SophonFarmingState.UserInfo memory finalUserInfo = getUserInfo(poolId, account1);

        SophonFarmingState.PoolInfo[] memory PoolInfo;
        PoolInfo = sophonFarming.getPoolInfo();

        uint256 rewardSettled = userInfo.amount * PoolInfo[poolId].accPointsPerShare / 1e18;
        uint256 rewardDebt = (userInfo.amount - withdrawAmount) * PoolInfo[poolId].accPointsPerShare / 1e18;

        assertApproxEqAbs(
            finalUserInfo.amount,
            depositAmount - withdrawAmount + finalAmountToDepositBoost * sophonFarming.boosterMultiplier() / 1e18,
            1
        );
        assertEq(finalUserInfo.boostAmount, finalAmountToDepositBoost * sophonFarming.boosterMultiplier() / 1e18);
        assertApproxEqAbs(finalUserInfo.depositAmount, depositAmount - withdrawAmount, 1);
        assertEq(finalUserInfo.rewardSettled, rewardSettled);
        assertEq(finalUserInfo.rewardDebt, rewardDebt);

        assertEq(sDAI.balanceOf(account1), withdrawAmount);
    }

    function testFuzz_DepositDai_MaxWithdraw(uint256 amountToDeposit) public {
        amountToDeposit = bound(amountToDeposit, 1e6, 1e27);

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
        sophonFarming.setEndBlock(block.number + blocks, 1);
        vm.roll(block.number + blocks + 1);

        SophonFarmingState.UserInfo memory userInfo = getUserInfo(poolId, account1);

        vm.startPrank(account1);
        sophonFarming.withdraw(poolId, withdrawAmount);

        SophonFarmingState.UserInfo memory finalUserInfo = getUserInfo(poolId, account1);

        SophonFarmingState.PoolInfo[] memory PoolInfo;
        PoolInfo = sophonFarming.getPoolInfo();

        uint256 rewardSettled = userInfo.amount * PoolInfo[poolId].accPointsPerShare / 1e18;

        assertEq(finalUserInfo.amount, 0);
        assertEq(finalUserInfo.boostAmount, 0);
        assertEq(finalUserInfo.depositAmount, 0);
        assertEq(finalUserInfo.rewardSettled, rewardSettled);
        assertEq(finalUserInfo.rewardDebt, 0);

        assertEq(sDAI.balanceOf(account1), depositAmount);
    }

    function testFuzz_DepositDai_RevertWhen_WithdrawTooHigh(uint256 amountToDeposit) public {
        amountToDeposit = bound(amountToDeposit, 1e6, 1e27);

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
        sophonFarming.setEndBlock(block.number + blocks, 1);
        vm.roll(block.number + blocks + 1);

        vm.startPrank(account1);
        vm.expectRevert(abi.encodeWithSelector(SophonFarming.WithdrawTooHigh.selector, depositAmount));
        sophonFarming.withdraw(poolId, withdrawAmount);
    }

    // IS_WITHDRAW_PERIOD_ENDED FUNCTION /////////////////////////////////////////////////////////////////
    function test_IsWithdrawPeriodEnded() public {
        vm.startPrank(deployer);

        sophonFarming.setEndBlock(block.number + 10, 1);
        vm.roll(block.number + 12);

        assertEq(sophonFarming.isWithdrawPeriodEnded(), true);
    }

    // BRIDGE POOL FUNCTION /////////////////////////////////////////////////////////////////
    function test_BridgePool() public {
        uint256 mintValue = 100e18;
        MockBridge bridge = new MockBridge();

        vm.startPrank(deployer);
        sophonFarming.setBridge(address(bridge));
        
        sophonFarming.setEndBlock(block.number + 10, 1);
        assertEq(sophonFarming.isFarmingEnded(), false);

        uint256 poolId = sophonFarming.typeToId(SophonFarmingState.PredefinedPool.wstETH);

        sophonFarming.setL2Farm(poolId, makeAddr("l2Farm"));

        vm.stopPrank();

        // Do some deposits
        setOneDepositorPerPool();

        vm.roll(block.number + 20);

        vm.startPrank(account1);
        deal(address(sophonToken), account1, mintValue);
        sophonToken.approve(address(sophonFarming), type(uint256).max);

        SophonFarmingState.PoolInfo[] memory poolInfo;

        poolInfo = sophonFarming.getPoolInfo();

        vm.expectEmit(true, false, true, true);
        emit SophonFarming.BridgePool(account1, poolId, poolInfo[poolId].amount);

        assertEq(sophonFarming.isBridged(poolId), false);
        sophonFarming.bridgePool(poolId, mintValue, address(sophonToken));
        assertEq(sophonFarming.isBridged(poolId), true);
    }

    function test_BridgePool_BEAM_WETH() public {
        uint256 mintValue = 100e18;
        uint256 depositAmount = 1000e18;

        MockBridge bridge = new MockBridge();

        vm.startPrank(deployer);
        sophonFarming.setBridge(address(bridge));
        
        sophonFarming.setEndBlock(block.number + 10, 1);
        assertEq(sophonFarming.isFarmingEnded(), false);

        MockERC20 mock = new MockERC20("Mock", "M", 18);
        sophonFarming.add(10000, address(mock), mock.name(), 0, 0);

        MockERC20 BEAM_WETH = new MockERC20("BEAM_WETH", "BEAM_WETH", 18);
        uint256 poolId = sophonFarming.add(10000, address(BEAM_WETH), BEAM_WETH.name(), 0, 0);
        assertEq(poolId, 4);
    
        sophonFarming.setL2Farm(poolId, makeAddr("l2Farm"));

        vm.stopPrank();

        vm.startPrank(account1);

        deal(address(sophonToken), account1, mintValue);
        assertEq(sophonToken.balanceOf(account1), mintValue);
        sophonToken.approve(address(sophonFarming), type(uint256).max);

        deal(address(BEAM_WETH), account1, depositAmount);
        assertEq(BEAM_WETH.balanceOf(account1), depositAmount);
        BEAM_WETH.approve(address(sophonFarming), depositAmount);

        sophonFarming.deposit(poolId, depositAmount, 0);

        vm.roll(block.number + 20);

        SophonFarmingState.PoolInfo[] memory poolInfo;

        poolInfo = sophonFarming.getPoolInfo();

        vm.expectEmit(true, false, true, true);
        emit SophonFarming.BridgePool(account1, poolId, poolInfo[poolId].amount);

        assertEq(sophonFarming.isBridged(poolId), false);
        sophonFarming.bridgePool(poolId, mintValue, address(sophonToken));
        assertEq(sophonFarming.isBridged(poolId), true);
    }

    function test_BridgePool_RevertWhen_Unauthorized() public {
        vm.startPrank(account1);

        uint256 poolId = sophonFarming.typeToId(SophonFarmingState.PredefinedPool.wstETH);

        vm.expectRevert(Unauthorized.selector);
        sophonFarming.bridgePool(poolId, 0, address(0));
    }

    function test_BridgePool_RevertWhen_PID7() public {
        vm.startPrank(account1);

        uint256 poolId = 7;

        vm.expectRevert(Unauthorized.selector);
        sophonFarming.bridgePool(poolId, 0, address(0));
    }

    function test_BridgePool_RevertWhen_BridgeInvalid() public {
        uint256 poolId = sophonFarming.typeToId(SophonFarmingState.PredefinedPool.wstETH);

        vm.prank(deployer);
        sophonFarming.setEndBlock(block.number + 10, 1);
        vm.roll(block.number + 20);

        vm.startPrank(account1);
        vm.expectRevert(SophonFarming.BridgeInvalid.selector);
        sophonFarming.bridgePool(poolId, 0, address(0));
    }

    // BRIDGE USDC FUNCTION
    function test_BridgeUSDC11() public {
        uint256 mintValue = 100e18;
        uint256 depositAmount = 1000e18;
        uint256 poolId;

        vm.startPrank(deployer);
        while (poolId < 6) {
            MockERC20 mock = new MockERC20("Mock", "M", 18);
            poolId = sophonFarming.add(10000, address(mock), mock.name(), 0, 0);
            console.log(poolId);
        }

        MockERC20 usdc = new MockERC20("USDC", "USDC", 18);
        poolId = sophonFarming.add(10000, address(usdc), usdc.name(), 0, 0);

        MockBridge bridge = new MockBridge();
        sophonFarming.setBridge(address(bridge));
        sophonFarming.setL2Farm(poolId, makeAddr("l2Farm"));
        sophonFarming.setEndBlock(block.number + 10, 1);
        assertEq(sophonFarming.isFarmingEnded(), false);

        deal(address(sophonToken), deployer, mintValue);
        assertEq(sophonToken.balanceOf(deployer), mintValue);
        sophonToken.approve(address(sophonFarming), type(uint256).max);

        vm.stopPrank();

        vm.startPrank(account1);

        deal(address(usdc), account1, depositAmount);
        assertEq(usdc.balanceOf(account1), depositAmount);
        usdc.approve(address(sophonFarming), depositAmount);

        sophonFarming.deposit(poolId, depositAmount, 0);

        vm.roll(block.number + 20);

        SophonFarmingState.PoolInfo[] memory poolInfo;

        poolInfo = sophonFarming.getPoolInfo();

        vm.stopPrank();
        vm.startPrank(deployer);

        vm.expectEmit(true, false, true, true);
        emit SophonFarming.BridgePool(deployer, poolId, poolInfo[poolId].amount);

        assertEq(sophonFarming.isBridged(poolId), false);
        sophonFarming.bridgeUSDC(mintValue, address(sophonToken), IBridgehub(address(bridge)));
        assertEq(sophonFarming.isBridged(poolId), true);
    }

    function test_BridgeUSDC_RevertWhen_Unauthorized() public {

    }

    // REVERT_FAILED_BRIDGE FUNCTION /////////////////////////////////////////////////////////////////
    // NOTE: function not fully implemented, an upgrade will implement this later
    function test_RevertFailedBridge_RevertWhen_Unauthorized() public {
        vm.startPrank(deployer);

        uint256 poolId = sophonFarming.typeToId(SophonFarmingState.PredefinedPool.wstETH);

        // vm.expectRevert(Unauthorized.selector);
        // sophonFarming.revertFailedBridge(poolId);
    }

    // BRIDGE USDC FUNCTION
    // function test_BridgeUSDC() public {
    //     sophonFarming.bridgeUSDC()
    // }

    // SET L2 FARM
    function test_SetL2Farm() public {
        vm.prank(deployer);
        sophonFarming.setL2Farm(0, makeAddr("l2Farm"));

        SophonFarmingState.PoolInfo[] memory PoolInfo;

        PoolInfo = sophonFarming.getPoolInfo();

        assertEq(PoolInfo[0].l2Farm, makeAddr("l2Farm"));
    }

    function test_SetL2Farm_RevertWhen_PoolExists() public {
        vm.expectRevert(SophonFarming.PoolExists.selector);
        vm.prank(deployer);
        sophonFarming.setL2Farm(type(uint256).max, address(0));
    }

    function test_SetL2Farm_RevertWhen_ZeroAddress() public {
        vm.expectRevert(SophonFarming.ZeroAddress.selector);
        vm.prank(deployer);
        sophonFarming.setL2Farm(0, address(0));
    }

    // INCREASE_BOOST FUNCTION /////////////////////////////////////////////////////////////////
    function testFuzz_IncreaseBoost(uint256 amountToDeposit, uint256 boostFraction) public {
        amountToDeposit = bound(amountToDeposit, 1e6, 1e27);
        boostFraction = bound(boostFraction, 1, 10);

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

    // TRANSFER_POINTS FUNCTION /////////////////////////////////////////////////////////////////
    function testFuzz_TransferPoints_ReceiverWithoutDeposit(uint256 amountToDeposit, uint256 rollBlocks, uint256 transferFraction) public {
        amountToDeposit = bound(amountToDeposit, 1e6, 1_000_000_000e18);
        rollBlocks = bound(rollBlocks, 1, 100);
        transferFraction = bound(transferFraction, 1, 10);

        vm.startPrank(deployer);

        // whitelist user
        address[] memory accounts = new address[](1);
        accounts[0] = account1;
        sophonFarming.setUsersWhitelisted(userAdmin, accounts, true);
        assertEq(sophonFarming.whitelist(userAdmin, account1), true);

        vm.stopPrank();
        vm.startPrank(account1);

        uint256 poolId = sophonFarming.typeToId(SophonFarmingState.PredefinedPool.wstETH);

        deal(address(wstETH), account1, amountToDeposit * 2);
        wstETH.approve(address(sophonFarming), amountToDeposit * 2);
        sophonFarming.deposit(poolId, amountToDeposit, 0);

        vm.roll(block.number + rollBlocks);

        sophonFarming.deposit(poolId, amountToDeposit, 0);
        assertEq(wstETH.balanceOf(account1), 0);

        SophonFarmingState.UserInfo memory user1Info;
        (user1Info.amount, user1Info.boostAmount, user1Info.depositAmount, user1Info.rewardSettled, user1Info.rewardDebt) =
            sophonFarming.userInfo(poolId, account1);

        SophonFarmingState.PoolInfo[] memory PoolInfo;

        PoolInfo = sophonFarming.getPoolInfo();

        uint256 transferPoints = user1Info.amount * PoolInfo[poolId].accPointsPerShare / 1e18 + user1Info.rewardSettled - user1Info.rewardDebt;
        uint256 transferPointsFraction = transferPoints / transferFraction;

        vm.stopPrank();
        vm.startPrank(userAdmin);

        // If transferFraction is 1, transfer all points by using type(uint256).max
        if (transferFraction == 1) {
            sophonFarming.transferPoints(poolId, account1, account2, type(uint256).max);
        } else {
            sophonFarming.transferPoints(poolId, account1, account2, transferPointsFraction);
        }

        SophonFarmingState.UserInfo memory user2Info;
        (user2Info.amount, user2Info.boostAmount, user2Info.depositAmount, user2Info.rewardSettled, user2Info.rewardDebt) =
            sophonFarming.userInfo(poolId, account2);

        assertEq(user2Info.amount, 0);
        assertEq(user2Info.boostAmount, 0);
        assertEq(user2Info.depositAmount, 0);
        assertEq(user2Info.rewardSettled, transferPointsFraction);
        assertEq(user2Info.rewardDebt, 0);

        SophonFarmingState.UserInfo memory user1InfoFinal;
        (user1InfoFinal.amount, user1InfoFinal.boostAmount, user1InfoFinal.depositAmount, user1InfoFinal.rewardSettled, user1InfoFinal.rewardDebt) =
            sophonFarming.userInfo(poolId, account1);

        assertEq(user1InfoFinal.amount, user1Info.amount);
        assertEq(user1InfoFinal.boostAmount, user1Info.boostAmount);
        assertEq(user1InfoFinal.depositAmount, user1Info.depositAmount);
        assertEq(user1InfoFinal.rewardSettled, transferPoints - transferPointsFraction);
        assertEq(user1InfoFinal.rewardDebt, user1Info.rewardDebt);
    }

    function testFuzz_TransferPoints_ReceiverWithDeposit(uint256 amountToDeposit, uint256 rollBlocks, uint256 transferFraction) public {
        amountToDeposit = bound(amountToDeposit, 1e6, 1_000_000_000e18);
        rollBlocks = bound(rollBlocks, 1, 100);
        transferFraction = bound(transferFraction, 1, 10);

        vm.startPrank(deployer);

        // whitelist user
        address[] memory accounts = new address[](1);
        accounts[0] = account1;
        sophonFarming.setUsersWhitelisted(userAdmin, accounts, true);
        assertEq(sophonFarming.whitelist(userAdmin, account1), true);

        vm.stopPrank();
        vm.startPrank(account1);

        uint256 poolId = sophonFarming.typeToId(SophonFarmingState.PredefinedPool.wstETH);

        deal(address(wstETH), account1, amountToDeposit * 2);
        wstETH.approve(address(sophonFarming), amountToDeposit * 2);
        sophonFarming.deposit(poolId, amountToDeposit, 0);

        vm.stopPrank();
        vm.startPrank(account2);

        deal(address(wstETH), account2, amountToDeposit);
        wstETH.approve(address(sophonFarming), amountToDeposit);
        sophonFarming.deposit(poolId, amountToDeposit, 0);

        vm.stopPrank();
        vm.startPrank(account1);

        vm.roll(block.number + rollBlocks);

        sophonFarming.deposit(poolId, amountToDeposit, 0);
        assertEq(wstETH.balanceOf(account1), 0);

        SophonFarmingState.UserInfo memory user1Info;
        (user1Info.amount, user1Info.boostAmount, user1Info.depositAmount, user1Info.rewardSettled, user1Info.rewardDebt) =
            sophonFarming.userInfo(poolId, account1);

        SophonFarmingState.PoolInfo[] memory PoolInfo;

        PoolInfo = sophonFarming.getPoolInfo();

        uint256 transferPoints = user1Info.amount * PoolInfo[poolId].accPointsPerShare / 1e18 + user1Info.rewardSettled - user1Info.rewardDebt;
        uint256 transferPointsFraction = transferPoints / transferFraction;

        SophonFarmingState.UserInfo memory user2Info;
        (user2Info.amount, user2Info.boostAmount, user2Info.depositAmount, user2Info.rewardSettled, user2Info.rewardDebt) =
            sophonFarming.userInfo(poolId, account2);

        vm.stopPrank();
        vm.startPrank(userAdmin);

        // If transferFraction is 1, transfer all points by using type(uint256).max
        if (transferFraction == 1) {
            sophonFarming.transferPoints(poolId, account1, account2, type(uint256).max);
        } else {
            sophonFarming.transferPoints(poolId, account1, account2, transferPointsFraction);
        }

        SophonFarmingState.UserInfo memory user2InfoFinal;
        (user2InfoFinal.amount, user2InfoFinal.boostAmount, user2InfoFinal.depositAmount, user2InfoFinal.rewardSettled, user2InfoFinal.rewardDebt) =
            sophonFarming.userInfo(poolId, account2);

        assertEq(user2InfoFinal.amount, amountToDeposit);
        assertEq(user2InfoFinal.boostAmount, 0);
        assertEq(user2InfoFinal.depositAmount, amountToDeposit);
        assertEq(user2InfoFinal.rewardSettled, user2Info.amount * PoolInfo[poolId].accPointsPerShare / 1e18 + user2Info.rewardSettled - user2Info.rewardDebt + transferPointsFraction); 
        assertEq(user2InfoFinal.rewardDebt, user2Info.amount * PoolInfo[poolId].accPointsPerShare / 1e18);

        SophonFarmingState.UserInfo memory user1InfoFinal;
        (user1InfoFinal.amount, user1InfoFinal.boostAmount, user1InfoFinal.depositAmount, user1InfoFinal.rewardSettled, user1InfoFinal.rewardDebt) =
            sophonFarming.userInfo(poolId, account1);

        assertEq(user1InfoFinal.amount, user1Info.amount);
        assertEq(user1InfoFinal.boostAmount, user1Info.boostAmount);
        assertEq(user1InfoFinal.depositAmount, user1Info.depositAmount);
        assertEq(user1InfoFinal.rewardSettled, transferPoints - transferPointsFraction);
        assertEq(user1InfoFinal.rewardDebt, user1Info.rewardDebt);
    }

    function test_TransferPoints_RevertWhen_TransferNotAllowed() public {
        vm.startPrank(account1);

        uint256 poolId = sophonFarming.typeToId(SophonFarmingState.PredefinedPool.wstETH);

        vm.expectRevert(abi.encodeWithSelector(SophonFarming.TransferNotAllowed.selector));
        sophonFarming.transferPoints(poolId, account1, account2, 1);
    }

    function test_TransferPoints_RevertWhen_InvalidTransfer() public {
        vm.startPrank(deployer);

        // whitelist user
        address[] memory accounts = new address[](1);
        accounts[0] = account1;
        sophonFarming.setUsersWhitelisted(userAdmin, accounts, true);
        assertEq(sophonFarming.whitelist(userAdmin, account1), true);

        vm.stopPrank();
        vm.startPrank(userAdmin);

        uint256 poolId = sophonFarming.typeToId(SophonFarmingState.PredefinedPool.wstETH);

        vm.expectRevert(abi.encodeWithSelector(SophonFarming.InvalidTransfer.selector));
        sophonFarming.transferPoints(poolId, account1, account1, 1);

        vm.expectRevert(abi.encodeWithSelector(SophonFarming.InvalidTransfer.selector));
        sophonFarming.transferPoints(poolId, account1, address(sophonFarming), 1);

        vm.expectRevert(abi.encodeWithSelector(SophonFarming.InvalidTransfer.selector));
        sophonFarming.transferPoints(poolId, account1, account2, 0);
    }

    function testFuzz_TransferPoints_TransferTooHigh(uint256 amountToDeposit, uint256 rollBlocks) public {
        amountToDeposit = bound(amountToDeposit, 1e6, 1_000_000_000e18);
        rollBlocks = bound(rollBlocks, 1, 100);

        vm.startPrank(deployer);

        // whitelist user
        address[] memory accounts = new address[](1);
        accounts[0] = account1;
        sophonFarming.setUsersWhitelisted(userAdmin, accounts, true);
        assertEq(sophonFarming.whitelist(userAdmin, account1), true);

        vm.stopPrank();
        vm.startPrank(account1);

        uint256 poolId = sophonFarming.typeToId(SophonFarmingState.PredefinedPool.wstETH);

        deal(address(wstETH), account1, amountToDeposit * 2);
        wstETH.approve(address(sophonFarming), amountToDeposit * 2);
        sophonFarming.deposit(poolId, amountToDeposit, 0);

        vm.roll(block.number + rollBlocks);

        sophonFarming.deposit(poolId, amountToDeposit, 0);
        assertEq(wstETH.balanceOf(account1), 0);

        SophonFarmingState.UserInfo memory user1Info;
        (user1Info.amount, user1Info.boostAmount, user1Info.depositAmount, user1Info.rewardSettled, user1Info.rewardDebt) =
            sophonFarming.userInfo(poolId, account1);

        SophonFarmingState.PoolInfo[] memory PoolInfo;

        PoolInfo = sophonFarming.getPoolInfo();

        uint256 transferPoints = user1Info.amount * PoolInfo[poolId].accPointsPerShare / 1e18 + user1Info.rewardSettled - user1Info.rewardDebt;

        vm.stopPrank();
        vm.startPrank(userAdmin);
        vm.expectRevert(abi.encodeWithSelector(SophonFarming.TransferTooHigh.selector, transferPoints));
        sophonFarming.transferPoints(poolId, account1, account2, type(uint256).max - 1);
    }

    // INCREASE_BOOST FUNCTION /////////////////////////////////////////////////////////////////
    function test_IncreaseBoost_RevertWhen_FarmingIsEnded() public {
        vm.prank(deployer);
        sophonFarming.setEndBlock(block.number + 9, 1);
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
        amountToDeposit = bound(amountToDeposit, 1e6, 1e27);

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
    function testFuzz_GetMaxAdditionalBoost(uint256 amountToDeposit) public {
        amountToDeposit = bound(amountToDeposit, 1e6, 1e27);

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

    // BRIDGE_PROCEEDS FUNCTION /////////////////////////////////////////////////////////////////
    // NOTE: function not fully implemented, an upgrade will implement this later
    function test_BridgeProceeds_RevertWhen_Unauthorized() public {
        vm.startPrank(deployer);

        uint256 poolId = sophonFarming.typeToId(SophonFarmingState.PredefinedPool.wstETH);

        // vm.expectRevert(Unauthorized.selector);
        // sophonFarming.bridgeProceeds(poolId, 0, 0);
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
            uint256 totalRewards,
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
        assertEq(PoolInfo.totalRewards, totalRewards);
        assertEq(abi.encode(PoolInfo.description), abi.encode(description));
    }

    // MULTIPLE DEPOSITS AND POINT DISTRIBUTION /////////////////////////////////////////////////////////////////
    function testFuzz_MultipleDeposits(uint256 rollBlocks) public {
        rollBlocks = bound(rollBlocks, 1, 1e18);
        setOneDepositorPerPool();
        SophonFarmingState.UserInfo[][] memory userInfos =
            new SophonFarmingState.UserInfo[][](sophonFarming.getPoolInfo().length);

        address[] memory accounts = new address[](3);
        accounts[0] = account1;
        accounts[1] = account2;
        accounts[2] = account3;

        uint256 poolsLength = sophonFarming.poolLength();

        vm.roll(block.number + rollBlocks);

        uint256[][] memory pendingPoints = new uint256[][](poolsLength);
        pendingPoints = sophonFarming.getPendingPoints(accounts);

        uint256[4][][] memory optimizedUserInfos = new uint256[4][][](2);
        optimizedUserInfos = sophonFarming.getOptimizedUserInfo(accounts);

        uint256 totalPoints;
        for (uint256 i = 0; i < accounts.length; i++) {
            for (uint256 j = 0; j < poolsLength; j++) {
                SophonFarmingState.UserInfo memory userInfo = getUserInfo(j, accounts[i]);

                totalPoints += pendingPoints[i][j];
                // console.log("pendingPoints[i][j]", pendingPoints[i][j]);

                assertEq(userInfo.amount, optimizedUserInfos[i][j][0]);
                assertEq(userInfo.boostAmount, optimizedUserInfos[i][j][1]);
                assertEq(userInfo.depositAmount, optimizedUserInfos[i][j][2]);
                assertEq(pendingPoints[i][j], optimizedUserInfos[i][j][3]);
                assertEq(pendingPoints[i][j], sophonFarming.pendingPoints(j, accounts[i]));
            }
        }

        // precision loss related to deposited amount and blocks elapsed
        uint256 delta =  rollBlocks * 100e18 * 3 / 1e16;
        assertApproxEqAbs(totalPoints, pointsPerBlock * rollBlocks, delta);
    }

    // POOL_START_BLOCK /////////////////////////////////////////////////////////////////
    function testFuzz_PoolStartBlock_Inactive(uint256 amountToDeposit, uint256 poolStartBlock, uint256 accruedBlocks) public {
        amountToDeposit = bound(amountToDeposit, 1e6, 1e27);
        poolStartBlock = bound(poolStartBlock, 10, 5e6);
        accruedBlocks = bound(accruedBlocks, 1, 5e6);

        vm.startPrank(deployer);

        SophonFarmingState.PoolInfo[] memory PoolInfo;
        PoolInfo = sophonFarming.getPoolInfo();

        uint256 wsthDepositedAmount = amountToDeposit;
        uint256 poolId = sophonFarming.typeToId(SophonFarmingState.PredefinedPool.wstETH);

        // Set block number lower than poolStartBlock to be able to update it
        vm.roll(0);
        sophonFarming.set(poolId, PoolInfo[poolId].allocPoint, poolStartBlock, 0);
        PoolInfo = sophonFarming.getPoolInfo();
        assertEq(PoolInfo[poolId].lastRewardBlock, poolStartBlock);
        vm.roll(1);

        vm.stopPrank();
        vm.startPrank(account1);
        deal(address(wstETH), account1, amountToDeposit * 2);

        wstETH.approve(address(sophonFarming), amountToDeposit * 2);
        sophonFarming.deposit(poolId, amountToDeposit, 0);

        vm.roll(poolStartBlock + accruedBlocks);

        uint256 pendingPoints = sophonFarming.pendingPoints(poolId, account1);

        sophonFarming.deposit(poolId, amountToDeposit, 0);
        PoolInfo = sophonFarming.getPoolInfo();

        SophonFarmingState.UserInfo memory userInfo;
        (userInfo.amount, userInfo.boostAmount, userInfo.depositAmount, userInfo.rewardSettled, userInfo.rewardDebt) =
            sophonFarming.userInfo(poolId, account1);

        uint256 pointReward = (accruedBlocks * 1e18) * sophonFarming.pointsPerBlock() * PoolInfo[poolId].allocPoint / sophonFarming.totalAllocPoint();
        uint256 accPointsPerShare = pointReward * 1e18 / (amountToDeposit);

        // precision loss related to deposited amount and blocks elapsed
        uint256 delta =  1 + accruedBlocks * amountToDeposit / 1e18;
        assertApproxEqAbs(pendingPoints, amountToDeposit * accPointsPerShare / 1e36, delta);
        assertGt(pendingPoints, 0);
        assertApproxEqAbs(pendingPoints, userInfo.rewardDebt - userInfo.rewardSettled, delta);
    }
}
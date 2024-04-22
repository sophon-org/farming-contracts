// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {SophonFarming} from "../contracts/farm/SophonFarming.sol";
import {SophonFarmingState} from "./../contracts/farm/SophonFarmingState.sol";
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
    address internal account1 = address(0x1);
    address internal account2 = address(0x2);

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
    
    // Helper functions
    function StETHRate(uint256 amount) internal pure returns (uint256) {
        return amount / 1001 * 1000;
    }

    function WstETHRate(uint256 amount) internal pure returns (uint256) {
        return amount * 861193049850366619 / 1e18;
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
            [
                address(dai),
                address(sDAI),
                address(weth),
                address(stETH),
                address(wstETH),
                address(0x10),
                address(0x11),
                address(0x12),
                address(0x13),
                address(0x14),
                address(0x15),
                address(0x16),
                address(0x17)
            ]    
        ));

        // Deploy proxy
        sophonFarmingProxy = new SophonFarmingProxy(implementation);

        // Grant the implementation interface to the proxy
        sophonFarming = SophonFarming(payable(address(implementation)));

        // Initialize SophonFarming
        sophonFarming.initialize(wstETHAllocPoint, sDAIAllocPoint, pointsPerBlock, startBlock, boosterMultiplier);

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

        sophonFarming.setEndBlocks(maxUint - 1000, maxUint);

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

    function test_ConstructorParameters() public {
        assertEq(sophonFarming.weth(), address(weth));
        assertEq(sophonFarming.stETH(), address(stETH));
        assertEq(sophonFarming.wstETH(), address(wstETH));
        assertEq(sophonFarming.dai(), address(dai));
        assertEq(sophonFarming.sDAI(), address(sDAI));
    }

    // INITIALIZE FUNCTION /////////////////////////////////////////////////////////////////
    function test_Initialize() public {
        (,,,,, uint256 _wstAllocPoint,,,) = sophonFarming.poolInfo(0);
        assertEq(_wstAllocPoint, wstETHAllocPoint);

        (,,,,, uint256 _sDAIAllocPoint,,,) = sophonFarming.poolInfo(1);
        assertEq(_sDAIAllocPoint, sDAIAllocPoint);

        assertEq(sophonFarming.startBlock(), startBlock);
        assertEq(sophonFarming.pointsPerBlock(), pointsPerBlock);
        assertEq(sophonFarming.boosterMultiplier(), boosterMultiplier);

        assertEq(sophonFarming.poolExists(address(weth)), true);
        assertEq(sophonFarming.poolExists(address(stETH)), true);
        assertEq(sophonFarming.poolExists(address(dai)), true);

        assertEq(stETH.allowance(address(sophonFarming), address(wstETH)), maxUint);
        assertEq(dai.allowance(address(sophonFarming), address(sDAI)), maxUint);
    }

    function test_RevertWhen_Initialize_AlreadyInitialized() public {
        vm.startPrank(deployer);

        vm.expectRevert(SophonFarming.AlreadyInitialized.selector);
        sophonFarming.initialize(0, 0, 0, 0, 0);
    }

    function test_RevertWhen_Initialize_InvalidStartBlock() public {
        vm.startPrank(deployer);

        address _implementation = address(new SophonFarming(
            [
                address(dai),
                address(sDAI),
                address(weth),
                address(stETH),
                address(wstETH),
                address(0x10),
                address(0x11),
                address(0x12),
                address(0x13),
                address(0x14),
                address(0x15),
                address(0x16),
                address(0x17)
            ]    
        ));

        // Deploy proxy
        SophonFarmingProxy _sophonFarmingProxy = new SophonFarmingProxy(_implementation);

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

    function test_RevertWhen_Add_FarmingIsEnded() public {
        vm.startPrank(deployer);

        sophonFarming.setEndBlocks(block.number + 1, 1);
        vm.roll(block.number + 2);

        MockERC20 mock = new MockERC20("Mock", "M", 18);
        uint256 startingAllocPoint = sophonFarming.totalAllocPoint();

        vm.expectRevert(SophonFarming.FarmingIsEnded.selector);
        sophonFarming.add(10000, address(mock), "Mock", true);
    }

    // SET FUNCTION /////////////////////////////////////////////////////////////////
    function testFuzz_Set(uint256 newAllocPoints) public {
        vm.assume(newAllocPoints > 0 && newAllocPoints <= 100000);
        vm.startPrank(deployer);

        uint256 poolId = sophonFarming.typeToId(SophonFarmingState.PredefinedPool.sDAI);
        uint256 startingTotalAllocPoint = sophonFarming.totalAllocPoint();
        (,,,,,uint256 startingAllocPoint,,,) = sophonFarming.poolInfo(poolId);
        sophonFarming.set(poolId, newAllocPoints, true);

        // SophonFarmingState.PoolInfo memory PoolInfo;

        (,,,,, uint256 allocPoint,,,) = sophonFarming.poolInfo(poolId);
        
        assertEq(allocPoint, newAllocPoints);
        assertEq(sophonFarming.totalAllocPoint(), startingTotalAllocPoint - startingAllocPoint + newAllocPoints);
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
    }

    function test_SetEndBlock_RevertWhen_InvalidEndBlock() public {
        vm.startPrank(deployer);

        vm.expectRevert(SophonFarming.InvalidEndBlock.selector);
        sophonFarming.setEndBlocks(block.number - 1, 1);

        sophonFarming.setStartBlock(block.number + 9);
        vm.expectRevert(SophonFarming.InvalidEndBlock.selector);
        sophonFarming.setEndBlocks(block.number + 8, 1);
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
        (
            userInfo.amount,
            userInfo.boostAmount,
            userInfo.depositAmount,
            userInfo.rewardSettled,
            userInfo.rewardDebt
        ) = sophonFarming.userInfo(poolId, account1);

        assertEq(userInfo.amount, wsthDepositedAmount);
        assertEq(userInfo.boostAmount, 0);
        assertEq(userInfo.depositAmount, wsthDepositedAmount);
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
        (
            userInfo.amount,
            userInfo.boostAmount,
            userInfo.depositAmount,
            userInfo.rewardSettled,
            userInfo.rewardDebt
        ) = sophonFarming.userInfo(poolId, account1);

        assertEq(userInfo.amount, wsthDepositedAmount + finalBoostAmount);
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

        uint256 wsthDepositedAmount = WstETHRate(StETHRate(amountToDeposit));
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

        uint256 wsthDepositedAmount = WstETHRate(StETHRate(amountToDeposit));
        uint256 amountToBoost = amountToDeposit / boostFraction;

        vm.expectRevert(SophonFarming.FarmingIsEnded.selector);
        sophonFarming.depositEth{value: amountToDeposit}(amountToBoost, SophonFarmingState.PredefinedPool.wstETH);
    }

    function testFuzz_DepositEth_RevertWhen_InvalidDeposit(uint256 amountToDeposit, uint256 boostFraction) public {
        vm.assume(amountToDeposit > 0 && amountToDeposit < 1001);
        vm.assume(boostFraction > 0 && boostFraction <= 10);

        vm.deal(account1, amountToDeposit);
        vm.startPrank(account1);

        uint256 wsthDepositedAmount = WstETHRate(StETHRate(amountToDeposit));
        console.log(wsthDepositedAmount);
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

    // DEPOSIT_DAI FUNCTION /////////////////////////////////////////////////////////////////
    function testFuzz_Dai_NotBoostedDeposit(uint256 amountToDeposit) public {
        vm.assume(amountToDeposit > 1e6 && amountToDeposit <= 1_000_000_000e18);

        deal(address(dai), account1, amountToDeposit);
        assertEq(dai.balanceOf(account1), amountToDeposit);

        uint256 poolId = sophonFarming.typeToId(SophonFarmingState.PredefinedPool.sDAI);

        vm.startPrank(account1);
        dai.approve(address(sophonFarming), amountToDeposit);
        sophonFarming.depositDai(amountToDeposit, 0);
        assertEq(dai.balanceOf(account1), 0);

        SophonFarmingState.UserInfo memory userInfo;
        (
            userInfo.amount,
            userInfo.boostAmount,
            userInfo.depositAmount,
            userInfo.rewardSettled,
            userInfo.rewardDebt
        ) = sophonFarming.userInfo(poolId, account1);

        assertEq(userInfo.amount, sDAI.convertToShares(amountToDeposit));
        assertEq(userInfo.boostAmount, 0);
        assertEq(userInfo.depositAmount, sDAI.convertToShares(amountToDeposit));
        assertEq(userInfo.rewardSettled, 0);
        assertEq(userInfo.rewardDebt, 0);
    }

    function testFuzz_Dai_NotBoostedWithdraw(uint256 amountToDeposit) public {
        vm.assume(amountToDeposit > 1e6 && amountToDeposit <= 1_000_000_000e18);

        deal(address(dai), account1, amountToDeposit);
        assertEq(dai.balanceOf(account1), amountToDeposit);

        uint256 poolId = sophonFarming.typeToId(SophonFarmingState.PredefinedPool.sDAI);

        vm.startPrank(account1);
        dai.approve(address(sophonFarming), amountToDeposit);
        sophonFarming.depositDai(amountToDeposit, 0);
        assertEq(dai.balanceOf(account1), 0);
        vm.stopPrank();

        SophonFarmingState.UserInfo memory userInfo;
        (
            userInfo.amount,
            userInfo.boostAmount,
            userInfo.depositAmount,
            userInfo.rewardSettled,
            userInfo.rewardDebt
        ) = sophonFarming.userInfo(poolId, account1);
        
        vm.prank(deployer);
        sophonFarming.setEndBlocks(block.number + 10, 1);
        vm.roll(block.number + 11);

        vm.startPrank(account1);
        sophonFarming.exit(sophonFarming.typeToId(SophonFarmingState.PredefinedPool.sDAI));

        SophonFarmingState.UserInfo memory finalUserInfo;
        (
            finalUserInfo.amount,
            finalUserInfo.boostAmount,
            finalUserInfo.depositAmount,
            finalUserInfo.rewardSettled,
            finalUserInfo.rewardDebt
        ) = sophonFarming.userInfo(poolId, account1);

        (
            ,,,,,,,uint256 accPointsPerShare,
        ) = sophonFarming.poolInfo(poolId);

        assertEq(finalUserInfo.amount, 0);
        assertEq(finalUserInfo.boostAmount, 0);
        assertEq(finalUserInfo.depositAmount, 0);
        assertEq(finalUserInfo.rewardSettled, (userInfo.amount * accPointsPerShare / 1e12 + userInfo.rewardSettled - userInfo.rewardDebt) / 2);
        assertEq(finalUserInfo.rewardDebt, 0);
    }

    function testFuzz_Dai_BoostedDeposit(uint256 amountToDeposit, uint256 boostFraction) public {
        vm.assume(amountToDeposit > 1e6 && amountToDeposit <= 1_000_000_000e18);
        vm.assume(boostFraction > 0 && boostFraction < 5);

        deal(address(dai), account1, amountToDeposit);
        assertEq(dai.balanceOf(account1), amountToDeposit);

        uint256 amountToDepositBoost = amountToDeposit / boostFraction;
        uint256 finalAmountToDepositBoost = amountToDepositBoost * sDAI.convertToShares(amountToDeposit) / amountToDeposit;
        uint256 poolId = sophonFarming.typeToId(SophonFarmingState.PredefinedPool.sDAI);

        vm.startPrank(account1);
        dai.approve(address(sophonFarming), amountToDeposit);
        sophonFarming.depositDai(amountToDeposit, amountToDepositBoost);
        assertEq(dai.balanceOf(account1), 0);

        SophonFarmingState.UserInfo memory userInfo;
        (
            userInfo.amount,
            userInfo.boostAmount,
            userInfo.depositAmount,
            userInfo.rewardSettled,
            userInfo.rewardDebt
        ) = sophonFarming.userInfo(poolId, account1);
        
        assertEq(userInfo.amount, sDAI.convertToShares(amountToDeposit) + finalAmountToDepositBoost * sophonFarming.boosterMultiplier() / 1e18);
        assertEq(userInfo.boostAmount, finalAmountToDepositBoost * sophonFarming.boosterMultiplier() / 1e18);
        assertEq(userInfo.depositAmount, sDAI.convertToShares(amountToDeposit) - finalAmountToDepositBoost);
        assertEq(userInfo.rewardSettled, 0);
        assertEq(userInfo.rewardDebt, 0);
    }

    function testFuzz_Dai_BoostedWithdraw(uint256 amountToDeposit, uint256 boostFraction) public {
        vm.assume(amountToDeposit > 1e6 && amountToDeposit <= 1_000_000_000e18);
        vm.assume(boostFraction > 0 && boostFraction < 5);
        boostFraction = 1;

        deal(address(dai), account1, amountToDeposit);
        assertEq(dai.balanceOf(account1), amountToDeposit);

        uint256 amountToDepositBoost = amountToDeposit / boostFraction;
        uint256 finalAmountToDepositBoost = amountToDepositBoost * sDAI.convertToShares(amountToDeposit) / amountToDeposit;

        vm.startPrank(account1);
        dai.approve(address(sophonFarming), amountToDeposit);
        sophonFarming.depositDai(amountToDeposit, amountToDepositBoost);
        assertEq(dai.balanceOf(account1), 0);

        uint256 poolId = sophonFarming.typeToId(SophonFarmingState.PredefinedPool.sDAI);

        vm.stopPrank();

        SophonFarmingState.UserInfo memory userInfo;
        (
            userInfo.amount,
            userInfo.boostAmount,
            userInfo.depositAmount,
            userInfo.rewardSettled,
            userInfo.rewardDebt
        ) = sophonFarming.userInfo(poolId, account1);
        
        vm.prank(deployer);
        sophonFarming.setEndBlocks(block.number + 10, 1);
        vm.roll(block.number + 11);

        vm.startPrank(account1);
        sophonFarming.exit(sophonFarming.typeToId(SophonFarmingState.PredefinedPool.sDAI));

        SophonFarmingState.UserInfo memory finalUserInfo;
        (
            finalUserInfo.amount,
            finalUserInfo.boostAmount,
            finalUserInfo.depositAmount,
            finalUserInfo.rewardSettled,
            finalUserInfo.rewardDebt
        ) = sophonFarming.userInfo(poolId, account1);

        (
            ,,,,,,,uint256 accPointsPerShare,
        ) = sophonFarming.poolInfo(poolId);

        assertEq(finalUserInfo.amount, 0);
        assertEq(finalUserInfo.boostAmount, 0);
        assertEq(finalUserInfo.depositAmount, 0);
        assertEq(finalUserInfo.rewardSettled, (userInfo.amount * accPointsPerShare / 1e12 + userInfo.rewardSettled - userInfo.rewardDebt) / 2);
        assertEq(finalUserInfo.rewardDebt, 0);

        console.log(sophonFarming.typeToId(SophonFarmingState.PredefinedPool.sDAI));
    }
}

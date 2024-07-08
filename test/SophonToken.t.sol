// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {StdInvariant} from "./../lib/forge-std/src/StdInvariant.sol";
import {SophonToken, TokenIsReceiver} from "../contracts/token/SophonToken.sol";
import {MockERC20} from "./../contracts/mocks/MockERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

contract SophonTokenTest is StdInvariant, Test {
    address internal deployer = address(0x1);
    address internal user;
    uint internal constant USER_PRIVATE_KEY = 0x0000000000000000000000000000000000000000000000000000000000000001;
    address internal spender = address(0x2);

    bytes32 private constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    SophonToken public sophonToken;
    MockERC20 internal mockToken;

    // Permit helper function
    function _getPermitTypehash(
        address owner,
        address spender,
        uint value,
        uint nonce,
        uint deadline
    ) private view returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                "\x19\x01",
                sophonToken.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        PERMIT_TYPEHASH,
                        owner,
                        spender,
                        value,
                        nonce,
                        deadline
                    )
                )
            )
        );
    }

    function setUp() public {
        user = vm.addr(USER_PRIVATE_KEY);

        vm.deal(deployer, 1000000e18);
        vm.startPrank(deployer);
        
        sophonToken = new SophonToken();
        targetContract(address(sophonToken));
    }

    function test_TokenSetting() public {
        assertEq(sophonToken.name(), "Sophon");
        assertEq(sophonToken.symbol(), "SOPH");
        assertEq(sophonToken.totalSupply(), 10_000_000_000e18);
        assertEq(sophonToken.balanceOf(deployer), 10_000_000_000e18);
        assertEq(sophonToken.owner(), deployer);
    }

    function testFuzz_Rescue(uint256 amount) public {
        amount = bound(amount, 1, type(uint256).max);
        mockToken = new MockERC20("Mock", "M", 18);

        mockToken.mint(deployer, amount);
        assertEq(mockToken.balanceOf(address(sophonToken)), 0);
        assertEq(mockToken.balanceOf(deployer), amount);

        mockToken.transfer(address(sophonToken), amount);

        assertEq(mockToken.balanceOf(address(sophonToken)), amount);
        assertEq(mockToken.balanceOf(deployer), 0);

        sophonToken.rescue(IERC20(address(mockToken)));

        assertEq(mockToken.balanceOf(address(sophonToken)), 0);
        assertEq(mockToken.balanceOf(deployer), amount);
    }

    function testFuzz_Approval(uint256 amount) public {
        amount = bound(amount, 0, type(uint256).max);

        sophonToken.approve(spender, amount);
        assertEq(sophonToken.allowance(deployer, spender), amount);
    }

    function testFuzz_Transfer(uint256 amount) public {
        amount = bound(amount, 0, sophonToken.totalSupply());

        sophonToken.transfer(user, amount);
        assertEq(sophonToken.balanceOf(user), amount);
    }

    function testFuzz_Transfer_RevertWhen_TokenIsReceiver(uint256 amount) public {
        amount = bound(amount, 0, type(uint256).max);

        vm.expectRevert(TokenIsReceiver.selector);
        sophonToken.transfer(address(sophonToken), amount);
    }

    function testFuzz_Transfer_RevertWhen_ZeroAddressReceiver(uint256 amount) public {
        amount = bound(amount, 0, type(uint256).max);

        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        sophonToken.transfer(address(0), amount);
    }

    function testFuzz_TransferFrom(uint256 amount) public {
        amount = bound(amount, 0, sophonToken.totalSupply());

        sophonToken.approve(spender, amount);
        vm.stopPrank();
        vm.prank(spender);
        sophonToken.transferFrom(deployer, user, amount);

        assertEq(sophonToken.allowance(deployer, spender), 0);
        assertEq(sophonToken.balanceOf(user), amount);
    }

    function testFuzz_TransferFrom_RevertWhen_TokenIsReceiver(uint256 amount) public {
        amount = bound(amount, 0, type(uint256).max);

        sophonToken.approve(spender, amount);
        vm.stopPrank();
        vm.prank(spender);

        vm.expectRevert(TokenIsReceiver.selector);
        sophonToken.transferFrom(deployer, address(sophonToken), amount);
    }

    function testFuzz_TransferFrom_RevertWhen_ZeroAddressReceiver(uint256 amount) public {
        amount = bound(amount, 0, type(uint256).max);

        sophonToken.approve(spender, amount);
        vm.stopPrank();
        vm.prank(spender);
        
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        sophonToken.transferFrom(deployer, address(0), amount);
    }

    function testFuzz_Permit(uint256 amount) public {
        amount = bound(amount, 0, type(uint256).max);

        bytes32 permitHash = _getPermitTypehash(
            user,
            spender,
            amount,
            sophonToken.nonces(spender),
            block.timestamp
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(USER_PRIVATE_KEY, permitHash);

        sophonToken.permit(
            user,
            spender,
            amount,
            block.timestamp,
            v,
            r,
            s
        );

        assertEq(sophonToken.allowance(user, spender), amount);
    }

    // function invariant_ConstantSupply() public {
    //     assertEq(sophonToken.totalSupply(), 10_000_000_000e18);
    // }
}
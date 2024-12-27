// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.26;

import "./MockERC20.sol";
import "../farm/interfaces/IsDAI.sol";

contract MockSDAI is MockERC20, IsDAI {

    error TransferOutFailed();
    error Unsupported();

    MockERC20 public immutable dai;

    constructor(MockERC20 dai_) MockERC20("Mock Savings Dai", "MockSDAI", 18) {
        dai = dai_;
    }

    function deposit(uint256 assets, address receiver) external returns (uint256 shares) {
        dai.transferFrom(msg.sender, address(this), assets);

        uint256 mintAmount = convertToShares(assets);
        
        balanceOf[receiver] = add(balanceOf[receiver], mintAmount);
        totalSupply    = add(totalSupply, mintAmount);
        emit Transfer(address(0), receiver, mintAmount);

        return mintAmount;
    }

    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets) {
        if (owner != msg.sender) {
            uint256 allowed = allowance[owner][msg.sender];
            if (allowed != type(uint256).max) {
                require(allowed >= shares, "insufficient-allowance");

                unchecked {
                    allowance[owner][msg.sender] = allowed - shares;
                }
            }
        }

        balanceOf[owner] = sub(balanceOf[owner], shares);
        totalSupply    = sub(totalSupply, shares);
        emit Transfer(owner, address(0), shares);

        uint256 returnAmount = convertToAssets(shares);
        dai.transfer(receiver, returnAmount);

        return returnAmount;
    }

    function convertToShares(uint256 assets) public view returns (uint256) {
        return assets * 939726078517424243 / 1e18;
    }

    function convertToAssets(uint256 shares) public view returns (uint256) {
        return shares * 1064139883802807721 / 1e18;
    }

    function mint(address usr, uint wad) external override {
        revert Unsupported();
    }

    function burn(address usr, uint wad) external override {
        revert Unsupported();
    }
}

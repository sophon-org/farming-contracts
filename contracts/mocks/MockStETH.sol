// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import "./MockERC20.sol";
import "../farm/interfaces/IstETH.sol";

contract MockStETH is MockERC20, IstETH {

    error TransferOutFailed();
    error Unsupported();

    constructor() MockERC20("Mock Liquid staked Ether 2.0", "MockStETH", 18) {}

    function submit(address _referral) external payable returns (uint256) {
        _referral;
        
        uint256 mintAmount = msg.value / 1001 * 1000;
        
        balanceOf[msg.sender] = add(balanceOf[msg.sender], mintAmount);
        totalSupply    = add(totalSupply, mintAmount);
        emit Transfer(address(0), msg.sender, mintAmount);

        return mintAmount;
    }

    function exit(uint256 amount) external returns (uint256) {        

        balanceOf[msg.sender] = sub(balanceOf[msg.sender], amount);
        totalSupply    = sub(totalSupply, amount);
        emit Transfer(msg.sender, address(0), amount);

        uint256 returnAmount = amount * 1001 / 1000;
        (bool success,) = msg.sender.call{value: returnAmount}("");
        if (!success) {
            revert TransferOutFailed();
        }

        return returnAmount;
    }

    function mint(address usr, uint wad) external override {
        revert Unsupported();
    }
    function burn(address usr, uint wad) external override {
        revert Unsupported();
    }
}

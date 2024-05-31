// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import "./MockERC20.sol";
import "../farm/interfaces/IweETH.sol";

contract MockWeETH is MockERC20, IweETH {

    error TransferOutFailed();
    error Unsupported();

    MockERC20 public immutable eETH;

    constructor(MockERC20 eETH_) MockERC20("Mock Wrapped eETH", "MockWeETH", 18) {
        eETH = eETH_;
    }

    function wrap(uint256 _eETHAmount) external returns (uint256) {
        eETH.transferFrom(msg.sender, address(this), _eETHAmount);

        uint256 mintAmount = getWeETHByeETH(_eETHAmount);
        
        balanceOf[msg.sender] = add(balanceOf[msg.sender], mintAmount);
        totalSupply    = add(totalSupply, mintAmount);
        emit Transfer(address(0), msg.sender, mintAmount);

        return mintAmount;
    }

    function unwrap(uint256 _weETHAmount) external returns (uint256) {

        balanceOf[msg.sender] = sub(balanceOf[msg.sender], _weETHAmount);
        totalSupply    = sub(totalSupply, _weETHAmount);
        emit Transfer(msg.sender, address(0), _weETHAmount);

        uint256 returnAmount = geteETHByWeETH(_weETHAmount);
        eETH.transfer(msg.sender, returnAmount);

        return returnAmount;
    }

    function getWeETHByeETH(uint256 _eETHAmount) public view returns (uint256) {
        return _eETHAmount * tokensPereETH() / 1e18;
    }

    function geteETHByWeETH(uint256 _weETHAmount) public view returns (uint256) {
        return _weETHAmount * eETHPerToken() / 1e18;
    }

    function eETHPerToken() public view returns (uint256) {
        return 1161179830902898325;
    }
    
    function tokensPereETH() public view returns (uint256) {
        return 861193049850366619;
    }

    function mint(address usr, uint wad) external override {
        revert Unsupported();
    }

    function burn(address usr, uint wad) external override {
        revert Unsupported();
    }
}

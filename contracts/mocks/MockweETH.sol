// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import "./MockERC20.sol";
import "../farm/interfaces/IweETH.sol";

contract MockweETH is MockERC20, IweETH {

    error TransferOutFailed();
    error Unsupported();

    MockERC20 public immutable stEth;

    constructor(MockERC20 stETH_) MockERC20("Mock Wrapped liquid staked Ether 2.0", "MockWstETH", 18) {
        stEth = stETH_;
    }

    function wrap(uint256 _stETHAmount) external returns (uint256) {        
        stEth.transferFrom(msg.sender, address(this), _stETHAmount);

        uint256 mintAmount = getWstETHByStETH(_stETHAmount);
        
        balanceOf[msg.sender] = add(balanceOf[msg.sender], mintAmount);
        totalSupply    = add(totalSupply, mintAmount);
        emit Transfer(address(0), msg.sender, mintAmount);

        return mintAmount;
    }

    function unwrap(uint256 _wstETHAmount) external returns (uint256) {

        balanceOf[msg.sender] = sub(balanceOf[msg.sender], _wstETHAmount);
        totalSupply    = sub(totalSupply, _wstETHAmount);
        emit Transfer(msg.sender, address(0), _wstETHAmount);

        uint256 returnAmount = getStETHByWstETH(_wstETHAmount);
        stEth.transfer(msg.sender, returnAmount);

        return returnAmount;
    }

    function getWstETHByStETH(uint256 _stETHAmount) public view returns (uint256) {
        return _stETHAmount * tokensPerStEth() / 1e18;
    }

    function getStETHByWstETH(uint256 _wstETHAmount) public view returns (uint256) {
        return _wstETHAmount * stEthPerToken() / 1e18;
    }

    function stEthPerToken() public view returns (uint256) {
        return 1161179830902898325;
    }
    
    function tokensPerStEth() public view returns (uint256) {
        return 861193049850366619;
    }

    function mint(address usr, uint wad) external override {
        revert Unsupported();
    }

    function burn(address usr, uint wad) external override {
        revert Unsupported();
    }
}

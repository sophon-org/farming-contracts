// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import "./MockERC20.sol";
import "../farm/interfaces/IeETHLiquidityPool.sol";

contract MockeETHLiquidityPool is IeETHLiquidityPool {

    error TransferOutFailed();
    error Unsupported();

    MockERC20 public immutable eEth;

    constructor(MockERC20 eEth_) {
        eEth = eEth_;
    }

    function deposit(address _referral) external payable returns (uint256) {
        _referral;
        
        uint256 mintAmount = msg.value / 1001 * 1000;
        
        eEth.mint(msg.sender, mintAmount);

        return mintAmount;
    }

    function exit(uint256 amount) external returns (uint256) {        

        eEth.burn(msg.sender, amount);

        uint256 returnAmount = amount * 1001 / 1000;
        (bool success,) = msg.sender.call{value: returnAmount}("");
        if (!success) {
            revert TransferOutFailed();
        }

        return returnAmount;
    }

    function sharesForAmount(uint256 _amount) external view returns (uint256) {
        return _amount;
    }

    function amountForShare(uint256 _share) external view returns (uint256) {
        return _share;
    }
}

// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";

error TransferOutFailed();
error TokenIsReceiver();

contract SophonToken is ERC20Permit, Ownable2Step {

    string internal constant _name = "Sophon";
    string internal constant _symbol = "SOPH";
    uint256 internal constant _maxSupply = 10_000_000_000e18;

    constructor() ERC20Permit(_name) ERC20(_name, _symbol) Ownable(msg.sender) {
        _mint(msg.sender, _maxSupply);
    }

    function rescue(IERC20 token) external onlyOwner {
        SafeERC20.safeTransfer(token, msg.sender, token.balanceOf(address(this)));
    }

    function _update(address from, address to, uint256 value) internal override {
        if (to == address(this)) {
            revert TokenIsReceiver();
        }
        super._update(from, to, value);
    }
}

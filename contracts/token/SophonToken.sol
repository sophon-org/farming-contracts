// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";

error TokenIsReceiver();

contract SophonToken is ERC20Permit, Ownable2Step {

    constructor(address initialOwner, address mintReceiver) ERC20Permit(name()) ERC20(name(), symbol()) Ownable(initialOwner) {
        _mint(mintReceiver, totalSupply());
    }

    function name() public view override returns (string memory) {
        return "Sophon";
    }

    function symbol() public view override returns (string memory) {
        return "SOPH";
    }

    function totalSupply() public view override returns (uint256) {
        return 10_000_000_000e18;
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

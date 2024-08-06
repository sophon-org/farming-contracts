// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Wrapper.sol";

contract MockstAZUR is ERC20Wrapper{
    constructor(IERC20 underlyingToken, string memory name_, string memory symbol_) ERC20Wrapper(underlyingToken) ERC20(name_, symbol_){

    }
}

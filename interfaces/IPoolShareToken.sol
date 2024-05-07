// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

interface IPoolShareToken {
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);

    function transfer(address dst, uint wad) external returns (bool);
    function transferFrom(address src, address dst, uint wad) external returns (bool);
    function mint(address usr, uint wad) external;
    function burn(address usr, uint wad) external;
    function approve(address usr, uint wad) external returns (bool);
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
}

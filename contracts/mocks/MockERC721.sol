// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import "@erc721a/ERC721A.sol";
import "@erc721a/extensions/ERC721AQueryable.sol";
import "@erc721a/extensions/ERC4907A.sol";

contract MockERC721 is ERC721A, ERC721AQueryable, ERC4907A {
    // --- Auth ---
    mapping (address => uint) public wards;
    function rely(address guy) external auth { wards[guy] = 1; }
    function deny(address guy) external auth { wards[guy] = 0; }
    modifier auth {
        require(wards[msg.sender] == 1, "not-authorized");
        _;
    }

    constructor(string memory name, string memory symbol) ERC721A(name, symbol) {
        wards[msg.sender] = 1;
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721A, IERC721A, ERC4907A) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function mint(address receiver, uint256 quantity) external auth {
        _mint(receiver, quantity);
    }
}
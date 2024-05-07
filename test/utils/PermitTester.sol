// SPDX-License-Identifier: UNLICENSED

import {PoolShareToken} from "../../contracts/farm/PoolShareToken.sol";

pragma solidity 0.8.24;

contract PermitTester {
    
    function transferWithPermit(
        PoolShareToken token,
        address from,
        address to,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        token.permit(
            from,
            to,
            amount,
            deadline,
            v,
            r,
            s
        );

        token.allowance(from, to);

        token.transferFrom(from, to, amount);
    }

    // Util function to get permit typehash
    function getPermitTypehash(
        PoolShareToken token,
        address owner,
        address spender,
        uint value,
        uint nonce,
        uint deadline
    ) external view returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                "\x19\x01",
                token.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        token.PERMIT_TYPEHASH(),
                        owner,
                        spender,
                        value,
                        nonce,
                        deadline
                    )
                )
            )
        );
    }
}
pragma solidity >=0.5.0;

interface ISyncSwapRouterV2 {
    struct TokenInput {
        address token;
        uint amount;
        bool useVault;
    }

    function addLiquidity2(
        address pool,
        TokenInput[] calldata inputs,
        bytes calldata data,
        uint minLiquidity,
        address callback,
        bytes calldata callbackData,
        address staking
    ) external payable returns (uint liquidity);
}
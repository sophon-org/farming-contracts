# Bridging SF Funds from L1 to L2

This file describes the step-by-step process of bridging SF funds from L1 to L2:

1. `exec(open("./scripts/deployment/sepolia/farming-bridge/L1.py").read())`
2. `exec(open("./scripts/deployment/sepolia/farming-bridge/L2.py").read())`

### What it does:
1. **L1 Preparation for Migration**:
   1. Sets the bridge address
   2. Calls `remove_liquidity` for `BEAM_WETH_LP`
   3. Bridges every pool

2. **L2 Farming Setup**:
   1. `SF_L2.addPool` sets pool information on L2
   2. Sets Merkle Root on the MerkleTree contract
   3. Sets pools on the MerkleTree contract

---

# How to Generate Merkle Tree

Execute the following files:

1. `exec(open("./scripts/merkle-l2/1-collect-userinfo-poolinfo.py").read())`
2. `exec(open("./scripts/merkle-l2/2-calculate-user-ratios.py").read())`
3. `exec(open("./scripts/merkle-l2/3-update-user-info.py").read())`
4. `exec(open("./scripts/merkle-l2/4-safety-checks.py").read())`
5. `node scripts/merkle-l2/5-build-merkle-tree.js`

### What it does:
1. This job queries `gateway.thegraph.com/api/` and gathers all the `userInfo` and `poolInfo` balances of the SF contract. It doesn't modify anything, just gathering data. Produces output: `./scripts/merkle-l2/output/1-userinfo-poolinfo.json`.
   
2. This job calculates `BEAM_LP_RATIO_PER_USER`. It will also update `rewardSettled` and `rewardDebt` to simulate `SF.withdraw`. Produces output: `./scripts/merkle-l2/output/2-withratios-userinfo-poolinfo.json`.

3. This job adds BEAM and WSTETH balances to the relevant pools in `UserInfo` balances for specific users. It also simulates `SF.deposit` for the `rewardSettled` and `rewardDebt` variables. This job will update `PoolInfo` with the corresponding balances and verify the calculations. Produces output: `./scripts/merkle-l2/output/3-update-user-info.json`.

4. This job verifies `UserInfo` and `PoolInfo` balances. It checks several rules, with the most important being: `amount == boost_amount + deposit_amount`.

5. This job generates the Merkle Tree. Produces output: `./scripts/merkle-l2/output/5-proof.json`.

### Notes:
All jobs store old balance values in `OLD_*` fields in the JSON files.




### TODO:
1. done - SF_L1 work on `revertFailedBridge`
2. done - decided not to do it. SF_L1 zero out points for users
3. done - vSOPH join multiple stream
4. done - vSOPH transferTokens function 
5. done - MerkleTree _calculateReward points vs vSOPH
6. done - Pendle
7. TESTING on testnet with everybody
8. done - Use paymaster for deployment 
9.  done - Make an exception for Pendle
10. done - batch Merkle.claim()
11. ZERO out rewards on L2
12. create test cases for LinearVestingWithLock
13. create test cases for MerkleAirdrop
    
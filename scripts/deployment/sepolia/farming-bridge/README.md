Small readme on how to do the bridging + upgrade


Part 1
1) Deploy SF_L2 - we need an address.
      ```
      deployer = accounts.load("sophon_sepolia")
      MA = MerkleAirdrop.deploy({"from": deployer})
      SFImpl_L2 = SophonFarmingL2.deploy(MA, {'from': deployer})
      SFProxy_L2 = SophonFarmingProxy.deploy(SFImpl_L2, {"from": deployer})
      SF_L2 = interface.ISophonFarming(SFProxy_L2)
      ```
2) Upgrade SF_L1
      ```
      exec(open("./scripts/env/sepolia.py").read())
      deployer = accounts.load("sophon_sepolia")
      args = [
         SF.dai(),
         SF.sDAI(),
         SF.weth(),
         SF.stETH(),
         SF.wstETH(),
         SF.eETH(),
         SF.eETHLiquidityPool(),
         SF.weETH()
      ]

      SFImpl = SophonFarmingFork.deploy(args, 531050104, {'from': deployer}) # note its a fork for testing purphose
      SF.replaceImplementation(SFImpl, {'from': deployer})
      SFImpl.becomeImplementation(SF, {'from': deployer
      ```

3) Uddate SF_L1 settings set `setEndBlock` to end farming
4) Update SF_L1 settings set `setBridge` to set bridge address
   ```
      SF.setBridge(BRIDGEHUB, {"from": deployer})
   ```
5) For each poool
   1) call `SF_L1.setL2Farm`
      ```
      pool_length = SF.poolLength()
      for pid in range(pool_length):
         SF.setL2Farm(pid, SF_L2, {'from': deployer, "gas_price": Wei("20 gwei")})
         print(f"L2 Farm set for Pool ID: {pid}")

      ```
   2) call `SF_L1.bridgePool` 
      ```
      mintValue = 100e18 # SOPH transaction cost
      pool_length = SF.poolLength()
      SOPH.approve(SF, 2**256-1, {'from': deployer, "gas_price": Wei("20 gwei")})
      for pid in range(7, pool_length):
         if pid == 4: # skipping BEAM_
            print("Skipping PID 4")
            continue  # Skip PID 4
         if pid == 7: # custom bridge USDC
            SF.bridgeUSDC(mintValue, SOPH, BRIDGEHUB, {'from': deployer, "gas_price": Wei("20 gwei")})
            print(f"Bridged Pool ID: {pid} with Mint Value: {mintValue}")
            continue
         SF.bridgePool(pid, mintValue, SOPH, {'from': deployer, "gas_price": Wei("20 gwei")})
         print(f"Bridged Pool ID: {pid} with Mint Value: {mintValue}")

      ```

Part 2
1) collect user info
   ```
   exec(open("./scripts/merkle-l2/1-collect-userinfo-poolinfo.py").read())
   ```
2) verify user info
   ```
   exec(open("./scripts/merkle-l2/4-safety-checks.py").read())
   ```
3) generate proof
   ```
   node ./scripts/merkle-l2/5-build-merkle-tree.js
   ```

Part 3
1) Deploy MA = MerkleAirdop.sol
   ```
   exec(open("./scripts/env/sophon-testnet.py").read())
   deployer = accounts.load("sophon_sepolia")
   proxy = UUPSProxy.deploy(
         MAImpl.address,
         MAImpl.initialize.encode_input(SF_L2),
         {'from': deployer}
   )

   ```
2) call `SF_L2.setMerkleRoot`
   ```
   MA.setMerkleRoot(merkleRoot, {"from": deployer})
   ```
3) call `SF_L2.addPool` for each pool !!! order is important
   ```
      exec(open("./scripts/env/sophon-testnet.py").read())
      deployer = accounts.load("sophon_sepolia")
      import json
      lastRewardBlock = chain.height
      file_path = ('./scripts/merkle-l2/output/1-userinfo-poolinfo.json')
      with open(file_path, 'r', encoding='utf-8') as file:
         data = json.load(file)
         pools = data.get('pools', [])
         for pid, pool in enumerate(pools):
            print(pool)
            # _lastRewardBlock should be the block from which farming is starting. it the same time approximately as SF_L1.endBlock
            SF_L2.addPool(
               pid,
               pool["lpToken"],
               pool["l2Farm"],
               int(pool["amount"]),
               int(pool["boostAmount"]),
               int(pool["depositAmount"]),
               int(pool["allocPoint"]),
               int(pool["lastRewardBlock"]),
               int(pool["accPointsPerShare"]),
               int(pool["totalRewards"]),
               pool["description"],
               int(pool["heldProceeds"]),
               {"from": deployer}
            )

   ```

Part 4 - how to start farming on l2 setting points per block
   old value - 12 sec block
   ```
   SF.pointsPerBlock()
   71000000000000000000
   ```

   assuming 1 sec block have to multiply by 12 =  852000000000000000000

   ```
   SF_L2.setPointsPerBlock(852000000000000000000, {"from": deployer})
   ```
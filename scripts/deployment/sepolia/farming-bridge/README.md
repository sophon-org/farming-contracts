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
      farmingPools = [
         sDAI,
         wstETH,
         weETH,
         ZERO_ADDRESS,
         BEAM,
         ZERO_ADDRESS,
         USDC,
         stAETHIR,
         PEPE,
         WBTC,
         AZURO,
         USDT,
         AZURO,
         stAVAIL,
         ZERO_ADDRESS
      ]
      import json
      lastRewardBlock = chain.height
      file_path = ('./scripts/merkle-l2/output/1-userinfo-poolinfo.json')
      with open(file_path, 'r', encoding='utf-8') as file:
         data = json.load(file)
         pools = data.get('pools', [])
         for pid, pool in enumerate(pools):
            print(pool)
            # _lastRewardBlock should be the block from which farming is starting. 
            # it the same time approximately as SF_L1.endBlock
            SF_L2.addPool(
               pid,
               farmingPools[pid],
               pool["l2Farm"],
               int(pool["amount"]),
               int(pool["boostAmount"]),
               int(pool["depositAmount"]),
               int(pool["allocPoint"]),
               lastRewardBlock, # this will start farming right immediately.
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

   assuming 1 sec block have to divide by 10 =  7100000000000000000

   ```
   SF_L2.setPointsPerBlock(852000000000000000000, {"from": deployer})
   ```

   ```
   >>> SF.totalAllocPoint()
   770000
   ```


   Part 4- set price feeds

      
      0,    SDAIUSD: '0xf31e0ed7d2f9d8fe977679f2b18841571a064b9b072cf7daa755a526fe9579ec',
      1,    
      2,    WEETHUSD: '0x2778ff4ef448d972c023c579b2bff9c55d48d0fde830dcdd72fff8189c01993e',
      3,    BEAMUSD: '0x7a103d78776b2ff5b0221e26ca533850e59f16be7381ccc952ada02e73beeef7',
      4,    
      5,    ZENTUSD: '0x01754fec1fe1377161a2abd3ba6b7ccbdc47d66f7a4c169532cdf8c16d082255'
      6,    USDCUSD: '0x7416a56f222e196d0487dce8a1a8003936862e7a15092a91898d69fa8bce290c',
      7,    ATHUSD: '0x57744b683b8f4f907ef849039fc12760510242140bd5733e2fc9dc7557653f3e',
      8,    PEPEUSD: '0x7740d9942fd36998a87156e36a2aa45d138b7679933e21fb59e01a005092c04f',
      9,    WBTCUSD: '0x1ddeb20108df88bf27cc4a55fff8489a99c37ae2917ce13927c6cdadf4128503',
      10,   AZURUSD: '0xcd4bc8c9ccfd4a5f6d4369d06be0094ea723b8275ac7156dabfd5c6454aee625',
      11,   USDTUSD: '0x6dcd0a8fb0460d4f0f98c524e06c10c63377cd098b589c0b90314bfb55751558',
      12,   
      13,   
      14    

      
      
      
      
      
      
      
      
      
      
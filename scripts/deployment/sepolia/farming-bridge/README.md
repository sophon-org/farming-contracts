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
   TODO

Part 3
1) Deploy MA = MerkleAirdop.sol
2) call `SF_L2.setMerkleRoot`
3) 
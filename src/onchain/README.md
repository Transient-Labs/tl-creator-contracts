# OnChainArt Commands
## Deploying Contract
```
forge create src/custom/OnChainArtDeployed.sol:OnChainArtDeployed \
	--rpc-url <rpc_url> \
	--verify \
	-l \
	--constructor-args \
	<implementation> \
	<name> \
	<symbol> \
	<royalty recipient> \
	<royalty percentage in bips> \
	<initial owner> \
	<admins e.x. "[]" > \
	<story enabled bool> \
	<blocklist registry>
```

## Minting new Token
1. At the root folder in this repo, create a file named `metadata.txt` with the `base64` encoded metadata
2. In the root folder run `python chunk.py metadata.txt chunks.json` , this will produce a pre-chunked json file to be used to mint.
3. Run the following script to mint the onchain artwork.
```
forge script script/OnChainArt.s.sol \
	--rpc-url <rpc_url> \
	--broadcast \
	--ledger \
	--sender <minter address>
```

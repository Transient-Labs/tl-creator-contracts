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

0x2eeD2371f88ae36A717Cbfe67eeD5bab69c77679

forge create src/onchain/OnChainArt.sol:OnChainArt \
	--rpc-url $GOERLI_RPC_URL\
	--verify \
	-l \
	--constructor-args \
	0xe6de8cCFE609aef6de78DC6C9F409C6762f58EC5 \
	TestNFT \
	NFT \
	0x2eeD2371f88ae36A717Cbfe67eeD5bab69c77679 \
	1000 \
	0x2eeD2371f88ae36A717Cbfe67eeD5bab69c77679 \
	"[]" \
	true \
	0x0000000000000000000000000000000000000000

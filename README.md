# Transient Labs Creator Contracts
A repository for Transient Labs Creator Contracts

## Deployments
See `deployments.json` for latest deployments

## Core Features
### Ownership & Access
We have implemented an `OwnableAccessControlUpgradeable` that is similar to OpenZeppelin's Access Control contract, but with the Ownable interface added in. There is also a custom admin and mint contract privileges. Admins are able to perform actions on behalf of the creator (contract owner). Approved mint contracts are allowed to mint NFTs or add metadata (ERC7160TL).

### Creator Royalties
ERC-2981 is used as it is the on-chain royalty specification used to return a royalty payout address and the royalty amount to pay based on the sale price. 

For each contract, there is a default royalty specification set that can be altered if needed. There are also individual token overrides in case of collaboration or anything like that.

As of version 4.1.0, royalties are capped at 10%.

### Limit Break's Creator Token Standard
Version 4 introduced Limit Break's Creator Token Standard, which can be used to enforce royalties by blocking transfers from unapproved operators. If the transfer validator is set to the zero-address, it cannot be subsequently set to a value. The zero address specifies that the artist permanently accepts optional royalties.

### Story Inscriptions
The ability to add human provenance to the blockchain to fully tell the story behind a token. See more [here](https://github.com/Transient-Labs/tl-story-inscriptions)

### NFT Delegation Integration
There are NFT delegation protocols in use today, such as [delegate.xyz](https://delegate.xyz), and more coming. Our creator contrats (ERC-721 based) have the ability to integrate with a delegation registry that aggregates and checks against popular delegation protocols. Right now, that is just delegate.xyz, but can expand to include others as well. 

We only use NFT delegation for NFT ownership utility that does not affect ownership. So this means that NFT delegation is not used for transfers and approvals. It is used for features like
- story inscriptions
- multi-metadata pinning & unpinning

## Contract Types
### ERC721TL
Our core ERC-721 creator contract.

### ERC1155TL
Our core ERC-1155 creator contract.

### ERC7160TL
Our implementation of [ERC-7160](https://eips.ethereum.org/EIPS/eip-7160). This brings multiple pieces of metadata to NFTs and allows token holders to pin or unpin metadata as they please. Only the contract owner/admin have the ability to add metadata for a token.

### ERC7160TLEditions
An implementation of [ERC-7160](https://eips.ethereum.org/EIPS/eip-7160) but with a focus on editions. Rather than have multiple pieces of metadata per token, like in ERC7160TL, there is a contract-wide metadata array from which token holders can choose to pin. This allows for immense flexibility and gas efficiency for ERC-721 editions.

## Rendering Contracts
Rendering contracts (`src/rendering-contracts/`) externalize `tokenURI` logic. When a creator contract has a rendering contract set, its `tokenURI(tokenId)` delegates to the renderer's `tokenURI(tokenId)`. All renderers implement `IRenderingContract` and advertise it via ERC-165, so backends/indexers can detect them by reading `renderingContract()` on the NFT. Like the creator contracts, they are deployable directly or as immutable [ERC-1167](https://eips.ethereum.org/EIPS/eip-1167) clones — call `initialize(...)` after cloning.

### StandardRenderingContract
Maps a base uri to each token, returning `<baseUri>/<tokenId>`. The base uri is set once at `initialize` and is immutable thereafter.

### EditionRenderingContract
Returns a single shared uri for every token in the collection. The uri is set once at `initialize` and is immutable thereafter.

### GenArtRenderingContract
A renderer for generative art (ERC721TL only). `tokenURI` returns a stable `<baseUri>/<tokenId>` pointer while the mint entropy that drives the art is injected off-chain as URL query params (it is cheap to derive from mint-transaction data and is therefore not stored on-chain). It additionally supports a mutable `baseUri` (e.g. to repoint to a frozen `ipfs://<CID>` bundle after mint-out), per-token artist `ExtraParams`, curated per-token `Seed` overrides for collector-driven drops, a permanent on-chain archive of the generative script stored in event logs (`storeScriptChunk`, reassembled off-chain in ascending `chunkIndex` order), and a canonical `activeScriptVersion` pointer. It advertises `IGenArtRenderingContract` via ERC-165 so indexers can distinguish it from a standard/edition renderer. Mutators emit ERC-4906 metadata updates on the NFT so marketplaces refresh.

### Access & composability
Renderer state changes are gated by deferring to the served NFT: the caller must be the NFT's `owner()` or hold `ADMIN_ROLE` on it. The renderers keep no access list of their own, so additional systems compose by being granted `ADMIN_ROLE` on the NFT — for example an admin param-helper, or a collector-seed forwarder that verifies `ownerOf(tokenId)` before calling `setSeed`. Because `ADMIN_ROLE` is NFT-wide (full creator-admin power, not a rendering-scoped subset), only grant it to trusted contracts.

## Proxy Deployments
We use immutable [ERC-1167](https://eips.ethereum.org/EIPS/eip-1167) proxies for creators to deploy contracts in a cheap and immutable way. Non-upgradeable [ERC-1967](https://eips.ethereum.org/EIPS/eip-1967) proxies can also be used. These contracts are not meant to be upgraded as changes may not be upgrade friendly (i.e. storage layout may break between versions).

## Running Tests
1. Install [foundry](getfoundry.sh)
2. Run `make install` or `make update`
3. Run `make test-*`

## Building InitCode for the TL Universal Deployer
1. Navigate the the contract type you want to deploy
2. Look at the initialize function to see the function signature
3. Run `cast calldata "<function-signature-here>" <constructor-args-here>`

Example: `cast calldata "initialize(string,string,string,address,uint256,address,address[],bool,address)" "The Enchanted Hour" "RK" "" 0x77B35947d508012589a91CA4c9d168824376Cc7D 1000 0x77B35947d508012589a91CA4c9d168824376Cc7D "[]" true 0x77B35947d508012589a91CA4c9d168824376Cc7D`

See more about cast calldata [here](https://book.getfoundry.sh/reference/cast/cast-calldata).

## Disclaimer
This codebase is provided on an "as is" and "as available" basis.

We do not give any warranties and will not be liable for any loss incurred through any use of this codebase.

## License
This code is copyright Transient Labs, Inc 2026 and is licensed under the MIT license.

# Transient Labs Creator Contracts
A repository for Transient Labs Creator Contracts

## Deployments
See https://docs.transientlabs.xyz/tl-creator-contracts/implementation for latest deployments

## Core Features
### Ownership & Access
We have implemented the `OwnableAccessControlUpgradeable` contract from [tl-sol-tools](https://github.com/Transient-Labs/tl-sol-tools) and have created custom admin and mint contract priviledges. Admins are able to perform actions on behalf of the creator (contract owner). Approved mint contracts are allowed to mint NFTs or metadata (ERC7160TL).

### Creator Royalties
EIP-2981 is used as it is the on-chain royalty specification used to return a royalty payout address and the royalty amount to pay based on the sale price. 

For each contract, there is a default royalty specification set that can be altered if needed. There are also individual token overrides in case of collaboration or anything like that.

### BlockList
A feature that allows creators to block operators, such as marketplaces, from getting approved on the contract. `setApprovalForAll` and `approve` will fail for any blocked addresses.

### Story Inscriptions
The ability to add human provenance to the blockchain to fully tell the story behind a token. See more [here](https://github.com/Transient-Labs/tl-story-inscriptions)

### NFT Delegation Integration
There are NFT delegation protocols in use today, such as [delegate.xyz](https://delegate.xyz), and more coming. Our creator contrats (ERC-721 based) have the ability to integrate with a delegation registry that aggregates and checks against popular delegation protocols. Right now, that is just delegate.xyz, but can expand to include others as well. 

We only use NFT delegation for NFT ownership utility that does not affect ownership. So this means that NFT delegation is not used for transfers and approvals. It is used for features like
- story inscriptions
- multi-metadata pinning & unpinning
- Synergy metadata updates

## ERC721TL
Our core ERC-721 creator contract.

### Synergy
This mechanism protects collectors from having token metadata changed on them unexpectedly. Artists need to be able to update metadata in certain situations, but collectors should have a right to review these changes after they have bought the piece. This is what Synergy allows; the collector must sign a transaction allowing the metadata to be updated.

### Airdrops
Allows creators to airdrop tokens to a list of addresses.

### Batch Minting
Allows creators to cheaply batch mint tokens to their wallet. 

Testing shows our implementation is market leading: [view here](https://docs.transientlabs.xyz/creator-contracts/ERC721TL)

## ERC7160TL
Our implementation of [ERC-7160](https://eips.ethereum.org/EIPS/eip-7160). This brings multiple pieces of metadata to NFTs and allows token holders to pin or unpin metadata as they please. Only the contract owner/admin have the ability to add metadata for a token.

### Airdrops
Allows creators to airdrop tokens to a list of addresses.

### Batch Minting
Allows creators to cheaply batch mint tokens to their wallet. 

Testing shows our implementation is market leading: [view here](https://docs.transientlabs.xyz/creator-contracts/ERC721TL)

## ERC7160TLEditions
An implementation of [ERC-7160](https://eips.ethereum.org/EIPS/eip-7160) but with a focus on editions. Rather than have multiple pieces of metadata per token, like in ERC7160TL, there is a contract-wide metadata array from which token holders can choose to pin. This allows for immense flexibility and gas efficiency for ERC-721 editions.

It shares similar features with `ERC7160TL`.

## Collector's Choice
A variant of Doppelganger that allows the creator to set a cutoff time, after which, all pinning and unpinning actions by token holders are blocked. This essentially freezes the metadata and can be use for interesting gameification.

## Shatter
Allows a 1/1 token to be shattered into many tokens, that can either be an edition or more 1/1 tokens. Later, all the tokens can be fused back into the 1/1 if the tokens are all owned by the same address.

Shares many similar features to `ERC721TL`.

## Proxy Deployments
We use immutable [ERC-1167](https://eips.ethereum.org/EIPS/eip-1167) proxies for creators to deploy contracts in a cheap and immutable way. [ERC-1967](https://eips.ethereum.org/EIPS/eip-1967) proxies can also be used.

## Running Tests
1. Install [foundry](getfoundry.sh)
2. Run `make install` or `make update`
3. Run `make quick_test`

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
This code is copyright Transient Labs, Inc 2024 and is licensed under the MIT license.
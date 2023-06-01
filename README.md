# Transient Labs Creator Contracts
A repository with creator contracts that have the following features:
    - ERC721 or ERC1155
    - EIP2981
    - EIP4906
    - Batch Minting
    - Royalty override per token
    - BlockList
    - Story
    - Synergy
    - Airdrops

## Deployments
See https://docs.transientlabs.xyz/tl-creator-contracts/implementation for latest deployments

## Features
### Ownership & Access
We have implemented the `OwnableAccessControlUpgradeable` contract from [tl-sol-tools](https://github.com/Transient-Labs/tl-sol-tools) and have created custom admin and mint contract priviledges. Admins are able to mint tokens, add approved mint contracts, and propose token uri updates. Approved mint contracts are allowed to mint NFTs.

### Creator Royalties
EIP-2981 is used as it is the on-chain royalty specification used to return a royalty payout address and the royalty amount to pay based on the sale price. 

For each contract, there is a default royalty specification set that can be altered if needed. There are also individual token overrides in case of collaboration or anything like that.

### EIP-4906
This EIP specifies two events for metadata updates as an extension of EIP-721. We are allowing creators to update their metadata as it has been a useful feature for artists. More on this later, as Synergy protects collectors.

### Synergy
This mechanism on the `ERC721TL` contract protects collectors from getting token metadata changed on them unexpectedly. Artists need to be able to update metadata in certain situations, but collectors should have a right to review these changes after they have bought the piece. This is what Synergy allows; the collector must sign a transaction allowing the metadata to be updated.

### BlockList
A feature that allows creators to block operators, such as marketplaces, from getting approved on the contract. `setApprovalForAll` and `approve` will fail for any blocked addresses.

### Airdrops
Allows creators to airdrop tokens to a list of addresses.

### Batch Minting
Allows creators to cheaply batch mint tokens to their wallet. Uses the `ConsecutiveTransfer` event to mint these tokens. Still needs to be tested on OpenSea, LR, etc. 

### Contract Factory
We use a contract factory approach to enable cheap minimal proxy contract creation and work in a more decentralized way.

## Running Tests
1. Install [foundry](getfoundry.sh)
2. Run `make install`
3. Run `forge test` (optionally can adjust the fuzz runs in `foundry.toml`)

## Disclaimer
This codebase is provided on an "as is" and "as available" basis.

We do not give any warranties and will not be liable for any loss incurred through any use of this codebase.

## License
This code is copyright Transient Labs, Inc 2022 and is licensed under the MIT license.
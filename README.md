# Transient Labs Core Contracts
A repository with core creator contracts that have the following features:
    - ERC721 or ERC1155
    - EIP2981
    - EIP4906
    - Batch Minting
    - Royalty override per token
    - Block List
    - Story
    - Synergy
    - Airdrops

## Ownership & Access
We have implemented a gas optimized version of OpenZeppelin's `OwnableUpgradeable.sol` contract. We combine this with custom, specific role-based access control mechanishms in `CoreAuthTL.sol`. 

## Creator Royalties
EIP-2981 is used as it is the on-chain royalty specification used to return a royalty payout address and the royalty amount to pay based on the sale price. 

For each contract, there is a default royalty specification set that cannot be altered. There are individual token overrides but should only be called if the creator owns the token.

## EIP-4906
This EIP specifies two events for metadata updates as an extension of EIP-721. We are allowing creators to update their metadata as it has been a useful feature for artists. 

## Block List
A feature that allows creators to block operators, such as marketplaces, from getting approved on the contract. `setApprovalForAll` and `approve` will fail for any blocked addresses.

## Airdrops
Allows creators to airdrop tokens to a list of addresses.

## Batch Minting
Allows creators to cheaply batch mint tokens to their wallet. Uses the `ConsecutiveTransfer` event to mint these tokens. Still needs to be tested on OpenSea, LR, etc. 

In order to achieve this, we had to remove all `ERC721Upgradeable.ownerOf` calls in `ERC721UpgradeableTL.sol` - a forked OpenZeppelin upgradeable contract. Those calls now are just `ownerOf` calls so that we can implement custom logic in our `ERC721TL.sol` contract. We need to test that all aspects of ERC721 still function with this forked contract.
- I believe the latest version of OpenZeppelin (4.8.0) allows us to override `_ownerOf` instead of modifying core contract but still investigating

## Contract Factory
We use a contract factory approach to enable cheap minimal proxy contract creation and work in a more decentralized way.

## License
Apache-2.0
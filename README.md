# Transient Labs Core Contracts
A repository with core creator contracts that have the following features:
    - ERC721 or ERC1155
    - EIP2981
    - EIP4906
    - Batch Minting
    - Royalty override per token
    - Block List
    - Airdrops

## EIP-2981
This is the on-chain royalty specification used to return a royalty payout address and the royalty amount to pay based on the sale price.

`EIP2981TL.sol` is the contract that is inherited. It has a default royalty spec but allows for individual token overrides so that collaborations are possible or in the event of a stolen NFT, the creator can set that royalty to 99%. 

## EIP-4906
This EIP specifies two events for metadata updates as an extension of EIP-721. We are allowing creators to update their metadata as it has been a useful feature for artists. 

## Block List
A feature that allows creators to block operators, such as marketplaces, from getting approved on the contract. `setApprovalForAll` and `approve` will fail for any blocked addresses.

## Airdrops
Allows creators to airdrop tokens to a list of addresses.

## Batch Minting
Allows creators to cheaply batch mint tokens to their wallet. Uses the `ConsecutiveTransfer` event to mint these tokens. Still needs to be tested on OpenSea, LR, etc. 

In order to achieve this, we had to remove all `ERC721Upgradeable.ownerOf` calls in `ERC721UpgradeableTL.sol` - a forked OpenZeppelin upgradeable contract. Those calls now are just `ownerOf` calls so that we can implement custom logic in our `ERC721TL.sol` contract. We need to test that all aspects of ERC721 still function with this forked contract.

## Ownership
We use `OwnableUpgradeable.sol` to verify ownership and specify the creator of each NFT on a contract.

## Contract Factory
We use a contract factory approach to enable cheap minimal proxy contract creation and work in a more decentralized way.

## License
Apache-2.0
// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

/// @title ICreatorBase.sol
/// @notice Base interface for creator contracts
/// @dev Interface id =
/// @author transientlabs.xyz
/// @custom:version 3.0.0
interface ICreatorBase {

    /*//////////////////////////////////////////////////////////////////////////
                                    Events
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Event for changing the BlockList registry
    event BlockListRegistryUpdate(address indexed sender, address indexed prevBlockListRegistry, address indexed newBlockListRegistry);

    /// @dev Event for changing the NFT Delegation registry
    event NftDelegationRegistryUpdate(address indexed sender, address indexed prevNftDelegationRegistry, address indexed newNftDelegationRegistry);

    /*//////////////////////////////////////////////////////////////////////////
                                    Functions
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Function to get total supply minted so far
    function totalSupply() external view returns (uint256);

    /// @notice Function to set approved mint contracts
    /// @dev Access to owner or admin
    /// @param minters Array of minters to grant approval to
    /// @param status Status for the minters
    function setApprovedMintContracts(address[] calldata minters, bool status) external;

    /// @notice Function to change the blocklist registry
    /// @dev Access to owner or admin
    /// @param newBlockListRegistry The new blocklist registry
    function setBlockListRegistry(address newBlockListRegistry) external;

    /// @notice Function to change the TL NFT delegation registry
    /// @dev Access to owner or admin
    /// @param newNftDelegationRegistry The new blocklist registry
    function setNftDelegationRegistry(address newNftDelegationRegistry) external;

    /// @notice Function to set the default royalty specification
    /// @dev Requires owner or admin
    /// @param newRecipient The new royalty payout address
    /// @param newPercentage The new royalty percentage in basis (out of 10,000)
    function setDefaultRoyalty(address newRecipient, uint256 newPercentage) external;

    /// @notice Function to override a token's royalty info
    /// @dev Requires owner or admin
    /// @param tokenId The token to override royalty for
    /// @param newRecipient The new royalty payout address for the token id
    /// @param newPercentage The new royalty percentage in basis (out of 10,000) for the token id
    function setTokenRoyalty(uint256 tokenId, address newRecipient, uint256 newPercentage) external;

    /// @notice Function to enable or disable collector story inscriptions
    /// @dev Requires owner or admin
    /// @param status The status to set for collector story inscriptions
    function setStoryStatus(bool status) external;
}

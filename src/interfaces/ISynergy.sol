// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

/// @title ISynergy.sol
/// @notice Interface for Synergy
/// @dev Interface id = 0x8193ebea
/// @author transientlabs.xyz
/// @custom:version 3.0.0
interface ISynergy {
    /*//////////////////////////////////////////////////////////////////////////
                                    Types
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Enum defining Synergy actions
    enum SynergyAction {
        Created,
        Accepted,
        Rejected
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    Events
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Event for changing the status of a proposed metadata update.
    event SynergyStatusChange(address indexed from, uint256 indexed tokenId, SynergyAction indexed action, string uri);

    /*//////////////////////////////////////////////////////////////////////////
                                    Functions
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Function to propose a token uri update for a specific token
    /// @dev Requires owner or admin
    /// @dev If the owner of the contract is the owner of the token, the change takes hold right away
    /// @dev MUST emit a `MetadataUpdate` event if the owner of the token is the owner of the contract
    /// @dev MUST emit a `SynergyStatusChange` event if the owner of the token is not the owner of the contract
    /// @param tokenId The token to propose new metadata for
    /// @param newUri The new token uri proposed
    function proposeNewTokenUri(uint256 tokenId, string calldata newUri) external;

    /// @notice Function to accept a proposed token uri update for a specific token
    /// @dev Requires owner of the token or delegate to call the function
    /// @dev MUST emit a `SynergyStatusChange` event
    /// @param tokenId The token to accept the metadata update for
    function acceptTokenUriUpdate(uint256 tokenId) external;

    /// @notice Function to reject a proposed token uri update for a specific token
    /// @dev Requires owner of the token or delegate to call the function
    /// @dev MUST emit a `SynergyStatusChange` event
    /// @param tokenId The token to reject the metadata update for
    function rejectTokenUriUpdate(uint256 tokenId) external;
}

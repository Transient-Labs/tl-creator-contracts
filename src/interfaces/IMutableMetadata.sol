// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

/// @title IMutableMetadata.sol
/// @notice Interface for Mutable Metadata
/// @dev Interface id = 0xd31af484
/// @author transientlabs.xyz
/// @custom:version 3.3.0
interface IMutableMetadata {

    /*//////////////////////////////////////////////////////////////////////////
                                    Functions
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Function to mutate the metadata for an ERC-721 token
    /// @dev Must be called by contract owner, admin, or approved mint contract
    /// @dev MUST emit a `MetadataUpdate` event from ERC-4906
    /// @param tokenId The token to push the metadata update to
    function updateTokenUri(uint256 tokenId, string calldata newUri) external;

}

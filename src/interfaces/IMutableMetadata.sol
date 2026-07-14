// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/// @title IMutableMetadata.sol
/// @notice Interface for Mutable Metadata
/// @dev Interface id = 0xa5edeaad
interface IMutableMetadata {
    error NotRenderingContract();

    /// @notice Function to mutate the metadata for an ERC-721 token
    /// @dev Must be called by contract owner or admin
    /// @dev MUST emit a `MetadataUpdate` event from ERC-4906
    /// @param tokenId The token to push the metadata update to
    function updateTokenUri(uint256 tokenId, string calldata newUri) external;

    /// @notice Function to set the rendering contract
    /// @dev Must be called by contract owner or admin
    /// @dev MUST emit a `MetadataUpdate` event from ERC-4906
    function setRenderingContract(address newRenderingContract) external;

    /// @notice Function to emit metadata update events for a single token
    /// @dev Must be called by the rendering contract
    /// @dev MUST emit a `MetadataUpdate` event from ERC-4906
    function emitMetadataUpdateEventSingleToken(uint256 tokenId) external;

    /// @notice Function to emit metadata update events for a batch of tokens
    /// @dev Must be called by the rendering contract
    /// @dev MUST emit a `BatchMetadataUpdate` event from ERC-4906
    function emitMetadataUpdateEventBatchToken(uint256 startTokenId, uint256 endTokenId) external;
}

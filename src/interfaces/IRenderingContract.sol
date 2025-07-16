// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

/// @title Rendering Contract Interface
/// @notice Official rendering contract interface that specfies a universal interface for custom rendering contracts
/// @dev Interface id = 0xc87b56dd
/// @author transientlabs.xyz
/// @custom:version 3.6.0
interface IRenderingContract {
    /// @notice Function for getting the URI for a token id
    /// @param tokenId The token id
    /// @return string To the token uri
    function tokenURI(uint256 tokenId) external view returns (string memory);
}

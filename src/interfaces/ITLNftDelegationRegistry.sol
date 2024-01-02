// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title ITLNftDelegationRegistry.sol
/// @notice Interface for the TL NFT Delegation Registry
/// @author transientlabs.xyz
/// @custom:version 1.0.0
interface ITLNftDelegationRegistry {
    /// @notice Function to check if an address is delegated for a vault for an ERC-721 token
    /// @dev This function does not ensure the vault is the current owner of the token
    /// @dev This function SHOULD return `True` if the delegate is delegated for the vault whether it's on the token level, contract level, or wallet level (all)
    /// @param delegate The address to check for delegation status
    /// @param vault The vault address to check against
    /// @param nftContract The nft contract address to check
    /// @param tokenId The token id to check against
    /// @return bool `True` is delegated, `False` if not
    function checkDelegateForERC721(address delegate, address vault, address nftContract, uint256 tokenId)
        external
        view
        returns (bool);

    /// @notice Function to check if an address is delegated for a vault for an ERC-1155 token
    /// @dev This function does not ensure the vault has a balance of the token in question
    /// @dev This function SHOULD return `True` if the delegate is delegated for the vault whether it's on the token level, contract level, or wallet level (all)
    /// @param delegate The address to check for delegation status
    /// @param vault The vault address to check against
    /// @param nftContract The nft contract address to check
    /// @param tokenId The token id to check against
    /// @return bool `True` is delegated, `False` if not
    function checkDelegateForERC1155(address delegate, address vault, address nftContract, uint256 tokenId)
        external
        view
        returns (bool);
}

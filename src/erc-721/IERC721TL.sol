// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

/// @title IERC721TL.sol
/// @notice Interface for ERC721TL
/// @dev Interface id =
/// @author transientlabs.xyz
/// @custom:version 3.0.0
interface IERC721TL {
    /*//////////////////////////////////////////////////////////////////////////
                                    Functions
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Function to mint a single token
    /// @dev Requires owner or admin
    /// @param recipient The recipient of the token - assumed as able to receive 721 tokens
    /// @param uri The token uri to mint
    function mint(address recipient, string calldata uri) external;

    /// @notice Function to mint a single token with specific token royalty
    /// @dev Requires owner or admin
    /// @param recipient The recipient of the token - assumed as able to receive 721 tokens
    /// @param uri The token uri to mint
    /// @param royaltyAddress Royalty payout address for this new token
    /// @param royaltyPercent Royalty percentage for this new token
    function mint(address recipient, string calldata uri, address royaltyAddress, uint256 royaltyPercent) external;

    /// @notice Function to batch mint tokens
    /// @dev Requires owner or admin
    /// @dev The `baseUri` folder should have the same number of json files in it as `numTokens`
    /// @dev The `baseUri` folder should have files named without any file extension
    /// @param recipient The recipient of the token - assumed as able to receive 721 tokens
    /// @param numTokens Number of tokens in the batch mint
    /// @param baseUri The base uri for the batch, expecting json to be in order, starting at file name 0, and SHOULD NOT have a trailing `/`
    function batchMint(address recipient, uint128 numTokens, string calldata baseUri) external;

    /// @notice Function to batch mint tokens with ultra gas savings using ERC-2309
    /// @dev Requires owner or admin
    /// @dev Usage of ERC-2309 MAY NOT be supported on all platforms
    /// @dev The `baseUri` folder should have the same number of json files in it as `numTokens`
    /// @dev The `baseUri` folder should have files named without any file extension
    /// @param recipient The recipient of the token - assumed as able to receive 721 tokens
    /// @param numTokens Number of tokens in the batch mint
    /// @param baseUri The base uri for the batch, expecting json to be in order, starting at file name 0, and SHOULD NOT have a trailing `/`
    function batchMintUltra(address recipient, uint128 numTokens, string calldata baseUri) external;

    /// @notice Function to airdrop tokens to addresses
    /// @dev Requires owner or admin
    /// @dev Utilizes batch mint token uri values to save some gas but still ultimately mints individual tokens to people
    /// @dev The `baseUri` folder should have the same number of json files in it as addresses in `addresses`
    /// @dev The `baseUri` folder should have files named without any file extension
    /// @param addresses Dynamic array of addresses to mint to
    /// @param baseUri The base uri for the batch, expecting json to be in order, starting at file name 0, and SHOULD NOT have a trailing `/`
    function airdrop(address[] calldata addresses, string calldata baseUri) external;

    /// @notice Function to allow an approved mint contract to mint
    /// @dev Requires the caller to be an approved mint contract
    /// @param recipient The recipient of the token - assumed as able to receive 721 tokens
    /// @param uri The token uri to mint
    function externalMint(address recipient, string calldata uri) external;

    /// @notice Function to burn a token
    /// @dev Caller must be approved or owner of the token
    /// @param tokenId The token to burn
    function burn(uint256 tokenId) external;
}

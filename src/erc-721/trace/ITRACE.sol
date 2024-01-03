// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

/// @title ITRACE.sol
/// @notice Interface for TRACE
/// @dev Interface id = 0xcfec4f64
/// @author transientlabs.xyz
/// @custom:version 3.0.0
interface ITRACE {
    /*//////////////////////////////////////////////////////////////////////////
                                    Events
    //////////////////////////////////////////////////////////////////////////*/

    event TRACERSRegistryUpdated(address indexed sender, address indexed oldTracersRegistry, address indexed newTracersRegistry);

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

    /// @notice Function to transfer token to another wallet
    /// @dev Callable only by owner or admin
    /// @dev Useful if a chip fails or an alteration damages a chip in some way
    /// @param from The current owner of the token
    /// @param to The recipient of the token
    /// @param tokenId The token to transfer
    function transferToken(address from, address to, uint256 tokenId) external;

    /// @notice Function to set a new TRACERS registry
    /// @dev Callable only by owner or admin
    /// @param newTracersRegistry The new TRACERS Registry
    function setTracersRegistry(address newTracersRegistry) external;

    /// @notice Function to write stories for tokens
    /// @dev Requires that the passed signature is signed by the token owner, which is the ARX Halo Chip (physical)
    /// @dev Uses EIP-712 for the signature
    /// @param tokenIds The tokens to add a stories to
    /// @param stories The story text
    /// @param signatures The signtatures from the chip to verify physical presence
    function addVerifiedStory(uint256[] calldata tokenIds, string[] calldata stories, bytes[] calldata signatures)
        external;

    /// @notice Function to update a token uri for a specific token
    /// @dev Requires owner or admin
    /// @param tokenId The token to propose new metadata for
    /// @param newUri The new token uri proposed
    function setTokenUri(uint256 tokenId, string calldata newUri) external;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

/// @title IERC1155TL.sol
/// @notice Interface for ERC1155TL
/// @dev Interface id = 0x452d5a4a
/// @author transientlabs.xyz
/// @custom:version 3.0.0
interface IERC1155TL {
    /*//////////////////////////////////////////////////////////////////////////
                                    Types
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Struct defining a token
    struct Token {
        bool created;
        string uri;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    Functions
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Function to get token creation details
    /// @param tokenId The token to lookup
    function getTokenDetails(uint256 tokenId) external view returns (Token memory);

    /// @notice Function to create a token that can be minted to creator or airdropped
    /// @dev Requires owner or admin
    /// @param newUri The uri for the token to create
    /// @param addresses The addresses to mint the new token to
    /// @param amounts The amount of the new token to mint to each address
    function createToken(string calldata newUri, address[] calldata addresses, uint256[] calldata amounts) external;

    /// @notice Function to create a token that can be minted to creator or airdropped
    /// @dev Overloaded function where you can set the token royalty config in this tx
    /// @dev Requires owner or admin
    /// @param newUri The uri for the token to create
    /// @param addresses The addresses to mint the new token to
    /// @param amounts The amount of the new token to mint to each address
    /// @param royaltyAddress Royalty payout address for the created token
    /// @param royaltyPercent Royalty percentage for this token
    function createToken(
        string calldata newUri,
        address[] calldata addresses,
        uint256[] calldata amounts,
        address royaltyAddress,
        uint256 royaltyPercent
    ) external;

    /// @notice function to batch create tokens that can be minted to creator or airdropped
    /// @dev requires owner or admin
    /// @param newUris the uris for the tokens to create
    /// @param addresses 2d dynamic array holding the addresses to mint the new tokens to
    /// @param amounts 2d dynamic array holding the amounts of the new tokens to mint to each address
    function batchCreateToken(string[] calldata newUris, address[][] calldata addresses, uint256[][] calldata amounts)
        external;

    /// @notice Function to batch create tokens that can be minted to creator or airdropped
    /// @dev Overloaded function where you can set the token royalty config in this tx
    /// @dev Requires owner or admin
    /// @param newUris Rhe uris for the tokens to create
    /// @param addresses 2d dynamic array holding the addresses to mint the new tokens to
    /// @param amounts 2d dynamic array holding the amounts of the new tokens to mint to each address
    /// @param royaltyAddresses Royalty payout addresses for the tokens
    /// @param royaltyPercents Royalty payout percents for the tokens
    function batchCreateToken(
        string[] calldata newUris,
        address[][] calldata addresses,
        uint256[][] calldata amounts,
        address[] calldata royaltyAddresses,
        uint256[] calldata royaltyPercents
    ) external;

    /// @notice Function to mint existing token to recipients
    /// @dev Requires owner or admin
    /// @param tokenId The token to mint
    /// @param addresses The addresses to mint to
    /// @param amounts Amounts of the token to mint to each address
    function mintToken(uint256 tokenId, address[] calldata addresses, uint256[] calldata amounts) external;

    /// @notice External mint function
    /// @dev Requires caller to be an approved mint contract
    /// @param tokenId The token to mint
    /// @param addresses The addresses to mint to
    /// @param amounts Amounts of the token to mint to each address
    function externalMint(uint256 tokenId, address[] calldata addresses, uint256[] calldata amounts) external;

    /// @notice Function to burn tokens from an account
    /// @dev Msg.sender must be token owner or operator
    /// @dev If this function is called from another contract as part of a burn/redeem, the contract must ensure that no amount is '0' or if it is, that it isn't a vulnerability.
    /// @param from Address to burn from
    /// @param tokenIds Array of tokens to burn
    /// @param amounts Amount of each token to burn
    function burn(address from, uint256[] calldata tokenIds, uint256[] calldata amounts) external;

    /// @notice Function to set a token uri
    /// @dev Requires owner or admin
    /// @param tokenId The token to mint
    /// @param newUri The new token uri
    function setTokenUri(uint256 tokenId, string calldata newUri) external;
}

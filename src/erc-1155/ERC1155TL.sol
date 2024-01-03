// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {Strings} from "openzeppelin/utils/Strings.sol";
import {ERC1155Upgradeable, IERC1155, IERC165} from "openzeppelin-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import {EIP2981TLUpgradeable} from "tl-sol-tools/upgradeable/royalties/EIP2981TLUpgradeable.sol";
import {OwnableAccessControlUpgradeable} from "tl-sol-tools/upgradeable/access/OwnableAccessControlUpgradeable.sol";
import {IStory} from "src/interfaces/IStory.sol";
import {IERC1155TL} from "src/erc-1155/IERC1155TL.sol";
import {ICreatorBase} from "src/interfaces/ICreatorBase.sol";
import {IBlockListRegistry} from "src/interfaces/IBlockListRegistry.sol";
import {ITLNftDelegationRegistry} from "src/interfaces/ITLNftDelegationRegistry.sol";

/// @title ERC1155TL.sol
/// @notice Transient Labs ERC-1155 Creator Contract
/// @author transientlabs.xyz
/// @custom:version 3.0.0
contract ERC1155TL is
    ERC1155Upgradeable,
    EIP2981TLUpgradeable,
    OwnableAccessControlUpgradeable,
    ICreatorBase,
    IERC1155TL,
    IStory
{
    /*//////////////////////////////////////////////////////////////////////////
                                Custom Types
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev String representation for address
    using Strings for address;

    /*//////////////////////////////////////////////////////////////////////////
                                State Variables
    //////////////////////////////////////////////////////////////////////////*/

    string public constant VERSION = "3.0.0";
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant APPROVED_MINT_CONTRACT = keccak256("APPROVED_MINT_CONTRACT");
    uint256 private _counter;
    string public name;
    string public symbol;
    bool public storyEnabled;
    ITLNftDelegationRegistry public tlNftDelegationRegistry;
    IBlockListRegistry public blocklistRegistry;
    mapping(uint256 => Token) private _tokens;

    /*//////////////////////////////////////////////////////////////////////////
                                    Errors
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Token uri is an empty string
    error EmptyTokenURI();

    /// @dev Batch size too small
    error BatchSizeTooSmall();

    /// @dev Mint to zero addresses
    error MintToZeroAddresses();

    /// @dev Array length mismatch
    error ArrayLengthMismatch();

    /// @dev Token not owned by the owner of the contract
    error TokenNotOwnedByOwner();

    /// @dev Caller is not approved or owner
    error CallerNotApprovedOrOwner();

    /// @dev Token does not exist
    error TokenDoesntExist();

    /// @dev Burning zero tokens
    error BurnZeroTokens();

    /*//////////////////////////////////////////////////////////////////////////
                                Constructor
    //////////////////////////////////////////////////////////////////////////*/

    /// @param disable Boolean to disable initialization for the implementation contract
    constructor(bool disable) {
        if (disable) _disableInitializers();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                Initializer
    //////////////////////////////////////////////////////////////////////////*/

    /// @param name_ The name of the 721 contract
    /// @param symbol_ The symbol of the 721 contract
    /// @param defaultRoyaltyRecipient The default address for royalty payments
    /// @param defaultRoyaltyPercentage The default royalty percentage of basis points (out of 10,000)
    /// @param initOwner The owner of the contract
    /// @param admins Array of admin addresses to add to the contract
    /// @param enableStory A bool deciding whether to add story fuctionality or not
    /// @param blockListRegistry Address of the blocklist registry to use
    function initialize(
        string memory name_,
        string memory symbol_,
        address defaultRoyaltyRecipient,
        uint256 defaultRoyaltyPercentage,
        address initOwner,
        address[] memory admins,
        bool enableStory,
        address blockListRegistry
    ) external initializer {
        // initialize parent contracts
        __ERC1155_init("");
        __EIP2981TL_init(defaultRoyaltyRecipient, defaultRoyaltyPercentage);
        __OwnableAccessControl_init(initOwner);

        // add admins
        _setRole(ADMIN_ROLE, admins, true);

        // set name & symbol
        name = name_;
        symbol = symbol_;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                General Functions
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc ICreatorBase
    function totalSupply() external view returns (uint256) {
        return _counter;
    }

    /// @inheritdoc IERC1155TL
    function getTokenDetails(uint256 tokenId) external view returns (Token memory) {
        return _tokens[tokenId];
    }

    /*//////////////////////////////////////////////////////////////////////////
                                Access Control Functions
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc ICreatorBase
    function setApprovedMintContracts(address[] calldata minters, bool status) external onlyRoleOrOwner(ADMIN_ROLE) {
        _setRole(APPROVED_MINT_CONTRACT, minters, status);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                Creation Functions
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc IERC1155TL
    function createToken(string calldata newUri, address[] calldata addresses, uint256[] calldata amounts)
        external
        onlyRoleOrOwner(ADMIN_ROLE)
    {
        _createToken(newUri, addresses, amounts);
    }

    /// @inheritdoc IERC1155TL
    function createToken(
        string calldata newUri,
        address[] calldata addresses,
        uint256[] calldata amounts,
        address royaltyAddress,
        uint256 royaltyPercent
    ) external onlyRoleOrOwner(ADMIN_ROLE) {
        uint256 tokenId = _createToken(newUri, addresses, amounts);
        _overrideTokenRoyaltyInfo(tokenId, royaltyAddress, royaltyPercent);
    }

    /// @inheritdoc IERC1155TL
    function batchCreateToken(string[] calldata newUris, address[][] calldata addresses, uint256[][] calldata amounts)
        external
        onlyRoleOrOwner(ADMIN_ROLE)
    {
        if (newUris.length == 0) revert EmptyTokenURI();
        for (uint256 i = 0; i < newUris.length; i++) {
            _createToken(newUris[i], addresses[i], amounts[i]);
        }
    }

    /// @inheritdoc IERC1155TL
    function batchCreateToken(
        string[] calldata newUris,
        address[][] calldata addresses,
        uint256[][] calldata amounts,
        address[] calldata royaltyAddresses,
        uint256[] calldata royaltyPercents
    ) external onlyRoleOrOwner(ADMIN_ROLE) {
        if (newUris.length == 0) revert EmptyTokenURI();
        for (uint256 i = 0; i < newUris.length; i++) {
            uint256 tokenId = _createToken(newUris[i], addresses[i], amounts[i]);
            _overrideTokenRoyaltyInfo(tokenId, royaltyAddresses[i], royaltyPercents[i]);
        }
    }

    /*//////////////////////////////////////////////////////////////////////////
                                Mint Functions
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc IERC1155TL
    function mintToken(uint256 tokenId, address[] calldata addresses, uint256[] calldata amounts)
        external
        onlyRoleOrOwner(ADMIN_ROLE)
    {
        _mintToken(tokenId, addresses, amounts);
    }

    /// @inheritdoc IERC1155TL
    function externalMint(uint256 tokenId, address[] calldata addresses, uint256[] calldata amounts)
        external
        onlyRole(APPROVED_MINT_CONTRACT)
    {
        _mintToken(tokenId, addresses, amounts);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                Burn Functions
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc IERC1155TL
    function burn(address from, uint256[] calldata tokenIds, uint256[] calldata amounts) external {
        if (tokenIds.length == 0) revert BurnZeroTokens();
        if (msg.sender != from && !isApprovedForAll(from, msg.sender)) revert CallerNotApprovedOrOwner();
        _burnBatch(from, tokenIds, amounts);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                Royalty Functions
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc ICreatorBase
    function setDefaultRoyalty(address newRecipient, uint256 newPercentage) external onlyOwner {
        _setDefaultRoyaltyInfo(newRecipient, newPercentage);
    }

    /// @inheritdoc ICreatorBase
    function setTokenRoyalty(uint256 tokenId, address newRecipient, uint256 newPercentage) external onlyOwner {
        _overrideTokenRoyaltyInfo(tokenId, newRecipient, newPercentage);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                Token Uri Functions
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc IERC1155TL
    function setTokenUri(uint256 tokenId, string calldata newUri) external onlyRoleOrOwner(ADMIN_ROLE) {
        if (!_exists(tokenId)) revert TokenDoesntExist();
        if (bytes(newUri).length == 0) revert EmptyTokenURI();
        _tokens[tokenId].uri = newUri;
        emit IERC1155.URI(newUri, tokenId);
    }

    /// @inheritdoc ERC1155Upgradeable
    function uri(uint256 tokenId) public view override(ERC1155Upgradeable) returns (string memory) {
        if (!_exists(tokenId)) revert TokenDoesntExist();
        return _tokens[tokenId].uri;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                Story Inscriptions
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc IStory
    function addCollectionStory(string calldata creatorName, string calldata story)
        external
        onlyRoleOrOwner(ADMIN_ROLE)
    {}

    /// @inheritdoc IStory
    function addCreatorStory(uint256 tokenId, string calldata creatorName, string calldata story)
        external
        onlyRoleOrOwner(ADMIN_ROLE)
    {}

    /// @inheritdoc IStory
    function addStory(uint256 tokenId, string calldata collectorName, string calldata story) external {}

    /// @inheritdoc ICreatorBase
    function setStoryStatus(bool status) external {}

    /*//////////////////////////////////////////////////////////////////////////
                                BlockList
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc ICreatorBase
    function setBlockListRegistry(address newBlockListRegistry) external {}

    /*//////////////////////////////////////////////////////////////////////////
                            NFT Delegation Registry
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc ICreatorBase
    function setNftDelegationRegistry(address newNftDelegationRegistry) external {}

    /*//////////////////////////////////////////////////////////////////////////
                                ERC-165 Support
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155Upgradeable, EIP2981TLUpgradeable)
        returns (bool)
    {
        return (
            ERC1155Upgradeable.supportsInterface(interfaceId) || EIP2981TLUpgradeable.supportsInterface(interfaceId)
                || interfaceId == type(ICreatorBase).interfaceId || interfaceId == type(IStory).interfaceId
                || interfaceId == 0x0d23ecb9 // previous story contract version that is still supported
                || interfaceId == type(IERC1155TL).interfaceId
        );
    }

    /*//////////////////////////////////////////////////////////////////////////
                                Internal Functions
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Private helper function to verify a token exists
    /// @param tokenId The token to check existence for
    function _exists(uint256 tokenId) private view returns (bool) {
        return _tokens[tokenId].created;
    }

    /// @notice Private helper function to create a new token
    /// @param newUri The uri for the token to create
    /// @param addresses The addresses to mint the new token to
    /// @param amounts The amount of the new token to mint to each address
    /// @return uint256 Token id created
    function _createToken(string memory newUri, address[] memory addresses, uint256[] memory amounts)
        private
        returns (uint256)
    {
        if (bytes(newUri).length == 0) revert EmptyTokenURI();
        if (addresses.length == 0) revert MintToZeroAddresses();
        if (addresses.length != amounts.length) revert ArrayLengthMismatch();
        _counter++;
        _tokens[_counter] = Token(true, newUri);
        for (uint256 i = 0; i < addresses.length; i++) {
            _mint(addresses[i], _counter, amounts[i], "");
        }

        return _counter;
    }

    /// @notice Private helper function
    /// @param tokenId The token to mint
    /// @param addresses The addresses to mint to
    /// @param amounts Amounts of the token to mint to each address
    function _mintToken(uint256 tokenId, address[] calldata addresses, uint256[] calldata amounts) private {
        if (!_exists(tokenId)) revert TokenDoesntExist();
        if (addresses.length == 0) revert MintToZeroAddresses();
        if (addresses.length != amounts.length) revert ArrayLengthMismatch();
        for (uint256 i = 0; i < addresses.length; i++) {
            _mint(addresses[i], tokenId, amounts[i], "");
        }
    }
}

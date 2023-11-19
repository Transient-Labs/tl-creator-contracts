// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Initializable} from "openzeppelin-upgradeable/proxy/utils/Initializable.sol";
import {ERC721Upgradeable, ERC165Upgradeable} from "openzeppelin-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {EIP712Upgradeable, ECDSAUpgradeable} from "openzeppelin-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import {StringsUpgradeable} from "openzeppelin-upgradeable/utils/StringsUpgradeable.sol";
import {EIP2981TLUpgradeable} from "tl-sol-tools/upgradeable/royalties/EIP2981TLUpgradeable.sol";
import {OwnableAccessControlUpgradeable} from "tl-sol-tools/upgradeable/access/OwnableAccessControlUpgradeable.sol";
import {StoryContractUpgradeable} from "tl-story/upgradeable/StoryContractUpgradeable.sol";
import {TRACERSRegistry} from "./TRACERSRegistry.sol";

/*//////////////////////////////////////////////////////////////////////////
                            Custom Errors
//////////////////////////////////////////////////////////////////////////*/

/// @dev token uri is an empty string
error EmptyTokenURI();

/// @dev batch mint to zero address
error MintToZeroAddress();

/// @dev batch size too small
error BatchSizeTooSmall();

/// @dev airdrop to too few addresses
error AirdropTooFewAddresses();

/// @dev token not owned by the owner of the contract
error TokenNotOwnedByOwner();

/// @dev caller is not the owner of the specific token
error CallerNotTokenOwner();

/// @dev caller is not approved or owner
error CallerNotApprovedOrOwner();

/// @dev token does not exist
error TokenDoesntExist();

/// @dev no proposed token uri to change to
error NoTokenUriUpdateAvailable();

/// @dev invalid signature
error InvalidSignature();

/// @dev unauthorized to add a verified story
error Unauthorized();

/*//////////////////////////////////////////////////////////////////////////
                            ERC721TL
//////////////////////////////////////////////////////////////////////////*/

/// @title TRACE.sol
/// @notice Transient Labs T.R.A.C.E. implementation contract
/// @dev features include
///      - airdrops
///      - ability to set multiple admins
///      - Story Contract backed by T.R.A.C.E. chip functionality
///      - individual token royalty overrides
/// @author transientlabs.xyz
/// @custom:version 2.9.0
contract TRACE is
    Initializable,
    ERC721Upgradeable,
    EIP2981TLUpgradeable,
    OwnableAccessControlUpgradeable,
    StoryContractUpgradeable,
    EIP712Upgradeable
{
    /*//////////////////////////////////////////////////////////////////////////
                                Custom Types
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev struct defining a batch mint - used for airdrops
    struct BatchMint {
        uint256 fromTokenId;
        uint256 toTokenId;
        string baseUri;
    }

    /// @dev struct for verified story & signed EIP-712 message
    struct VerifiedStory {
        uint256 nonce;
        uint256 tokenId;
        address sender;
        string story;
    }

    /// @dev string representation of uint256
    using StringsUpgradeable for uint256;

    /// @dev string representation for address
    using StringsUpgradeable for address;

    /*//////////////////////////////////////////////////////////////////////////
                                State Variables
    //////////////////////////////////////////////////////////////////////////*/

    string public constant VERSION = "2.9.0";
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    TRACERSRegistry public tracersRegistry;
    uint256 private _counter; // token ids
    mapping(uint256 => string) private _tokenUris; // established token uris
    mapping(uint256 => uint256) private _tokenNonces; // token nonces to prevent replay attacks
    BatchMint[] private _batchMints; // dynamic array for batch mints

    /*//////////////////////////////////////////////////////////////////////////
                                Events
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev This event emits when the metadata of a token is changed
    ///      so that the third-party platforms such as NFT market can
    ///      timely update the images and related attributes of the NFT.
    /// @dev see EIP-4906
    event MetadataUpdate(uint256 tokenId);

    /// @dev This event emits when the metadata of a range of tokens is changed
    ///      so that the third-party platforms such as NFT market could
    ///      timely update the images and related attributes of the NFTs.
    /// @dev see EIP-4906
    event BatchMetadataUpdate(uint256 fromTokenId, uint256 toTokenId);

    /*//////////////////////////////////////////////////////////////////////////
                                Constructor
    //////////////////////////////////////////////////////////////////////////*/

    /// @param disable: boolean to disable initialization for the implementation contract
    constructor(bool disable) {
        if (disable) _disableInitializers();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                Initializer
    //////////////////////////////////////////////////////////////////////////*/

    /// @param name: the name of the contract
    /// @param symbol: the symbol of the contract
    /// @param defaultRoyaltyRecipient: the default address for royalty payments
    /// @param defaultRoyaltyPercentage: the default royalty percentage of basis points (out of 10,000)
    /// @param initOwner: the owner of the contract
    /// @param admins: array of admin addresses to add to the contract
    /// @param defaultTracersRegistry: address of the TRACERS registry to use
    function initialize(
        string memory name,
        string memory symbol,
        address defaultRoyaltyRecipient,
        uint256 defaultRoyaltyPercentage,
        address initOwner,
        address[] memory admins,
        address defaultTracersRegistry
    ) external initializer {
        // initialize parent contracts
        __ERC721_init(name, symbol);
        __EIP2981TL_init(defaultRoyaltyRecipient, defaultRoyaltyPercentage);
        __OwnableAccessControl_init(initOwner);
        __StoryContractUpgradeable_init(true);
        __EIP712_init(name, "1");

        // add admins
        _setRole(ADMIN_ROLE, admins, true);

        // set TRACERS Registry
        tracersRegistry = TRACERSRegistry(defaultTracersRegistry);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                General Functions
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice function to get total supply minted so far
    function totalSupply() external view returns (uint256) {
        return _counter;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                Mint Functions
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice function to mint a single token
    /// @dev requires owner or admin
    /// @param recipient the recipient of the token - assumed as able to receive 721 tokens
    /// @param uri the token uri to mint
    function mint(address recipient, string calldata uri) external onlyRoleOrOwner(ADMIN_ROLE) {
        if (bytes(uri).length == 0) revert EmptyTokenURI();
        _counter++;
        _tokenUris[_counter] = uri;
        _mint(recipient, _counter);
    }

    /// @notice function to mint a single token with specific token royalty
    /// @dev requires owner or admin
    /// @param recipient: the recipient of the token - assumed as able to receive 721 tokens
    /// @param uri the token uri to mint
    /// @param royaltyAddress royalty payout address for this new token
    /// @param royaltyPercent royalty percentage for this new token
    function mint(address recipient, string calldata uri, address royaltyAddress, uint256 royaltyPercent)
        external
        onlyRoleOrOwner(ADMIN_ROLE)
    {
        if (bytes(uri).length == 0) revert EmptyTokenURI();
        _counter++;
        _tokenUris[_counter] = uri;
        _overrideTokenRoyaltyInfo(_counter, royaltyAddress, royaltyPercent);
        _mint(recipient, _counter);
    }

    /// @notice function to airdrop tokens to addresses
    /// @dev requires owner or admin
    /// @dev utilizes batch mint token uri values to save some gas
    ///      but still ultimately mints individual tokens to people
    /// @param addresses dynamic array of addresses to mint to
    /// @param baseUri the base uri for the batch, expecting json to be in order and starting at 0
    ///                 NOTE: the number of json files in this folder should be equal to the number of addresses
    ///                 NOTE: files should be named without any file extension
    ///                 NOTE: baseUri should not have a trailing `/`
    function airdrop(address[] calldata addresses, string calldata baseUri) external onlyRoleOrOwner(ADMIN_ROLE) {
        if (bytes(baseUri).length == 0) revert EmptyTokenURI();
        if (addresses.length < 2) revert AirdropTooFewAddresses();

        uint256 start = _counter + 1;
        _counter += addresses.length;
        _batchMints.push(BatchMint(start, start + addresses.length, baseUri));
        for (uint256 i = 0; i < addresses.length; i++) {
            _mint(addresses[i], start + i);
        }
    }

    /*//////////////////////////////////////////////////////////////////////////
                                Batch Mint Functions
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice function to get batch mint info
    /// @param tokenId token id to look up for batch mint info
    /// @return string the uri for the tokenId
    function _getBatchInfo(uint256 tokenId) internal view returns (string memory) {
        uint256 i = 0;
        for (i; i < _batchMints.length; i++) {
            if (tokenId >= _batchMints[i].fromTokenId && tokenId <= _batchMints[i].toTokenId) {
                break;
            }
        }
        if (i >= _batchMints.length) {
            return "";
        }
        string memory tokenUri =
            string(abi.encodePacked(_batchMints[i].baseUri, "/", (tokenId - _batchMints[i].fromTokenId).toString()));
        return tokenUri;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                T.R.A.C.E. Functions
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice function to transfer token to another wallet
    /// @dev callable only by owner or admin
    /// @dev useful if a chip fails or an alteration damages a chip in some way
    /// @param from the current owner of the token
    /// @param to the recipient of the token
    /// @param tokenId the token to transfer
    function transferToken(address from, address to, uint256 tokenId) external onlyRoleOrOwner(ADMIN_ROLE) {
        _transfer(from, to, tokenId);
    }

    /// @notice function to set a new TRACERS registry
    /// @dev callable only by owner or admin
    /// @param newTracersRegistry the new TRACERS Registry
    function setTracersRegistry(address newTracersRegistry) external onlyRoleOrOwner(ADMIN_ROLE) {
        tracersRegistry = TRACERSRegistry(newTracersRegistry);
    }

    /// @notice function to write a story for a token
    /// @dev requires that the passed signature is signed by the token owner, which is the ARX Halo Chip (physical)
    /// @dev uses EIP-712 for the signature
    /// @param tokenId the token to add a story to
    /// @param story the story text
    /// @param signature the signtature from the chip to verify physical presence
    function addVerifiedStory(uint256 tokenId, string calldata story, bytes calldata signature) external {
        // default name to hex address
        string memory registeredAgentName = msg.sender.toHexString();

        // only check registered agent if the registry is not the zero address
        if (address(tracersRegistry) != address(0)) {
            if (address(tracersRegistry).code.length == 0) revert Unauthorized();
            bool isRegisteredAgent;
            (isRegisteredAgent, registeredAgentName) = tracersRegistry.isRegisteredAgent(msg.sender);
            if (!isRegisteredAgent) revert Unauthorized();
        }

        // verify signature
        address tokenOwner = ownerOf(tokenId);
        bytes32 digest = _hashTypedDataV4(_hashVerifiedStory(tokenId, _tokenNonces[tokenId]++, msg.sender, story));
        if (tokenOwner != ECDSAUpgradeable.recover(digest, signature)) revert InvalidSignature();

        // emit story
        emit Story(tokenId, msg.sender, registeredAgentName, story);
    }

    /// @notice function to return the nonce for a token
    /// @param tokenId the token to query
    /// @return uint256 the token nonce
    function getTokenNonce(uint256 tokenId) external view returns (uint256) {
        return _tokenNonces[tokenId];
    }

    /// @notice function to hash the typed data
    function _hashVerifiedStory(uint256 tokenId, uint256 nonce, address sender, string memory story)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                // keccak256("VerifiedStory(uint256 nonce,uint256 tokenId,address sender,string story)"),
                0x3ea278f3e0e25a71281e489b82695f448ae01ef3fc312598f1e61ac9956ab954,
                nonce,
                tokenId,
                sender,
                keccak256(bytes(story))
            )
        );
    }

    /*//////////////////////////////////////////////////////////////////////////
                                Royalty Functions
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice function to set the default royalty specification
    /// @dev requires owner
    /// @param newRecipient the new royalty payout address
    /// @param newPercentage the new royalty percentage in basis (out of 10,000)
    function setDefaultRoyalty(address newRecipient, uint256 newPercentage) external onlyRoleOrOwner(ADMIN_ROLE) {
        _setDefaultRoyaltyInfo(newRecipient, newPercentage);
    }

    /// @notice function to override a token's royalty info
    /// @dev requires owner
    /// @param tokenId the token to override royalty for
    /// @param newRecipient the new royalty payout address for the token id
    /// @param newPercentage the new royalty percentage in basis (out of 10,000) for the token id
    function setTokenRoyalty(uint256 tokenId, address newRecipient, uint256 newPercentage) external onlyRoleOrOwner(ADMIN_ROLE) {
        _overrideTokenRoyaltyInfo(tokenId, newRecipient, newPercentage);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                Metadata Update Functions
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice function to update a token uri for a specific token
    /// @dev requires owner or admin
    /// @param tokenId the token to propose new metadata for
    /// @param newUri the new token uri proposed
    function updateTokenUri(uint256 tokenId, string calldata newUri) external onlyRoleOrOwner(ADMIN_ROLE) {
        if (!_exists(tokenId)) revert TokenDoesntExist();
        if (bytes(newUri).length == 0) revert EmptyTokenURI();
        _tokenUris[tokenId] = newUri;
        emit MetadataUpdate(tokenId);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                Token Uri Override
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc ERC721Upgradeable
    function tokenURI(uint256 tokenId) public view override(ERC721Upgradeable) returns (string memory) {
        if (!_exists(tokenId)) revert TokenDoesntExist();
        string memory uri = _tokenUris[tokenId];
        if (bytes(uri).length == 0) {
            uri = _getBatchInfo(tokenId);
        }
        return uri;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                Story Contract Hooks
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc StoryContractUpgradeable
    function _isStoryAdmin(address potentialAdmin) internal view override(StoryContractUpgradeable) returns (bool) {
        return potentialAdmin == owner() || hasRole(ADMIN_ROLE, potentialAdmin);
    }

    /// @inheritdoc StoryContractUpgradeable
    function _tokenExists(uint256 tokenId) internal view override(StoryContractUpgradeable) returns (bool) {
        return _exists(tokenId);
    }

    /// @inheritdoc StoryContractUpgradeable
    function _isTokenOwner(address potentialOwner, uint256 tokenId)
        internal
        view
        override(StoryContractUpgradeable)
        returns (bool)
    {
        address tokenOwner = ownerOf(tokenId);
        return tokenOwner == potentialOwner;
    }

    /// @inheritdoc StoryContractUpgradeable
    function _isCreator(address potentialCreator, uint256 /* tokenId */ )
        internal
        view
        override(StoryContractUpgradeable)
        returns (bool)
    {
        return potentialCreator == owner() || hasRole(ADMIN_ROLE, potentialCreator);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                ERC-165 Support
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc ERC165Upgradeable
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Upgradeable, EIP2981TLUpgradeable, StoryContractUpgradeable)
        returns (bool)
    {
        return (
            ERC721Upgradeable.supportsInterface(interfaceId) || EIP2981TLUpgradeable.supportsInterface(interfaceId)
                || StoryContractUpgradeable.supportsInterface(interfaceId) || interfaceId == bytes4(0x49064906)
        ); // EIP-4906 support
    }
}

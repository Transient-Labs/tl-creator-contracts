// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {IERC4906} from "openzeppelin/interfaces/IERC4906.sol";
import {Strings} from "openzeppelin/utils/Strings.sol";
import {ECDSA} from "openzeppelin/utils/cryptography/ECDSA.sol";
import {ERC721Upgradeable, IERC165} from "openzeppelin-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {EIP712Upgradeable} from "openzeppelin-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import {EIP2981TLUpgradeable} from "tl-sol-tools/upgradeable/royalties/EIP2981TLUpgradeable.sol";
import {OwnableAccessControlUpgradeable} from "tl-sol-tools/upgradeable/access/OwnableAccessControlUpgradeable.sol";
import {IBlockListRegistry} from "../../interfaces/IBlockListRegistry.sol";
import {ICreatorBase} from "../../interfaces/ICreatorBase.sol";
import {IStory} from "../../interfaces/IStory.sol";
import {ITLNftDelegationRegistry} from "../../interfaces/ITLNftDelegationRegistry.sol";
import {ITRACERSRegistry} from "../../interfaces/ITRACERSRegistry.sol";
import {ITRACE} from "./ITRACE.sol";

/// @title TRACE.sol
/// @notice Sovereign T.R.A.C.E. Creator Contract allowing for digital Certificates of Authenticity backed by the blockchain
/// @author transientlabs.xyz
/// @custom:version 3.0.1
contract TRACE is
    ERC721Upgradeable,
    OwnableAccessControlUpgradeable,
    EIP2981TLUpgradeable,
    EIP712Upgradeable,
    ICreatorBase,
    ITRACE,
    IStory,
    IERC4906
{
    /*//////////////////////////////////////////////////////////////////////////
                                Custom Types
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Struct defining a batch mint - used for airdrops
    struct BatchMint {
        uint256 fromTokenId;
        uint256 toTokenId;
        string baseUri;
    }

    /// @dev Struct for verified story & signed EIP-712 message
    struct VerifiedStory {
        address nftContract;
        uint256 tokenId;
        string story;
    }

    /// @dev String representation of uint256
    using Strings for uint256;

    /// @dev String representation for address
    using Strings for address;

    /*//////////////////////////////////////////////////////////////////////////
                                State Variables
    //////////////////////////////////////////////////////////////////////////*/

    string public constant VERSION = "3.0.1";
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant APPROVED_MINT_CONTRACT = keccak256("APPROVED_MINT_CONTRACT");
    ITRACERSRegistry public tracersRegistry;
    uint256 private _counter; // token ids
    mapping(uint256 => string) private _tokenUris; // established token uris
    mapping(bytes32 => bool) private _verifiedStoryHashUsed; // prevent replay attacks
    BatchMint[] private _batchMints; // dynamic array for batch mints

    /*//////////////////////////////////////////////////////////////////////////
                                Custom Errors
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Token uri is an empty string
    error EmptyTokenURI();

    /// @dev Airdrop to too few addresses
    error AirdropTooFewAddresses();

    /// @dev Token does not exist
    error TokenDoesntExist();

    /// @dev Verified story already written for token
    error VerifiedStoryAlreadyWritten();

    /// @dev Array length mismatch
    error ArrayLengthMismatch();

    /// @dev Invalid signature
    error InvalidSignature();

    /// @dev Unauthorized to add a verified story
    error Unauthorized();

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

    /// @dev `tx.origin` is used in the events here as these can be deployed via contract factories and we want to capture the true sender
    /// @param name The name of the contract
    /// @param symbol The symbol of the contract
    /// @param personalization A string to emit as a collection story. Can be ASCII art or something else that is a personalization of the contract.
    /// @param defaultRoyaltyRecipient The default address for royalty payments
    /// @param defaultRoyaltyPercentage The default royalty percentage of basis points (out of 10,000)
    /// @param initOwner The owner of the contract
    /// @param admins Array of admin addresses to add to the contract
    /// @param defaultTracersRegistry Address of the TRACERS registry to use
    function initialize(
        string memory name,
        string memory symbol,
        string memory personalization,
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
        __EIP712_init("T.R.A.C.E.", "3");

        // add admins
        _setRole(ADMIN_ROLE, admins, true);

        // set TRACERS Registry
        tracersRegistry = ITRACERSRegistry(defaultTracersRegistry);

        // emit personalization as collection story
        if (bytes(personalization).length > 0) {
            emit CollectionStory(tx.origin, tx.origin.toHexString(), personalization);
        }
    }

    /*//////////////////////////////////////////////////////////////////////////
                                General Functions
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc ICreatorBase
    function totalSupply() external view returns (uint256) {
        return _counter;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                Access Control Functions
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc ICreatorBase
    function setApprovedMintContracts(address[] calldata minters, bool status) external onlyRoleOrOwner(ADMIN_ROLE) {
        _setRole(APPROVED_MINT_CONTRACT, minters, status);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                Mint Functions
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc ITRACE
    function mint(address recipient, string calldata uri) external onlyRoleOrOwner(ADMIN_ROLE) {
        if (bytes(uri).length == 0) revert EmptyTokenURI();
        _counter++;
        _tokenUris[_counter] = uri;
        _mint(recipient, _counter);
        emit CreatorStory(_counter, msg.sender, "", "{\n\"trace\": {\"type\": \"trace_authentication\"}\n}");
    }

    /// @inheritdoc ITRACE
    function mint(address recipient, string calldata uri, address royaltyAddress, uint256 royaltyPercent)
        external
        onlyRoleOrOwner(ADMIN_ROLE)
    {
        if (bytes(uri).length == 0) revert EmptyTokenURI();
        _counter++;
        _tokenUris[_counter] = uri;
        _overrideTokenRoyaltyInfo(_counter, royaltyAddress, royaltyPercent);
        _mint(recipient, _counter);
        emit CreatorStory(_counter, msg.sender, "", "{\n\"trace\": {\"type\": \"trace_authentication\"}\n}");
    }

    /// @inheritdoc ITRACE
    function airdrop(address[] calldata addresses, string calldata baseUri) external onlyRoleOrOwner(ADMIN_ROLE) {
        if (bytes(baseUri).length == 0) revert EmptyTokenURI();
        if (addresses.length < 2) revert AirdropTooFewAddresses();

        uint256 start = _counter + 1;
        uint256 end = start + addresses.length - 1;
        _counter += addresses.length;
        _batchMints.push(BatchMint(start, end, baseUri));
        for (uint256 i = 0; i < addresses.length; i++) {
            _mint(addresses[i], start + i);
            emit CreatorStory(start + i, msg.sender, "", "{\n\"trace\": {\"type\": \"trace_authentication\"}\n}");
        }
    }

    /// @inheritdoc ITRACE
    function externalMint(address recipient, string calldata uri) external onlyRole(APPROVED_MINT_CONTRACT) {
        if (bytes(uri).length == 0) revert EmptyTokenURI();
        _counter++;
        _tokenUris[_counter] = uri;
        _mint(recipient, _counter);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                T.R.A.C.E. Functions
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc ITRACE
    function transferToken(address from, address to, uint256 tokenId) external onlyRoleOrOwner(ADMIN_ROLE) {
        _transfer(from, to, tokenId);
        emit CreatorStory(tokenId, msg.sender, "", "{\n\"trace\": {\"type\": \"trace_authentication\"}\n}");
    }

    /// @inheritdoc ITRACE
    function setTracersRegistry(address newTracersRegistry) external onlyRoleOrOwner(ADMIN_ROLE) {
        address oldTracersRegistry = address(tracersRegistry);
        tracersRegistry = ITRACERSRegistry(newTracersRegistry);
        emit TRACERSRegistryUpdated(msg.sender, oldTracersRegistry, newTracersRegistry);
    }

    /// @inheritdoc ITRACE
    function addVerifiedStory(uint256[] calldata tokenIds, string[] calldata stories, bytes[] calldata signatures)
        external
    {
        if (tokenIds.length != stories.length && stories.length != signatures.length) {
            revert ArrayLengthMismatch();
        }
        for (uint256 i = 0; i < tokenIds.length; i++) {
            // get variables
            uint256 tokenId = tokenIds[i];
            string memory story = stories[i];
            bytes memory signature = signatures[i];

            // add verified story
            _addVerifiedStory(tokenId, story, signature);
        }
    }

    /*//////////////////////////////////////////////////////////////////////////
                                Royalty Functions
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc ICreatorBase
    function setDefaultRoyalty(address newRecipient, uint256 newPercentage) external onlyRoleOrOwner(ADMIN_ROLE) {
        _setDefaultRoyaltyInfo(newRecipient, newPercentage);
    }

    /// @inheritdoc ICreatorBase
    function setTokenRoyalty(uint256 tokenId, address newRecipient, uint256 newPercentage)
        external
        onlyRoleOrOwner(ADMIN_ROLE)
    {
        _overrideTokenRoyaltyInfo(tokenId, newRecipient, newPercentage);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                Metadata Update Functions
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc ITRACE
    function setTokenUri(uint256 tokenId, string calldata newUri) external onlyRoleOrOwner(ADMIN_ROLE) {
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
                                Story Inscriptions
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc IStory
    /// @dev ignores the creator name to avoid sybil
    function addCollectionStory(string calldata, /*creatorName*/ string calldata story)
        external
        onlyRoleOrOwner(ADMIN_ROLE)
    {
        emit CollectionStory(msg.sender, msg.sender.toHexString(), story);
    }

    /// @inheritdoc IStory
    /// @dev ignores the creator name to avoid sybil
    function addCreatorStory(uint256 tokenId, string calldata, /*creatorName*/ string calldata story)
        external
        onlyRoleOrOwner(ADMIN_ROLE)
    {
        if (!_exists(tokenId)) revert TokenDoesntExist();
        emit CreatorStory(tokenId, msg.sender, msg.sender.toHexString(), story);
    }

    /// @inheritdoc IStory
    function addStory(uint256, /*tokenId*/ string calldata, /*collectorName*/ string calldata /*story*/ )
        external
        pure
    {
        revert();
    }

    /// @inheritdoc ICreatorBase
    function setStoryStatus(bool /*status*/ ) external pure {
        revert();
    }

    /// @inheritdoc ICreatorBase
    function storyEnabled() external pure returns (bool) {
        return true;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                BlockList
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc ICreatorBase
    function setBlockListRegistry(address /*newBlockListRegistry*/ ) external pure {
        revert();
    }

    /// @inheritdoc ICreatorBase
    function blocklistRegistry() external pure returns (IBlockListRegistry) {
        return IBlockListRegistry(address(0));
    }

    /*//////////////////////////////////////////////////////////////////////////
                            NFT Delegation Registry
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc ICreatorBase
    function setNftDelegationRegistry(address /*newNftDelegationRegistry*/ ) external pure {
        revert();
    }

    /// @inheritdoc ICreatorBase
    function tlNftDelegationRegistry() external pure returns (ITLNftDelegationRegistry) {
        return ITLNftDelegationRegistry(address(0));
    }

    /*//////////////////////////////////////////////////////////////////////////
                                ERC-165 Support
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Upgradeable, EIP2981TLUpgradeable, IERC165)
        returns (bool)
    {
        return (
            ERC721Upgradeable.supportsInterface(interfaceId) || EIP2981TLUpgradeable.supportsInterface(interfaceId)
                || interfaceId == 0x49064906 // ERC-4906
                || interfaceId == type(ICreatorBase).interfaceId || interfaceId == type(IStory).interfaceId
                || interfaceId == 0x0d23ecb9 // previous story contract version that is still supported
                || interfaceId == type(ITRACE).interfaceId
        );
    }

    /*//////////////////////////////////////////////////////////////////////////
                                Internal Functions
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

    /// @notice Function to check if a token exists
    /// @param tokenId The token id to check
    function _exists(uint256 tokenId) internal view returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }

    /// @notice Function to add a verified story in a reusable way
    function _addVerifiedStory(uint256 tokenId, string memory story, bytes memory signature) internal {
        // default name to hex address
        string memory registeredAgentName = msg.sender.toHexString();

        // only check registered agent if the registry is not the zero address
        if (address(tracersRegistry) != address(0)) {
            bool isRegisteredAgent;
            (isRegisteredAgent, registeredAgentName) = tracersRegistry.isRegisteredAgent(msg.sender);
            if (!isRegisteredAgent) revert Unauthorized();
        }

        // verify signature
        bytes32 verifiedStoryHash = _hashVerifiedStory(address(this), tokenId, story);
        if (_verifiedStoryHashUsed[verifiedStoryHash]) revert VerifiedStoryAlreadyWritten();
        _verifiedStoryHashUsed[verifiedStoryHash] = true;
        address tokenOwner = ownerOf(tokenId);
        bytes32 digest = _hashTypedDataV4(verifiedStoryHash);
        if (tokenOwner != ECDSA.recover(digest, signature)) revert InvalidSignature();

        // emit story
        emit Story(tokenId, msg.sender, registeredAgentName, story);
    }

    /// @notice Function to hash the typed data
    function _hashVerifiedStory(address nftContract, uint256 tokenId, string memory story)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                // keccak256("VerifiedStory(address nftContract,uint256 tokenId,string story)"),
                0x76b12200216600191228eb643bc7cba6e319d03951a863e3306595415759682b,
                nftContract,
                tokenId,
                keccak256(bytes(story))
            )
        );
    }
}

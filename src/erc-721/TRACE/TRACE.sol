// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {IERC2309} from "openzeppelin/interfaces/IERC2309.sol";
import {IERC4906} from "openzeppelin/interfaces/IERC4906.sol";
import {Strings} from "openzeppelin/utils/Strings.sol";
import {ECDSA} from "openzeppelin/utils/cryptography/ECDSA.sol";
import {
    ERC721Upgradeable, IERC165
} from "openzeppelin-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {OwnableAccessControlUpgradeable} from "tl-sol-tools/upgradeable/access/OwnableAccessControlUpgradeable.sol";
import {EIP2981TLUpgradeable} from "tl-sol-tools/upgradeable/royalties/EIP2981TLUpgradeable.sol";
import {ITRACE} from "src/trace/ITRACE.sol";
import {IBlockListRegistry} from "src/interfaces/IBlockListRegistry.sol";
import {ICreatorBase} from "src/interfaces/ICreatorBase.sol";
import {IStory} from "src/interfaces/IStory.sol";
import {ITLNftDelegationRegistry} from "src/interfaces/ITLNftDelegationRegistry.sol";
import {EIP712Upgradeable} from "openzeppelin-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import {EIP2981TLUpgradeable} from "tl-sol-tools/upgradeable/royalties/EIP2981TLUpgradeable.sol";
import {OwnableAccessControlUpgradeable} from "tl-sol-tools/upgradeable/access/OwnableAccessControlUpgradeable.sol";
import {ITRACERSRegistry} from "src/interfaces/ITRACERSRegistry.sol";

/// @title TRACE.sol
/// @notice Transient Labs T.R.A.C.E. implementation contract
/// @author transientlabs.xyz
/// @custom:version 3.0.0
contract TRACE is
    ERC721Upgradeable,
    OwnableAccessControlUpgradeable,
    EIP2981TLUpgradeable,
    EIP712Upgradeable,
    ICreatorBase,
    ITRACE,
    IStory,
    IERC2309,
    IERC4906
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
    using Strings for uint256;

    /// @dev string representation for address
    using Strings for address;

    /*//////////////////////////////////////////////////////////////////////////
                                State Variables
    //////////////////////////////////////////////////////////////////////////*/

    string public constant VERSION = "3.0.0";
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    ITRACERSRegistry public tracersRegistry;
    uint256 private _counter; // token ids
    mapping(uint256 => string) private _tokenUris; // established token uris
    mapping(uint256 => uint256) private _tokenNonces; // token nonces to prevent replay attacks
    BatchMint[] private _batchMints; // dynamic array for batch mints

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
                                Constructor
    //////////////////////////////////////////////////////////////////////////*/

    /// @param disable Boolean to disable initialization for the implementation contract
    constructor(bool disable) {
        if (disable) _disableInitializers();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                Initializer
    //////////////////////////////////////////////////////////////////////////*/

    /// @param name The name of the contract
    /// @param symbol The symbol of the contract
    /// @param defaultRoyaltyRecipient The default address for royalty payments
    /// @param defaultRoyaltyPercentage The default royalty percentage of basis points (out of 10,000)
    /// @param initOwner The owner of the contract
    /// @param admins Array of admin addresses to add to the contract
    /// @param defaultTracersRegistry Address of the TRACERS registry to use
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
        __EIP712_init("T.R.A.C.E.", "1");

        // add admins
        _setRole(ADMIN_ROLE, admins, true);

        // set TRACERS Registry
        tracersRegistry = ITRACERSRegistry(defaultTracersRegistry);
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
    function setApprovedMintContracts(address[] calldata /*minters*/, bool /*status*/) external {
        revert("N/A");
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
        tracersRegistry = ITRACERSRegistry(newTracersRegistry);
    }

    /// @inheritdoc ITRACE
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
        if (tokenOwner != ECDSA.recover(digest, signature)) revert InvalidSignature();

        // emit story
        emit Story(tokenId, msg.sender, registeredAgentName, story);
    }

    /// @inheritdoc ITRACE
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
                                Story Inscriptions
    //////////////////////////////////////////////////////////////////////////*/

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
                || interfaceId == type(IERC2309).interfaceId
                || interfaceId == type(IERC4906).interfaceId 
                || interfaceId == type(IStory).interfaceId || interfaceId == 0x0d23ecb9 // previous story contract version that is still supported
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
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {IERC4906} from "@openzeppelin-contracts-5.0.2/interfaces/IERC4906.sol";
import {Strings} from "@openzeppelin-contracts-5.0.2/utils/Strings.sol";
import {ERC721Upgradeable, IERC165, IERC721} from "@openzeppelin-contracts-upgradeable-5.0.2/token/ERC721/ERC721Upgradeable.sol";
import {OwnableAccessControlUpgradeable} from "tl-sol-tools-3.1.4/upgradeable/access/OwnableAccessControlUpgradeable.sol";
import {EIP2981TLUpgradeable} from "tl-sol-tools-3.1.4/upgradeable/royalties/EIP2981TLUpgradeable.sol";
import {IBlockListRegistry} from "../../interfaces/IBlockListRegistry.sol";
import {ICreatorBase} from "../../interfaces/ICreatorBase.sol";
import {IERC7160} from "../../interfaces/IERC7160.sol";
import {IStory} from "../../interfaces/IStory.sol";
import {ITLNftDelegationRegistry} from "../../interfaces/ITLNftDelegationRegistry.sol";
import {IERC721TL} from "../IERC721TL.sol";

/// @title ERC7160TL.sol
/// @notice Sovereign ERC-7160 Creator Contract with Story Inscriptions
/// @author transientlabs.xyz
/// @custom:version 3.1.1
contract ERC7160TL is
    ERC721Upgradeable,
    EIP2981TLUpgradeable,
    OwnableAccessControlUpgradeable,
    ICreatorBase,
    IERC721TL,
    IStory,
    IERC4906,
    IERC7160
{
    /*//////////////////////////////////////////////////////////////////////////
                                Custom Types
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Struct defining a batch mint
    struct BatchMint {
        address creator;
        uint256 fromTokenId;
        uint256 toTokenId;
        string baseUri;
    }

    /// @dev Struct for specifying base uri index and folder index
    struct MetadataLoc {
        uint128 baseUriIndex;
        uint128 folderIndex;
    }

    /// @dev Struct for holding additional metadata used in ERC-7160
    struct MultiMetadata {
        bool pinned;
        uint256 index;
        MetadataLoc[] metadataLocs;
    }

    /// @dev String representation of uint256
    using Strings for uint256;

    /// @dev String representation for address
    using Strings for address;

    /*//////////////////////////////////////////////////////////////////////////
                                State Variables
    //////////////////////////////////////////////////////////////////////////*/

    string public constant VERSION = "3.1.1";
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant APPROVED_MINT_CONTRACT = keccak256("APPROVED_MINT_CONTRACT");
    uint256 private _counter; // token ids
    bool public storyEnabled;
    bool public floatWhenUnpinned;
    ITLNftDelegationRegistry public tlNftDelegationRegistry;
    IBlockListRegistry public blocklistRegistry;
    mapping(uint256 => bool) private _burned; // flag to see if a token is burned or not -- needed for burning batch mints
    mapping(uint256 => string) private _tokenUris;
    mapping(uint256 => MultiMetadata) private _multiMetadatas;
    string[] private _multiMetadataBaseUris;
    BatchMint[] private _batchMints; // dynamic array for batch mints

    /*//////////////////////////////////////////////////////////////////////////
                                Custom Errors
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Token uri is an empty string
    error EmptyTokenURI();

    /// @dev Mint to zero address
    error MintToZeroAddress();

    /// @dev Batch size too small
    error BatchSizeTooSmall();

    /// @dev Airdrop to too few addresses
    error AirdropTooFewAddresses();

    /// @dev Caller is not approved or owner
    error CallerNotApprovedOrOwner();

    /// @dev Token does not exist
    error TokenDoesntExist();

    /// @dev Index given for ERC-7160 is invalid
    error InvalidTokenURIIndex();

    /// @dev No tokens in tokenIds array
    error NoTokensSpecified();

    /// @dev Not owner, admin, or mint contract
    error NotOwnerAdminOrMintContract();

    /// @dev Caller is not the owner or delegate of the owner of the specific token
    error CallerNotTokenOwnerOrDelegate();

    /// @dev Operator for token approvals blocked
    error OperatorBlocked();

    /// @dev Story not enabled for collectors
    error StoryNotEnabled();

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

    /// @param name The name of the 721 contract
    /// @param symbol The symbol of the 721 contract
    /// @param personalization A string to emit as a collection story. Can be ASCII art or something else that is a personalization of the contract.
    /// @param defaultRoyaltyRecipient The default address for royalty payments
    /// @param defaultRoyaltyPercentage The default royalty percentage of basis points (out of 10,000)
    /// @param initOwner The owner of the contract
    /// @param admins Array of admin addresses to add to the contract
    /// @param enableStory A bool deciding whether to add story fuctionality or not
    /// @param initBlockListRegistry Address of the blocklist registry to use
    /// @param initNftDelegationRegistry Address of the TL nft delegation registry to use
    function initialize(
        string memory name,
        string memory symbol,
        string memory personalization,
        address defaultRoyaltyRecipient,
        uint256 defaultRoyaltyPercentage,
        address initOwner,
        address[] memory admins,
        bool enableStory,
        address initBlockListRegistry,
        address initNftDelegationRegistry
    ) external initializer {
        // initialize parent contracts
        __ERC721_init(name, symbol);
        __EIP2981TL_init(defaultRoyaltyRecipient, defaultRoyaltyPercentage);
        __OwnableAccessControl_init(initOwner);

        // add admins
        _setRole(ADMIN_ROLE, admins, true);

        // story
        storyEnabled = enableStory;
        emit StoryStatusUpdate(initOwner, enableStory);

        // blocklist and nft delegation registry
        blocklistRegistry = IBlockListRegistry(initBlockListRegistry);
        emit BlockListRegistryUpdate(initOwner, address(0), initBlockListRegistry);
        tlNftDelegationRegistry = ITLNftDelegationRegistry(initNftDelegationRegistry);
        emit NftDelegationRegistryUpdate(initOwner, address(0), initNftDelegationRegistry);

        // emit personalization as collection story
        if (bytes(personalization).length > 0) {
            emit CollectionStory(initOwner, initOwner.toHexString(), personalization);
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

    /// @inheritdoc IERC721TL
    function mint(address recipient, string calldata uri) external onlyRoleOrOwner(ADMIN_ROLE) {
        if (bytes(uri).length == 0) revert EmptyTokenURI();
        _counter++;
        _tokenUris[_counter] = uri;
        _mint(recipient, _counter);
    }

    /// @inheritdoc IERC721TL
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

    /// @inheritdoc IERC721TL
    function batchMint(address recipient, uint128 numTokens, string calldata baseUri)
        external
        onlyRoleOrOwner(ADMIN_ROLE)
    {
        if (recipient == address(0)) revert MintToZeroAddress();
        if (bytes(baseUri).length == 0) revert EmptyTokenURI();
        if (numTokens < 2) revert BatchSizeTooSmall();
        uint256 start = _counter + 1;
        uint256 end = start + numTokens - 1;
        _counter += numTokens;
        _batchMints.push(BatchMint(recipient, start, end, baseUri));

        _increaseBalance(recipient, numTokens); // this function adds the number of tokens to the recipient address

        for (uint256 id = start; id < end + 1; ++id) {
            emit Transfer(address(0), recipient, id);
        }
    }

    /// @inheritdoc IERC721TL
    function airdrop(address[] calldata addresses, string calldata baseUri) external onlyRoleOrOwner(ADMIN_ROLE) {
        if (bytes(baseUri).length == 0) revert EmptyTokenURI();
        if (addresses.length < 2) revert AirdropTooFewAddresses();

        uint256 start = _counter + 1;
        uint256 end = start + addresses.length - 1;
        _counter += addresses.length;
        _batchMints.push(BatchMint(address(0), start, end, baseUri));
        for (uint256 i = 0; i < addresses.length; i++) {
            _mint(addresses[i], start + i);
        }
    }

    /// @inheritdoc IERC721TL
    function externalMint(address recipient, string calldata uri) external onlyRole(APPROVED_MINT_CONTRACT) {
        if (bytes(uri).length == 0) revert EmptyTokenURI();
        _counter++;
        _tokenUris[_counter] = uri;
        _mint(recipient, _counter);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                Burn Functions
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc IERC721TL
    function burn(uint256 tokenId) external {
        address owner = ownerOf(tokenId);
        if (!_isAuthorized(owner, msg.sender, tokenId)) revert CallerNotApprovedOrOwner();
        _burn(tokenId);
        _burned[tokenId] = true;
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
                                ERC-7160 Functions
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Function to change the unpinned display state
    /// @dev floating means that the last item in the tokenUris array will be returned from `tokenUri`
    /// @dev if not floating, the first item in the tokenUris array is returned
    /// @param float Bool indicating whether to float or not
    function setUnpinnedFloatState(bool float) external onlyRoleOrOwner(ADMIN_ROLE) {
        floatWhenUnpinned = float;
        emit BatchMetadataUpdate(1, _counter);
    }


    /// @notice Function to add token uris
    /// @dev Written to take in many token ids and a base uri that contains metadata files with file names matching the index of each token id in the `tokenIds` array (aka folderIndex)
    /// @dev No trailing slash on the base uri
    /// @dev Must be called by contract owner, admin, or approved mint contract
    /// @param tokenIds Array of token ids that get metadata added to them
    /// @param baseUri The base uri of a folder containing metadata - file names start at 0 and increase monotonically
    function addTokenUris(uint256[] calldata tokenIds, string calldata baseUri) external {
        if (msg.sender != owner() && !hasRole(ADMIN_ROLE, msg.sender) && !hasRole(APPROVED_MINT_CONTRACT, msg.sender)) {
            revert NotOwnerAdminOrMintContract();
        }
        if (bytes(baseUri).length == 0) revert EmptyTokenURI();
        if (tokenIds.length == 0) revert NoTokensSpecified();
        uint128 baseUriIndex = uint128(_multiMetadataBaseUris.length);
        _multiMetadataBaseUris.push(baseUri);
        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (!_exists(tokenIds[i])) revert TokenDoesntExist();
            MetadataLoc memory m = MetadataLoc(baseUriIndex, uint128(i));
            _multiMetadatas[tokenIds[i]].metadataLocs.push(m);
            emit MetadataUpdate(tokenIds[i]);
        }
    }

    /// @inheritdoc IERC7160
    function tokenURIs(uint256 tokenId) external view returns (uint256 index, string[] memory uris, bool pinned) {
        if (!_exists(tokenId)) revert TokenDoesntExist();
        MultiMetadata memory multiMetadata = _multiMetadatas[tokenId];
        // build uris
        uris = new string[](multiMetadata.metadataLocs.length + 1);
        uris[0] = _getMintedMetadataUri(tokenId);
        for (uint256 i = 0; i < multiMetadata.metadataLocs.length; i++) {
            uris[i + 1] = _getMultiMetadataUri(multiMetadata, i);
        }
        // get if pinned
        pinned = multiMetadata.pinned;

        // set index
        if (pinned) {
            index = multiMetadata.index;
        } else {
            index = floatWhenUnpinned ? uris.length - 1 : 0;
        }
    }

    /// @inheritdoc IERC7160
    function pinTokenURI(uint256 tokenId, uint256 index) external {
        if (!_exists(tokenId)) revert TokenDoesntExist();
        if (!_isTokenOwnerOrDelegate(tokenId)) revert CallerNotTokenOwnerOrDelegate();
        if (index > _multiMetadatas[tokenId].metadataLocs.length) {
            revert InvalidTokenURIIndex();
        }

        _multiMetadatas[tokenId].index = index;
        _multiMetadatas[tokenId].pinned = true;

        emit TokenUriPinned(tokenId, index);
        emit MetadataUpdate(tokenId);
    }

    /// @inheritdoc IERC7160
    function unpinTokenURI(uint256 tokenId) external {
        if (!_exists(tokenId)) revert TokenDoesntExist();
        if (!_isTokenOwnerOrDelegate(tokenId)) revert CallerNotTokenOwnerOrDelegate();

        _multiMetadatas[tokenId].pinned = false;

        emit TokenUriUnpinned(tokenId);
        emit MetadataUpdate(tokenId);
    }

    /// @inheritdoc IERC7160
    function hasPinnedTokenURI(uint256 tokenId) external view returns (bool) {
        if (!_exists(tokenId)) revert TokenDoesntExist();
        return _multiMetadatas[tokenId].pinned;
    }

    /// @inheritdoc ERC721Upgradeable
    function tokenURI(uint256 tokenId) public view override(ERC721Upgradeable) returns (string memory uri) {
        if (!_exists(tokenId)) revert TokenDoesntExist();
        MultiMetadata memory multiMetadata = _multiMetadatas[tokenId];
        if (multiMetadata.pinned) {
            if (multiMetadata.index == 0) {
                uri = _getMintedMetadataUri(tokenId);
            } else {
                uri = _getMultiMetadataUri(multiMetadata, multiMetadata.index - 1);
            }
        } else {
            if (multiMetadata.metadataLocs.length == 0 || !floatWhenUnpinned) {
                uri = _getMintedMetadataUri(tokenId);
            } else {
                uri = _getMultiMetadataUri(multiMetadata, multiMetadata.metadataLocs.length - 1);
            }
        }
    }

    /*//////////////////////////////////////////////////////////////////////////
                                Story Inscriptions
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc IStory
    function addCollectionStory(string calldata, /*creatorName*/ string calldata story)
        external
        onlyRoleOrOwner(ADMIN_ROLE)
    {
        emit CollectionStory(msg.sender, msg.sender.toHexString(), story);
    }

    /// @inheritdoc IStory
    function addCreatorStory(uint256 tokenId, string calldata, /*creatorName*/ string calldata story)
        external
        onlyRoleOrOwner(ADMIN_ROLE)
    {
        if (!_exists(tokenId)) revert TokenDoesntExist();
        emit CreatorStory(tokenId, msg.sender, msg.sender.toHexString(), story);
    }

    /// @inheritdoc IStory
    function addStory(uint256 tokenId, string calldata, /*collectorName*/ string calldata story) external {
        if (!storyEnabled) revert StoryNotEnabled();
        if (!_isTokenOwnerOrDelegate(tokenId)) revert CallerNotTokenOwnerOrDelegate();
        emit Story(tokenId, msg.sender, msg.sender.toHexString(), story);
    }

    /// @inheritdoc ICreatorBase
    function setStoryStatus(bool status) external onlyRoleOrOwner(ADMIN_ROLE) {
        storyEnabled = status;
        emit StoryStatusUpdate(msg.sender, status);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                BlockList
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc ICreatorBase
    function setBlockListRegistry(address newBlockListRegistry) external onlyRoleOrOwner(ADMIN_ROLE) {
        address oldBlockListRegistry = address(blocklistRegistry);
        blocklistRegistry = IBlockListRegistry(newBlockListRegistry);
        emit BlockListRegistryUpdate(msg.sender, oldBlockListRegistry, newBlockListRegistry);
    }

    /// @inheritdoc ERC721Upgradeable
    function approve(address to, uint256 tokenId) public override(ERC721Upgradeable, IERC721) {
        if (_isOperatorBlocked(to)) revert OperatorBlocked();
        ERC721Upgradeable.approve(to, tokenId);
    }

    /// @inheritdoc ERC721Upgradeable
    function setApprovalForAll(address operator, bool approved) public override(ERC721Upgradeable, IERC721) {
        if (approved) {
            if (_isOperatorBlocked(operator)) revert OperatorBlocked();
        }
        ERC721Upgradeable.setApprovalForAll(operator, approved);
    }

    /*//////////////////////////////////////////////////////////////////////////
                            NFT Delegation Registry
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc ICreatorBase
    function setNftDelegationRegistry(address newNftDelegationRegistry) external onlyRoleOrOwner(ADMIN_ROLE) {
        address oldNftDelegationRegistry = address(tlNftDelegationRegistry);
        tlNftDelegationRegistry = ITLNftDelegationRegistry(newNftDelegationRegistry);
        emit NftDelegationRegistryUpdate(msg.sender, oldNftDelegationRegistry, newNftDelegationRegistry);
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
                || interfaceId == type(IERC7160).interfaceId || interfaceId == type(ICreatorBase).interfaceId
                || interfaceId == type(IStory).interfaceId || interfaceId == 0x0d23ecb9 // previous story contract version that is still supported
                || interfaceId == type(IERC721TL).interfaceId
        );
    }

    /*//////////////////////////////////////////////////////////////////////////
                                Internal Functions
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Function to get batch mint info
    /// @param tokenId Token id to look up for batch mint info
    /// @return adress The token owner
    /// @return string The uri for the tokenId
    function _getBatchInfo(uint256 tokenId) internal view returns (address, string memory) {
        uint256 i = 0;
        for (i; i < _batchMints.length; i++) {
            if (tokenId >= _batchMints[i].fromTokenId && tokenId <= _batchMints[i].toTokenId) {
                break;
            }
        }
        if (i >= _batchMints.length) {
            return (address(0), "");
        }
        string memory tokenUri =
            string(abi.encodePacked(_batchMints[i].baseUri, "/", (tokenId - _batchMints[i].fromTokenId).toString()));
        return (_batchMints[i].creator, tokenUri);
    }

    /// @notice Function to override { ERC721Upgradeable._ownerOf } to allow for batch minting
    /// @inheritdoc ERC721Upgradeable
    function _ownerOf(uint256 tokenId) internal view override(ERC721Upgradeable) returns (address) {
        if (_burned[tokenId]) {
            return address(0);
        } else {
            if (tokenId > 0 && tokenId <= _counter) {
                address owner = ERC721Upgradeable._ownerOf(tokenId);
                if (owner == address(0)) {
                    // see if can find token in a batch mint
                    (owner,) = _getBatchInfo(tokenId);
                }
                return owner;
            } else {
                return address(0);
            }
        }
    }

    /// @notice internal function to get original metadata uri from mint
    function _getMintedMetadataUri(uint256 tokenId) internal view returns (string memory uri) {
        uri = _tokenUris[tokenId];
        if (bytes(uri).length == 0) {
            (, uri) = _getBatchInfo(tokenId);
        }
    }

    /// @notice internal function to help get metadata from multi-metadata struct
    /// @param multiMetadata The multimMtadata struct in memory
    /// @param index The index of the multiMetadataLoc
    function _getMultiMetadataUri(MultiMetadata memory multiMetadata, uint256 index)
        internal
        view
        returns (string memory uri)
    {
        uri = string(
            abi.encodePacked(
                _multiMetadataBaseUris[multiMetadata.metadataLocs[index].baseUriIndex],
                "/",
                uint256(multiMetadata.metadataLocs[index].folderIndex).toString()
            )
        );
    }

    /// @notice Function to check if a token exists
    /// @param tokenId The token id to check
    function _exists(uint256 tokenId) internal view returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }

    /// @notice Function to get if msg.sender is the token owner or delegated owner
    function _isTokenOwnerOrDelegate(uint256 tokenId) internal view returns (bool) {
        address tokenOwner = _ownerOf(tokenId);
        if (msg.sender == tokenOwner) {
            return true;
        } else if (address(tlNftDelegationRegistry) == address(0)) {
            return false;
        } else {
            return tlNftDelegationRegistry.checkDelegateForERC721(msg.sender, tokenOwner, address(this), tokenId);
        }
    }

    // @notice Function to get if an operator is blocked for token approvals
    function _isOperatorBlocked(address operator) internal view returns (bool) {
        if (address(blocklistRegistry) == address(0)) {
            return false;
        } else {
            return blocklistRegistry.getBlockListStatus(operator);
        }
    }
}

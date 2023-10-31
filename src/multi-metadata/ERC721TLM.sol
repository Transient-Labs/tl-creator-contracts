// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Initializable} from "openzeppelin-upgradeable/proxy/utils/Initializable.sol";
import {ERC721Upgradeable, ERC165Upgradeable} from "openzeppelin-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {IERC2309Upgradeable} from "openzeppelin-upgradeable/interfaces/IERC2309Upgradeable.sol";
import {StringsUpgradeable} from "openzeppelin-upgradeable/utils/StringsUpgradeable.sol";
import {EIP2981TLUpgradeable} from "tl-sol-tools/upgradeable/royalties/EIP2981TLUpgradeable.sol";
import {OwnableAccessControlUpgradeable} from "tl-sol-tools/upgradeable/access/OwnableAccessControlUpgradeable.sol";
import {StoryContractUpgradeable} from "tl-story/upgradeable/StoryContractUpgradeable.sol";
import {BlockListUpgradeable} from "tl-blocklist/BlockListUpgradeable.sol";
import {IERC7160} from "./IERC7160.sol";

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

/// @dev index given for ERC-7160 is invalid
error InvalidTokenURIIndex();

/// @dev mismatching array length
error ArrayLengthMismatch();

/*//////////////////////////////////////////////////////////////////////////
                            ERC721TLM
//////////////////////////////////////////////////////////////////////////*/

/// @title ERC721TLM.sol
/// @notice Transient Labs ERC-721 Creator Contract with multi-metadata support (ERC-7160)
/// @dev features include
///      - ultra efficient batch minting
///      - airdrops
///      - ability to hook in external mint contracts
///      - ability to set multiple admins
///      - Story Contract
///      - BlockList
///      - Multi-metadata per ERC-7160
///      - individual token royalty overrides
/// @dev When unpinned, the latest metadata added for a token is returned from `tokenURI` and `tokenURIs`
/// @author transientlabs.xyz
/// @custom:version 2.8.0
contract ERC721TLM is
    Initializable,
    ERC721Upgradeable,
    EIP2981TLUpgradeable,
    OwnableAccessControlUpgradeable,
    StoryContractUpgradeable,
    BlockListUpgradeable,
    IERC2309Upgradeable,
    IERC7160
{
    /*//////////////////////////////////////////////////////////////////////////
                                Custom Types
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev struct defining a batch mint
    struct BatchMint {
        address creator;
        uint256 fromTokenId;
        uint256 toTokenId;
        string baseUri;
    }

    /// @dev struct for holding additional metadata used in ERC-7160
    struct MultiMetadata {
        bool pinned;
        uint256 index;
        uint256[] baseUriIndices;
    }

    /// @dev string representation of uint256
    using StringsUpgradeable for uint256;

    /*//////////////////////////////////////////////////////////////////////////
                                State Variables
    //////////////////////////////////////////////////////////////////////////*/

    string public constant VERSION = "2.8.0";
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant APPROVED_MINT_CONTRACT = keccak256("APPROVED_MINT_CONTRACT");
    uint256 private _counter; // token ids
    mapping(uint256 => bool) private _burned; // flag to see if a token is burned or not -- needed for burning batch mints
    mapping(uint256 => string) private _tokenUris;
    mapping(uint256 => MultiMetadata) private _multiMetadatas;
    string[] private _multiMetadataBaseUris;
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

    /// @param name: the name of the 721 contract
    /// @param symbol: the symbol of the 721 contract
    /// @param defaultRoyaltyRecipient: the default address for royalty payments
    /// @param defaultRoyaltyPercentage: the default royalty percentage of basis points (out of 10,000)
    /// @param initOwner: the owner of the contract
    /// @param admins: array of admin addresses to add to the contract
    /// @param enableStory: a bool deciding whether to add story fuctionality or not
    /// @param blockListRegistry: address of the blocklist registry to use
    function initialize(
        string memory name,
        string memory symbol,
        address defaultRoyaltyRecipient,
        uint256 defaultRoyaltyPercentage,
        address initOwner,
        address[] memory admins,
        bool enableStory,
        address blockListRegistry
    ) external initializer {
        // initialize parent contracts
        __ERC721_init(name, symbol);
        __EIP2981TL_init(defaultRoyaltyRecipient, defaultRoyaltyPercentage);
        __OwnableAccessControl_init(initOwner);
        __StoryContractUpgradeable_init(enableStory);
        __BlockList_init(blockListRegistry);

        // add admins
        _setRole(ADMIN_ROLE, admins, true);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                General Functions
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice function to get total supply minted so far
    function totalSupply() external view returns (uint256) {
        return _counter;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                Access Control Functions
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice function to set approved mint contracts
    /// @dev access to owner or admin
    /// @param minters: array of minters to grant approval to
    /// @param status: status for the minters
    function setApprovedMintContracts(address[] calldata minters, bool status) external onlyRoleOrOwner(ADMIN_ROLE) {
        _setRole(APPROVED_MINT_CONTRACT, minters, status);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                Mint Functions
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice function to mint a single token
    /// @dev requires owner or admin
    /// @param recipient: the recipient of the token - assumed as able to receive 721 tokens
    /// @param uri: the token uri to mint
    function mint(address recipient, string calldata uri) external onlyRoleOrOwner(ADMIN_ROLE) {
        if (bytes(uri).length == 0) revert EmptyTokenURI();
        _counter++;
        _tokenUris[_counter] = uri;
        _mint(recipient, _counter);
    }

    /// @notice function to mint a single token with specific token royalty
    /// @dev requires owner or admin
    /// @param recipient: the recipient of the token - assumed as able to receive 721 tokens
    /// @param uri: the token uri to mint
    /// @param royaltyAddress: royalty payout address for this new token
    /// @param royaltyPercent: royalty percentage for this new token
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

    /// @notice function to batch mint tokens
    /// @dev requires owner or admin
    /// @param recipient: the recipient of the token - assumed as able to receive 721 tokens
    /// @param numTokens: number of tokens in the batch mint
    /// @param baseUri: the base uri for the batch, expecting json to be in order and starting at 0
    ///                 NOTE: this folder should have the same number of json files in it as numTokens
    ///                 NOTE: files should be named without any file extension
    ///                 NOTE: baseUri should NOT have a trailing `/`
    function batchMint(address recipient, uint256 numTokens, string calldata baseUri)
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

        __unsafe_increaseBalance(recipient, numTokens); // this function adds the number of tokens to the recipient address

        for (uint256 id = start; id < end + 1; ++id) {
            emit Transfer(address(0), recipient, id);
        }
    }

    /// @notice function to batch mint tokens, ultra gas savings with ERC-2309
    /// @dev requires owner or admin
    /// @dev uses ERC-2309. BEWARE may not be compatible with all platforms
    /// @param recipient: the recipient of the token - assumed as able to receive 721 tokens
    /// @param numTokens: number of tokens in the batch mint
    /// @param baseUri: the base uri for the batch, expecting json to be in order and starting at 0
    ///                 NOTE: this folder should have the same number of json files in it as numTokens
    ///                 NOTE: files should be named without any file extension
    ///                 NOTE: baseUri should NOT have a trailing `/`
    function batchMintUltra(address recipient, uint256 numTokens, string calldata baseUri)
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

        __unsafe_increaseBalance(recipient, numTokens); // this function adds the number of tokens to the recipient address

        emit ConsecutiveTransfer(start, end, address(0), recipient);
    }

    /// @notice function to airdrop tokens to addresses
    /// @dev requires owner or admin
    /// @dev utilizes batch mint token uri values to save some gas
    ///      but still ultimately mints individual tokens to people
    /// @param addresses: dynamic array of addresses to mint to
    /// @param baseUri: the base uri for the batch, expecting json to be in order and starting at 0
    ///                 NOTE: the number of json files in this folder should be equal to the number of addresses
    ///                 NOTE: files should be named without any file extension
    ///                 NOTE: baseUri should not have a trailing `/`
    function airdrop(address[] calldata addresses, string calldata baseUri) external onlyRoleOrOwner(ADMIN_ROLE) {
        if (bytes(baseUri).length == 0) revert EmptyTokenURI();
        if (addresses.length < 2) revert AirdropTooFewAddresses();

        uint256 start = _counter + 1;
        _counter += addresses.length;
        _batchMints.push(BatchMint(address(0), start, start + addresses.length, baseUri));
        for (uint256 i = 0; i < addresses.length; i++) {
            _mint(addresses[i], start + i);
        }
    }

    /// @notice function to allow an approved mint contract to mint
    /// @dev requires the contract to be an approved mint contract
    /// @param recipient: the recipient of the token - assumed as able to receive 721 tokens
    /// @param uri: the token uri to mint
    function externalMint(address recipient, string calldata uri) external onlyRole(APPROVED_MINT_CONTRACT) {
        if (bytes(uri).length == 0) revert EmptyTokenURI();
        _counter++;
        _tokenUris[_counter] = uri;
        _mint(recipient, _counter);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                Batch Mint Functions
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice function to get batch mint info
    /// @param tokenId: token id to look up for batch mint info
    /// @return owner of the token (address)
    /// @return string of the uri for the tokenId
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

    /// @notice function to override { ERC721Upgradeable._ownerOf } to allow for batch minting
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

    /*//////////////////////////////////////////////////////////////////////////
                                Burn Functions
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice function to burn a token
    /// @dev caller must be approved or owner of the token
    /// @param tokenId: the token to burn
    function burn(uint256 tokenId) external {
        if (!_isApprovedOrOwner(msg.sender, tokenId)) revert CallerNotApprovedOrOwner();
        _burn(tokenId);
        _burned[tokenId] = true;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                Royalty Functions
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice function to set the default royalty specification
    /// @dev requires owner
    /// @param newRecipient: the new royalty payout address
    /// @param newPercentage: the new royalty percentage in basis (out of 10,000)
    function setDefaultRoyalty(address newRecipient, uint256 newPercentage) external onlyOwner {
        _setDefaultRoyaltyInfo(newRecipient, newPercentage);
    }

    /// @notice function to override a token's royalty info
    /// @dev requires owner
    /// @param tokenId: the token to override royalty for
    /// @param newRecipient: the new royalty payout address for the token id
    /// @param newPercentage: the new royalty percentage in basis (out of 10,000) for the token id
    function setTokenRoyalty(uint256 tokenId, address newRecipient, uint256 newPercentage) external onlyOwner {
        _overrideTokenRoyaltyInfo(tokenId, newRecipient, newPercentage);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                ERC-7160 Functions
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice function to add token uris
    /// @dev written to take in many token ids and a base uri that contains metadata files with file names matching the token id
    /// @dev no trailing slash on the base uri
    /// @param tokenIds: array of token ids that get metadata added to them
    /// @param baseUri: the base uri of a folder containing metadata - file names are the same as token ids and no file extension
    function addTokenUris(uint256[] calldata tokenIds, string calldata baseUri) external onlyRoleOrOwner(ADMIN_ROLE) {
        if (bytes(baseUri).length == 0) revert EmptyTokenURI();
        uint256 baseUriIndex = _multiMetadataBaseUris.length;
        _multiMetadataBaseUris.push(baseUri);
        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (!_exists(tokenIds[i])) revert TokenDoesntExist();
            _multiMetadatas[tokenIds[i]].baseUriIndices.push(baseUriIndex);
            emit MetadataUpdate(tokenIds[i]);
        }
    }

    /// @inheritdoc IERC7160
    function tokenURIs(uint256 tokenId) external view returns (uint256 index, string[] memory uris, bool pinned) {
        if (!_exists(tokenId)) revert TokenDoesntExist();
        MultiMetadata memory multiMetadata = _multiMetadatas[tokenId];
        // build uris
        uris = new string[](multiMetadata.baseUriIndices.length + 1);
        uris[0] = _tokenUris[tokenId];
        if (bytes(uris[0]).length == 0) {
            (, uris[0]) = _getBatchInfo(tokenId);
        }
        for (uint256 i = 0; i < multiMetadata.baseUriIndices.length; i++) {
            uris[i + 1] = string(
                abi.encodePacked(_multiMetadataBaseUris[multiMetadata.baseUriIndices[i]], "/", tokenId.toString())
            );
        }
        // get if pinned
        pinned = multiMetadata.pinned;
        // set index
        index = pinned ? multiMetadata.index : uris.length - 1;
    }

    /// @inheritdoc IERC7160
    function pinTokenURI(uint256 tokenId, uint256 index) external {
        if (!_exists(tokenId)) revert TokenDoesntExist();
        if (ownerOf(tokenId) != msg.sender) revert CallerNotTokenOwner();
        if (index > _multiMetadatas[tokenId].baseUriIndices.length) {
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
        if (ownerOf(tokenId) != msg.sender) revert CallerNotTokenOwner();

        _multiMetadatas[tokenId].pinned = false;

        emit TokenUriUnpinned(tokenId);
        emit MetadataUpdate(tokenId);
    }

    /// @inheritdoc IERC7160
    function hasPinnedTokenURI(uint256 tokenId) external view returns (bool) {
        if (!_exists(tokenId)) revert TokenDoesntExist();
        return _multiMetadatas[tokenId].pinned;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                Token Uri Override
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc ERC721Upgradeable
    function tokenURI(uint256 tokenId) public view override(ERC721Upgradeable) returns (string memory uri) {
        if (!_exists(tokenId)) revert TokenDoesntExist();
        MultiMetadata memory multiMetadata = _multiMetadatas[tokenId];
        if (multiMetadata.pinned) {
            if (multiMetadata.index == 0) {
                uri = _tokenUris[tokenId];
                if (bytes(uri).length == 0) {
                    (, uri) = _getBatchInfo(tokenId);
                }
            } else {
                uri = string(
                    abi.encodePacked(
                        _multiMetadataBaseUris[multiMetadata.baseUriIndices[multiMetadata.index - 1]],
                        "/",
                        tokenId.toString()
                    )
                );
            }
        } else {
            if (multiMetadata.baseUriIndices.length == 0) {
                uri = _tokenUris[tokenId];
                if (bytes(uri).length == 0) {
                    (, uri) = _getBatchInfo(tokenId);
                }
            } else {
                uri = string(
                    abi.encodePacked(
                        _multiMetadataBaseUris[multiMetadata.baseUriIndices[multiMetadata.baseUriIndices.length - 1]],
                        "/",
                        tokenId.toString()
                    )
                );
            }
        }
    }

    /*//////////////////////////////////////////////////////////////////////////
                                Story Contract Hooks
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc StoryContractUpgradeable
    /// @dev restricted to the owner of the contract
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
    /// @dev restricted to the owner of the contract
    function _isCreator(address potentialCreator, uint256 /* tokenId */ )
        internal
        view
        override(StoryContractUpgradeable)
        returns (bool)
    {
        return potentialCreator == owner() || hasRole(ADMIN_ROLE, potentialCreator);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                BlockList Functions & Overrides
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc BlockListUpgradeable
    /// @dev restricted to the owner of the contract
    function isBlockListAdmin(address potentialAdmin) public view override(BlockListUpgradeable) returns (bool) {
        return potentialAdmin == owner();
    }

    /// @inheritdoc ERC721Upgradeable
    /// @dev added the `notBlocked` modifier for blocklist
    function approve(address to, uint256 tokenId) public override(ERC721Upgradeable) notBlocked(to) {
        ERC721Upgradeable.approve(to, tokenId);
    }

    /// @inheritdoc ERC721Upgradeable
    /// @dev added the `notBlocked` modifier for blocklist
    function setApprovalForAll(address operator, bool approved)
        public
        override(ERC721Upgradeable)
        notBlocked(operator)
    {
        ERC721Upgradeable.setApprovalForAll(operator, approved);
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
                || interfaceId == type(IERC7160).interfaceId
        );
    }
}

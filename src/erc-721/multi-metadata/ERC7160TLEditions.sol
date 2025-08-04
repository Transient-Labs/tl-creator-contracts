// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC4906} from "@openzeppelin-contracts-5.0.2/interfaces/IERC4906.sol";
import {Strings} from "@openzeppelin-contracts-5.0.2/utils/Strings.sol";
import {IERC20} from "@openzeppelin-contracts-5.0.2/token/ERC20/IERC20.sol";
import {
    ERC721Upgradeable,
    IERC165,
    IERC721
} from "@openzeppelin-contracts-upgradeable-5.0.2/token/ERC721/ERC721Upgradeable.sol";
import {OwnableAccessControlUpgradeable} from "../../lib/OwnableAccessControlUpgradeable.sol";
import {ERC2981TLUpgradeable} from "../../lib/ERC2981TLUpgradeable.sol";
import {IBlockListRegistry} from "../../interfaces/IBlockListRegistry.sol";
import {ICreatorBase} from "../../interfaces/ICreatorBase.sol";
import {IERC7160} from "../../interfaces/IERC7160.sol";
import {IStory} from "../../interfaces/IStory.sol";
import {ITLNftDelegationRegistry} from "../../interfaces/ITLNftDelegationRegistry.sol";
import {IERC721TL} from "../IERC721TL.sol";

/// @title ERC7160TLEditions.sol
/// @notice Sovereign ERC-7160 Editions Creator Contract with Story Inscriptions
/// @author transientlabs.xyz
/// @custom:version 3.7.0
contract ERC7160TLEditions is
    ERC721Upgradeable,
    ERC2981TLUpgradeable,
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
    }

    /// @dev Struct for holding values used in ERC-7160
    struct MultiMetadata {
        bool pinned;
        uint256 index;
    }

    /// @dev String representation of uint256
    using Strings for uint256;

    /// @dev String representation for address
    using Strings for address;

    /*//////////////////////////////////////////////////////////////////////////
                                State Variables
    //////////////////////////////////////////////////////////////////////////*/

    string public constant VERSION = "3.7.0";
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant APPROVED_MINT_CONTRACT = keccak256("APPROVED_MINT_CONTRACT");
    uint256 private _counter; // token ids
    bool public storyEnabled;
    bool public floatWhenUnpinned;
    ITLNftDelegationRegistry public tlNftDelegationRegistry;
    IBlockListRegistry public blocklistRegistry;
    mapping(uint256 => bool) private _burned; // flag to see if a token is burned or not - needed for burning batch mints
    mapping(uint256 => MultiMetadata) private _multiMetadatas;
    string[] private _tokenUris;
    BatchMint[] private _batchMints; // dynamic array for batch mints

    /*//////////////////////////////////////////////////////////////////////////
                                Custom Errors
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev No token uris added yet
    error EmptyTokenURIs();

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
    /// @dev cannot mint unless at least one token uri has been added to the array
    function mint(address recipient, string calldata /*uri*/ ) external onlyRoleOrOwner(ADMIN_ROLE) {
        if (_tokenUris.length == 0) revert EmptyTokenURIs();
        _counter++;
        _mint(recipient, _counter);
    }

    /// @inheritdoc IERC721TL
    /// @dev cannot mint unless at least one token uri has been added to the array
    function mint(address recipient, string calldata, /*uri*/ address royaltyAddress, uint256 royaltyPercent)
        external
        onlyRoleOrOwner(ADMIN_ROLE)
    {
        if (_tokenUris.length == 0) revert EmptyTokenURIs();
        _counter++;
        _overrideTokenRoyaltyInfo(_counter, royaltyAddress, royaltyPercent);
        _mint(recipient, _counter);
    }

    /// @inheritdoc IERC721TL
    /// @dev cannot mint unless at least one token uri has been added to the array
    function batchMint(address recipient, uint128 numTokens, string calldata /*baseUri*/ )
        external
        onlyRoleOrOwner(ADMIN_ROLE)
    {
        if (_tokenUris.length == 0) revert EmptyTokenURIs();
        if (recipient == address(0)) revert MintToZeroAddress();
        if (numTokens < 2) revert BatchSizeTooSmall();
        uint256 start = _counter + 1;
        uint256 end = start + numTokens - 1;
        _counter += numTokens;
        _batchMints.push(BatchMint(recipient, start, end));

        _increaseBalance(recipient, numTokens); // this function adds the number of tokens to the recipient address

        for (uint256 id = start; id < end + 1; ++id) {
            emit Transfer(address(0), recipient, id);
        }
    }

    /// @inheritdoc IERC721TL
    /// @dev cannot mint unless at least one token uri has been added to the array
    function airdrop(address[] calldata addresses, string calldata /*baseUri*/ ) external onlyRoleOrOwner(ADMIN_ROLE) {
        if (_tokenUris.length == 0) revert EmptyTokenURIs();
        if (addresses.length < 2) revert AirdropTooFewAddresses();

        uint256 start = _counter + 1;
        _counter += addresses.length;
        for (uint256 i = 0; i < addresses.length; i++) {
            _mint(addresses[i], start + i);
        }
    }

    /// @inheritdoc IERC721TL
    /// @dev cannot mint unless at least one token uri has been added to the array
    function externalMint(address recipient, string calldata /*uri*/ ) external onlyRole(APPROVED_MINT_CONTRACT) {
        if (_tokenUris.length == 0) revert EmptyTokenURIs();
        _counter++;
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
    /// @dev Must be called by contract owner, admin, or approved mint contract
    /// @param tokenUris Array of token uris to add
    function addTokenUris(string[] calldata tokenUris) external {
        if (msg.sender != owner() && !hasRole(ADMIN_ROLE, msg.sender) && !hasRole(APPROVED_MINT_CONTRACT, msg.sender)) {
            revert NotOwnerAdminOrMintContract();
        }
        if (tokenUris.length == 0) revert EmptyTokenURIs();
        for (uint256 i = 0; i < tokenUris.length; i++) {
            _tokenUris.push(tokenUris[i]);

            uint256 numTokens = _counter;
            if (numTokens > 0) {
                emit BatchMetadataUpdate(1, numTokens);
            }
        }
    }

    /// @inheritdoc IERC7160
    function tokenURIs(uint256 tokenId) external view returns (uint256 index, string[] memory uris, bool pinned) {
        if (!_exists(tokenId)) revert TokenDoesntExist();
        MultiMetadata memory multiMetadata = _multiMetadatas[tokenId];
        // build uris
        uris = _tokenUris;
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
        if (index >= _tokenUris.length) {
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
            uri = _tokenUris[multiMetadata.index];
        } else {
            uri = floatWhenUnpinned ? _tokenUris[_tokenUris.length - 1] : _tokenUris[0];
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
                                Withdraw Funds
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc ICreatorBase
    function withdrawERC20(address currency, uint256 amount, address recipient) external onlyRoleOrOwner(ADMIN_ROLE) {
        // slither-disable-next-line unchecked-transfer
        IERC20(currency).transfer(recipient, amount);
    }

    /// @inheritdoc ICreatorBase
    function withdrawERC721(address token, uint256 id, address recipient) external onlyRoleOrOwner(ADMIN_ROLE) {
        IERC721(token).safeTransferFrom(address(this), recipient, id);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                ERC-165 Support
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Upgradeable, ERC2981TLUpgradeable, IERC165)
        returns (bool)
    {
        return (
            ERC721Upgradeable.supportsInterface(interfaceId) || ERC2981TLUpgradeable.supportsInterface(interfaceId)
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
    function _getBatchInfo(uint256 tokenId) internal view returns (address) {
        uint256 i = 0;
        for (i; i < _batchMints.length; i++) {
            if (tokenId >= _batchMints[i].fromTokenId && tokenId <= _batchMints[i].toTokenId) {
                break;
            }
        }
        if (i >= _batchMints.length) {
            return address(0);
        }
        return _batchMints[i].creator;
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
                    owner = _getBatchInfo(tokenId);
                }
                return owner;
            } else {
                return address(0);
            }
        }
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

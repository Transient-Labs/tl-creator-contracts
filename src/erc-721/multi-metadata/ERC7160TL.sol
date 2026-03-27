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
import {ICreatorBase} from "../../interfaces/ICreatorBase.sol";
import {ICreatorToken} from "../../interfaces/ICreatorToken.sol";
import {IERC7160} from "../../interfaces/IERC7160.sol";
import {IStory} from "../../interfaces/IStory.sol";
import {ITLNftDelegationRegistry} from "../../interfaces/ITLNftDelegationRegistry.sol";
import {ITransferValidator} from "../../interfaces/ITransferValidator.sol";
import {IERC721TL} from "../IERC721TL.sol";

/// @title ERC7160TL.sol
/// @notice Sovereign ERC-7160 Creator Contract with Story Inscriptions
/// @author transientlabs.xyz
/// @custom:version 4.0.0
contract ERC7160TL is
    ERC721Upgradeable,
    ERC2981TLUpgradeable,
    OwnableAccessControlUpgradeable,
    ICreatorBase,
    ICreatorToken,
    IERC721TL,
    IStory,
    IERC4906,
    IERC7160
{
    /////////////////////////////////////////////////////////////////////
    // Custom Types
    /////////////////////////////////////////////////////////////////////

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

    /////////////////////////////////////////////////////////////////////
    // State Variables
    /////////////////////////////////////////////////////////////////////

    string public constant VERSION = "4.0.0";
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant APPROVED_MINT_CONTRACT = keccak256("APPROVED_MINT_CONTRACT");
    uint256 private _counter; // token ids
    uint256 private _burnCounter; // total burned token count
    bool public storyEnabled;
    bool public floatWhenUnpinned;
    bool public supplyLocked;
    ITLNftDelegationRegistry public tlNftDelegationRegistry;
    address private _transferValidator;
    mapping(uint256 => bool) private _burned; // flag to see if a token is burned or not -- needed for burning batch mints
    mapping(uint256 => string) private _tokenUris;
    mapping(uint256 => MultiMetadata) private _multiMetadatas;
    string[] private _multiMetadataBaseUris;
    BatchMint[] private _batchMints; // dynamic array for batch mints

    /////////////////////////////////////////////////////////////////////
    // Custom Errors
    /////////////////////////////////////////////////////////////////////

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

    /// @dev Story not enabled for collectors
    error StoryNotEnabled();

    /// @dev Supply locked
    error SupplyIsLocked();

    /////////////////////////////////////////////////////////////////////
    // Constructor
    /////////////////////////////////////////////////////////////////////

    /// @param disable Boolean to disable initialization for the implementation contract
    constructor(bool disable) {
        if (disable) _disableInitializers();
    }

    /////////////////////////////////////////////////////////////////////
    // Initializer
    /////////////////////////////////////////////////////////////////////

    /// @param name The name of the 721 contract
    /// @param symbol The symbol of the 721 contract
    /// @param defaultRoyaltyRecipient The default address for royalty payments
    /// @param defaultRoyaltyPercentage The default royalty percentage of basis points (out of 10,000)
    /// @param initOwner The owner of the contract
    /// @param admins Array of admin addresses to add to the contract
    /// @param enableStory A bool deciding whether to add story fuctionality or not
    /// @param initTransferValidator Address of the transfer validators to use
    /// @param initListId The initial list id to use in the transfer validator (allows Transient protocol)
    /// @param initNftDelegationRegistry Address of the TL nft delegation registry to use
    function initialize(
        string memory name,
        string memory symbol,
        address defaultRoyaltyRecipient,
        uint256 defaultRoyaltyPercentage,
        address initOwner,
        address[] memory admins,
        bool enableStory,
        address initTransferValidator,
        uint48 initListId,
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

        // transfer validator
        _transferValidator = initTransferValidator;
        emit TransferValidatorUpdated(address(0), initTransferValidator);
        _setupTransferValidatorV5(initTransferValidator, initListId);

        // nft delegation registry
        tlNftDelegationRegistry = ITLNftDelegationRegistry(initNftDelegationRegistry);
        emit NftDelegationRegistryUpdate(initOwner, address(0), initNftDelegationRegistry);
    }

    /////////////////////////////////////////////////////////////////////
    // General Functions
    /////////////////////////////////////////////////////////////////////

    /// @inheritdoc ICreatorBase
    function totalSupply() external view returns (uint256) {
        return _counter - _burnCounter;
    }

    /////////////////////////////////////////////////////////////////////
    // Access Control Functions
    /////////////////////////////////////////////////////////////////////

    /// @inheritdoc ICreatorBase
    function setApprovedMintContracts(address[] calldata minters, bool status) external onlyRoleOrOwner(ADMIN_ROLE) {
        _setRole(APPROVED_MINT_CONTRACT, minters, status);
    }

    /////////////////////////////////////////////////////////////////////
    // Mint Functions
    /////////////////////////////////////////////////////////////////////

    /// @inheritdoc IERC721TL
    function mint(address recipient, string calldata uri) external onlyRoleOrOwner(ADMIN_ROLE) {
        if (supplyLocked) revert SupplyIsLocked();
        if (bytes(uri).length == 0) revert EmptyTokenURI();
        unchecked {
            _counter++;
        }
        _tokenUris[_counter] = uri;
        _mint(recipient, _counter);
    }

    /// @inheritdoc IERC721TL
    function mint(address recipient, string calldata uri, address royaltyAddress, uint256 royaltyPercent)
        external
        onlyRoleOrOwner(ADMIN_ROLE)
    {
        if (supplyLocked) revert SupplyIsLocked();
        if (bytes(uri).length == 0) revert EmptyTokenURI();
        unchecked {
            _counter++;
        }
        _tokenUris[_counter] = uri;
        _overrideTokenRoyaltyInfo(_counter, royaltyAddress, royaltyPercent);
        _mint(recipient, _counter);
    }

    /// @inheritdoc IERC721TL
    function batchMint(address recipient, uint128 numTokens, string calldata baseUri)
        external
        onlyRoleOrOwner(ADMIN_ROLE)
    {
        if (supplyLocked) revert SupplyIsLocked();
        if (recipient == address(0)) revert MintToZeroAddress();
        if (bytes(baseUri).length == 0) revert EmptyTokenURI();
        if (numTokens < 2) revert BatchSizeTooSmall();
        uint256 start = _counter + 1;
        uint256 end = start + numTokens - 1;
        unchecked {
            _counter += numTokens;
        }
        _batchMints.push(BatchMint(recipient, start, end, baseUri));

        _increaseBalance(recipient, numTokens); // this function adds the number of tokens to the recipient address

        for (uint256 id = start; id < end + 1; ++id) {
            emit Transfer(address(0), recipient, id);
        }
    }

    /// @inheritdoc IERC721TL
    function airdrop(address[] calldata addresses, string calldata baseUri) external onlyRoleOrOwner(ADMIN_ROLE) {
        if (supplyLocked) revert SupplyIsLocked();
        if (bytes(baseUri).length == 0) revert EmptyTokenURI();
        if (addresses.length < 2) revert AirdropTooFewAddresses();

        uint256 start = _counter + 1;
        uint256 end = start + addresses.length - 1;
        unchecked {
            _counter += addresses.length;
        }
        _batchMints.push(BatchMint(address(0), start, end, baseUri));
        for (uint256 i = 0; i < addresses.length; i++) {
            _mint(addresses[i], start + i);
        }
    }

    /// @inheritdoc IERC721TL
    function externalMint(address recipient, string calldata uri) external onlyRole(APPROVED_MINT_CONTRACT) {
        if (supplyLocked) revert SupplyIsLocked();
        if (bytes(uri).length == 0) revert EmptyTokenURI();
        unchecked {
            _counter++;
        }
        _tokenUris[_counter] = uri;
        _mint(recipient, _counter);
    }

    /////////////////////////////////////////////////////////////////////
    // Burn Functions
    /////////////////////////////////////////////////////////////////////

    /// @inheritdoc IERC721TL
    function burn(uint256 tokenId) external {
        address owner = ownerOf(tokenId);
        if (!_isAuthorized(owner, msg.sender, tokenId)) revert CallerNotApprovedOrOwner();
        _burnWithTracking(tokenId);
    }

    /// @notice Internal helper function to burn with tracking
    function _burnWithTracking(uint256 tokenId) internal {
        _burn(tokenId);
        _burned[tokenId] = true;
        unchecked {
            _burnCounter++;
        }
    }

    /////////////////////////////////////////////////////////////////////
    // Lock Functions
    /////////////////////////////////////////////////////////////////////

    /// @inheritdoc IERC721TL
    function lockSupply() external onlyRoleOrOwner(ADMIN_ROLE) {
        if (supplyLocked) revert SupplyIsLocked();
        supplyLocked = true;

        emit IERC721TL.SupplyLocked(msg.sender);
    }

    /////////////////////////////////////////////////////////////////////
    // Royalty Functions
    /////////////////////////////////////////////////////////////////////

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

    /////////////////////////////////////////////////////////////////////
    // ERC-7160 Functions
    /////////////////////////////////////////////////////////////////////

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

    /////////////////////////////////////////////////////////////////////
    // Story Inscriptions
    /////////////////////////////////////////////////////////////////////

    /// @inheritdoc IStory
    function addCollectionStory(
        string calldata,
        /*creatorName*/
        string calldata story
    )
        external
        onlyRoleOrOwner(ADMIN_ROLE)
    {
        emit CollectionStory(msg.sender, msg.sender.toHexString(), story);
    }

    /// @inheritdoc IStory
    function addCreatorStory(
        uint256 tokenId,
        string calldata,
        /*creatorName*/
        string calldata story
    )
        external
        onlyRoleOrOwner(ADMIN_ROLE)
    {
        if (!_exists(tokenId)) revert TokenDoesntExist();
        emit CreatorStory(tokenId, msg.sender, msg.sender.toHexString(), story);
    }

    /// @inheritdoc IStory
    function addStory(
        uint256 tokenId,
        string calldata,
        /*collectorName*/
        string calldata story
    )
        external
    {
        if (!storyEnabled) revert StoryNotEnabled();
        if (!_isTokenOwnerOrDelegate(tokenId)) revert CallerNotTokenOwnerOrDelegate();
        emit Story(tokenId, msg.sender, msg.sender.toHexString(), story);
    }

    /// @inheritdoc ICreatorBase
    function setStoryStatus(bool status) external onlyRoleOrOwner(ADMIN_ROLE) {
        storyEnabled = status;
        emit StoryStatusUpdate(msg.sender, status);
    }

    /////////////////////////////////////////////////////////////////////
    // Transfer Validator
    /////////////////////////////////////////////////////////////////////

    /// @inheritdoc ICreatorToken
    function setTransferValidator(address newTransferValidator) external onlyRoleOrOwner(ADMIN_ROLE) {
        address oldTransferValidator = _transferValidator;
        _transferValidator = newTransferValidator;
        emit TransferValidatorUpdated(oldTransferValidator, newTransferValidator);
    }

    /// @inheritdoc ICreatorToken
    function getTransferValidationFunction() external pure returns (bytes4 functionSignature, bool isViewFunction) {
        functionSignature = bytes4(keccak256("validateTransfer(address,address,address,uint256)"));
        isViewFunction = true;
    }

    /// @inheritdoc ICreatorToken
    function getTransferValidator() external view returns (address validator) {
        validator = _transferValidator;
    }

    /// @inheritdoc ERC721Upgradeable
    function _update(address to, uint256 tokenId, address auth) internal override(ERC721Upgradeable) returns (address) {
        // only check transfer validator if not a mint or burn
        address transferValidator = _transferValidator;
        address from = _ownerOf(tokenId);
        if (from != address(0) && to != address(0) && transferValidator != address(0)) {
            ITransferValidator(transferValidator).validateTransfer(msg.sender, from, to, tokenId);
        }

        // run the inherited update function
        return ERC721Upgradeable._update(to, tokenId, auth);
    }

    /////////////////////////////////////////////////////////////////////
    // NFT Delegation Registry
    /////////////////////////////////////////////////////////////////////

    /// @inheritdoc ICreatorBase
    function setNftDelegationRegistry(address newNftDelegationRegistry) external onlyRoleOrOwner(ADMIN_ROLE) {
        address oldNftDelegationRegistry = address(tlNftDelegationRegistry);
        tlNftDelegationRegistry = ITLNftDelegationRegistry(newNftDelegationRegistry);
        emit NftDelegationRegistryUpdate(msg.sender, oldNftDelegationRegistry, newNftDelegationRegistry);
    }

    /////////////////////////////////////////////////////////////////////
    // Withdraw Funds
    /////////////////////////////////////////////////////////////////////

    /// @inheritdoc ICreatorBase
    function withdrawERC20(address currency, uint256 amount, address recipient) external onlyRoleOrOwner(ADMIN_ROLE) {
        // slither-disable-next-line unchecked-transfer
        IERC20(currency).transfer(recipient, amount);
    }

    /// @inheritdoc ICreatorBase
    function withdrawERC721(address token, uint256 id, address recipient) external onlyRoleOrOwner(ADMIN_ROLE) {
        IERC721(token).safeTransferFrom(address(this), recipient, id);
    }

    /////////////////////////////////////////////////////////////////////
    // ERC-165 Support
    /////////////////////////////////////////////////////////////////////

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Upgradeable, ERC2981TLUpgradeable, IERC165)
        returns (bool)
    {
        return (ERC721Upgradeable.supportsInterface(interfaceId) || ERC2981TLUpgradeable.supportsInterface(interfaceId)
                || interfaceId == 0x49064906 // ERC-4906
                || interfaceId == type(IERC7160).interfaceId || interfaceId == type(ICreatorBase).interfaceId
                || interfaceId == type(ICreatorToken).interfaceId || interfaceId == type(IStory).interfaceId
                || interfaceId == 0x0d23ecb9 // previous story contract version that is still supported
                || interfaceId == type(IERC721TL).interfaceId);
    }

    /////////////////////////////////////////////////////////////////////
    // Internal Functions
    /////////////////////////////////////////////////////////////////////

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

    /// @notice Function to setup the v5 transfer validator by Limit Break
    /// @dev We know how the rulset options work by default so all good to fix the values in code here.
    ///      But we will pass in the initial list id as that is different across chains.
    function _setupTransferValidatorV5(address transferValidator, uint48 listId) internal view {
        if (transferValidator == address(0)) return;

        ITransferValidator tv = ITransferValidator(transferValidator);
        tv.applyListToCollection(address(this), listId);
        tv.setRulesetOfCollection(address(this), 0, address(0), 0, 6);
    }
}

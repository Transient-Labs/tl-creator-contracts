// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {IERC4906} from "openzeppelin/interfaces/IERC4906.sol";
import {Strings} from "openzeppelin/utils/Strings.sol";
import {ERC721Upgradeable, IERC165} from "openzeppelin-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {OwnableAccessControlUpgradeable} from "tl-sol-tools/upgradeable/access/OwnableAccessControlUpgradeable.sol";
import {EIP2981TLUpgradeable} from "tl-sol-tools/upgradeable/royalties/EIP2981TLUpgradeable.sol";
import {IShatter} from "src/erc-721/shatter/IShatter.sol";
import {IBlockListRegistry} from "src/interfaces/IBlockListRegistry.sol";
import {ICreatorBase} from "src/interfaces/ICreatorBase.sol";
import {IStory} from "src/interfaces/IStory.sol";
import {ISynergy} from "src/interfaces/ISynergy.sol";
import {ITLNftDelegationRegistry} from "src/interfaces/ITLNftDelegationRegistry.sol";

/// @title Shatter.sol
/// @notice Shatter implementation. Turns 1/1 into a multiple sub-pieces.
/// @author transientlabs.xyz
/// @custom:version 3.0.0
contract Shatter is
    ERC721Upgradeable,
    EIP2981TLUpgradeable,
    OwnableAccessControlUpgradeable,
    IShatter,
    ICreatorBase,
    ISynergy,
    IStory,
    IERC4906
{
    /*//////////////////////////////////////////////////////////////////////////
                                Custom Types
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev string representation of uint256
    using Strings for uint256;

    /// @dev String representation for address
    using Strings for address;

    /*//////////////////////////////////////////////////////////////////////////
                                State Variables
    //////////////////////////////////////////////////////////////////////////*/

    string public constant VERSION = "3.0.0";
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bool public isShattered;
    bool public isFused;
    bool public storyEnabled;
    ITLNftDelegationRegistry public tlNftDelegationRegistry;
    IBlockListRegistry public blocklistRegistry;
    uint128 public minShatters;
    uint128 public maxShatters;
    uint128 public shatters;
    uint256 public shatterTime;
    address private _shatterAddress;
    string private _baseUri;
    mapping(uint256 => string) private _proposedTokenUris; // Synergy proposed token uri override
    mapping(uint256 => string) private _tokenUris; // established token uri overrides

    /*//////////////////////////////////////////////////////////////////////////
                                Custom Errors
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev token uri is an empty string
    error EmptyTokenURI();

    /// @dev already minted the first token and can't mint another token to this contract
    error AlreadyMinted();

    /// @dev not shattered
    error NotShattered();

    /// @dev token is shattered
    error IsShattered();

    /// @dev token is fused
    error IsFused();

    /// @dev caller is not the owner of the specific token
    error CallerNotTokenOwner();

    /// @dev caller does not own all shatters for fusing
    error CallerDoesNotOwnAllTokens();

    /// @dev number shatters requested is invalid
    error InvalidNumShatters();

    /// @dev calling shatter prior to shatter time
    error CallPriorToShatterTime();

    /// @dev no proposed token uri to change to
    error NoTokenUriUpdateAvailable();

    /// @dev token does not exist
    error TokenDoesntExist();

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

    /// @param name The name of the collection
    /// @param symbol The token tracker symbol
    /// @param royaltyRecipient The default royalty recipient
    /// @param royaltyPercentage The default royalty percentage
    /// @param initOwner The owner of the contract
    /// @param admins Array of admin addresses to add to the contract
    /// @param enableStory Bool deciding whether to add story fuctionality or not
    /// @param blockListRegistry Address of the blocklist registry to use
    function initialize(
        string memory name,
        string memory symbol,
        address royaltyRecipient,
        uint256 royaltyPercentage,
        address initOwner,
        address[] memory admins,
        bool enableStory,
        address blockListRegistry
    ) external initializer {
        __ERC721_init(name, symbol);
        __EIP2981TL_init(royaltyRecipient, royaltyPercentage);
        __OwnableAccessControl_init(initOwner);

        _setRole(ADMIN_ROLE, admins, true);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                General Functions
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice function to get total supply of tokens on the contract
    function totalSupply() external view returns (uint256) {
        return shatters;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                Access Control Functions
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc ICreatorBase
    function setApprovedMintContracts(address[] calldata, /*minters*/ bool /*status*/ ) external pure {
        revert("N/A");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                Mint Function
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Function for minting the 1/1
    /// @dev Requires contract owner or admin
    /// @dev Requires that shatters is equal to 0 -> meaning no piece has been minted
    /// @param recipient The address to mint to token to
    /// @param uri The base uri to be used for the shatter folder WITHOUT trailing "/"
    /// @param min The minimum number of shatters
    /// @param max The maximum number of shatters
    /// @param time Time after which shatter can occur
    function mint(address recipient, string memory uri, uint128 min, uint128 max, uint256 time)
        external
        onlyRoleOrOwner(ADMIN_ROLE)
    {
        if (shatters != 0) revert AlreadyMinted();
        if (bytes(uri).length == 0) revert EmptyTokenURI();

        if (min < 1) {
            minShatters = 1;
        } else {
            minShatters = min;
        }
        maxShatters = max;

        shatterTime = time;
        _baseUri = uri;
        shatters = 1;
        _mint(recipient, 0);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                Shatter Functions
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc IShatter
    function shatter(uint128 numShatters) external {
        if (isShattered) revert IsShattered();
        if (msg.sender != ownerOf(0)) revert CallerNotTokenOwner();
        if (numShatters < minShatters || numShatters > maxShatters) revert InvalidNumShatters();
        if (block.timestamp < shatterTime) revert CallPriorToShatterTime();

        if (numShatters > 1) {
            _burn(0);
            _shatterAddress = msg.sender;
            _increaseBalance(_shatterAddress, numShatters);

            for (uint256 id = 1; id < numShatters + 1; ++id) {
                emit Transfer(address(0), msg.sender, id);
            }
            emit Shattered(msg.sender, numShatters, block.timestamp);
        } else {
            isFused = true;
            emit Shattered(msg.sender, numShatters, block.timestamp);
            emit Fused(msg.sender, block.timestamp);
        }
        // no reentrancy so can set these after burning and minting
        // needs to be called here since _burn relies on ownership check
        isShattered = true;
        shatters = numShatters;
    }

    /// @inheritdoc IShatter
    function fuse() external {
        if (isFused) revert IsFused();
        if (!isShattered) revert NotShattered();

        for (uint256 id = 1; id < shatters + 1; id++) {
            if (msg.sender != ownerOf(id)) revert CallerDoesNotOwnAllTokens();
            _burn(id);
        }
        isFused = true;
        shatters = 1;
        _mint(msg.sender, 0);

        emit Fused(msg.sender, block.timestamp);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                Royalty Functions
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice function to set the default royalty specification
    /// @dev requires owner
    /// @param newRecipient the new royalty payout address
    /// @param newPercentage the new royalty percentage in basis (out of 10,000)
    function setDefaultRoyalty(address newRecipient, uint256 newPercentage) external onlyOwner {
        _setDefaultRoyaltyInfo(newRecipient, newPercentage);
    }

    /// @notice function to override a token's royalty info
    /// @dev requires owner
    /// @param tokenId the token to override royalty for
    /// @param newRecipient the new royalty payout address for the token id
    /// @param newPercentage the new royalty percentage in basis (out of 10,000) for the token id
    function setTokenRoyalty(uint256 tokenId, address newRecipient, uint256 newPercentage) external onlyOwner {
        _overrideTokenRoyaltyInfo(tokenId, newRecipient, newPercentage);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                Synergy Functions
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice function to propose a token uri update for a specific token
    /// @dev requires owner
    /// @dev if the owner of the contract is the owner of the token, the change takes hold right away
    /// @param tokenId the token to propose new metadata for
    /// @param newUri the new token uri proposed
    function proposeNewTokenUri(uint256 tokenId, string calldata newUri) external onlyRoleOrOwner(ADMIN_ROLE) {
        if (!_exists(tokenId)) revert TokenDoesntExist();
        if (bytes(newUri).length == 0) revert EmptyTokenURI();
        if (ownerOf(tokenId) == owner()) {
            // creator owns the token
            _tokenUris[tokenId] = newUri;
            emit MetadataUpdate(tokenId);
        } else {
            // creator does not own the token
            _proposedTokenUris[tokenId] = newUri;
            emit SynergyStatusChange(msg.sender, tokenId, SynergyAction.Created, newUri);
        }
    }

    /// @notice function to accept a proposed token uri update for a specific token
    /// @dev requires owner of the token to call the function
    /// @param tokenId the token to accept the metadata update for
    function acceptTokenUriUpdate(uint256 tokenId) external {
        if (ownerOf(tokenId) != msg.sender) revert CallerNotTokenOwner();
        string memory uri = _proposedTokenUris[tokenId];
        if (bytes(uri).length == 0) revert NoTokenUriUpdateAvailable();
        _tokenUris[tokenId] = uri;
        delete _proposedTokenUris[tokenId];
        emit MetadataUpdate(tokenId);
        emit SynergyStatusChange(msg.sender, tokenId, SynergyAction.Accepted, uri);
    }

    /// @notice function to reject a proposed token uri update for a specific token
    /// @dev requires owner of the token to call the function
    /// @param tokenId the token to reject the metadata update for
    function rejectTokenUriUpdate(uint256 tokenId) external {
        if (ownerOf(tokenId) != msg.sender) revert CallerNotTokenOwner();
        string memory uri = _proposedTokenUris[tokenId];
        if (bytes(uri).length == 0) revert NoTokenUriUpdateAvailable();
        delete _proposedTokenUris[tokenId];
        emit SynergyStatusChange(msg.sender, tokenId, SynergyAction.Rejected, "");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                Token Uri Override
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc ERC721Upgradeable
    function tokenURI(uint256 tokenId) public view override(ERC721Upgradeable) returns (string memory) {
        if (!_exists(tokenId)) revert TokenDoesntExist();
        string memory uri = _tokenUris[tokenId];
        if (bytes(uri).length == 0) {
            // no override
            return string(abi.encodePacked(_baseUri, "/", tokenId.toString()));
        }
        return uri;
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
        override(ERC721Upgradeable, EIP2981TLUpgradeable, IERC165)
        returns (bool)
    {
        return (
            ERC721Upgradeable.supportsInterface(interfaceId) || EIP2981TLUpgradeable.supportsInterface(interfaceId)
                || interfaceId == 0x49064906 // ERC-4906
                || interfaceId == type(ICreatorBase).interfaceId
                || interfaceId == type(ISynergy).interfaceId || interfaceId == type(IStory).interfaceId
                || interfaceId == 0x0d23ecb9 // previous story contract version that is still supported
                || interfaceId == type(IShatter).interfaceId
        );
    }

    /*//////////////////////////////////////////////////////////////////////////
                                Internal Functions
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc ERC721Upgradeable
    /// @notice function to override { ERC721Upgradeable._ownerOf } to allow for batch minting/shatter
    function _ownerOf(uint256 tokenId) internal view virtual override returns (address) {
        if (isShattered && !isFused) {
            if (tokenId > shatters) {
                return address(0);
            }
            if (tokenId > 0 && ERC721Upgradeable._ownerOf(tokenId) == address(0)) {
                return _shatterAddress;
            }
        }

        return ERC721Upgradeable._ownerOf(tokenId);
    }

    /// @notice Function to check if a token exists
    /// @param tokenId The token id to check
    function _exists(uint256 tokenId) internal view returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }
}

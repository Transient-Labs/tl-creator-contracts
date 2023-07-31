// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Initializable} from "openzeppelin-upgradeable/proxy/utils/Initializable.sol";
import {ERC721Upgradeable, ERC165Upgradeable} from "openzeppelin-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {EIP2981TLUpgradeable} from "tl-sol-tools/upgradeable/royalties/EIP2981TLUpgradeable.sol";
import {StringsUpgradeable} from "openzeppelin-upgradeable/utils/StringsUpgradeable.sol";
import {IERC2309Upgradeable} from "openzeppelin-upgradeable/interfaces/IERC2309Upgradeable.sol";
import {OwnableAccessControlUpgradeable} from "tl-sol-tools/upgradeable/access/OwnableAccessControlUpgradeable.sol";
import {StoryContractUpgradeable} from "tl-story/upgradeable/StoryContractUpgradeable.sol";
import {BlockListUpgradeable} from "tl-blocklist/BlockListUpgradeable.sol";
import {IShatter} from "./IShatter.sol";

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
                            Shatter
//////////////////////////////////////////////////////////////////////////*/

/// @title Shatter
/// @notice Shatter implementation. Turns 1/1 into a multiple sub-pieces.
/// @author transientlabs.xyz
/// @custom:version 2.5.0
contract Shatter is
    Initializable,
    ERC721Upgradeable,
    EIP2981TLUpgradeable,
    OwnableAccessControlUpgradeable,
    StoryContractUpgradeable,
    BlockListUpgradeable,
    IERC2309Upgradeable,
    IShatter
{
    /*//////////////////////////////////////////////////////////////////////////
                                Custom Types
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev enum defining Synergy actions
    enum SynergyAction {
        Created,
        Accepted,
        Rejected
    }

    /// @dev string representation of uint256
    using StringsUpgradeable for uint256;

    /*//////////////////////////////////////////////////////////////////////////
                                State Variables
    //////////////////////////////////////////////////////////////////////////*/

    string public constant VERSION = "2.5.0";
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bool public isShattered;
    bool public isFused;
    uint256 public minShatters;
    uint256 public maxShatters;
    uint256 public shatters;
    uint256 public shatterTime;
    address private _shatterAddress;
    string private _baseUri;
    mapping(uint256 => string) private _proposedTokenUris; // Synergy proposed token uri override
    mapping(uint256 => string) private _tokenUris; // established token uri overrides

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

    /// @dev This event is for changing the status of a proposed metadata update.
    /// @dev Options include creation, accepted, rejected.
    event SynergyStatusChange(address indexed from, uint256 indexed tokenId, SynergyAction indexed action, string uri);

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

    /// @param name is the name of the collection
    /// @param symbol is the token tracker symbol
    /// @param royaltyRecipient is the default royalty recipient
    /// @param royaltyPercentage is the default royalty percentage
    /// @param initOwner: the owner of the contract
    /// @param admins: array of admin addresses to add to the contract
    /// @param enableStory: a bool deciding whether to add story fuctionality or not
    /// @param blockListRegistry: address of the blocklist registry to use
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
        __StoryContractUpgradeable_init(enableStory);
        __BlockList_init(blockListRegistry);

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
                                Mint Function
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice function for minting the 1/1
    /// @dev requires contract owner or admin
    /// @dev requires that shatters is equal to 0 -> meaning no piece has been minted
    /// @dev using _mint function so the recipient should be verified to be able to receive ERC721 tokens prior to calling
    /// @dev parameters like uri, min, max, and time cannot be changed after the transaction goes through
    /// @param recipient: the address to mint to token to
    /// @param uri: the base uri to be used for the shatter folder
    ///     NOTE: there is no trailing "/" expected on this uri but it is expected to be a folder uri
    /// @param min: the minimum number of shatters
    /// @param max: the maximum number of shatters
    /// @param time: time after which shatter can occur
    function mint(address recipient, string memory uri, uint256 min, uint256 max, uint256 time)
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
    function shatter(uint256 numShatters) external {
        if (isShattered) revert IsShattered();
        if (msg.sender != ownerOf(0)) revert CallerNotTokenOwner();
        if (numShatters < minShatters || numShatters > maxShatters) revert InvalidNumShatters();
        if (block.timestamp < shatterTime) revert CallPriorToShatterTime();

        if (numShatters > 1) {
            _burn(0);
            _batchMint(msg.sender, numShatters, false);
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

    /// @notice function to shatter using ERC-2309
    /// @dev same requirements as `shatter` in {IShatter}
    /// @dev uses ERC-2309. BEWARE - this may not be supported by all platforms.
    function shatterUltra(uint256 numShatters) external {
        if (isShattered) revert IsShattered();
        if (msg.sender != ownerOf(0)) revert CallerNotTokenOwner();
        if (numShatters < minShatters || numShatters > maxShatters) revert InvalidNumShatters();
        if (block.timestamp < shatterTime) revert CallPriorToShatterTime();

        if (numShatters > 1) {
            _burn(0);
            _batchMint(msg.sender, numShatters, true);
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
                            Batch Mint Functions 
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice function to batch mint upon shatter
    /// @dev only mints tokenIds 1 -> quantity to recipient
    /// @dev does not check if the recipient ifs the zero address or can receive ERC-721 tokens
    /// @param recipient: address to receive the tokens
    /// @param quantity: amount of tokens to batch mint
    /// @param ultra: bool specifying to use ERC-2309 or the regular `Transfer` event
    function _batchMint(address recipient, uint256 quantity, bool ultra) internal {
        _shatterAddress = recipient;
        __unsafe_increaseBalance(_shatterAddress, quantity);

        if (ultra) {
            emit ConsecutiveTransfer(1, quantity, address(0), recipient);
        } else {
            for (uint256 id = 1; id < quantity + 1; ++id) {
                emit Transfer(address(0), recipient, id);
            }
        }
    }

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
                                Synergy Functions
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice function to propose a token uri update for a specific token
    /// @dev requires owner
    /// @dev if the owner of the contract is the owner of the token, the change takes hold right away
    /// @param tokenId: the token to propose new metadata for
    /// @param newUri: the new token uri proposed
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
    /// @param tokenId: the token to accept the metadata update for
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
    /// @param tokenId: the token to reject the metadata update for
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
        override(EIP2981TLUpgradeable, ERC721Upgradeable, StoryContractUpgradeable)
        returns (bool)
    {
        return interfaceId == bytes4(0x49064906) || interfaceId == type(IShatter).interfaceId
            || ERC721Upgradeable.supportsInterface(interfaceId) || EIP2981TLUpgradeable.supportsInterface(interfaceId)
            || StoryContractUpgradeable.supportsInterface(interfaceId);
    }
}

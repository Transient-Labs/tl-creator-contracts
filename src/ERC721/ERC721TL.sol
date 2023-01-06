// SPDX-License-Identifier: Apache-2.0

/// @title ERC721TL.sol
/// @notice Transient Labs core ERC721 contract (v1)
/// @dev features include
///      - ultra efficient batch minting (market leading?)
///      - airdrops (market leading?)
///      - ability to hook in external mint contracts
///      - ability to set multiple admins
///      - ability to enable/disable the Story Contract at creation time
///      - ability to enable/disable BlockList at creation time
///      - Synergy metadata protection
///      - individual token royalty overrides (only if owner is the owner of the token)
/// @author transientlabs.xyz

/*
    ____        _ __    __   ____  _ ________                     __ 
   / __ )__  __(_) /___/ /  / __ \(_) __/ __/__  ________  ____  / /_
  / __  / / / / / / __  /  / / / / / /_/ /_/ _ \/ ___/ _ \/ __ \/ __/
 / /_/ / /_/ / / / /_/ /  / /_/ / / __/ __/  __/ /  /  __/ / / / /__ 
/_____/\__,_/_/_/\__,_/  /_____/_/_/ /_/  \___/_/   \___/_/ /_/\__(_)

*/

pragma solidity 0.8.17;

///////////////////// IMPORTS /////////////////////

import { Initializable } from "openzeppelin-upgradeable/proxy/utils/Initializable.sol";
import { ERC721Upgradeable } from "openzeppelin-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import { StringsUpgradeable } from "openzeppelin-upgradeable/utils/StringsUpgradeable.sol";
import { StoryContractUpgradeable } from "tl-story/upgradeable/StoryContractUpgradeable.sol";
import { EIP2981TL } from "../royalties/EIP2981TL.sol";
import { CoreAuthTL } from "../access/CoreAuthTL.sol";

///////////////////// CUSTOM ERRORS /////////////////////

/// @dev token uri is an empty string
error EmptyTokenURI();

/// @dev batch size too small
error BatchSizeTooSmall();

/// @dev airdrop to zero addresses
error AirdropToZeroAddresses();

/// @dev token not owned by the owner of the contract
error TokenNotOwnedByOwner();

/// @dev caller is not the owner of the specific token
error CallerNotTokenOwner();

/// @dev caller is not approved or owner
error CallerNotApprovedOrOwner();

/// @dev token does not exist
error TokenDoesNotExist();

/// @dev no proposed token uri to change to
error NoTokenUriUpdateAvailable();

///////////////////// ERC721TL CONTRACT /////////////////////

contract ERC721TL is Initializable, ERC721Upgradeable, EIP2981TL, CoreAuthTL, StoryContractUpgradeable {

    ///////////////////// STRUCTS & ENUMS /////////////////////

    /// @dev struct defining a batch mint
    struct BatchMint {
        address creator;
        uint256 fromTokenId;
        uint256 toTokenId;
        string baseUri;
    }

    /// @dev enum defining Synergy actions
    enum SynergyAction { Created, Accepted, Rejected }

    ///////////////////// STORAGE VARIABLES /////////////////////
    using StringsUpgradeable for uint256;
    uint256 private _counter; // token ids
    mapping(uint256 => string) private _proposedTokenUris; // Synergy
    mapping(uint256 => string) private _tokenUris; // established token ids
    BatchMint[] private _batchMints; // dynamic array for batch mints

    ///////////////////// EVENTS /////////////////////

    /// @dev This event is for consecutive transfers per EIP-2309
    event ConsecutiveTransfer(uint256 indexed fromTokenId, uint256 toTokenId, address indexed fromAddress, address indexed toAddress);

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

    ///////////////////// INITIALIZER /////////////////////

    function initialize(
        string memory name, 
        string memory symbol, 
        address initOwner,
        address[] memory admins,
        address[] memory mintContracts,
        address defaultRoyaltyRecipient, 
        uint256 defaultRoyaltyPercentage, 
        bool enableStory,
        bool enableBlockList,
        address blockListSubscription
    ) external initializer {
        __ERC721_init(name, symbol);
        __EIP2981_init(defaultRoyaltyRecipient, defaultRoyaltyPercentage);
        __CoreAuthTL_init(initOwner, admins, mintContracts);
        __StoryContractUpgradeable_init(enableStory);
    }

    ///////////////////// GENERAL FUNCTIONS /////////////////////

    /// @notice function to get total supply minted so far
    function totalSupply() external view returns (uint256) {
        return _counter;
    }

    /// @notice function to give back version
    function version() external pure returns (uint256) {
        return 1;
    }

    ///////////////////// MINT FUNCTIONS /////////////////////

    /// @notice function to mint a single token to contract owner
    /// @dev requires owner or admin
    function mint(string calldata uri) external onlyAdminOrOwner {
        if (bytes(uri).length == 0) {
            revert EmptyTokenURI();
        }
        _counter++;
        _tokenUris[_counter] = uri;
        _mint(owner(), _counter);
    }

    /// @notice function to batch mint tokens to contract owner
    /// @dev requires owner or admin
    function batchMint(uint256 numTokens, string calldata baseUri) external onlyAdminOrOwner {
        if (bytes(baseUri).length == 0) {
            revert EmptyTokenURI(); // can't have an empty uri
        }
        if (numTokens < 2) {
            revert BatchSizeTooSmall(); // can't have a batch size less than or equal to 1 - logic breaks
        }
        uint256 start = _counter + 1;
        uint256 end = start + numTokens;
        address owner = owner();
        _batchMints.push(
            BatchMint(owner, start, end, baseUri)
        );
        _counter += numTokens;

        _beforeTokenTransfer(address(0), owner, start, numTokens); // this hook adds the number of tokens to the owner address

        emit ConsecutiveTransfer(start, end, address(0), owner);
    }

    /// @notice function to airdrop tokens to addresses
    /// @dev requires owner or admin
    /// @dev utilizes batch mint token uri values to save some gas 
    ///      but still ultimately mints individual tokens to people
    function airdrop(address[] calldata addresses, string calldata baseUri) external onlyAdminOrOwner {
        if (bytes(baseUri).length == 0) {
            revert EmptyTokenURI(); // can't have an empty uri
        }
        if (addresses.length < 1) {
            revert AirdropToZeroAddresses(); // can't airdrop to 0 addresses
        }
        uint256 start = _counter + 1;
        _counter += addresses.length;
        _batchMints.push(
            BatchMint(address(0), start, start + addresses.length, baseUri)
        );
        for (uint256 i = 0; i < addresses.length; i++) {
            _mint(addresses[i], start + i);
        }
    }

    /// @notice function to allow an approved mint contract to mint
    /// @dev requires the contract to be an approved mint contract in CoreAuthTL
    function externalMint(address recipient, string calldata uri) external onlyApprovedMintContract {
        if (bytes(uri).length == 0) {
            revert EmptyTokenURI();
        }
        _counter++;
        _tokenUris[_counter] = uri;
        _mint(recipient, _counter);
    }

    ///////////////////// BATCH MINT FUNCTION & OVERRIDE /////////////////////

    /// @notice function to get batch mint info
    /// @return owner of the token (address)
    /// @return string of the uri
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
        string memory tokenUri = string(
            abi.encodePacked(
                _batchMints[i].baseUri,
                (tokenId - _batchMints[i].fromTokenId).toString()
            )
        );
        return (_batchMints[i].creator, tokenUri);
    }

    /// @notice function to override { ERC721Upgradeable._ownerOf } to allow for batch minting
    function _ownerOf(uint256 tokenId) internal view override(ERC721Upgradeable) returns (address) {
        if (tokenId > 1 && tokenId <= _counter) {
            address owner = ERC721Upgradeable._ownerOf(tokenId);
            if (owner == address(0)) {
                // see if can find token in a batch mint
                (owner, ) = _getBatchInfo(tokenId);
            }
            return owner;
        } else {
            return address(0);
        }
        
    }

    ///////////////////// BURN FUNCTIONS /////////////////////

    /// @notice function to burn a token
    /// @dev caller must be approved or owner
    function burn(uint256 tokenId) external {
        if (!_isApprovedOrOwner(msg.sender, tokenId)) {
            revert CallerNotApprovedOrOwner();
        }
        _burn(tokenId);
    }

    /// @notice function to burn a batch of tokens
    /// @dev caller must be approved or owner for each token
    function burnBatch(uint256[] calldata tokenIds) external {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (!_isApprovedOrOwner(msg.sender, tokenIds[i])) {
                revert CallerNotApprovedOrOwner();
            }
            _burn(tokenIds[i]);
        }
    }

    ///////////////////// ROYALTY FUNCTIONS /////////////////////

    /// @notice function to override a token's royalty info
    /// @dev requires owner or admin
    /// @dev requires the token to be owned by the owner
    function setTokenRoyalty(uint256 tokenId, address newRecipient, uint256 newPercentage) external onlyAdminOrOwner {
        if (ownerOf(tokenId) != owner()) {
            revert TokenNotOwnedByOwner();
        }
        _overrideTokenRoyaltyInfo(tokenId, newRecipient, newPercentage);
    }

    ///////////////////// SYNERGY FUNCTIONS /////////////////////

    /// @notice function to propose a token uri update for a specific token
    /// @dev requires admin or owner
    /// @dev if the owner of the contract is the owner of the token, the change takes hold right away
    function proposeNewTokenUri(uint256 tokenId, string calldata newUri) external onlyAdminOrOwner {
        if (!_exists(tokenId)) {
            revert TokenDoesNotExist();
        }
        if (bytes(newUri).length == 0) {
            revert EmptyTokenURI();
        }
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
    /// @dev requires owner of the token to call the function (although may want to allow operators too imo)
    function acceptTokenUriUpdate(uint256 tokenId) external {
        if (ownerOf(tokenId) != msg.sender) {
            revert CallerNotTokenOwner();
        }
        string memory uri = _proposedTokenUris[tokenId];
        if (bytes(uri).length == 0) {
            revert NoTokenUriUpdateAvailable();
        }
        _tokenUris[tokenId] = uri;
        delete _proposedTokenUris[tokenId];
        emit MetadataUpdate(tokenId);
        emit SynergyStatusChange(msg.sender, tokenId, SynergyAction.Accepted, uri);
    }

    /// @notice function to reject a proposed token uri update for a specific token
    /// @dev simply rejects the proposal
    function rejectTokenUriUpdate(uint256 tokenId) external {
        if (ownerOf(tokenId) != msg.sender) {
            revert CallerNotTokenOwner();
        }
        string memory uri = _proposedTokenUris[tokenId];
        if (bytes(uri).length == 0) {
            revert NoTokenUriUpdateAvailable();
        }
        delete _proposedTokenUris[tokenId];
        emit SynergyStatusChange(msg.sender, tokenId, SynergyAction.Rejected, "");
    }

    ///////////////////// TOKEN URI OVERRIDE /////////////////////

    /// @notice function for token uris
    function tokenURI(uint256 tokenId) public view override(ERC721Upgradeable) returns (string memory) {
        if (!_exists(tokenId)) {
            revert TokenDoesNotExist();
        }

        string memory uri = _tokenUris[tokenId];
        if (bytes(uri).length == 0) {
            (, uri) = _getBatchInfo(tokenId);
        }

        return uri;
    }

    ///////////////////// STORY CONTRACT HOOKS /////////////////////

    /// @dev function to check if a token exists on the token contract
    function _tokenExists(uint256 tokenId) internal view override(StoryContractUpgradeable) returns (bool) {
        return _exists(tokenId);
    }

    /// @dev function to check ownership of a token
    function _isTokenOwner(address potentialOwner, uint256 tokenId) internal view override(StoryContractUpgradeable) returns (bool) {
        address tokenOwner = ownerOf(tokenId);
        return tokenOwner == potentialOwner;
    }

    /// @dev function to check creatorship of a token
    /// @dev currently restricted to the owner of the contract although a case could be made for admins too
    function _isCreator(address potentialCreator, uint256 /* tokenId */) internal view override(StoryContractUpgradeable) returns (bool) {
        return getIfOwner(potentialCreator);
    }

    ///////////////////// BLOCKLIST FUNCTIONS /////////////////////



    ///////////////////// ERC-165 OVERRIDE /////////////////////

    /// @notice function to override ERC165 supportsInterface
    function supportsInterface(bytes4 interfaceId) public view override(ERC721Upgradeable, EIP2981TL, CoreAuthTL, StoryContractUpgradeable) returns (bool) {
        return (
            ERC721Upgradeable.supportsInterface(interfaceId) ||
            EIP2981TL.supportsInterface(interfaceId) ||
            CoreAuthTL.supportsInterface(interfaceId) ||
            StoryContractUpgradeable.supportsInterface(interfaceId) ||
            interfaceId == bytes4(0x49064906) // EIP-4906 support
        );
    }
}
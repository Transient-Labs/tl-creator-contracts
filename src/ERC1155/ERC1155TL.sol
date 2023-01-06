// SPDX-License-Identifier: Apache-2.0

/// @title ERC1155TL.sol
/// @notice Transient Labs core ERC1155 contract (v1)
/// @dev features include
///      - batch minting
///      - airdrops
///      - ability to hook in external mint contracts
///      - ability to set multiple admins
///      - ability to enable/disable the Story Contract at creation time
///      - ability to enable/disable BlockList at creation time
///      - Synergy metadata protection? - don't know if there is a good way for this
///      - individual token royalties
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

import { ERC1155Upgradeable } from "openzeppelin-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import { IERC1155Upgradeable } from "openzeppelin-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";
import { StoryContractUpgradeable } from "tl-story/upgradeable/StoryContractUpgradeable.sol";
import { CoreAuthTL } from "../access/CoreAuthTL.sol";
import { EIP2981TL } from "../royalties/EIP2981TL.sol";

///////////////////// CUSTOM ERRORS /////////////////////

/// @dev token uri is an empty string
error EmptyTokenURI();

/// @dev batch size too small
error BatchSizeTooSmall();

/// @dev mint to zero addresses
error MintToZeroAddresses();

/// @dev array length mismatch
error ArrayLengthMismatch();

/// @dev token not owned by the owner of the contract
error TokenNotOwnedByOwner();

/// @dev caller is not approved or owner
error CallerNotApprovedOrOwner();

/// @dev token does not exist
error TokenDoesNotExist();

/// @dev burning zero tokens
error BurnZeroTokens();

///////////////////// ERC1155TL CONTRACT /////////////////////

contract ERC1155TL is ERC1155Upgradeable, EIP2981TL, CoreAuthTL, StoryContractUpgradeable {

    ///////////////////// STRUCTS /////////////////////

    /// @dev struct defining a token
    struct Token {
        bool created;
        string uri;
    }

    ///////////////////// STORAGE VARIABLES /////////////////////

    uint256 private _counter;
    string public name;
    mapping(uint256 => Token) private _tokens;

    ///////////////////// INITIALIZER /////////////////////

    function initialize(
        string memory name_, 
        address initOwner,
        address[] memory admins,
        address[] memory mintContracts,
        address defaultRoyaltyRecipient, 
        uint256 defaultRoyaltyPercentage,
        bool enableStory,
        bool enableBlockList,
        address blockListSubscription
    ) external initializer {
        __ERC1155_init("");
        __EIP2981_init(defaultRoyaltyRecipient, defaultRoyaltyPercentage);
        __CoreAuthTL_init(initOwner, admins, mintContracts);
        __StoryContractUpgradeable_init(enableStory);
        name = name_;
    }

    ///////////////////// GENERAL FUNCTIONS /////////////////////

    /// @notice function to give back version
    function version() external pure returns (uint256) {
        return 1;
    }

    ///////////////////// CREATION FUNCTIONS /////////////////////

    /// @notice function to create a token that can be minted to creator or airdropped
    /// @dev requires owner or admin
    function createToken(string memory newUri, address[] calldata addresses, uint256[] calldata amounts) external onlyAdminOrOwner {
        _createToken(newUri, addresses, amounts);
    }

    /// @notice function to create a token that can be minted to creator or airdropped
    /// @dev requires owner
    function createToken(string memory newUri, address[] calldata addresses, uint256[] calldata amounts, address royaltyRecipient, uint256 royaltyPercentage) external onlyAdminOrOwner {
        _overrideTokenRoyaltyInfo(_counter, royaltyRecipient, royaltyPercentage);
        _createToken(newUri, addresses, amounts);
    }

    /// @notice private helper function
    function _createToken(string memory newUri, address[] calldata addresses, uint256[] calldata amounts) private {
        if (bytes(newUri).length == 0) {
            revert EmptyTokenURI();
        }
        if (addresses.length == 0) {
            revert MintToZeroAddresses();
        }
        if (addresses.length != amounts.length) {
            revert ArrayLengthMismatch();
        }
        _counter++;
        _tokens[_counter] = Token(true, newUri);
        for (uint256 i = 0; i < addresses.length; i++) {
            _mint(addresses[i], _counter, amounts[i], "");
        }
    }

    /// @notice private helper function to verify a token exists
    function _exists(uint256 tokenId) private view returns(bool) {
        return _tokens[tokenId].created;
    }

    ///////////////////// MINT FUNCTIONS /////////////////////

    /// @notice function to mint existing token to recipients
    /// @dev requires owner or admin
    function mintToken(uint256 tokenId, address[] calldata addresses, uint256[] calldata amounts) external onlyAdminOrOwner {
        _mintToken(tokenId, addresses, amounts);
    }

    /// @notice external mint function
    /// @dev requires caller to be an approved mint contract
    function externalMint(uint256 tokenId, address[] calldata addresses, uint256[] calldata amounts) external onlyApprovedMintContract {
        _mintToken(tokenId, addresses, amounts);
    }

    /// @notice private helper function
    function _mintToken(uint256 tokenId, address[] calldata addresses, uint256[] calldata amounts) private {
        if (!_exists(tokenId)) {
            revert TokenDoesNotExist();
        }
        if (addresses.length == 0) {
            revert MintToZeroAddresses();
        }
        if (addresses.length != amounts.length) {
            revert ArrayLengthMismatch();
        }

        for (uint256 i = 0; i < addresses.length; i++) {
            _mint(addresses[i], tokenId, amounts[i], "");
        }
    }

    ///////////////////// BURN FUNCTIONS /////////////////////

    /// @notice function to burn tokens from an account
    /// @dev msg.sender must be owner or operator
    function burn(address from, uint256[] calldata tokenIds, uint256[] calldata amounts) external {
        if (tokenIds.length == 0) {
            revert BurnZeroTokens();
        }
        if (msg.sender != from && !isApprovedForAll(from, msg.sender)) {
            revert CallerNotApprovedOrOwner();
        }
        _burnBatch(from, tokenIds, amounts);
    }

    ///////////////////// TOKEN URI FUNCTIONS /////////////////////

    /// @notice function to set token Uri for a token
    /// @dev requires owner or admin
    function setTokenUri(uint256 tokenId, string calldata newUri) external onlyAdminOrOwner {
        if (!_exists(tokenId)) {
            revert TokenDoesNotExist();
        }
        if (bytes(newUri).length == 0) {
            revert EmptyTokenURI();
        }
        _tokens[tokenId].uri = newUri;
        emit IERC1155Upgradeable.URI(newUri, tokenId);
    }

    /// @notice function for token uris
    function uri(uint256 tokenId) public view override(ERC1155Upgradeable) returns (string memory) {
        if (!_exists(tokenId)) {
            revert TokenDoesNotExist();
        }

        return _tokens[tokenId].uri;
    }

    ///////////////////// STORY CONTRACT HOOKS /////////////////////

    /// @dev function to check if a token exists on the token contract
    function _tokenExists(uint256 tokenId) internal view override(StoryContractUpgradeable) returns (bool) {
        return _exists(tokenId);
    }

    /// @dev function to check ownership of a token
    function _isTokenOwner(address potentialOwner, uint256 tokenId) internal view override(StoryContractUpgradeable) returns (bool) {
        uint256 tokenBalance = balanceOf(potentialOwner, tokenId);
        return tokenBalance > 0;
    }

    /// @dev function to check creatorship of a token
    /// @dev currently restricted to the owner of the contract although a case could be made for admins too
    function _isCreator(address potentialCreator, uint256 /* tokenId */) internal view override(StoryContractUpgradeable) returns (bool) {
        return getIfOwner(potentialCreator);
    }

    ///////////////////// BLOCKLIST FUNCTIONS /////////////////////



    ///////////////////// ERC-165 OVERRIDE /////////////////////

    /// @notice function to override ERC165 supportsInterface
    function supportsInterface(bytes4 interfaceId) public view override(ERC1155Upgradeable, EIP2981TL, CoreAuthTL, StoryContractUpgradeable) returns (bool) {
        return (
            ERC1155Upgradeable.supportsInterface(interfaceId) ||
            EIP2981TL.supportsInterface(interfaceId) ||
            CoreAuthTL.supportsInterface(interfaceId) ||
            StoryContractUpgradeable.supportsInterface(interfaceId)
        );
    }

}
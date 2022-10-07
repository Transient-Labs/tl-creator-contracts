// SPDX-License-Identifier: Apache-2.0

/// @title ERC1155TL.sol
/// @notice Transient Labs core ERC1155 contract for creators to mint artwork in a series/collection
/// @author transientlabs.xyz

/*
    ____        _ __    __   ____  _ ________                     __ 
   / __ )__  __(_) /___/ /  / __ \(_) __/ __/__  ________  ____  / /_
  / __  / / / / / / __  /  / / / / / /_/ /_/ _ \/ ___/ _ \/ __ \/ __/
 / /_/ / /_/ / / / /_/ /  / /_/ / / __/ __/  __/ /  /  __/ / / / /__ 
/_____/\__,_/_/_/\__,_/  /_____/_/_/ /_/  \___/_/   \___/_/ /_/\__(_)

*/

pragma solidity ^0.8.14;

import "OpenZeppelin/openzeppelin-contracts-upgradeable@4.7.3/contracts/token/ERC1155/ERC1155Upgradeable.sol";
import "./EIP2981TL.sol";
import "OpenZeppelin/openzeppelin-contracts-upgradeable@4.7.3/contracts/access/OwnableUpgradeable.sol";

contract ERC1155TL is ERC1155Upgradeable, EIP2981TL, OwnableUpgradeable {

    //================= State Variables =================//
    struct Token {
        bool created;
        string uri;
    }

    uint256 private _counter;
    string public name;
    mapping(uint256 => Token) private _tokens;
    mapping(address => bool) private _blockList;

    //================= Init =================//

    function initialize(string memory name_, address owner, address defaultRecipient, uint256 defaultPercentage) external onlyInitializing {
        __ERC1155_init("");
        __EIP2981_init(defaultRecipient, defaultPercentage);
        __Ownable_init();
        _transferOwnership(owner);
        name = name_;
    }

    //================= Custom Functions =================//

    /// @notice function to set an address either on or off the BlockList
    /// @dev requires owner
    function setBlockList(address operator, bool status) external onlyOwner {
        _blockList[operator] = status;
    }

    /// @notice function to set default royalty info
    /// @dev requires owner
    function setRoyaltyInfo(address newRecipient, uint256 newPercentage) external onlyOwner {
        _setRoyaltyInfo(newRecipient, newPercentage);
    }

    /// @notice function to override a token's royalty info
    /// @dev requires owner
    function setTokenRoyalty(uint256 tokenId, address newRecipient, uint256 newPercentage) external onlyOwner {
        _overrideTokenRoyaltyInfo(tokenId, newRecipient, newPercentage);
    }

    /// @notice function to create a token that can be minted to creator or airdropped
    /// @dev requires owner
    function createToken(string memory uri_, address royaltyRecipient, uint256 royaltyPercentage) external onlyOwner {
        require(bytes(uri_).length != 0, "ERC1155TL: uri cannot be empty");
        _counter++;
        _tokens[_counter].created = true;
        _tokens[_counter].uri = uri_;
        _overrideTokenRoyaltyInfo(_counter, royaltyRecipient, royaltyPercentage);
    }

    /// @notice function to mint tokens to owner wallet
    /// @dev requires owner
    function mint(uint256 tokenId, uint256 numTokens) external onlyOwner {
        require(_tokens[tokenId].created, "ERC1155TL: nonexistent token");
        _mint(owner(), tokenId, numTokens, "");
    }

    /// @notice function to airdrop tokens to addresses
    /// @dev rquires owner
    function airdrop(uint256 tokenId, address[] calldata addresses) external onlyOwner {
        require(_tokens[tokenId].created, "ERC1155TL: nonexistent token");
        for (uint256 i; i < addresses.length; i++) {
            _mint(addresses[i], tokenId, 1, "");
        }
    }

    /// @notice function to set token uri
    /// @dev requires owner
    function setUri(uint256 tokenId, string calldata newUri) external onlyOwner {
        require(_tokens[tokenId].created, "ERC1155TL: nonexistent token");
        _tokens[tokenId].uri = newUri;
    }

    /// @notice function to burn a token from an account
    /// @dev msg.sender must be owner or operator
    function burn(address from, uint256 tokenId, uint256 amount) external {
        require(msg.sender == from || isApprovedForAll(from, msg.sender), "ERC1155: not approved to burn tokens for this address");
        _burn(from, tokenId, amount);
    }

    //================= Override for BlockList =================//

    /// @notice function override to implement BlockList
    /// @dev lets any removal of approval through regardless of operator
    function setApprovalForAll(address operator, bool approved) public virtual override {
        require(!_blockList[operator] || !approved, "ERC1155TL: operator cannot be approved... is on BlockList");
        ERC1155Upgradeable.setApprovalForAll(operator, approved);
    }

    //================= Needed Overrides =================//

    /// @notice override function for token uri
    function uri(uint256 tokenId) public view override returns (string memory) {
        require(_tokens[tokenId].created, "ERC1155TL: nonexistent token");
        return _tokens[tokenId].uri;
    }   

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC1155Upgradeable, EIP2981TL) returns (bool) {
        return ERC1155Upgradeable.supportsInterface(interfaceId) || EIP2981TL.supportsInterface(interfaceId);
    }
}
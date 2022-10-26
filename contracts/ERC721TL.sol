// SPDX-License-Identifier: Apache-2.0

/// @title ERC721TL.sol
/// @notice Transient Labs core ERC721 contract for creators to mint artwork in a series/collection
/// @author transientlabs.xyz

/*
    ____        _ __    __   ____  _ ________                     __ 
   / __ )__  __(_) /___/ /  / __ \(_) __/ __/__  ________  ____  / /_
  / __  / / / / / / __  /  / / / / / /_/ /_/ _ \/ ___/ _ \/ __ \/ __/
 / /_/ / /_/ / / / /_/ /  / /_/ / / __/ __/  __/ /  /  __/ / / / /__ 
/_____/\__,_/_/_/\__,_/  /_____/_/_/ /_/  \___/_/   \___/_/ /_/\__(_)

*/

pragma solidity ^0.8.14;

import "./ERC721UpgradeableTL.sol";
import "./EIP2981TL.sol";
import "./IStory.sol";
import "OpenZeppelin/openzeppelin-contracts-upgradeable@4.7.3/contracts/access/OwnableUpgradeable.sol";

contract ERC721TL is IStory, ERC721UpgradeableTL, EIP2981TL, OwnableUpgradeable {

    //================= State Variables =================//
    struct BatchMint {
        address creator;
        uint256 fromTokenId;
        uint256 toTokenId;
        string baseUri;
    }

    uint256 private _counter;
    mapping(address => bool) private _blockList;
    mapping(uint256 => string) private _tokenUris;
    BatchMint[] private _batchMints;

    bool private _storyEnabled;

    //================= Events =================//

    /// @dev This event is for consecutive transfers per EIP-2309
    event ConsecutiveTransfer(uint256 indexed fromTokenId, uint256 toTokenId, address indexed fromAddress, address indexed toAddress);

    /// @dev This event emits when the metadata of a token is changed.
    /// So that the third-party platforms such as NFT market could
    /// timely update the images and related attributes of the NFT.
    /// @dev EIP-4906
    event MetadataUpdate(uint256 _tokenId);

    /// @dev This event emits when the metadata of a range of tokens is changed.
    /// So that the third-party platforms such as NFT market could
    /// timely update the images and related attributes of the NFTs.   
    /// @dev EIP-4906 
    event BatchMetadataUpdate(uint256 _fromTokenId, uint256 _toTokenId);

    //================= Init =================//

    function initialize(
        string memory name, 
        string memory symbol, 
        address owner, 
        address royaltyRecipient, 
        uint256 royaltyPercentage, 
        bool storyEnabled
    ) external initializer {
        __ERC721_init(name, symbol);
        __EIP2981_init(royaltyRecipient, royaltyPercentage);
        __Ownable_init();
        _transferOwnership(owner);
        _storyEnabled = storyEnabled;
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

    /// @notice function to mint a single token
    /// @dev requires owner
    function mint(string calldata uri) external onlyOwner {
        require(bytes(uri).length != 0, "ERC721TL: uri cannot be empty");
        _counter++;
        _tokenUris[_counter] = uri;
        _mint(owner(), _counter);
    }

    /// @notice function to batch mint tokens
    /// @dev requires owner
    function batchMint(uint256 numTokens, string calldata baseUri) external onlyOwner {
        require(bytes(baseUri).length != 0, "ERC721TL: base uri cannot be empty");
        uint256 start = _counter + 1;
        uint256 end = start + numTokens;
        _batchMints.push(BatchMint(owner(), start, end, baseUri));
        _counter += numTokens;

        _beforeConsecutiveTokenTransfer(address(0), owner(), start, uint96(numTokens));

        emit ConsecutiveTransfer(start, end, address(0), owner());
    }

    /// @notice function to airdrop
    /// @dev requires owner
    function airdrop(address[] calldata addresses, string calldata baseUri) external onlyOwner {
        require(bytes(baseUri).length != 0, "ERC721TL: base uri cannot be empty");
        uint256 start = _counter + 1;
        _counter += addresses.length;
        _batchMints.push(BatchMint(owner(), start, start + addresses.length, baseUri));
        for (uint256 i; i < addresses.length; i++) {
            _safeMint(addresses[i], start + i);
        }
    }

    /// @notice function to set token Uri for a token
    /// @dev requires owner
    function setTokenUri(uint256 tokenId, string calldata newUri) external onlyOwner {
        require(_exists(tokenId), "ERC721TL: cannot set uri for nonexistent token");
        require(bytes(newUri).length != 0, "ERC721TL: new uri cannot be empty");
        _tokenUris[tokenId] = newUri;
    }

    /// @notice function to burn a token
    function burn(uint256 tokenId) external {
        require(_exists(tokenId), "ERC721TL: cannot burn nonexistent token");
        _burn(tokenId);
    }

    /// @notice function to get total supply minted so far
    function totalSupply() external view returns (uint256) {
        return _counter;
    }

    /// @notice function to get batch mint info
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
        return (_batchMints[i].creator, _batchMints[i].baseUri);
    }

    //================= Overrides for BlockList =================//

    /// @notice function override to implement BlockList
    function approve(address to, uint256 tokenId) public virtual override {
        require(!_blockList[to], "ERC721TL: address cannot be approved... is on BlockList");
        ERC721UpgradeableTL.approve(to, tokenId);
    }

    /// @notice function override to implement BlockList
    /// @dev lets any removal of approval through regardless of operator
    function setApprovalForAll(address operator, bool approved) public virtual override {
        require(!_blockList[operator] || !approved, "ERC721TL: operator cannot be approved... is on BlockList");
        ERC721UpgradeableTL.setApprovalForAll(operator, approved);
    }

    //================= Overrides for Batch Minting =================//
    function ownerOf(uint256 tokenId) public view override returns (address) {
        if (tokenId > 0 && tokenId <= _counter) {
            address owner = ERC721UpgradeableTL.ownerOf(tokenId);
            if (owner == address(0)) {
                (owner, ) = _getBatchInfo(tokenId);
                if (owner == address(0)) {
                    revert("ERC721TL: nonexistent token");
                }
            }

            return owner;

        } else {
            revert("ERC721TL: nonexistent token");
        }
    }

    function _exists(uint256 tokenId) internal view override returns (bool) {
        (address owner, ) = _getBatchInfo(tokenId);
        return _ownerOf(tokenId) != address(0) || owner != address(0);
    }
    
    //================= Needed Overrides =================//

    /// @notice function for token uris
    function tokenURI(uint256 tokenId) override public view returns (string memory) {
        require(_exists(tokenId), "ERC721TL: nonexistent token");

        string memory uri = _tokenUris[tokenId];
        if (bytes(uri).length == 0) {
            (, uri) = _getBatchInfo(tokenId);
        }

        return uri;
    }

    /// @notice function to override ERC165 supportsInterface
    function supportsInterface(bytes4 interfaceId) public view override(ERC721UpgradeableTL, EIP2981TL) returns (bool) {
        return ERC721UpgradeableTL.supportsInterface(interfaceId) || EIP2981TL.supportsInterface(interfaceId);
    }

    //================= Functions for IStory =================//

    /// @notice Allows owner to enable/disable stories
    /// @dev requires owner
    function setStoryEnabled(bool storyEnabled) external onlyOwner {
        _storyEnabled = storyEnabled;
    }

    /// @notice Shows if story feature is enabled
    /// @return bool True if enabled, False otherwise
    function storyEnabled() external view returns (bool) {
        return _storyEnabled;
    }

    /// @notice Allows creator to add a story.
    /// @dev requires owner
    /// @dev emits a CreatorStory event
    /// @param tokenId The token id a creator is adding a story to
    /// @param creatorName The name of the creator/artist
    /// @param story The story to be attached to the token
    function addCreatorStory(uint256 tokenId, string calldata creatorName, string calldata story) external onlyOwner {
        require(_storyEnabled, "ERC721TL: Story must be enabled");
        require(_exists(tokenId), "ERC721TL: token must exist");
        emit CreatorStory(tokenId, msg.sender, creatorName, story);
    }

    /// @notice Allows creator to add a story.
    /// @dev requires token owner
    /// @dev emits a Story event
    /// @param tokenId The token id a creator is adding a story to
    /// @param collectorName The name of the collector
    /// @param story The story to be attached to the token
    function addStory(uint256 tokenId, string calldata collectorName, string calldata story) external {
        require(_storyEnabled, "ERC721TL: Story must be enabled");
        require(ownerOf(tokenId) == msg.sender, "ERC721TL: must be token owner");
        emit Story(tokenId, msg.sender, collectorName, story);
    }
}
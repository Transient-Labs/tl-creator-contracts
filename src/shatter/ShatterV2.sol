// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC721ConsecutiveUpgradeable, ERC721Upgradeable, ERC165Upgradeable} from "openzeppelin-upgradeable/token/ERC721/extensions/ERC721ConsecutiveUpgradeable.sol";
import {EIP2981TLUpgradeable} from "tl-sol-tools/upgradeable/royalties/EIP2981TLUpgradeable.sol";
import {OwnableAccessControlUpgradeable} from "tl-sol-tools/upgradeable/access/OwnableAccessControlUpgradeable.sol";
import {StoryContractUpgradeable} from "tl-story/upgradeable/StoryContractUpgradeable.sol";
import {BlockListUpgradeable} from "tl-blocklist/BlockListUpgradeable.sol";

/// @title Shatter V2
/// @notice Shatter V2 where the original pieces Shatters into unique 1/1's. No Fuse functionality and owners don't choose number to shatter
/// @author transientlabs.xyz
/// @custom:version 2.0.0
contract ShatterV2 is
    ERC721ConsecutiveUpgradeable,
    EIP2981TLUpgradeable,
    OwnableAccessControlUpgradeable,
    StoryContractUpgradeable,
    BlockListUpgradeable
{
    /*//////////////////////////////////////////////////////////////////////////
                                      Events
    //////////////////////////////////////////////////////////////////////////*/

    event Shattered(
        address indexed user,
        uint256 indexed numShatters,
        uint256 indexed shatteredTime
    );

    event Fused(address indexed user, uint256 indexed fuseTime);

    /*//////////////////////////////////////////////////////////////////////////
                                        Constants
    //////////////////////////////////////////////////////////////////////////*/

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /*//////////////////////////////////////////////////////////////////////////
                                Private State Variables
    //////////////////////////////////////////////////////////////////////////*/
    
    address private _shatterAddress;
    string private _baseUri;

    /*//////////////////////////////////////////////////////////////////////////
                                Public State Variables
    //////////////////////////////////////////////////////////////////////////*/

    bool public isShattered;
    bool public isFused;
    uint256 public numShatters;
    uint256 public shatters;
    uint256 public shatterTime;

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

    /// @param name is the name of the contract
    /// @param symbol is the contract symbol
    /// @param royaltyRecipient is the royalty recipient
    /// @param royaltyPercentage is the royalty percentage to set
    /// @param initOwner: the owner of the contract
    /// @param admins: array of admin addresses to add to the contract
    /// @param enableStory: a bool deciding whether to add story fuctionality or not
    /// @param blockListRegistry: address of the blocklist registry to use
    /// @param num is the number of shatters that will happen
    /// @param time is time after which shatter can occur
    function initialize(
        string memory name,
        string memory symbol,
        address royaltyRecipient,
        uint256 royaltyPercentage,
        address initOwner,
        address[] memory admins,
        bool enableStory,
        address blockListRegistry,
        uint256 num,
        uint256 time
    ) external initializer {
        require(num >= 1, "Cannot deploy a shatter contract with 0 shatters");
        numShatters = num;
        shatterTime = time;

        __ERC721_init(name, symbol);
        __EIP2981TL_init(royaltyRecipient, royaltyPercentage);
        __OwnableAccessControl_init(initOwner);
        __StoryContractUpgradeable_init(enableStory);
        __BlockList_init(blockListRegistry);

        _setRole(ADMIN_ROLE, admins, true);
    }

    /// @notice function to change the royalty info
    /// @dev requires owner
    /// @dev this is useful if the amount was set improperly at contract creation.
    /// @param newAddr is the new royalty payout addresss
    /// @param newPerc is the new royalty percentage, in basis points (out of 10,000)
    function setRoyaltyInfo(
        address newAddr,
        uint256 newPerc
    ) external onlyOwner {
        _setDefaultRoyaltyInfo(newAddr, newPerc);
    }

    /// @notice function to set base uri
    /// @dev requires owner
    /// @param newUri is the new base uri
    function setBaseURI(string memory newUri) public onlyOwner {
        _setBaseUri(newUri);
    }

    /// @notice function for minting the 1/1 to the owner's address
    /// @dev requires contract owner or admin
    /// @dev sets the description, image, animation url (if exists), and traits for the piece
    /// @dev requires that shatters is equal to 0 -> meaning no piece has been minted
    /// @dev using _mint function as owner() should always be an EOA or trusted entity
    function mint(string memory newUri) external onlyRoleOrOwner(ADMIN_ROLE) {
        require(shatters == 0, "Already minted the first piece");
        _setBaseUri(newUri);
        shatters = 1;
        _mint(owner(), 0);
    }

    /// @notice function for owner of token 0 to unlock the pieces
    /// @dev requires msg.sender to be the owner of token 0
    /// @dev shatters to specified number of shatters
    /// @dev requires isShattered to be false
    /// @dev requires block timestamp to be greater than or equal to shatterTime
    /// @dev purposefully not letting approved addresses shatter as we want owner to be the only one to shatter the token
    function shatter() external {
        address sender = _msgSender();
        require(!isShattered, "Already is shattered");
        require(sender == ownerOf(0), "Caller is not owner of token 0");
        require(
            block.timestamp >= shatterTime,
            "Cannot shatter prior to shatterTime"
        );

        _burn(0);
        _batchMint(sender, numShatters);

        // no reentrancy so can set these after burning and minting
        isShattered = true;
        shatters = numShatters;

        emit Shattered(msg.sender, numShatters, block.timestamp);
    }

    /// @notice function to fuse editions back into a 1/1
    /// @dev requires msg.sender to own all of the editions
    /// @dev can't have already fused
    /// @dev must be shattered
    /// @dev purposefully not letting approved addresses fuse as we want the owner to have only control over fusing
    function fuse() external {
        require(!isFused, "Already is fused");
        require(isShattered, "Can't fuse if not already shattered");
        address sender = _msgSender();
        for (uint256 id = 1; id < shatters + 1; id++) {
            require(sender == ownerOf(id), "Msg sender must own all editions");
            _burn(id);
        }
        isFused = true;
        shatters = 1;
        _mint(sender, 0);

        emit Fused(sender, block.timestamp);
    }

    /// @notice function to override ownerOf in ERC721S
    /// @dev if is shattered and not fused, checks to see if that token has been transferred or if it belongs to the shatterAddress.
    ///     Otherwise, returns result from ERC721S.
    function ownerOf(
        uint256 tokenId
    ) public view virtual override returns (address) {
        if (isShattered) {
            if (tokenId > 0 && tokenId <= shatters) {
                address owner = _ownerOf(tokenId);
                if (owner == address(0)) {
                    return _shatterAddress;
                } else {
                    return owner;
                }
            } else {
                revert("Invalid token id");
            }
        } else {
            return super.ownerOf(tokenId);
        }
    }

    /// @notice function to override the _exists function in ERC721S
    /// @dev if is shattered and not fused, checks to see if tokenId is in the range of shatters
    ///     otherwise, returns result from ERC721S
    function _exists(
        uint256 tokenId
    ) internal view virtual override returns (bool) {
        if (isShattered) {
            if (tokenId > 0 && tokenId <= shatters) {
                return true;
            } else {
                return false;
            }
        } else {
            return super._exists(tokenId);
        }
    }

    /// @notice function to batch mint upon shatter
    /// @dev only mints tokenIds 1 -> quantity to shatterExecutor
    function _batchMint(address shatterExecutor, uint256 quantity) internal {
        require(uint96(quantity) == quantity);
        _shatterAddress = shatterExecutor;
        _mintConsecutive(shatterExecutor, uint96(quantity));
    }

    /// @notice function to set base uri internally
    function _setBaseUri(string memory newUri) internal {
        _baseUri = newUri;
    }

    /// @notice override _baseURI() function from ERC721A
    function _baseURI() internal view override returns (string memory) {
        return _baseUri;
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
    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(
            EIP2981TLUpgradeable,
            ERC721Upgradeable,
            StoryContractUpgradeable
        )
        returns (bool)
    {
        return
            ERC721Upgradeable.supportsInterface(interfaceId) ||
            EIP2981TLUpgradeable.supportsInterface(interfaceId) ||
            StoryContractUpgradeable.supportsInterface(interfaceId) ||
            interfaceId == bytes4(0x49064906);
    }
}

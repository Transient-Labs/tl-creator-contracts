// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC721Upgradeable, ERC165Upgradeable} from "openzeppelin-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {IERC2309Upgradeable} from "openzeppelin-upgradeable/interfaces/IERC2309Upgradeable.sol";
import {EIP2981TLUpgradeable} from "tl-sol-tools/upgradeable/royalties/EIP2981TLUpgradeable.sol";
import {OwnableAccessControlUpgradeable} from "tl-sol-tools/upgradeable/access/OwnableAccessControlUpgradeable.sol";
import {StoryContractUpgradeable} from "tl-story/upgradeable/StoryContractUpgradeable.sol";
import {BlockListUpgradeable} from "tl-blocklist/BlockListUpgradeable.sol";

/// @title Shatter
/// @notice Shatter implementation. Turns 1/1 into a multiple sub-pieces.
/// @author transientlabs.xyz
/// @custom:version 2.0.0
contract Shatter is
    ERC721Upgradeable,
    IERC2309Upgradeable,
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
    uint256 public minShatters;
    uint256 public maxShatters;
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

    /// @param name is the name of the contract and piece
    /// @param symbol is the symbol
    /// @param royaltyRecipient is the royalty recipient
    /// @param royaltyPercentage is the royalty percentage to set
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
    /// @param newUri is the base uri to be used for the shatter folder
    /// @param min is the minimum number of editions
    /// @param max is the maximum number of editions
    /// @param time is time after which replication can occur
    /// @dev requires contract owner or admin
    /// @dev sets the description, image, animation url (if exists), and traits for the piece
    /// @dev requires that shatters is equal to 0 -> meaning no piece has been minted
    /// @dev using _mint function as owner() should always be an EOA or trusted entity that can receive ERC721 tokens
    function mint(
        string memory newUri,
        uint256 min,
        uint256 max,
        uint256 time
    ) external onlyRoleOrOwner(ADMIN_ROLE) {
        require(shatters == 0, "Already minted the first piece");
        
        if (min < 1) {
            minShatters = 1;
        } else {
            minShatters = min;
        }
        maxShatters = max;
        
        shatterTime = time;
        _setBaseUri(newUri);
        shatters = 1;
        _mint(owner(), 0);
    }

    /// @notice function for owner of token 0 to unlock the piece and turn it into an edition
    /// @dev requires msg.sender to be the owner of token 0
    /// @dev requires a number of editions less than or equal to maxShatters or greater than or equal to minShatters
    /// @dev requires isShattered to be false
    /// @dev requires block timestamp to be greater than or equal to shatterTime
    /// @dev purposefully not letting approved addresses shatter as we want owner to be the only one to shatter the token
    /// @dev if number of editions == 1, fuse occurs at the same time
    /// @param numShatters is the total number of editions to make. Can be set between minShatters and maxShatters. This number is the total number of editions that will live on this contract
    function shatter(uint256 numShatters) external {
        address sender = _msgSender();
        require(!isShattered, "Already is shattered");
        require(sender == ownerOf(0), "Caller is not owner of token 0");
        require(
            numShatters >= minShatters && numShatters <= maxShatters,
            "Cannot set number of editions above max or below the min"
        );
        require(
            block.timestamp >= shatterTime,
            "Cannot shatter prior to shatterTime"
        );

        if (numShatters > 1) {
            _burn(0);
            _batchMint(sender, numShatters);
            emit Shattered(sender, numShatters, block.timestamp);
        } else {
            isFused = true;
            emit Shattered(sender, numShatters, block.timestamp);
            emit Fused(sender, block.timestamp);
        }
        // no reentrancy so can set these after burning and minting
        isShattered = true;
        shatters = numShatters;
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
    /// @dev if is shattered and not fused, checks to see if that token has been transferred or if it belongs to the _shatterAddress.
    ///     Otherwise, returns result from ERC721S.
    function ownerOf(
        uint256 tokenId
    ) public view virtual override returns (address) {
        if (isShattered && !isFused) {
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

    /*//////////////////////////////////////////////////////////////////////////
                            Internal Functions 
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice function to override the _exists function in ERC721S
    /// @dev if is shattered and not fused, checks to see if tokenId is in the range of shatters
    ///     otherwise, returns result from ERC721S
    function _exists(
        uint256 tokenId
    ) internal view virtual override returns (bool) {
        if (isShattered && !isFused) {
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
        _beforeTokenTransfer(address(0), _shatterAddress, 0, quantity);
        emit ConsecutiveTransfer(1, quantity, address(0), _shatterAddress);
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

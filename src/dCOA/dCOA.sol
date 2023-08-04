// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC1967Proxy} from "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";
import {EIP712, ECDSA} from "openzeppelin/utils/cryptography/EIP712.sol";
import {IERC721} from "openzeppelin/interfaces/IERC721.sol";

/*//////////////////////////////////////////////////////////////////////////
                            Doppelganger
//////////////////////////////////////////////////////////////////////////*/

/// @title dCOA.sol
/// @notice contract built for the purpose of being a digital & decentralized Certificate of Authenticity (COA) for physical objects
/// @dev this works for only ERC721 contracts, implementation contract should reflect that
/// @author transientlabs.xyz
/// @custom:version 2.7.0
contract dCOA is ERC1967Proxy, EIP712 {
    /*//////////////////////////////////////////////////////////////////////////
                                    Constants
    //////////////////////////////////////////////////////////////////////////*/

    // bytes32(uint256(keccak256('erc721.tl.dCOA')) - 1);
    bytes32 public constant D_COA_STORAGE_SLOT = 0x506d9631d29a36413b99378b28108918d79038e9b044315c404934777355fa94;

    /*//////////////////////////////////////////////////////////////////////////
                                    Events
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice event describing a collector story getting added to a token
    /// @dev this events stores collector stories on chain in the event log
    /// @param tokenId - the token id to which the story is attached
    /// @param collectorAddress - the address of the collector of the token
    /// @param collectorName - string representation of the collectors's name
    /// @param story - the story written and attached to the token id
    event Story(uint256 indexed tokenId, address indexed collectorAddress, string collectorName, string story);

    /*//////////////////////////////////////////////////////////////////////////
                                    Errors
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev unauthorized to write a story
    error Unauthorized();

    /*//////////////////////////////////////////////////////////////////////////
                                    Structs
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev struct used for our storage 
    struct dCOAStorage {
        mapping(uint256 => uint256) nonces; // tokenId -> nonce
    }

    /// @dev struct for story access & EIP-712
    struct StoryAccess {
        address collector;
        uint256 tokenId;
        uint256 tokenNonce;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    Constructor
    //////////////////////////////////////////////////////////////////////////*/

    /// @param name: the name of the contract
    /// @param symbol: the symbol of the contract
    /// @param defaultRoyaltyRecipient: the default address for royalty payments
    /// @param defaultRoyaltyPercentage: the default royalty percentage of basis points (out of 10,000)
    /// @param initOwner: initial owner of the contract
    /// @param admins: array of admin addresses to add to the contract
    /// @param enableStory: a bool deciding whether to add story fuctionality or not
    /// @param blockListRegistry: address of the blocklist registry to use
    constructor(
        address implementation,
        string memory name,
        string memory symbol,
        address defaultRoyaltyRecipient,
        uint256 defaultRoyaltyPercentage,
        address initOwner,
        address[] memory admins,
        bool enableStory,
        address blockListRegistry
    )
        ERC1967Proxy(
            implementation,
            abi.encodeWithSelector(
                0x1fbd2402, // selector for "initialize(string,string,address,uint256,address,address[],bool,address)"
                name,
                symbol,
                defaultRoyaltyRecipient,
                defaultRoyaltyPercentage,
                initOwner,
                admins,
                enableStory,
                blockListRegistry
            )
        )
        EIP712(name, "1")
    {}

    /*//////////////////////////////////////////////////////////////////////////
                                Public Write Functions
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice function to write a story for a token
    /// @dev requires that the passed signature is signed by the token owner, which is the ARX Halo Chip (physical)
    /// @dev uses EIP-712 for the signature
    function addPhysicalOwnerStory(uint256 tokenId, string calldata creatorName, string calldata story, bytes calldata signature) external {
        dCOAStorage storage store;

        assembly {
            store.slot := D_COA_STORAGE_SLOT
        }

        bytes32 digest = _hashTypedDataV4(_hashStoryAccess(tokenId, store.nonces[tokenId]));
        if (IERC721(address(this)).ownerOf(tokenId) != ECDSA.recover(digest, signature)) {
            revert Unauthorized();   
        }

        store.nonces[tokenId]++;

        emit Story(tokenId, msg.sender, creatorName, story);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                External View Functions
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice function to return the nonce for a token
    /// @param tokenId The token to query
    /// @return uint256 The token nonce
    function getTokenNonce(uint256 tokenId) external view returns (uint256) {
        dCOAStorage storage store;

        assembly {
            store.slot := D_COA_STORAGE_SLOT
        }

        return store.nonces[tokenId];
    }

    /*//////////////////////////////////////////////////////////////////////////
                                Internal View Functions
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice function to hash the typed data
    function _hashStoryAccess(uint256 tokenId, uint256 nonce) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("StoryAccess(address collector,uint256 tokenId,uint256 tokenNonce)"),
                msg.sender,
                tokenId,
                nonce
            )
        );
    }
}

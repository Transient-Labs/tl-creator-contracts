// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC1967Proxy} from "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";
import {EIP712, ECDSA} from "openzeppelin/utils/cryptography/EIP712.sol";
import {IERC721} from "openzeppelin/interfaces/IERC721.sol";
import {Strings} from "openzeppelin/utils/Strings.sol";
import {OwnableAccessControl} from "tl-sol-tools/access/OwnableAccessControl.sol";
import {TRACERSRegistry} from "./TRACERSRegistry.sol";

/*//////////////////////////////////////////////////////////////////////////
                                    TRACE
//////////////////////////////////////////////////////////////////////////*/

/// @title TRACE.sol
/// @notice Tokenized Record for Artwork/Asset Certification and Evolution (T.R.A.C.E.)
/// @dev contract built for the purpose of being a digitally Traced Certificate of Authenticity (COA) for physical objects
/// @dev this works for only ERC721 contracts, implementation contract should reflect that
/// @author transientlabs.xyz
/// @custom:version 2.6.0
contract TRACE is ERC1967Proxy, EIP712 {

    using Strings for address;

    /*//////////////////////////////////////////////////////////////////////////
                                    Constants
    //////////////////////////////////////////////////////////////////////////*/

    // bytes32(uint256(keccak256('erc721.tl.TRACE')) - 1);
    bytes32 public constant TRACE_STORAGE_SLOT = 0x6903afa62760e546de6be4476e800b244654a868ec5cf438c7afd6b310bb4804;
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /*//////////////////////////////////////////////////////////////////////////
                                    Events
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice event describing a story getting added to a token
    /// @dev this events stores stories on chain in the event log
    /// @param tokenId - the token id to which the story is attached
    /// @param senderAddress - the address of the sender for this story
    /// @param senderName - string representation of the sender's name
    /// @param story - the story written and attached to the token id
    event Story(uint256 indexed tokenId, address indexed senderAddress, string senderName, string story);

    /*//////////////////////////////////////////////////////////////////////////
                                    Errors
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev invalid signature
    error InvalidSignature();

    /// @dev unauthorized to add a verified story
    error Unauthorized();

    /// @dev not contract owner or admin
    error NotCreatorOrAdmin();

    /*//////////////////////////////////////////////////////////////////////////
                                    Structs
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev struct used for our storage
    struct TRACEStorage {
        TRACERSRegistry registry;
        mapping(uint256 => uint256) nonces; // tokenId -> nonce
    }

    /// @dev struct for verified story & signed EIP-712 message
    struct VerifiedStory {
        uint256 nonce;
        uint256 tokenId;
        address sender;
        string story;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    Constructor
    //////////////////////////////////////////////////////////////////////////*/

    /// @param name The name of the contract
    /// @param symbol The symbol of the contract
    /// @param defaultRoyaltyRecipient The default address for royalty payments
    /// @param defaultRoyaltyPercentage The default royalty percentage of basis points (out of 10,000)
    /// @param initOwner The initial owner of the contract
    /// @param admins: Array of admin addresses to add to the contract
    /// @param enableStory: Bool deciding whether to add story fuctionality or not (should be set to true for this contract really)
    /// @param blockListRegistry: Address of the blocklist registry to use
    /// @param tracersRegistry: The initial TRACERS Registry address
    constructor(
        address implementation,
        string memory name,
        string memory symbol,
        address defaultRoyaltyRecipient,
        uint256 defaultRoyaltyPercentage,
        address initOwner,
        address[] memory admins,
        bool enableStory,
        address blockListRegistry,
        address tracersRegistry
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
    {
        TRACEStorage storage store;
        assembly {
            store.slot := TRACE_STORAGE_SLOT
        }

        store.registry = TRACERSRegistry(tracersRegistry);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                Owner Admin Functions
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Function to set the TRACERS Registry
    /// @dev Only callable by the creator or admin
    function setTRACERSRegistry(address tracersRegistry) external {
        OwnableAccessControl c = OwnableAccessControl(address(this));
        if (c.owner() != msg.sender && !c.hasRole(ADMIN_ROLE, msg.sender)) revert NotCreatorOrAdmin();

        TRACEStorage storage store;
        assembly {
            store.slot := TRACE_STORAGE_SLOT
        }

        store.registry = TRACERSRegistry(tracersRegistry);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                Public Write Functions
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice function to write a story for a token
    /// @dev requires that the passed signature is signed by the token owner, which is the ARX Halo Chip (physical)
    /// @dev uses EIP-712 for the signature
    function addVerifiedStory(uint256 tokenId, string calldata story, bytes calldata signature) external {
        TRACEStorage storage store;
        assembly {
            store.slot := TRACE_STORAGE_SLOT
        }

        // default name to hex address
        string memory registeredAgentName = msg.sender.toHexString();

        // only check registered agent if the registry is not the zero address
        if (address(store.registry) != address(0)) {
            if (address(store.registry).code.length == 0) revert Unauthorized();
            bool isRegisteredAgent;
            (isRegisteredAgent, registeredAgentName) = store.registry.isRegisteredAgent(msg.sender);
            if (!isRegisteredAgent) revert Unauthorized();
        }

        // verify signature
        address coaOwner = IERC721(address(this)).ownerOf(tokenId);
        bytes32 digest = _hashTypedDataV4(_hashVerifiedStory(tokenId, store.nonces[tokenId]++, msg.sender, story));
        if (coaOwner != ECDSA.recover(digest, signature)) revert InvalidSignature();

        // emit story
        emit Story(tokenId, msg.sender, registeredAgentName, story);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                External View Functions
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Function to return the nonce for a token
    /// @param tokenId The token to query
    /// @return uint256 The token nonce
    function getTokenNonce(uint256 tokenId) external view returns (uint256) {
        TRACEStorage storage store;
        assembly {
            store.slot := TRACE_STORAGE_SLOT
        }

        return store.nonces[tokenId];
    }

    /// @notice Function to return the TRACERS registry
    /// @return address The TRACERS registry
    function getTRACERSRegistry() external view returns (address) {
        TRACEStorage storage store;
        assembly {
            store.slot := TRACE_STORAGE_SLOT
        }

        return address(store.registry);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                Internal View Functions
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice function to hash the typed data
    function _hashVerifiedStory(uint256 tokenId, uint256 nonce, address sender, string memory story)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                // keccak256("VerifiedStory(uint256 nonce,uint256 tokenId,address sender,string story)"),
                0x3ea278f3e0e25a71281e489b82695f448ae01ef3fc312598f1e61ac9956ab954,
                nonce,
                tokenId,
                sender,
                keccak256(bytes(story))
            )
        );
    }
}

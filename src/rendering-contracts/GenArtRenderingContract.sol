// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Initializable} from "@openzeppelin-contracts-upgradeable-5.6.1/proxy/utils/Initializable.sol";
import {Strings} from "@openzeppelin-contracts-5.6.1/utils/Strings.sol";
import {IERC165} from "@openzeppelin-contracts-5.6.1/utils/introspection/IERC165.sol";
import {IGenArtRenderingContract, IRenderingContract} from "../interfaces/IGenArtRenderingContract.sol";
import {ERC721TL} from "../erc-721/ERC721TL.sol";

/// @title Generative Art Rendering Contract
/// @notice A rendering contract for generative art (ERC721TL only)
/// @author mpeyfuss
/// @dev DETECTION: this contract reports `type(IGenArtRenderingContract).interfaceId` via ERC-165
///      `supportsInterface`, so backend/indexer systems can read `ERC721TL.renderingContract()` and
///      detect that a given collection is rendered as generative art (vs. a standard/edition renderer).
///
/// @dev RENDER INPUTS (off-chain responsibility):
///      The on-chain `tokenURI` only returns a stable pointer (`<baseUri>/<tokenId>`). The actual mint
///      entropy that drives the art is NOT stored on-chain — it is cheap to derive from the mint
///      transaction and must be injected by the backend as URL query params on the token HTML
///      (`index.html?tokenId=...&blockhash=...`). The renderer (`art.js`) reads them from
///      `window.location.search`. Param names are exact and case-sensitive:
///        - `tokenId`   (REQUIRED) decimal, no leading zeros (`"0"` valid). Uniqueness.
///        - `blockhash` (REQUIRED) `0x` + 64 hex chars (full 32 bytes, do NOT strip leading-zero bytes).
///        - `txHash`    (optional) `0x` + 64 hex chars. Extra entropy.
///        - `minter`    (optional) `0x` + 40 hex chars. Extra entropy.
///        - `gasPrice`  (optional) decimal wei, no unit suffix. Extra entropy.
///        - `gasUsed`   (optional) decimal. Extra entropy.
///        - `seed`      (optional) arbitrary string — a curated FULL override (see `Seed` below).
///
/// @dev DETERMINISM RULES the backend MUST honor (the seed is hashed from the string representation):
///      1. Values are frozen at mint, forever. Once injected for a token they must never change — any
///         change re-rolls that token into completely different art.
///      2. Formatting must be canonical and stable per field, for every token, every time. Case is safe
///         for hex (the renderer lowercases), but nothing else is normalized: keep `0x` prefixes and full
///         widths; decimals have no leading zeros and no unit suffixes.
///      3. Don't change which fields exist for a collection mid-flight. If the artist seeds from `minter`,
///         that field must be present and stable for all tokens.
///
/// @dev SEED OVERRIDE (curated drops): when a token has a `Seed` stored here with `enabled == true`, the
///      backend injects `seed=<value>` verbatim and it fully replaces the field composition above
///      (`tokenId`/`blockhash` are ignored for seeding). Use only for collector-curated drops; leave
///      `Seed` disabled for normal algorithmic mints. 
///
/// @dev EXTRA PARAMS: `ExtraParams` are additional artist-defined query
///      params injected alongside the above.
///
/// @dev ACCESS CONTROL & COMPOSABILITY: every mutator is gated by `_isApprovedSender`, which defers to the
///      served NFT — the caller must be `ERC721TL.owner()` or hold `ADMIN_ROLE` on it. The renderer keeps no
///      access list of its own, so helper contracts compose simply by being granted `ADMIN_ROLE` on the NFT
///      (e.g. an admin param-helper, or a collector-seed forwarder that checks `ownerOf(tokenId)` before
///      calling `setSeed`). Note that `ADMIN_ROLE` is NFT-wide: such a helper gains full creator-admin power
///      (mint, royalties, etc.), not a rendering-scoped subset — grant it only to trusted, immutable contracts.
///
/// @dev Deployable directly or as an ERC-1167 minimal proxy clone (call `initialize` after cloning).
contract GenArtRenderingContract is Initializable, IGenArtRenderingContract {
    /////////////////////////////////////////////////////////////////////
    // TYPES
    /////////////////////////////////////////////////////////////////////

    using Strings for uint256;

    /////////////////////////////////////////////////////////////////////
    // STORAGE
    /////////////////////////////////////////////////////////////////////

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    address public nftContract;

    mapping(uint256 tokenId => ExtraParams[]) private _extraParams;
    mapping(uint256 tokenId => Seed) private _seeds;

    string private _baseUri;
    string private _scriptUri;
    uint256 private _activeScriptVersion;

    /////////////////////////////////////////////////////////////////////
    // ERRORS
    /////////////////////////////////////////////////////////////////////

    error InvalidAddress();
    error InvalidScriptVersion();
    error NotApprovedSender();
    error NotNftContract();

    /////////////////////////////////////////////////////////////////////
    // CONSTRUCTOR
    /////////////////////////////////////////////////////////////////////

    /// @param disable Boolean to disable initialization for the implementation contract
    constructor(bool disable) {
        if (disable) _disableInitializers();
    }

    /////////////////////////////////////////////////////////////////////
    // INITIALIZER
    /////////////////////////////////////////////////////////////////////

    /// @param initNftContract The nft contract this renderer serves
    /// @param initBaseUri The base uri used to build the token pointer (`<baseUri>/<tokenId>`)
    function initialize(address initNftContract, string memory initBaseUri) external initializer {
        if (initNftContract == address(0) || initNftContract.code.length == 0) revert InvalidAddress();
        nftContract = initNftContract;
        _baseUri = initBaseUri;
        _activeScriptVersion = 1;

        emit BaseUriSet(initBaseUri);
    }

    /////////////////////////////////////////////////////////////////////
    // SETTER FUNCTIONS
    /////////////////////////////////////////////////////////////////////

    /// @notice Sets the base uri used to build each token pointer (`<baseUri>/<tokenId>`)
    /// @dev Restricted to the nft owner or an admin. Refreshes all token metadata so marketplaces re-fetch.
    ///      Repoint here to migrate the live render target (e.g. backend -> `ipfs://<CID>` after mint-out).
    /// @param newBaseUri The new base uri (should NOT end in a slash)
    function setBaseUri(string calldata newBaseUri) external {
        if (!_isApprovedSender(msg.sender)) revert NotApprovedSender();

        _baseUri = newBaseUri;

        ERC721TL nft = ERC721TL(nftContract);
        nft.emitMetadataUpdateEventBatchToken(1, nft.totalSupply());

        emit BaseUriSet(newBaseUri);
    }

    /// @notice Sets the convenience pointer to the generative script (e.g. an https/ipfs url)
    /// @dev Restricted to the nft owner or an admin. Refreshes all token metadata so marketplaces re-fetch.
    ///      This is a mutable pointer; the immutable archive of the script lives in `GenerativeScriptChunk` logs.
    /// @param newScriptUri The new script uri
    function setScriptUri(string calldata newScriptUri) external {
        if (!_isApprovedSender(msg.sender)) revert NotApprovedSender();

        _scriptUri = newScriptUri;

        ERC721TL nft = ERC721TL(nftContract);
        nft.emitMetadataUpdateEventBatchToken(1, nft.totalSupply());

        emit ScriptUriSet(newScriptUri);
    }

    /// @notice Sets the artist-defined extra query params for a single token, replacing any prior set
    /// @dev Restricted to the nft owner or an admin. Refreshes the token's metadata so marketplaces re-fetch.
    ///      Passing an empty array clears the token's extra params.
    /// @param tokenId The token to set extra params for
    /// @param extraParams The full list of extra params to store (overwrites the previous list)
    function setExtraParams(uint256 tokenId, ExtraParams[] calldata extraParams) external {
        if (!_isApprovedSender(msg.sender)) revert NotApprovedSender();

        delete _extraParams[tokenId];
        for (uint256 i; i < extraParams.length; ++i) {
            _extraParams[tokenId].push(extraParams[i]);
        }

        ERC721TL nft = ERC721TL(nftContract);
        nft.emitMetadataUpdateEventSingleToken(tokenId);

        emit ExtraParamsSet(tokenId, extraParams);
    }

    /// @notice Sets the curated seed override for a single token (for collector-curated drops)
    /// @dev Restricted to the nft owner or an admin. Refreshes the token's metadata so marketplaces re-fetch.
    ///      When `seed.enabled` is true the backend injects `seed=<value>` verbatim, fully replacing the
    ///      `tokenId`/`blockhash` entropy composition. Leave disabled for normal algorithmic mints.
    ///      It should be set *after* the token is minted.
    /// @param tokenId The token to set the seed for
    /// @param seed The seed override (`enabled` toggles it; `seed` is the override value)
    function setSeed(uint256 tokenId, Seed calldata seed) external {
        if (!_isApprovedSender(msg.sender)) revert NotApprovedSender();

        _seeds[tokenId] = seed;

        ERC721TL nft = ERC721TL(nftContract);
        nft.emitMetadataUpdateEventSingleToken(tokenId);

        emit SeedSet(tokenId, seed.enabled, seed.seed);
    }

    /// @notice Stores one chunk of the generative script in event logs as a permanent on-chain archive
    /// @dev Restricted to the nft owner or an admin. Emits only an event (not readable on-chain). `chunkIndex`
    ///      is the 0-based position of this chunk within `version`; off-chain reassembly concatenates all
    ///      chunks for a version in ascending `chunkIndex` order. Chunking is required because a full script
    ///      exceeds per-tx limits.
    /// @param version The script revision this chunk belongs to
    /// @param chunkIndex The 0-based position of this chunk within `version`
    /// @param chunk The raw script bytes for this chunk
    function storeScriptChunk(uint256 version, uint256 chunkIndex, bytes memory chunk) external {
        if (!_isApprovedSender(msg.sender)) revert NotApprovedSender();

        emit GenerativeScriptChunk(version, chunkIndex, chunk);
    }

    /// @notice Sets the canonical script version off-chain renderers should assemble & run
    /// @dev Restricted to the nft owner or an admin. Refreshes all token metadata so the new version is
    ///      picked up. Version 0 is reserved as "unset" and rejected.
    /// @param version The script version to make canonical (must be non-zero)
    function setActiveScriptVersion(uint256 version) external {
        if (!_isApprovedSender(msg.sender)) revert NotApprovedSender();
        if (version == 0) revert InvalidScriptVersion();

        _activeScriptVersion = version;

        ERC721TL nft = ERC721TL(nftContract);
        nft.emitMetadataUpdateEventBatchToken(1, nft.totalSupply());

        emit ActiveScriptVersionSet(version);
    }

    /////////////////////////////////////////////////////////////////////
    // TOKEN URI FUNCTION
    /////////////////////////////////////////////////////////////////////

    /// @inheritdoc IRenderingContract
    /// @dev Returns the base uri + `/` + <tokenId>
    function tokenURI(uint256 tokenId) external view returns (string memory) {
        if (msg.sender != nftContract) revert NotNftContract();
        return string(abi.encodePacked(_baseUri, "/", tokenId.toString()));
    }

    /////////////////////////////////////////////////////////////////////
    // GEN ART READ FUNCTIONS
    /////////////////////////////////////////////////////////////////////

    /// @inheritdoc IGenArtRenderingContract
    function getActiveScriptVersion() external view returns (uint256) {
        return _activeScriptVersion;
    }

    /// @inheritdoc IGenArtRenderingContract
    function getBaseUri() external view returns (string memory) {
        return _baseUri;
    }

    /// @inheritdoc IGenArtRenderingContract
    function getExtraParams(uint256 tokenId) external view returns (ExtraParams[] memory) {
        return _extraParams[tokenId];
    }

    /// @inheritdoc IGenArtRenderingContract
    function getScriptUri() external view returns (string memory) {
        return _scriptUri;
    }

    /// @inheritdoc IGenArtRenderingContract
    function getSeed(uint256 tokenId) external view returns (Seed memory) {
        return _seeds[tokenId];
    }

    /////////////////////////////////////////////////////////////////////
    // ERC-165
    /////////////////////////////////////////////////////////////////////

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(IERC165).interfaceId
            || interfaceId == type(IRenderingContract).interfaceId
            || interfaceId == type(IGenArtRenderingContract).interfaceId;
    }

    /////////////////////////////////////////////////////////////////////
    // INTERNAL FUNCTIONS
    /////////////////////////////////////////////////////////////////////

    /// @dev Checks the nft contract to verify that the sender is either the owner or an admin
    function _isApprovedSender(address sender) internal view returns (bool) {
        ERC721TL nft = ERC721TL(nftContract);
        return nft.owner() == sender || nft.hasRole(ADMIN_ROLE, sender);
    }
}

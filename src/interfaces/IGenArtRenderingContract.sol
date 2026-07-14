// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {IRenderingContract} from "./IRenderingContract.sol";

/// @title Generative Art Rendering Contract Interface
/// @notice Interface for generative art that extends the regular rendering contract interface
/// @dev Features include extra param storage + explicit seed storage + the ability to store the generative code in event logs
/// @dev Interface id = 0xdd4085f1
interface IGenArtRenderingContract is IRenderingContract {
    /////////////////////////////////////////////////////////////////////
    // TYPES
    /////////////////////////////////////////////////////////////////////

    struct ExtraParams {
        string name;
        string value;
    }

    struct Seed {
        bool enabled;
        bytes32 seed;
    }

    /////////////////////////////////////////////////////////////////////
    // EVENTS
    /////////////////////////////////////////////////////////////////////

    event ActiveScriptVersionSet(uint256 indexed version);
    event BaseUriSet(string baseUri);
    event ExtraParamsSet(uint256 indexed tokenId, ExtraParams[] extraParams);
    /// @dev `chunkIndex` is the 0-based position of this chunk within `version`; indexers reassemble a
    ///      script by concatenating all chunks for a version in ascending `chunkIndex` order.
    event GenerativeScriptChunk(uint256 indexed version, uint256 indexed chunkIndex, bytes chunk);
    event ScriptUriSet(string scriptUri);
    event SeedSet(uint256 indexed tokenId, bool indexed enabled, bytes32 indexed seed);

    /////////////////////////////////////////////////////////////////////
    // READ FUNCTIONS
    /////////////////////////////////////////////////////////////////////

    /// @notice Function to get the canonical script version off-chain renderers could assemble from logs & run
    /// @dev Most off-chain renderers should just use `getScriptUri` in reality.
    function getActiveScriptVersion() external view returns (uint256);

    /// @notice Function to get the base uri used to build each token pointer (`<baseUri>/<tokenId>`)
    function getBaseUri() external view returns (string memory);

    /// @notice Function to get any extra params associated with a token
    function getExtraParams(uint256 tokenId) external view returns (ExtraParams[] memory);

    /// @notice Function to get the generative script url
    function getScriptUri() external view returns (string memory);

    /// @notice Function to get the seed override
    function getSeed(uint256 tokenId) external view returns (Seed memory);
    
}
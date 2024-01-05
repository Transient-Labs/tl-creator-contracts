// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title IShatter.sol
/// @notice interface defining the Shatter standard
/// Interface id = 0xf2528cbb
/// @author transientlabs.xyz
/// @custom:version 3.0.0
interface IShatter {
    /*//////////////////////////////////////////////////////////////////////////
                                      Events
    //////////////////////////////////////////////////////////////////////////*/

    event Shattered(address indexed user, uint256 indexed numShatters, uint256 indexed shatteredTime);
    event Fused(address indexed user, uint256 indexed fuseTime);

    /*//////////////////////////////////////////////////////////////////////////
                                      Functions
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Function for minting the 1/1
    /// @dev Requires contract owner or admin
    /// @dev Requires that shatters is equal to 0 -> meaning no piece has been minted
    /// @param recipient The address to mint to token to
    /// @param uri The base uri to be used for the shatter folder WITHOUT trailing "/"
    /// @param min The minimum number of shatters
    /// @param max The maximum number of shatters
    /// @param time Time after which shatter can occur
    function mint(address recipient, string memory uri, uint128 min, uint128 max, uint256 time)
        external;

    /// @notice function to shatter the 1/1 token
    /// @dev care should be taken to ensure that the following conditions are met
    ///     - this function can only be called once
    ///     - msg.sender actually owns the 1/1 token
    ///     - the token has not been shattered yet
    ///     - block.timestamp is past the shatter time (if applicable)
    ///     - numShatters is an allowed value as set by the creator
    /// @param numShatters is the total number of shatters to make
    function shatter(uint128 numShatters) external;

    /// @notice function to fuse shatters back into a 1/1
    /// @dev care should be taken to ensure that the following conditions are met
    ///     - this function can only be called once
    ///     - the 1/1 is actually shattered
    ///     - msg.sender actually owns all of the shatters
    function fuse() external;
}

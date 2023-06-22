// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/// @title IShatter.sol
/// @notice interface defining the Shatter standard
/// @dev shatter turns a 1/1 into a multiple sub-pieces.
/// @author transientlabs.xyz
/// @custom:version 2.4.0
interface IShatter {
    /*//////////////////////////////////////////////////////////////////////////
                                      Events
    //////////////////////////////////////////////////////////////////////////*/

    event Shattered(address indexed user, uint256 indexed numShatters, uint256 indexed shatteredTime);
    event Fused(address indexed user, uint256 indexed fuseTime);

    /*//////////////////////////////////////////////////////////////////////////
                                      Functions
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice function to shatter the 1/1 token
    /// @dev care should be taken to ensure that the following conditions are met
    ///     - this function can only be called once
    ///     - msg.sender actually owns the 1/1 token
    ///     - the token has not been shattered yet
    ///     - block.timestamp is past the shatter time (if applicable)
    ///     - numShatters is an allowed value as set by the creator
    /// @param numShatters is the total number of shatters to make
    function shatter(uint256 numShatters) external;

    /// @notice function to fuse shatters back into a 1/1
    /// @dev care should be taken to ensure that the following conditions are met
    ///     - this function can only be called once
    ///     - the 1/1 is actually shattered
    ///     - msg.sender actually owns all of the shatters
    function fuse() external;
}

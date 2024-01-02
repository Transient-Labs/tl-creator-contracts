// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title BlockList Registry
/// @notice Interface for the BlockListRegistry Contract
/// @author transientlabs.xyz
/// @custom:version 4.0.3
interface IBlockListRegistry {
    /*//////////////////////////////////////////////////////////////////////////
                                Events
    //////////////////////////////////////////////////////////////////////////*/

    event BlockListStatusChange(address indexed user, address indexed operator, bool indexed status);

    event BlockListCleared(address indexed user);

    /*//////////////////////////////////////////////////////////////////////////
                          Public Read Functions
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Function to get blocklist status with True meaning that the operator is blocked
    /// @param operator The operator in question to check against the blocklist
    function getBlockListStatus(address operator) external view returns (bool);

    /*//////////////////////////////////////////////////////////////////////////
                          Public Write Functions
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Function to set the block list status for multiple operators
    /// @dev Must be called by the blockList owner
    /// @param operators An address array of operators to set a status for
    /// @param status The status to set for all `operators`
    function setBlockListStatus(address[] calldata operators, bool status) external;

    /// @notice Function to clear the block list status
    /// @dev Must be called by the blockList owner
    function clearBlockList() external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Transient Labs Story Inscriptions Interface
/// @dev Interface id: 0x2464f17b
/// @dev Previous interface id that is still supported: 0x0d23ecb9
/// @author transientlabs.xyz
/// @custom:version 6.0.0
interface IStory {
    /*//////////////////////////////////////////////////////////////////////////
                                Events
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Event describing a collection story getting added to a contract
    /// @dev This event stories creator stories on chain in the event log that apply to an entire collection
    /// @param creatorAddress The address of the creator of the collection
    /// @param creatorName String representation of the creator's name
    /// @param story The story written and attached to the collection
    event CollectionStory(address indexed creatorAddress, string creatorName, string story);

    /// @notice Event describing a creator story getting added to a token
    /// @dev This events stores creator stories on chain in the event log
    /// @param tokenId The token id to which the story is attached
    /// @param creatorAddress The address of the creator of the token
    /// @param creatorName String representation of the creator's name
    /// @param story The story written and attached to the token id
    event CreatorStory(uint256 indexed tokenId, address indexed creatorAddress, string creatorName, string story);

    /// @notice Event describing a collector story getting added to a token
    /// @dev This events stores collector stories on chain in the event log
    /// @param tokenId The token id to which the story is attached
    /// @param collectorAddress The address of the collector of the token
    /// @param collectorName String representation of the collectors's name
    /// @param story The story written and attached to the token id
    event Story(uint256 indexed tokenId, address indexed collectorAddress, string collectorName, string story);

    /*//////////////////////////////////////////////////////////////////////////
                                Story Functions
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Function to let the creator add a story to the collection they have created
    /// @dev Depending on the implementation, this function may be restricted in various ways, such as
    ///      limiting the number of times the creator may write a story.
    /// @dev This function MUST emit the CollectionStory event each time it is called
    /// @dev This function MUST implement logic to restrict access to only the creator
    /// @param creatorName String representation of the creator's name
    /// @param story The story written and attached to the token id
    function addCollectionStory(string calldata creatorName, string calldata story) external;

    /// @notice Function to let the creator add a story to any token they have created
    /// @dev Depending on the implementation, this function may be restricted in various ways, such as
    ///      limiting the number of times the creator may write a story.
    /// @dev This function MUST emit the CreatorStory event each time it is called
    /// @dev This function MUST implement logic to restrict access to only the creator
    /// @dev This function MUST revert if a story is written to a non-existent token
    /// @param tokenId The token id to which the story is attached
    /// @param creatorName String representation of the creator's name
    /// @param story The story written and attached to the token id
    function addCreatorStory(uint256 tokenId, string calldata creatorName, string calldata story) external;

    /// @notice Function to let collectors add a story to any token they own
    /// @dev Depending on the implementation, this function may be restricted in various ways, such as
    ///      limiting the number of times a collector may write a story.
    /// @dev This function MUST emit the Story event each time it is called
    /// @dev This function MUST implement logic to restrict access to only the owner of the token
    /// @dev This function MUST revert if a story is written to a non-existent token
    /// @param tokenId The token id to which the story is attached
    /// @param collectorName String representation of the collectors's name
    /// @param story The story written and attached to the token id
    function addStory(uint256 tokenId, string calldata collectorName, string calldata story) external;
}

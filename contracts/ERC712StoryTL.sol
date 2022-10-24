// SPDX-License-Identifier: Apache-2.0

/// @title ERC721TL.sol
/// @notice Transient Labs Story ERC721 Contract, Has all the features of the core but with story support.
/// @author transientlabs.xyz

/*
    ____        _ __    __   ____  _ ________                     __ 
   / __ )__  __(_) /___/ /  / __ \(_) __/ __/__  ________  ____  / /_
  / __  / / / / / / __  /  / / / / / /_/ /_/ _ \/ ___/ _ \/ __ \/ __/
 / /_/ / /_/ / / / /_/ /  / /_/ / / __/ __/  __/ /  /  __/ / / / /__ 
/_____/\__,_/_/_/\__,_/  /_____/_/_/ /_/  \___/_/   \___/_/ /_/\__(_)

*/

pragma solidity ^0.8.14;

import "./ERC721TL.sol";
import "./IStory.sol";

contract ERC721StoryTL is IStory, ERC721TL {

    //================= Functions for IStory =================//

    /// @notice Allows creator to add a story.
    /// @dev requires owner
    function addCreatorStory(uint256 tokenId, string calldata creatorName, string calldata story) external onlyOwner {
        require(_exists(tokenId), "ERC721TERC721TLStory: token must exist");
        emit CreatorStory(tokenId, msg.sender, creatorName, story);
    }

    function addStory(uint256 tokenId, string calldata collectorName, string calldata story) external {
        require(ownerOf(tokenId) == msg.sender, "ERC721TLStory: must be token owner");
        require(_exists(tokenId), "ERC721TERC721TLStory: token must exist");
        emit Story(tokenId, msg.sender, collectorName, story);
    }
}

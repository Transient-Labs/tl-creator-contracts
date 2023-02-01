// SPDX-License-Identifier: Apache-2.0

/// @title TLCoreContractsFactory.sol
/// @notice contract factory for ERC721TL and ERC1155TL
/// @author transientlabs.xyz

/*
    ____        _ __    __   ____  _ ________                     __ 
   / __ )__  __(_) /___/ /  / __ \(_) __/ __/__  ________  ____  / /_
  / __  / / / / / / __  /  / / / / / /_/ /_/ _ \/ ___/ _ \/ __ \/ __/
 / /_/ / /_/ / / / /_/ /  / /_/ / / __/ __/  __/ /  /  __/ / / / /__ 
/_____/\__,_/_/_/\__,_/  /_____/_/_/ /_/  \___/_/   \___/_/ /_/\__(_)*/

pragma solidity 0.8.17;

import {Clones} from "openzeppelin/proxy/Clones.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";
import {ERC721TL} from "./ERC721TL.sol";
import {ERC1155TL} from "./ERC1155TL.sol";

contract TLCoreContractsFactory is Ownable {
    address public ERC721TLImplementation;
    address public ERC1155TLImplementation;

    event ERC721TLCreated(address indexed creator, address indexed implementation, address indexed contractAddress);
    event ERC1155TLCreated(address indexed creator, address indexed implementation, address indexed contractAddress);

    constructor(address ERC721TLImplementation_, address ERC1155TLImplementation_) Ownable() {
        ERC721TLImplementation = ERC721TLImplementation_;
        ERC1155TLImplementation = ERC1155TLImplementation_;
    }

    /// @notice function to set ERC721TL implementation address
    /// @dev requires owner
    /// @param newImplementation: the new implementation address
    function setERC721TLImplementation(address newImplementation) external onlyOwner {
        ERC721TLImplementation = newImplementation;
    }

    /// @notice function to set ERC1155TL implementation address
    /// @dev requires owner
    /// @param newImplementation: the new implementation address
    function setERC1155TLImplementation(address newImplementation) external onlyOwner {
        ERC1155TLImplementation = newImplementation;
    }

    /// @notice function to create ERC721TL contract
    /// @dev anyone can call as we all deserve to own our own contracts
    /// @dev msg.sender is the initial owner of the contract
    /// @param name: the name of the 721 contract
    /// @param symbol: the symbol of the 721 contract
    /// @param royaltyRecipient: the default address for royalty payments
    /// @param royaltyPercentage: the default royalty percentage of basis points (out of 10,000)
    /// @param admins: array of admin addresses to add to the contract
    /// @param enableStory: a bool deciding whether to add story fuctionality or not
    /// @param blockListRegistry: address of the blocklist registry to use
    function createERC721TL(
        string memory name,
        string memory symbol,
        address royaltyRecipient,
        uint256 royaltyPercentage,
        address[] memory admins,
        bool enableStory,
        address blockListRegistry
    ) external returns (address) {
        address newContract = Clones.clone(ERC721TLImplementation);
        ERC721TL(newContract).initialize(
            name, symbol, royaltyRecipient, royaltyPercentage, msg.sender, admins, enableStory, blockListRegistry
        );

        emit ERC721TLCreated(msg.sender, ERC721TLImplementation, newContract);

        return newContract;
    }

    /// @notice function to create ERC1155TL contract
    /// @dev anyone can call as we all deserve to own our own contracts
    /// @dev msg.sender is the initial owner of the contract
    /// @param name_: the name of the 721 contract
    /// @param royaltyRecipient: the default address for royalty payments
    /// @param royaltyPercentage: the default royalty percentage of basis points (out of 10,000)
    /// @param admins: array of admin addresses to add to the contract
    /// @param enableStory: a bool deciding whether to add story fuctionality or not
    /// @param blockListRegistry: address of the blocklist registry to use
    function createERC1155TL(
        string memory name_,
        address royaltyRecipient,
        uint256 royaltyPercentage,
        address[] memory admins,
        bool enableStory,
        address blockListRegistry
    ) external returns (address) {
        address newContract = Clones.clone(ERC1155TLImplementation);
        ERC1155TL(newContract).initialize(
            name_, royaltyRecipient, royaltyPercentage, msg.sender, admins, enableStory, blockListRegistry
        );

        emit ERC1155TLCreated(msg.sender, ERC1155TLImplementation, newContract);

        return newContract;
    }
}

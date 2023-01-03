// SPDX-License-Identifer: Apache-2.0

/// @title TLCoreContractsFactory.sol
/// @notice registry and contract factory for ERC721TL and ERC1155TL
/// @author transientlabs.xyz

/*
    ____        _ __    __   ____  _ ________                     __ 
   / __ )__  __(_) /___/ /  / __ \(_) __/ __/__  ________  ____  / /_
  / __  / / / / / / __  /  / / / / / /_/ /_/ _ \/ ___/ _ \/ __ \/ __/
 / /_/ / /_/ / / / /_/ /  / /_/ / / __/ __/  __/ /  /  __/ / / / /__ 
/_____/\__,_/_/_/\__,_/  /_____/_/_/ /_/  \___/_/   \___/_/ /_/\__(_)

*/

pragma solidity 0.8.17;

import { Clones } from "openzeppelin/proxy/Clones.sol";
import { Ownable } from "openzeppelin/access/Ownable.sol";

interface ERC721TL {
    function initialize(string memory name, string memory symbol, address owner, address royaltyRecipient, uint256 royaltyPercentage) external;
}

interface ERC1155TL {
    function initialize(string memory name_, address owner, address defaultRecipient, uint256 defaultPercentage) external;
}

contract TLCoreContractsFactory is Ownable {

    address public ERC721TLImplementation;
    address public ERC1155TLImplementation;

    event ERC721TLCreated(address indexed creator, address indexed contractAddress);
    event ERC1155TLCreated(address indexed creator, address indexed contractAddress);

    constructor(address ERC721TLImplementation_, address ERC1155TLImplementation_) Ownable() {
        ERC721TLImplementation = ERC721TLImplementation_;
        ERC1155TLImplementation = ERC1155TLImplementation_;
    }

    /// @notice function to set ERC721TL implementation address 
    /// @dev requires owner
    function setERC721TLImplementation(address newImplementation) external onlyOwner {
        require(newImplementation != address(0), "new implemenation cannot be the zero address");
        ERC721TLImplementation = newImplementation;
    }

    /// @notice function to set ERC1155TL implementation address 
    /// @dev requires owner
    function setERC115TLImplementation(address newImplementation) external onlyOwner {
        require(newImplementation != address(0), "new implemenation cannot be the zero address");
        ERC1155TLImplementation = newImplementation;
    }

    /// @notice function to create ERC721TL contract
    /// @dev anyone can call as we all deserve to own our own contracts
    function createERC721TL(string calldata name, string calldata symbol, address royaltyRecipient, uint256 royaltyPercentage) external returns (address) {
        address newContract = Clones.clone(ERC721TLImplementation);
        ERC721TL(newContract).initialize(name, symbol, msg.sender, royaltyRecipient, royaltyPercentage);

        emit ERC721TLCreated(msg.sender, newContract);

        return newContract;
    }

    /// @notice function to create ERC1155TL contract
    /// @dev anyone can call as we all deserve to own our own contracts
    function createERC1155TL(string calldata name, address royaltyRecipient, uint256 royaltyPercentage) external returns (address) {
        address newContract = Clones.clone(ERC1155TLImplementation);
        ERC1155TL(newContract).initialize(name, msg.sender, royaltyRecipient, royaltyPercentage);

        emit ERC1155TLCreated(msg.sender, newContract);

        return newContract;
    }

}
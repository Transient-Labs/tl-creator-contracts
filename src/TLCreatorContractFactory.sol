// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Ownable} from "openzeppelin/access/Ownable.sol";
import {Clones} from "openzeppelin/proxy/Clones.sol";

/*//////////////////////////////////////////////////////////////////////////
                          InitializableInterface
//////////////////////////////////////////////////////////////////////////*/
interface InitializableInterface {
    function initialize(
        string memory name,
        string memory symbol,
        address defaultRoyaltyRecipient,
        uint256 defaultRoyaltyPercentage,
        address initOwner,
        address[] memory admins,
        bool enableStory,
        address blockListRegistry
    ) external;
}

/*//////////////////////////////////////////////////////////////////////////
                          TLCreatorContractFactory
//////////////////////////////////////////////////////////////////////////*/

/// @title TLCreatorContractFactory
/// @notice Contract factory for TL creator contracts
/// @dev deploys any contract compatible with the InitializableInterface above
/// @author transientlabs.xyz
/// @custom:version 2.6.2
contract TLCreatorContractFactory is Ownable {
    /*//////////////////////////////////////////////////////////////////////////
                                    Structs
    //////////////////////////////////////////////////////////////////////////*/

    struct ContractType {
        string name;
        address[] implementations;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                State Variables
    //////////////////////////////////////////////////////////////////////////*/

    ContractType[] private _contractTypes;

    /*//////////////////////////////////////////////////////////////////////////
                                    Events
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev event emitted whenever a contract type is added
    event ContractTypeAdded(uint256 indexed contractTypeId, address indexed firstImplementation, string name);

    /// @dev event emitted whenever an implementation is added for a contract type
    event ImplementationAdded(uint256 indexed contractTypeId, address indexed implementation);

    /// @dev event emitted whenever a contract is deployed
    event ContractDeployed(address indexed contractAddress, address indexed implementationAddress, address indexed sender);

    /*//////////////////////////////////////////////////////////////////////////
                                  Constructor
    //////////////////////////////////////////////////////////////////////////*/

    constructor() Ownable() {}

    /*//////////////////////////////////////////////////////////////////////////
                              Ownership Functions  
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Function to add a contract type
    /// @dev only callable by the factory owner
    /// @param name The new contract type name
    /// @param implementation The first implementation address to add
    function addContractType(string memory name, address implementation) external onlyOwner {
        address[] memory implementations = new address[](1);
        implementations[0] = implementation;

        _contractTypes.push(ContractType(name, implementations));
        uint256 contractTypeId = _contractTypes.length - 1;

        emit ContractTypeAdded(contractTypeId, implementation, name);
    }

    /// @notice Function to add an implementation contract for a type
    /// @dev only callable by the factory owner
    /// @param contractTypeId The contract type id
    /// @param implementation The new implementation address to add
    function addContractImplementation(uint256 contractTypeId, address implementation) external onlyOwner {
        ContractType storage contractType = _contractTypes[contractTypeId];
        contractType.implementations.push(implementation);

        emit ImplementationAdded(contractTypeId, implementation);
    }

    /*//////////////////////////////////////////////////////////////////////////
                           Contract Creation Functions
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Function to deploy the latest implementation contract for a contract type
    /// @param contractTypeId The contract type id
    /// @param contractName The deployed contract name
    /// @param contractSymbol The deployed contract symbol
    /// @param defaultRoyaltyRecipient The default royalty recipient
    /// @param defaultRoyaltyPercentage The default royalty percentage
    /// @param initOwner The initial owner of the deployed contract
    /// @param admins The intial admins on the contract
    /// @param enableStory The initial state of story inscriptions on the deployed contract
    /// @param blockListRegistry The blocklist registry
    /// @return contractAddress The deployed contract address
    function deployLatestImplementation(
        uint256 contractTypeId,
        string memory contractName,
        string memory contractSymbol,
        address defaultRoyaltyRecipient,
        uint256 defaultRoyaltyPercentage,
        address initOwner,
        address[] memory admins,
        bool enableStory,
        address blockListRegistry
    ) external returns (address contractAddress) {
        ContractType memory contractType = _contractTypes[contractTypeId];
        address implementation = contractType.implementations[contractType.implementations.length - 1];
        return _deployContract(
            implementation,
            contractName,
            contractSymbol,
            defaultRoyaltyRecipient,
            defaultRoyaltyPercentage,
            initOwner,
            admins,
            enableStory,
            blockListRegistry
        );
    }

    /// @notice Function to deploy a specific implementation contract for a contract type
    /// @param contractTypeId The contract type id
    /// @param implementationIndex The index specifying the implementation contract
    /// @param contractName The deployed contract name
    /// @param contractSymbol The deployed contract symbol
    /// @param defaultRoyaltyRecipient The default royalty recipient
    /// @param defaultRoyaltyPercentage The default royalty percentage
    /// @param initOwner The initial owner of the deployed contract
    /// @param admins The intial admins on the contract
    /// @param enableStory The initial state of story inscriptions on the deployed contract
    /// @param blockListRegistry The blocklist registry
    /// @return contractAddress The deployed contract address
    function deployImplementation(
        uint256 contractTypeId,
        uint256 implementationIndex,
        string memory contractName,
        string memory contractSymbol,
        address defaultRoyaltyRecipient,
        uint256 defaultRoyaltyPercentage,
        address initOwner,
        address[] memory admins,
        bool enableStory,
        address blockListRegistry
    ) external returns (address contractAddress) {
        ContractType memory contractType = _contractTypes[contractTypeId];
        address implementation = contractType.implementations[implementationIndex];
        return _deployContract(
            implementation,
            contractName,
            contractSymbol,
            defaultRoyaltyRecipient,
            defaultRoyaltyPercentage,
            initOwner,
            admins,
            enableStory,
            blockListRegistry
        );
    }

    /*//////////////////////////////////////////////////////////////////////////
                                View Functions
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Function to get all contract types
    /// @return contractTypes A list of contract type structs
    function getContractTypes() external view returns (ContractType[] memory contractTypes) {
        return _contractTypes;
    }

    /// @notice Function to get contract type info by id
    /// @param contractTypeId The contract type id
    /// @return contractType A contract type struct
    function getContractType(uint256 contractTypeId) external view returns (ContractType memory contractType) {
        return _contractTypes[contractTypeId];
    }

    /*//////////////////////////////////////////////////////////////////////////
                               Internal Functions
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Internal function to deploy a contract
    /// @param implementation The implementation address
    /// @param contractName The deployed contract name
    /// @param contractSymbol The deployed contract symbol
    /// @param defaultRoyaltyRecipient The default royalty recipient
    /// @param defaultRoyaltyPercentage The default royalty percentage
    /// @param initOwner The initial owner of the deployed contract
    /// @param admins The intial admins on the contract
    /// @param enableStory The initial state of story inscriptions on the deployed contract
    /// @param blockListRegistry The blocklist registry
    /// @return contractAddress The deployed contract address
    function _deployContract(
        address implementation,
        string memory contractName,
        string memory contractSymbol,
        address defaultRoyaltyRecipient,
        uint256 defaultRoyaltyPercentage,
        address initOwner,
        address[] memory admins,
        bool enableStory,
        address blockListRegistry
    ) private returns (address contractAddress) {
        contractAddress = Clones.clone(implementation);
        InitializableInterface(contractAddress).initialize(
            contractName,
            contractSymbol,
            defaultRoyaltyRecipient,
            defaultRoyaltyPercentage,
            initOwner,
            admins,
            enableStory,
            blockListRegistry
        );

        emit ContractDeployed(contractAddress, implementation, msg.sender);

        return contractAddress;
    }
}

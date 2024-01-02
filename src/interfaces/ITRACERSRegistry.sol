// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title ITRACERSRegistry.sol
/// @notice Interface for TRACE Registered Agents Registry
/// @author transientlabs.xyz
/// @custom:version 3.0.0
interface ITRACERSRegistry {
    /*//////////////////////////////////////////////////////////////////////////
                                    Types
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Struct defining a registered agent
    /// @param isPermanent A bool defining if the agent is a permanent agent (if true, ignore `numberOfStories`)
    /// @param numberOfStories The number of stories allowed for this agent (N/A if `isPermanent` is true)
    /// @param name The name of the registered agent
    struct RegisteredAgent {
        bool isPermanent;
        uint128 numberOfStories;
        string name;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    Events
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev event whenever a registered agent is added, removed, or updated
    event RegisteredAgentUpdate(
        address indexed sender, address indexed registeredAgentAddress, RegisteredAgent registeredAgent
    );

    /// @dev event whenever a registered agent override is added, removed, or updated
    event RegisteredAgentOverrideUpdate(
        address indexed sender,
        address indexed nftContract,
        address indexed indexedregisteredAgentAddress,
        RegisteredAgent registeredAgent
    );

    /*//////////////////////////////////////////////////////////////////////////
                                Registered Agent Functions
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Function to add a global registered agent by the contract owner
    /// @dev This is a for a global registered agent so `registeredAgent.numberOfStories` is ignored
    /// @dev MUST emit the event `RegisteredAgentUpdate`
    /// @param registeredAgentAddress The registered agent address
    /// @param registeredAgent The registered agent
    function setRegisteredAgent(address registeredAgentAddress, RegisteredAgent memory registeredAgent) external;

    /// @notice Function to add a registered agent override by an nft contract owner or admin
    /// @dev MUST emit the event `RegisteredAgentOverrideUpdate`
    /// @param nftContract The nft contract
    /// @param registeredAgentAddress The registered agent address
    /// @param registeredAgent The registered agent
    function setRegisteredAgentOverride(
        address nftContract,
        address registeredAgentAddress,
        RegisteredAgent calldata registeredAgent
    ) external;

    /*//////////////////////////////////////////////////////////////////////////
                                External Functions
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Function callable by an nft contract to check the registered agent
    /// @dev This MUST be called by the nft contract in order to check overrides properly
    /// @dev Adjusts overrides that are limited in the number of stories allowed, hence no view modifier
    /// @param registeredAgentAddress The registered agent address
    /// @return bool Boolean indicating if the address is question is a registered agent or not
    /// @return string The name of the registered agent
    function isRegisteredAgent(address registeredAgentAddress) external returns (bool, string memory);

    /// @notice External view function to get a registered agent, returning an overrided agent for a contract if it exists
    /// @param nftContract The nft contract (set to the zero address if not looking for an override)
    /// @param registeredAgentAddress The registered agent address
    /// @return registeredAgent The registered agent struct
    function getRegisteredAgent(address nftContract, address registeredAgentAddress)
        external
        view
        returns (RegisteredAgent memory registeredAgent);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {OwnableAccessControl} from "tl-sol-tools/access/OwnableAccessControl.sol";

/// @title TRACERSRegistry
/// @notice Registry for TRACE Registered agents
/// @author transientlabs.xyz
/// @custom:version 2.7.0
contract TRACERSRegistry is OwnableAccessControl {
    /*//////////////////////////////////////////////////////////////////////////
                                    Custom Types
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
                                State Variables
    //////////////////////////////////////////////////////////////////////////*/

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    mapping(address => RegisteredAgent) private _registeredAgents; // registered agent address -> registered agent (global so should not use `numberOfStories`)
    mapping(address => mapping(address => RegisteredAgent)) private _registeredAgentOverrides; // nft contract -> registered agent address -> registered agent (not global so can use `numberOfStories` or `isPermanent`)

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
                                Custom Errors
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev not creator or admin for nft contract
    error NotCreatorOrAdmin();

    /*//////////////////////////////////////////////////////////////////////////
                                Constructor
    //////////////////////////////////////////////////////////////////////////*/

    constructor() OwnableAccessControl() {}

    /*//////////////////////////////////////////////////////////////////////////
                                Registered Agent Functions
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Function to add a global registered agent by the contract owner
    /// @dev This is a for a global registered agent so `registeredAgent.numberOfStories` is ignored
    /// @param registeredAgentAddress The registered agent address
    /// @param registeredAgent The registered agent
    function setRegisteredAgent(address registeredAgentAddress, RegisteredAgent memory registeredAgent)
        external
        onlyOwner
    {
        // set `registeredAgent.numberOfStories` to 0
        registeredAgent.numberOfStories = 0;
        // set registered agent
        _registeredAgents[registeredAgentAddress] = registeredAgent;
        emit RegisteredAgentUpdate(msg.sender, registeredAgentAddress, registeredAgent);
    }

    /// @notice Function to add a registered agent override by an nft contract owner or admin
    /// @param nftContract The nft contract
    /// @param registeredAgentAddress The registered agent address
    /// @param registeredAgent The registered agent
    function setRegisteredAgentOverride(
        address nftContract,
        address registeredAgentAddress,
        RegisteredAgent calldata registeredAgent
    ) external {
        // restrict access to creator or admin
        OwnableAccessControl c = OwnableAccessControl(nftContract);
        if (c.owner() != msg.sender && !c.hasRole(ADMIN_ROLE, msg.sender)) revert NotCreatorOrAdmin();

        //set registered agent
        _registeredAgentOverrides[nftContract][registeredAgentAddress] = registeredAgent;
        emit RegisteredAgentOverrideUpdate(msg.sender, nftContract, registeredAgentAddress, registeredAgent);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                External Functions
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Function callable by an nft contract to check the registered agent
    /// @dev This MUST be called by the nft contract in order to check overrides properly
    /// @dev Adjusts overrides that are limited in the number of stories allowed, hence no view modifier
    /// @param registeredAgentAddress The registered agent address
    /// @return bool Boolean indicating if the address is question is a registered agent or not
    /// @return string The name of the registered agent
    function isRegisteredAgent(address registeredAgentAddress) external returns (bool, string memory) {
        RegisteredAgent storage registeredAgent = _registeredAgents[registeredAgentAddress];
        RegisteredAgent storage registeredAgentOverride = _registeredAgentOverrides[msg.sender][registeredAgentAddress];

        if (registeredAgentOverride.isPermanent) {
            return (true, registeredAgentOverride.name);
        } else if (registeredAgentOverride.numberOfStories > 0) {
            registeredAgentOverride.numberOfStories--;
            return (true, registeredAgentOverride.name);
        } else if (registeredAgent.isPermanent) {
            return (true, registeredAgent.name);
        } else {
            return (false, "");
        }
    }

    /// @notice External view function to get a registered agent, returning an overrided agent for a contract if it exists
    /// @param nftContract The nft contract (set to the zero address if not looking for an override)
    /// @param registeredAgentAddress The registered agent address
    /// @return registeredAgent The registered agent struct
    function getRegisteredAgent(address nftContract, address registeredAgentAddress)
        external
        view
        returns (RegisteredAgent memory registeredAgent)
    {
        RegisteredAgent storage registeredAgentGlobal = _registeredAgents[registeredAgentAddress];
        RegisteredAgent storage registeredAgentOverride = _registeredAgentOverrides[nftContract][registeredAgentAddress];

        if (registeredAgentOverride.isPermanent || registeredAgentOverride.numberOfStories > 0) {
            registeredAgent = registeredAgentOverride;
        } else {
            registeredAgent = registeredAgentGlobal;
        }
        return registeredAgent;
    }
}

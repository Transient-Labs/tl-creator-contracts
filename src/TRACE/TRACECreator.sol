// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC1967Proxy} from "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";

/*//////////////////////////////////////////////////////////////////////////
                            TRACECreator
//////////////////////////////////////////////////////////////////////////*/

/// @title TRACECreator.sol
/// @notice Transient Labs TRACE Creator Proxy Contract
/// @author transientlabs.xyz
/// @custom:version 2.9.0
contract TRACECreator is ERC1967Proxy {
    /// @param name: the name of the contract
    /// @param symbol: the symbol of the contract
    /// @param defaultRoyaltyRecipient: the default address for royalty payments
    /// @param defaultRoyaltyPercentage: the default royalty percentage of basis points (out of 10,000)
    /// @param initOwner: initial owner of the contract
    /// @param admins: array of admin addresses to add to the contract
    /// @param defaultTracersRegistry: address of the TRACERS registry to use
    constructor(
        address implementation,
        string memory name,
        string memory symbol,
        address defaultRoyaltyRecipient,
        uint256 defaultRoyaltyPercentage,
        address initOwner,
        address[] memory admins,
        address defaultTracersRegistry
    )
        ERC1967Proxy(
            implementation,
            abi.encodeWithSelector(
                0x42499e50, // selector for "initialize(string,string,address,uint256,address,address[],address)"
                name,
                symbol,
                defaultRoyaltyRecipient,
                defaultRoyaltyPercentage,
                initOwner,
                admins,
                defaultTracersRegistry
            )
        )
    {}
}

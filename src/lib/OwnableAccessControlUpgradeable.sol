// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {OwnableUpgradeable} from "@openzeppelin-contracts-upgradeable-5.0.2/access/OwnableUpgradeable.sol";
import {EnumerableSet} from "@openzeppelin-contracts-5.0.2/utils/structs/EnumerableSet.sol";

/// @title OwnableAccessControlUpgradeable.sol
/// @notice Single owner, flexible access control mechanics
/// @dev Can easily be extended by inheriting and applying additional roles
/// @dev By default, only the owner can grant roles but by inheriting, but you
///      may allow other roles to grant roles by using the internal helper.
/// @author transientlabs.xyz
/// @custom:version 3.7.0
abstract contract OwnableAccessControlUpgradeable is OwnableUpgradeable {
    /*//////////////////////////////////////////////////////////////////////////
                                    Types
    //////////////////////////////////////////////////////////////////////////*/

    using EnumerableSet for EnumerableSet.AddressSet;

    /*//////////////////////////////////////////////////////////////////////////
                                    Storage
    //////////////////////////////////////////////////////////////////////////*/

    /// @custom:storage-location erc7201:transientlabs.storage.OwnableAccessControl
    struct OwnableAccessControlStorage {
        uint256 c; // counter to be able to revoke all priviledges
        mapping(uint256 => mapping(bytes32 => mapping(address => bool))) roleStatus;
        mapping(uint256 => mapping(bytes32 => EnumerableSet.AddressSet)) roleMembers;
    }

    // keccak256(abi.encode(uint256(keccak256("transientlabs.storage.OwnableAccessControl")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant OwnableAccessControlStorageLocation =
        0x0d0469b3d32e63681b9fc586a5627ad5e70b3d1ad20f31767e4b6c4141c7e300;

    function _getOwnableAccessControlStorage() private pure returns (OwnableAccessControlStorage storage $) {
        assembly {
            $.slot := OwnableAccessControlStorageLocation
        }
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    Events
    //////////////////////////////////////////////////////////////////////////*/

    /// @param from Address that authorized the role change
    /// @param user The address who's role has been changed
    /// @param approved Boolean indicating the user's status in role
    /// @param role The bytes32 role created in the inheriting contract
    event RoleChange(address indexed from, address indexed user, bool indexed approved, bytes32 role);

    /// @param from Address that authorized the revoke
    event AllRolesRevoked(address indexed from);

    /*//////////////////////////////////////////////////////////////////////////
                                    Errors
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Does not have specified role
    error NotSpecifiedRole(bytes32 role);

    /// @dev Is not specified role or owner
    error NotRoleOrOwner(bytes32 role);

    /*//////////////////////////////////////////////////////////////////////////
                                    Modifiers
    //////////////////////////////////////////////////////////////////////////*/

    modifier onlyRole(bytes32 role) {
        if (!hasRole(role, msg.sender)) {
            revert NotSpecifiedRole(role);
        }
        _;
    }

    modifier onlyRoleOrOwner(bytes32 role) {
        if (!hasRole(role, msg.sender) && owner() != msg.sender) {
            revert NotRoleOrOwner(role);
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    Initializer
    //////////////////////////////////////////////////////////////////////////*/

    /// @param initOwner The address of the initial owner
    function __OwnableAccessControl_init(address initOwner) internal onlyInitializing {
        __Ownable_init(initOwner);
        __OwnableAccessControl_init_unchained();
    }

    function __OwnableAccessControl_init_unchained() internal onlyInitializing {}

    /*//////////////////////////////////////////////////////////////////////////
                                External Role Functions
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Function to revoke all roles currently present
    /// @dev Increments the `_c` variables
    /// @dev Requires owner privileges
    function revokeAllRoles() external onlyOwner {
        OwnableAccessControlStorage storage $ = _getOwnableAccessControlStorage();
        $.c++;
        emit AllRolesRevoked(msg.sender);
    }

    /// @notice Function to renounce role
    /// @param role Bytes32 role created in inheriting contracts
    function renounceRole(bytes32 role) external {
        address[] memory members = new address[](1);
        members[0] = msg.sender;
        _setRole(role, members, false);
    }

    /// @notice Function to grant/revoke a role to an address
    /// @dev Requires owner to call this function but this may be further
    ///      extended using the internal helper function in inheriting contracts
    /// @param role Bytes32 role created in inheriting contracts
    /// @param roleMembers List of addresses that should have roles attached to them based on `status`
    /// @param status Bool whether to remove or add `roleMembers` to the `role`
    function setRole(bytes32 role, address[] memory roleMembers, bool status) external onlyOwner {
        _setRole(role, roleMembers, status);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                External View Functions
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Function to see if an address is the owner
    /// @param role Bytes32 role created in inheriting contracts
    /// @param potentialRoleMember Address to check for role membership
    function hasRole(bytes32 role, address potentialRoleMember) public view returns (bool) {
        OwnableAccessControlStorage storage $ = _getOwnableAccessControlStorage();
        return $.roleStatus[$.c][role][potentialRoleMember];
    }

    /// @notice Function to get role members
    /// @param role Bytes32 role created in inheriting contracts
    function getRoleMembers(bytes32 role) public view returns (address[] memory) {
        OwnableAccessControlStorage storage $ = _getOwnableAccessControlStorage();
        return $.roleMembers[$.c][role].values();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                Internal Helper Functions
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Helper function to set addresses for a role
    /// @param role Bytes32 role created in inheriting contracts
    /// @param roleMembers List of addresses that should have roles attached to them based on `status`
    /// @param status Bool whether to remove or add `roleMembers` to the `role`
    function _setRole(bytes32 role, address[] memory roleMembers, bool status) internal {
        OwnableAccessControlStorage storage $ = _getOwnableAccessControlStorage();
        for (uint256 i = 0; i < roleMembers.length; i++) {
            $.roleStatus[$.c][role][roleMembers[i]] = status;
            if (status) {
                $.roleMembers[$.c][role].add(roleMembers[i]);
            } else {
                $.roleMembers[$.c][role].remove(roleMembers[i]);
            }
            emit RoleChange(msg.sender, roleMembers[i], status, role);
        }
    }
}

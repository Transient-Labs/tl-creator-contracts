// SPDX-License-Identifier: Apache-2.0

/// @title CoreAuthTL.sol
/// @notice abstract contract that combines Ownable and role based access mechanisms
/// @author transientlabs.xyz

/*
    ____        _ __    __   ____  _ ________                     __ 
   / __ )__  __(_) /___/ /  / __ \(_) __/ __/__  ________  ____  / /_
  / __  / / / / / / __  /  / / / / / /_/ /_/ _ \/ ___/ _ \/ __ \/ __/
 / /_/ / /_/ / / / /_/ /  / /_/ / / __/ __/  __/ /  /  __/ / / / /__ 
/_____/\__,_/_/_/\__,_/  /_____/_/_/ /_/  \___/_/   \___/_/ /_/\__(_)

*/

pragma solidity 0.8.17;

///////////////////// IMPORTS /////////////////////

import { OwnableTL } from "src/access/OwnableTL.sol";
import { EnumerableSetUpgradeable} from "openzeppelin-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";

///////////////////// CUSTOM ERRORS /////////////////////
/// @dev error if is not admin or owner
error NotAdminOrOwner();
/// @dev error if is not a mint contract
error NotApprovedMintContract();

abstract contract CoreAuthTL is OwnableTL {

    ///////////////////// STORAGE VARIABLES /////////////////////

    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant APPROVED_MINT_CONTRACT = keccak256("APPROVED_MINT_CONTRACT");
    mapping(bytes32 => mapping(address => bool)) private _hasRole;
    mapping(bytes32 => EnumerableSetUpgradeable.AddressSet) private _roleMembers;

    ///////////////////// EVENTS /////////////////////

    event AdminApprovalChange(address indexed from, address indexed admin, bool indexed approved);
    event MintContractApprovalChange(address indexed from, address indexed mintContract, bool indexed approved);

    ///////////////////// MODIFIERS /////////////////////

    /// @notice modifer for functions restricted to owner or admin
    modifier onlyAdminOrOwner {
        if (!_isOwner() && !_isAdmin()) {
            revert NotAdminOrOwner();
        }
        _;
    }

    /// @notice modifier for functions restricted to approved mint contracts
    modifier onlyApprovedMintContract {
        if (!_isApprovedMintContract()) {
            revert NotApprovedMintContract();
        }
        _;
    }

    ///////////////////// INTIALIZER /////////////////////

    function __CoreAuthTL_init(address initOwner, address[] memory newAdmins, address[] memory newMinters) internal onlyInitializing {
        __OwnableTL_init(initOwner);
        __CoreAuthTL_init_unchained(newAdmins, newMinters);
    }

    function __CoreAuthTL_init_unchained(address[] memory newAdmins, address[] memory newMinters) internal onlyInitializing {
        _setAdmins(newAdmins, true);
        _setMintContracts(newMinters, true);
    }

    ///////////////////// ADMIN FUNCTIONS /////////////////////

    /// @notice function to add admin addresses
    /// @dev can only be called by the owner
    function addAdmins(address[] calldata newAdmins) external onlyOwner {
        _setAdmins(newAdmins, true);
    }

    /// @notice function to remove admin addresses
    /// @dev can only be called by the owner
    function removeAdmins(address[] calldata newAdmins) external onlyOwner {
        _setAdmins(newAdmins, false);
    }

    /// @notice function to get all admins
    function getAdmins() external view returns(address[] memory) {
        return _roleMembers[ADMIN_ROLE].values();
    }

    /// @notice private helper function to add admin addresses
    function _setAdmins(address[] memory newAdmins, bool approved) private {
        for (uint256 i = 0; i < newAdmins.length; i++) {
            _hasRole[ADMIN_ROLE][newAdmins[i]] = approved;
            if (approved) {
                _roleMembers[ADMIN_ROLE].add(newAdmins[i]);
            } else {
                _roleMembers[ADMIN_ROLE].remove(newAdmins[i]);
            }
            emit AdminApprovalChange(msg.sender, newAdmins[i], approved);
        }
    }

    /// @notice internal helper function to see if an address is an admin
    function _isAdmin() internal view returns(bool) {
        return _hasRole[ADMIN_ROLE][msg.sender];
    }

    ///////////////////// APPROVED MINT CONTRACT FUNCTIONS /////////////////////

    /// @notice function to add mint contract addresses
    /// @dev can only be called by the owner
    function addMintContracts(address[] calldata newMinters) external onlyOwner {
        _setAdmins(newMinters, true);
    }

    /// @notice function to remove mint contract addresses
    /// @dev can only be called by the owner
    function removeMintContracts(address[] calldata newMinters) external onlyOwner {
        _setMintContracts(newMinters, false);
    }

    /// @notice function to get all mint contracts
    function getMintContracts() external view returns(address[] memory) {
        return _roleMembers[APPROVED_MINT_CONTRACT].values();
    }

    /// @notice private helper function to add mint contract addresses
    /// @dev technically minters can be EOAs, but no real point in checking if supplied addresses
    ///      are contracts as it doesn't offer that much security when the rights to minters will be
    ///      restricted further than admins
    function _setMintContracts(address[] memory newMinters, bool approved) private {
        for (uint256 i = 0; i < newMinters.length; i++) {
            _hasRole[APPROVED_MINT_CONTRACT][newMinters[i]] = approved;
            if (approved) {
                _roleMembers[APPROVED_MINT_CONTRACT].add(newMinters[i]);
            } else {
                _roleMembers[APPROVED_MINT_CONTRACT].remove(newMinters[i]);
            }
            emit MintContractApprovalChange(msg.sender, newMinters[i], approved);
        }
    }

    /// @notice internal helper function to see if an address is an approved mint contract
    function _isApprovedMintContract() internal view returns(bool) {
        return _hasRole[APPROVED_MINT_CONTRACT][msg.sender];
    }
}
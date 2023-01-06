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

import { EnumerableSetUpgradeable} from "openzeppelin-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import { OwnableTL } from "./OwnableTL.sol";

///////////////////// CUSTOM ERRORS /////////////////////

/// @dev error if is not admin or owner
error NotAdminOrOwner();

/// @dev error if is not a mint contract
error NotApprovedMintContract();

///////////////////// CORE AUTH CONTRACT /////////////////////

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
        if (!getIfOwner(msg.sender) && !getIfAdmin(msg.sender)) {
            revert NotAdminOrOwner();
        }
        _;
    }

    /// @notice modifier for functions restricted to approved mint contracts
    modifier onlyApprovedMintContract {
        if (!getIfMintContract(msg.sender)) {
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
    function removeAdmins(address[] calldata admins) external onlyOwner {
        _setAdmins(admins, false);
    }

    /// @notice function to let an admin renounce their admin status
    /// @dev helpful if they know their wallet is compromised
    function renounceAdmin() external {
        address[] memory admins = new address[](1);
        admins[0] = msg.sender;
        _setAdmins(admins, false);
    }

    /// @notice function to get all admins
    function getAdmins() external view returns(address[] memory) {
        return _roleMembers[ADMIN_ROLE].values();
    }

    /// @notice function to get if address is an admin
    function getIfAdmin(address potentialAdmin) public view returns(bool) {
        return _hasRole[ADMIN_ROLE][potentialAdmin];
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

    ///////////////////// APPROVED MINT CONTRACT FUNCTIONS /////////////////////

    /// @notice function to add mint contract addresses
    /// @dev can only be called by the owner or admins
    function addMintContracts(address[] calldata newMinters) external onlyAdminOrOwner {
        _setMintContracts(newMinters, true);
    }

    /// @notice function to remove mint contract addresses
    /// @dev can only be called by the owner or admins
    function removeMintContracts(address[] calldata minters) external onlyAdminOrOwner {
        _setMintContracts(minters, false);
    }

    /// @notice function to get all mint contracts
    function getMintContracts() external view returns(address[] memory) {
        return _roleMembers[APPROVED_MINT_CONTRACT].values();
    }

    /// @notice function to get if address is a mint contract
    function getIfMintContract(address potentialMintContract) public view returns(bool) {
        return _hasRole[APPROVED_MINT_CONTRACT][potentialMintContract];
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

    ///////////////////// ERC-165 OVERRIDE /////////////////////

    /// @notice override ERC-165 implementation of this function
    /// @dev if using this contract with another contract that suppports ERC-165, will have to override in the inheriting contract
    function supportsInterface(bytes4 interfaceId) public view virtual override(OwnableTL) returns (bool) {
        return OwnableTL.supportsInterface(interfaceId);
    }
}
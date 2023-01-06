// SPDX-License-Identifier: Apache-2.0

/// @title AuthTL.sol
/// @notice single owner abstract contract
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

import { Initializable } from "openzeppelin-upgradeable/proxy/utils/Initializable.sol";
import { ERC165Upgradeable } from "openzeppelin-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import { IERC173 } from "./IERC173.sol";

///////////////////// CUSTOM ERRORS /////////////////////

/// @dev is not the owner
error NotOwner();

///////////////////// OWNABLE TL CONTRACT /////////////////////

abstract contract OwnableTL is Initializable, ERC165Upgradeable, IERC173 {

    ///////////////////// STORAGE VARIABLES /////////////////////

    address private _owner;

    ///////////////////// MODIFIERS /////////////////////

    modifier onlyOwner {
        if (!getIfOwner(msg.sender)) {
            revert NotOwner();
        }
        _;
    }

    ///////////////////// INITIALIZER /////////////////////

    /// @notice function to initialize this contract
    /// @dev must supply ownership address so that this can easily be used in a contract factory setting
    function __OwnableTL_init(address initOwner) internal onlyInitializing {
        __OwnableTL_init_unchained(initOwner);
    }

    function __OwnableTL_init_unchained(address initOwner) internal onlyInitializing {
        _transferOwnership(initOwner);
    }

    ///////////////////// EXTERNAL FUNCTIONS /////////////////////

    /// @notice function to transfer ownership
    /// @dev must be called by the owner
    /// @dev this can be dangerous if you aren't careful when inputting a new owner address
    function transferOwnership(address newOwner) external onlyOwner {
        _transferOwnership(newOwner);
    }

    /// @notice function to view the owner
    function owner() public view returns(address) {
        return _owner;
    }

    /// @notice function to see if an address is the owner
    function getIfOwner(address potentialOwner) public view returns(bool) {
        return potentialOwner == _owner;
    }

    ///////////////////// INTERNAL FUNCTIONS /////////////////////

    /// @notice helper function for ownership transfer
    function _transferOwnership(address newOwner) internal {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    ///////////////////// ERC-165 OVERRIDE /////////////////////

    /// @notice override ERC-165 implementation of this function
    /// @dev if using this contract with another contract that suppports ERC-165, will have to override in the inheriting contract
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165Upgradeable) returns (bool) {
        return interfaceId == type(IERC173).interfaceId || ERC165Upgradeable.supportsInterface(interfaceId);
    }
}
// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC2981TLUpgradeable} from "src/lib/ERC2981TLUpgradeable.sol";

/// @dev this contract does not have proper access control but is only for testing

contract MockERC2981TLUpgradeable is ERC2981TLUpgradeable {
    function initialize(address recipient, uint256 percentage) external initializer {
        __EIP2981TL_init(recipient, percentage);
    }

    /// @dev function to set new default royalties
    function setDefaultRoyalty(address recipient, uint256 percentage) external {
        _setDefaultRoyaltyInfo(recipient, percentage);
    }

    /// @dev function to set token specific royalties
    function setTokenRoyalty(uint256 tokenId, address recipient, uint256 percentage) external {
        _overrideTokenRoyaltyInfo(tokenId, recipient, percentage);
    }
}

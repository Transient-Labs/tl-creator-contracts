// SPDX-License-Identifier: Apache-2.0

/// @title EIP2981TL.sol
/// @notice contract to define a default royalty spec while allowing for specific token overrides
/// @author transientlabs.xyz

/*
    ____        _ __    __   ____  _ ________                     __ 
   / __ )__  __(_) /___/ /  / __ \(_) __/ __/__  ________  ____  / /_
  / __  / / / / / / __  /  / / / / / /_/ /_/ _ \/ ___/ _ \/ __ \/ __/
 / /_/ / /_/ / / / /_/ /  / /_/ / / __/ __/  __/ /  /  __/ / / / /__ 
/_____/\__,_/_/_/\__,_/  /_____/_/_/ /_/  \___/_/   \___/_/ /_/\__(_)

*/

pragma solidity ^0.8.14;

import "openzeppelin/proxy/utils/Initializable.sol";
import "openzeppelin/utils/introspection/ERC165Upgradeable.sol";
import "./IEIP2981.sol";

contract EIP2981TL is Initializable, ERC165Upgradeable, IEIP2981 {

    struct RoyaltySpec {
        address recipient;
        uint256 percentage;
    }
    address private _defaultRecipient;
    uint256 private _defaultPercentage;
    mapping(uint256 => RoyaltySpec) private _tokenOverrides;

    function __EIP2981_init(address defaultRecipient, uint256 defaultPercentage) internal onlyInitializing {
        _setRoyaltyInfo(defaultRecipient, defaultPercentage);
    }

    /// @notice EIP 2981 royalty support
    function royaltyInfo(uint256 tokenId, uint256 salePrice) external view virtual override returns (address receiver, uint256 royaltyAmount) {
        address recipient = _defaultRecipient;
        uint256 percentage = _defaultPercentage;
        if (_tokenOverrides[tokenId].recipient != address(0)) {
            recipient = _tokenOverrides[tokenId].recipient;
            percentage = _tokenOverrides[tokenId].percentage;
        }
        return (recipient, salePrice / 10_000 * percentage); // divide first to avoid overflow
    }

    /// @notice override ERC 165 implementation of this function
    /// @dev if using this contract with another contract that suppports ERC 165, will have to override in the inheriting contract
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165Upgradeable) returns (bool) {
        return interfaceId == type(IEIP2981).interfaceId || super.supportsInterface(interfaceId);
    }

    /// @notice function to set default royalty info
    function _setRoyaltyInfo(address newRecipient, uint256 newPercentage) internal {
        require(newRecipient != address(0), "EIP2981TL: new recipient cannot be the zero address");
        require(newPercentage < 10_000, "EIP2981TL: new percentage must be less than 10,000");
        _defaultRecipient = newRecipient;
        _defaultPercentage = newPercentage;
    }

    /// @notice function to override royalty spec on a specific token
    function _overrideTokenRoyaltyInfo(uint256 tokenId, address newRecipient, uint256 newPercentage) internal {
        require(newRecipient != address(0), "EIP2981TL: new recipient cannot be the zero address");
        require(newPercentage < 10_000, "EIP2981TL: new percentage must be less than 10,000");
        _tokenOverrides[tokenId].recipient = newRecipient;
        _tokenOverrides[tokenId].percentage = newPercentage;
    }
    
}
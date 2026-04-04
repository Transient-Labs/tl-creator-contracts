// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @title Limit Break's creator token interface
/// @dev The interface id = 0xad0d7f6c
interface ICreatorToken {
    event TransferValidatorUpdated(address oldValidator, address newValidator);

    /// @notice Function to get the address of the transfer validator
    function getTransferValidator() external view returns (address validator);

    /// @notice Function to get the function signature used for the Transfer Validator
    /// @dev Should be `0xcaee23ea`: `bytes4(keccak256("validateTransfer(address,address,address,uint256)"))` for ERC-721
    ///      Should be `0x1854b241`: `bytes4(keccak256("validateTransfer(address,address,address,uint256,uint256)"))` for ERC-1155
    function getTransferValidationFunction() external view returns (bytes4 functionSignature, bool isViewFunction);

    /// @notice Function to set the transfer validator
    /// @dev Requires owner or admin role access
    function setTransferValidator(address validator) external;
}

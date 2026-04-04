// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @title ITransferValidator
/// @notice Limit Break's Transfer Validator interface
interface ITransferValidator {
    function applyListToCollection(address collection, uint48 id) external view;
    function setRulesetOfCollection(
        address collection,
        uint8 rulesetId,
        address customRuleset,
        uint8 globalOptions,
        uint16 rulesetOptions
    ) external view;

    function applyCollectionTransferPolicy(address caller, address from, address to) external view;
    function validateTransfer(address caller, address from, address to) external view;
    function validateTransfer(address caller, address from, address to, uint256 tokenId) external view;
    function validateTransfer(address caller, address from, address to, uint256 tokenId, uint256 amount) external;

    function beforeAuthorizedTransfer(address operator, address token, uint256 tokenId) external;
    function afterAuthorizedTransfer(address token, uint256 tokenId) external;
    function beforeAuthorizedTransfer(address operator, address token) external;
    function afterAuthorizedTransfer(address token) external;
    function beforeAuthorizedTransfer(address token, uint256 tokenId) external;
    function beforeAuthorizedTransferWithAmount(address token, uint256 tokenId, uint256 amount) external;
    function afterAuthorizedTransferWithAmount(address token, uint256 tokenId) external;
}

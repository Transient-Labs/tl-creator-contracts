// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ITransferValidator} from "src/interfaces/ITransferValidator.sol";

contract MockTransferValidator is ITransferValidator {
    error Revert721();
    error Revert1155();
    error RevertCollection();

    bool public revert721;
    bool public revert1155;
    bool public revertCollection;

    function setRevert721(bool status) external {
        revert721 = status;
    }

    function setRevert1155(bool status) external {
        revert1155 = status;
    }

    function setRevertCollection(bool status) external {
        revertCollection = status;
    }

    function applyListToCollection(address, uint48) external view {}

    function setRulesetOfCollection(address, uint8, address, uint8, uint16) external view {}

    function applyCollectionTransferPolicy(address, address, address) external view {
        if (revertCollection) revert RevertCollection();
    }

    function validateTransfer(address, address, address) external view {
        if (revertCollection) revert RevertCollection();
    }

    function validateTransfer(address, address, address, uint256) external view {
        if (revert721) revert Revert721();
    }

    function validateTransfer(address, address, address, uint256, uint256) external view {
        if (revert1155) revert Revert1155();
    }

    function beforeAuthorizedTransfer(address, address, uint256) external {}

    function afterAuthorizedTransfer(address, uint256) external {}

    function beforeAuthorizedTransfer(address, address) external {}

    function afterAuthorizedTransfer(address) external {}

    function beforeAuthorizedTransfer(address, uint256) external {}

    function beforeAuthorizedTransferWithAmount(address, uint256, uint256) external {}

    function afterAuthorizedTransferWithAmount(address, uint256) external {}
}

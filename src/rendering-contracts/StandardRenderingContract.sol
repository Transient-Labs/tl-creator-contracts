// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Strings} from "@openzeppelin-contracts-5.0.2/utils/Strings.sol";
import {IRenderingContract} from "../interfaces/IRenderingContract.sol";

/// @title Standard Rendering Contract
/// @notice A rendering contract that maps a base uri to token id
/// @dev Base uri should NOT end in a slash and should point to a folder of files of the format `<tokenId>.json`
/// @author Transient Labs, Inc
contract StandardRenderingContract is IRenderingContract {
    using Strings for uint256;

    string public baseUri;

    constructor(string memory initBaseUri) {
        baseUri = initBaseUri;
    }

    function tokenURI(uint256 tokenId) external view returns (string memory) {
        return string(abi.encodePacked(baseUri, "/", tokenId.toString(), ".json"));
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IRenderingContract} from "src/interfaces/IRenderingContract.sol";
import {Strings} from "@openzeppelin-contracts-5.0.2/utils/Strings.sol";

contract MockRenderingContract is IRenderingContract {
    using Strings for uint256;

    string public baseUri = "renderingContract/";

    function tokenURI(uint256 tokenId) external view returns (string memory) {
        return string(abi.encodePacked(baseUri, tokenId.toString()));
    }
}

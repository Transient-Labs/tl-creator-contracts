// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IRenderingContract} from "src/interfaces/IRenderingContract.sol";
import {IERC165} from "@openzeppelin-contracts-5.6.1/utils/introspection/IERC165.sol";
import {Strings} from "@openzeppelin-contracts-5.6.1/utils/Strings.sol";

contract MockRenderingContract is IRenderingContract {
    using Strings for uint256;

    string public baseUri = "renderingContract/";

    function tokenURI(uint256 tokenId) external view returns (string memory) {
        return string(abi.encodePacked(baseUri, tokenId.toString()));
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == 0x01ffc9a7 || interfaceId == type(IRenderingContract).interfaceId;
    }
}

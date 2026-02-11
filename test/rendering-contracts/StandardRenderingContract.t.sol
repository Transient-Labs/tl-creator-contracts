// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std-1.14.0/Test.sol";
import {Strings} from "@openzeppelin-contracts-5.0.2/utils/Strings.sol";
import {StandardRenderingContract} from "src/rendering-contracts/StandardRenderingContract.sol";

contract StandardRenderingContractTest is Test {
    using Strings for uint256;

    function test_constructor_setsBaseUri(string memory initBaseUri) public {
        StandardRenderingContract renderingContract = new StandardRenderingContract(initBaseUri);

        assertEq(renderingContract.baseUri(), initBaseUri);
    }

    function test_tokenURI_formatsExpectedUri() public {
        StandardRenderingContract renderingContract = new StandardRenderingContract("ipfs://example-base");

        assertEq(renderingContract.tokenURI(1), "ipfs://example-base/1.json");
        assertEq(renderingContract.tokenURI(42), "ipfs://example-base/42.json");
        assertEq(renderingContract.tokenURI(0), "ipfs://example-base/0.json");
    }

    function test_tokenURI_fuzz(uint256 tokenId, string memory initBaseUri) public {
        StandardRenderingContract renderingContract = new StandardRenderingContract(initBaseUri);

        string memory expectedUri = string(abi.encodePacked(initBaseUri, "/", tokenId.toString(), ".json"));
        assertEq(renderingContract.tokenURI(tokenId), expectedUri);
    }
}

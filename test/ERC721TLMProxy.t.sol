// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {ERC721TLM} from "../src/multi-metadata/ERC721TLM.sol";
import {TLCreator} from "../src/TLCreator.sol";

contract ERC721TLMProxyUnitTest is Test {
    ERC721TLM public erc721;
    ERC721TLM public proxy;

    function setUp() public {
        erc721 = new ERC721TLM(true);
        TLCreator depProxy = new TLCreator(
            address(erc721),
            "Test",
            "TST",
            address(1),
            1000,
            address(1),
            new address[](0),
            true,
            address(0)
        );
        proxy = ERC721TLM(address(depProxy));
    }

    function testDeployment() public {
        assertEq(proxy.name(), "Test");
        assertEq(proxy.symbol(), "TST");
        assertTrue(proxy.storyEnabled());
        (address recp, uint256 amt) = proxy.royaltyInfo(1, 10000);
        assertEq(recp, address(1));
        assertEq(amt, 1000);
        assertEq(address(proxy.blockListRegistry()), address(0));
        assertEq(proxy.owner(), address(1));
    }

    function testInitImplementation() public {
        vm.expectRevert(abi.encodePacked("Initializable: contract is already initialized"));
        erc721.initialize("Test721", "T721", address(1), 1000, address(this), new address[](0), true, address(0));
    }
}

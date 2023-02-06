// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import {ERC1155TL} from "../src/ERC1155TL.sol";
import {ERC1155TLProxy} from "../src/ERC1155TLProxy.sol";

contract ERC1155TLProxyUnitTest is Test {

    ERC1155TL public erc1155;
    ERC1155TL public proxy;

    function setUp() public {
        erc1155 = new ERC1155TL(true);
        ERC1155TLProxy depProxy = new ERC1155TLProxy(
            address(erc1155),
            "Test",
            address(1),
            1000,
            address(this),
            new address[](0),
            true,
            address(0)
        );
        proxy = ERC1155TL(address(depProxy));
    }

    function testDeployment() public {
        assertEq(proxy.name(), "Test");
        assertTrue(proxy.storyEnabled());
        (address recp, uint256 amt) = proxy.royaltyInfo(1, 10000);
        assertEq(recp, address(1));
        assertEq(amt, 1000);
        assertEq(address(proxy.blockListRegistry()), address(0));
        assertEq(proxy.owner(), address(this));
    }

    function testInitImplementation() public {
        vm.expectRevert(abi.encodePacked("Initializable: contract is already initialized"));
        erc1155.initialize("Test721", address(1), 1000, address(this), new address[](0), true, address(0));
    }
}
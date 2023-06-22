// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {Shatter} from "../src/shatter/Shatter.sol";
import {TLCreator} from "../src/TLCreator.sol";

contract ShatterProxyUnitTest is Test {
    Shatter public shatter;
    Shatter public proxy;

    function setUp() public {
        shatter = new Shatter(true);
        TLCreator depProxy = new TLCreator(
            address(shatter),
            "Test",
            "TST",
            address(1),
            1000,
            address(1),
            new address[](0),
            true,
            address(0)
        );
        proxy = Shatter(address(depProxy));
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
        assert(!proxy.isShattered());
        assert(!proxy.isFused());
        assert(proxy.shatters() == 0);
    }

    function testInitImplementation() public {
        vm.expectRevert(abi.encodePacked("Initializable: contract is already initialized"));
        shatter.initialize("Test721", "T721", address(1), 1000, address(this), new address[](0), true, address(0));
    }
}

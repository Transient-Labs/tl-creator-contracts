// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import "forge-std/Test.sol";
import {TRACE} from "tl-creator-contracts/TRACE/TRACE.sol";
import {TRACECreator} from "tl-creator-contracts/TRACE/TRACECreator.sol";

contract TRACEProxyUnitTest is Test {
    TRACE public trace;
    TRACE public proxy;

    function setUp() public {
        trace = new TRACE(true);
        TRACECreator depProxy = new TRACECreator(
            address(trace),
            "Test",
            "TST",
            address(1),
            1000,
            address(1),
            new address[](0),
            address(0)
        );
        proxy = TRACE(address(depProxy));
    }

    function testDeployment() public {
        assertEq(proxy.name(), "Test");
        assertEq(proxy.symbol(), "TST");
        assertTrue(proxy.storyEnabled());
        (address recp, uint256 amt) = proxy.royaltyInfo(1, 10000);
        assertEq(recp, address(1));
        assertEq(amt, 1000);
        assertEq(address(proxy.tracersRegistry()), address(0));
        assertEq(proxy.owner(), address(1));
    }

    function testInitImplementation() public {
        vm.expectRevert(abi.encodePacked("Initializable: contract is already initialized"));
        trace.initialize("Test721", "T721", address(1), 1000, address(this), new address[](0), address(0));
    }
}

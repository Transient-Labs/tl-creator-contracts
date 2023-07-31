// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {ERC721TL} from "tl-creator-contracts/core/ERC721TL.sol";
import {Doppelganger} from "tl-creator-contracts/doppelganger/Doppelganger.sol";

contract DoppelgangerTest is Test {
    event NewURIAdded(address indexed sender, string newUri, uint256 index);

    event MetadataUpdate(uint256 tokenId);

    error Unauthorized();

    error MetadataSelectionDoesNotExist(uint256 selection);

    ERC721TL public erc721;
    ERC721TL public proxy;

    address public alice = address(0xbeef);
    address public bob = address(0xcafe);
    address public charlie = address(0x42069);

    function setUp() public {
        erc721 = new ERC721TL(true);
        Doppelganger depProxy = new Doppelganger(
            address(erc721),
            "Test",
            "TST",
            alice,
            1000,
            alice,
            new address[](0),
            true,
            address(0)
        );
        proxy = ERC721TL(address(depProxy));

        string[] memory uris = new string[](1);
        uris[0] = "defaultURI://";

        vm.startPrank(alice);
        vm.expectEmit(true, false, false, false);
        emit NewURIAdded(alice, "doppelgangURI1://", 1);
        Doppelganger(payable(address(proxy))).addNewURIs(uris);
        vm.stopPrank();
    }

    function testSetUp() public {
        assertEq(proxy.name(), "Test");
        assertEq(proxy.symbol(), "TST");
        assertTrue(proxy.storyEnabled());
        (address recp, uint256 amt) = proxy.royaltyInfo(1, 10000);
        assertEq(recp, alice);
        assertEq(amt, 1000);
        assertEq(address(proxy.blockListRegistry()), address(0));
        assertEq(proxy.owner(), alice);
    }

    function testInitFailAlreadyInitialized() public {
        vm.expectRevert(abi.encodePacked("Initializable: contract is already initialized"));
        erc721.initialize("Test721", "T721", address(1), 1000, address(this), new address[](0), true, address(0));
    }

    function testTokenUri() public {
        vm.startPrank(alice);
        proxy.mint(bob, "berries and cream");
        vm.stopPrank();

        assert(keccak256(abi.encodePacked(proxy.tokenURI(1))) == keccak256(abi.encodePacked("defaultURI://")));

        assert(proxy.balanceOf(bob) == 1);
        assert(proxy.ownerOf(1) == bob);
    }

    function testAddNewURI() external {
        string[] memory uris = new string[](1);
        uris[0] = "doppelgangURI1://";

        vm.startPrank(alice);
        vm.expectEmit(true, false, false, false);
        emit NewURIAdded(alice, "doppelgangURI1://", 1);
        Doppelganger(payable(address(proxy))).addNewURIs(uris);
        vm.stopPrank();
        assert(Doppelganger(payable(address(proxy))).numURIs() == 2);
    }

    function testAddNewURIUnauthorized() external {
        string[] memory uris = new string[](1);
        uris[0] = "doppelgangURI1://";

        vm.startPrank(bob);
        vm.expectRevert(Unauthorized.selector);
        Doppelganger(payable(address(proxy))).addNewURIs(uris);
        vm.stopPrank();
    }

    function testChangeURI() public {
        string[] memory uris = new string[](1);
        uris[0] = "doppelgangURI1://";

        vm.startPrank(alice);
        proxy.mint(bob, "berries and cream");
        Doppelganger(payable(address(proxy))).addNewURIs(uris);
        vm.stopPrank();

        vm.prank(bob);
        vm.expectEmit(true, false, false, false);
        emit MetadataUpdate(1);
        Doppelganger(payable(address(proxy))).changeURI(1, 1);

        assert(keccak256(abi.encodePacked(proxy.tokenURI(1))) == keccak256(abi.encodePacked("doppelgangURI1://")));
    }

    function testChangeURIUnauthorized() public {
        string[] memory uris = new string[](1);
        uris[0] = "doppelgangURI1://";

        vm.startPrank(alice);
        proxy.mint(bob, "berries and cream");
        Doppelganger(payable(address(proxy))).addNewURIs(uris);
        vm.stopPrank();

        vm.prank(charlie);
        vm.expectRevert(Unauthorized.selector);
        Doppelganger(payable(address(proxy))).changeURI(1, 1);

        assert(keccak256(abi.encodePacked(proxy.tokenURI(1))) == keccak256(abi.encodePacked("defaultURI://")));
    }

    function testChangeURIMetadataDoesntExist() public {
        vm.startPrank(alice);
        proxy.mint(bob, "berries and cream");
        vm.stopPrank();

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(MetadataSelectionDoesNotExist.selector, 1));
        Doppelganger(payable(address(proxy))).changeURI(1, 1);

        assert(keccak256(abi.encodePacked(proxy.tokenURI(1))) == keccak256(abi.encodePacked("defaultURI://")));
    }

    function testChangeURITokenDoesntExist() public {
        vm.prank(bob);
        vm.expectRevert("ERC721: invalid token ID");
        Doppelganger(payable(address(proxy))).changeURI(1, 1);
    }

    function testTokenUriTokenDoesntExist() public {
        vm.expectRevert("ERC721: invalid token ID");
        proxy.tokenURI(1);
    }
}

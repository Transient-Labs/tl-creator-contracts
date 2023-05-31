// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {ERC721TL} from "../src/core/ERC721TL.sol";
import {CollectorsChoice} from "../src/doppelganger/CollectorsChoice.sol";

contract CollectorsChoiceTest is Test {
    event NewURIAdded(address indexed sender, string newUri, uint256 index);

    event URIChanged(address indexed sender, uint256 tokenId, string newUri);

    error Unauthorized();

    error MetadataSelectionDoesNotExist(uint256 selection);

    ERC721TL public erc721;
    ERC721TL public proxy;

    address public alice = address(0xbeef);
    address public bob = address(0xcafe);
    address public charlie = address(0x42069);

    function setUp() public {
        erc721 = new ERC721TL(true);
        CollectorsChoice depProxy = new CollectorsChoice(
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
        CollectorsChoice(payable(address(proxy))).addNewURIs(uris);
        vm.stopPrank();
    }

    function test_setUp() public {
        assertEq(proxy.name(), "Test");
        assertEq(proxy.symbol(), "TST");
        assertTrue(proxy.storyEnabled());
        (address recp, uint256 amt) = proxy.royaltyInfo(1, 10000);
        assertEq(recp, alice);
        assertEq(amt, 1000);
        assertEq(address(proxy.blockListRegistry()), address(0));
        assertEq(proxy.owner(), alice);
    }

    function test_init_fail_already_initialized() public {
        vm.expectRevert(abi.encodePacked("Initializable: contract is already initialized"));
        erc721.initialize("Test721", "T721", address(1), 1000, address(this), new address[](0), true, address(0));
    }

    function test_tokenUri() public {
        vm.startPrank(alice);
        proxy.mint(bob, "berries and cream");
        vm.stopPrank();

        assert(keccak256(abi.encodePacked(proxy.tokenURI(1))) == keccak256(abi.encodePacked("defaultURI://")));

        assert(proxy.balanceOf(bob) == 1);
        assert(proxy.ownerOf(1) == bob);
    }

    function test_addURI() external {
        string[] memory uris = new string[](1);
        uris[0] = "doppelgangURI1://";

        vm.startPrank(alice);
        vm.expectEmit(true, false, false, false);
        emit NewURIAdded(alice, "doppelgangURI1://", 1);
        CollectorsChoice(payable(address(proxy))).addNewURIs(uris);
        vm.stopPrank();
        assert(CollectorsChoice(payable(address(proxy))).numURIs() == 2);
    }

    function test_addURI_fail_unauthorized() external {
        string[] memory uris = new string[](1);
        uris[0] = "doppelgangURI1://";

        vm.startPrank(bob);
        vm.expectRevert(Unauthorized.selector);
        CollectorsChoice(payable(address(proxy))).addNewURIs(uris);
        vm.stopPrank();
    }

    function test_changeURI() public {
        string[] memory uris = new string[](1);
        uris[0] = "doppelgangURI1://";

        vm.startPrank(alice);
        proxy.mint(bob, "berries and cream");
        CollectorsChoice(payable(address(proxy))).addNewURIs(uris);
        vm.stopPrank();

        vm.prank(bob);
        vm.expectEmit(true, false, false, false);
        emit URIChanged(bob, 1, "doppelgangURI1://");
        CollectorsChoice(payable(address(proxy))).changeURI(1, 1);

        assert(keccak256(abi.encodePacked(proxy.tokenURI(1))) == keccak256(abi.encodePacked("doppelgangURI1://")));
    }

    function test_changeURI_fail_unauthorized() public {
        string[] memory uris = new string[](1);
        uris[0] = "doppelgangURI1://";

        vm.startPrank(alice);
        proxy.mint(bob, "berries and cream");
        CollectorsChoice(payable(address(proxy))).addNewURIs(uris);
        vm.stopPrank();

        vm.prank(charlie);
        vm.expectRevert(Unauthorized.selector);
        CollectorsChoice(payable(address(proxy))).changeURI(1, 1);

        assert(keccak256(abi.encodePacked(proxy.tokenURI(1))) == keccak256(abi.encodePacked("defaultURI://")));
    }

    function test_changeURI_fail_metadata_doesnt_exist() public {
        vm.startPrank(alice);
        proxy.mint(bob, "berries and cream");
        vm.stopPrank();

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(MetadataSelectionDoesNotExist.selector, 1));
        CollectorsChoice(payable(address(proxy))).changeURI(1, 1);

        assert(keccak256(abi.encodePacked(proxy.tokenURI(1))) == keccak256(abi.encodePacked("defaultURI://")));
    }

    function test_changeURI_fail_metadata_token_doesnt_exist() public {
        vm.prank(bob);
        vm.expectRevert("ERC721: invalid token ID");
        CollectorsChoice(payable(address(proxy))).changeURI(1, 1);
    }

    function test_tokenUri_fail_doesnt_exist() public {
        vm.expectRevert("ERC721: invalid token ID");
        proxy.tokenURI(1);
    }

    function test_setCutoff() public {
        string[] memory uris = new string[](1);
        uris[0] = "doppelgangURI1://";

        vm.startPrank(alice);
        proxy.mint(bob, "berries and cream");
        CollectorsChoice(payable(address(proxy))).setCutoff(block.timestamp + 500);
        CollectorsChoice(payable(address(proxy))).addNewURIs(uris);
        vm.stopPrank();

        vm.prank(bob);
        vm.expectEmit(true, false, false, false);
        emit URIChanged(bob, 1, "doppelgangURI1://");
        CollectorsChoice(payable(address(proxy))).changeURI(1, 1);

        assert(keccak256(abi.encodePacked(proxy.tokenURI(1))) == keccak256(abi.encodePacked("doppelgangURI1://")));

        vm.warp(block.timestamp + 501);
        vm.prank(bob);
        vm.expectRevert();
        CollectorsChoice(payable(address(proxy))).changeURI(1, 1);
    }

    function test_setCutoff_fail() public {
        string[] memory uris = new string[](1);
        uris[0] = "doppelgangURI1://";

        vm.startPrank(alice);
        proxy.mint(bob, "berries and cream");
        CollectorsChoice(payable(address(proxy))).setCutoff(block.timestamp + 500);
        CollectorsChoice(payable(address(proxy))).addNewURIs(uris);

        vm.expectRevert();
        CollectorsChoice(payable(address(proxy))).setCutoff(block.timestamp + 200);
        vm.stopPrank();
    }
}

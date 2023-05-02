// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import {ERC721TL} from "../src/ERC721TL.sol";
import {Doppelganger} from "../src/custom/Doppelganger.sol";

contract DoppelgangerTest is Test {

    event NewDoppelgangerAdded(
        address indexed sender,
        string newUri,
        uint256 index
    );

    event Cloned(
        address indexed sender,
        uint256 tokenId,
        string newUri
    );

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
            "defaultURI://",
            true,
            address(0)
        );
        proxy = ERC721TL(address(depProxy));
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

        assert(keccak256(abi.encodePacked(proxy.tokenURI(1))) == 
            keccak256(abi.encodePacked("defaultURI://")));

        assert(proxy.balanceOf(bob) == 1);
        assert(proxy.ownerOf(1) == bob);
    }

    function test_addDoppelganger() external {
        vm.startPrank(alice);
        vm.expectEmit(true, false, false, false);
        emit NewDoppelgangerAdded(alice, "doppelgangURI1://", 1);
        Doppelganger(payable(address(proxy))).addDoppelganger("doppelgangURI1://");
        vm.stopPrank();
        assert(Doppelganger(payable(address(proxy))).numDoppelgangerURIs() == 2);
    }

    function test_addDoppelganger_fail_unauthorized() external {
        vm.startPrank(bob);
        vm.expectRevert(Unauthorized.selector);
        Doppelganger(payable(address(proxy))).addDoppelganger("doppelgangURI1://");
        vm.stopPrank();
    }

    function test_dopplegang() public {
        vm.startPrank(alice);
        proxy.mint(bob, "berries and cream");
        Doppelganger(payable(address(proxy))).addDoppelganger("doppelgangURI1://");
        vm.stopPrank();

        vm.prank(bob);
        vm.expectEmit(true, false, false, false);
        emit Cloned(bob, 1, "doppelgangURI1://");
        Doppelganger(payable(address(proxy))).doppelgang(1, 1);

        assert(keccak256(abi.encodePacked(proxy.tokenURI(1))) == 
            keccak256(abi.encodePacked("doppelgangURI1://")));
    }

    function test_dopplegang_fail_unauthorized() public {
        vm.startPrank(alice);
        proxy.mint(bob, "berries and cream");
        Doppelganger(payable(address(proxy))).addDoppelganger("doppelgangURI1://");
        vm.stopPrank();

        vm.prank(charlie);
        vm.expectRevert(Unauthorized.selector);
        Doppelganger(payable(address(proxy))).doppelgang(1, 1);

        assert(keccak256(abi.encodePacked(proxy.tokenURI(1))) == 
            keccak256(abi.encodePacked("defaultURI://")));
    }

    function test_dopplegang_fail_metadata_doesnt_exist() public {
        vm.startPrank(alice);
        proxy.mint(bob, "berries and cream");
        vm.stopPrank();

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(MetadataSelectionDoesNotExist.selector, 1));
        Doppelganger(payable(address(proxy))).doppelgang(1, 1);

        assert(keccak256(abi.encodePacked(proxy.tokenURI(1))) == 
            keccak256(abi.encodePacked("defaultURI://")));
    }

    function test_dopplegang_fail_metadata_token_doesnt_exist() public {
        vm.prank(bob);
        vm.expectRevert("ERC721: invalid token ID");
        Doppelganger(payable(address(proxy))).doppelgang(1, 1);
    }

    function test_tokenUri_fail_doesnt_exist() public {
        vm.expectRevert("ERC721: invalid token ID");
        proxy.tokenURI(1);
    }
}

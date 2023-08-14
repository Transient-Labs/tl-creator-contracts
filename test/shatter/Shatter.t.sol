// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {
    Shatter,
    EmptyTokenURI,
    AlreadyMinted,
    NotShattered,
    IsShattered,
    IsFused,
    CallerNotTokenOwner,
    CallerDoesNotOwnAllTokens,
    InvalidNumShatters,
    CallPriorToShatterTime,
    NoTokenUriUpdateAvailable,
    TokenDoesntExist
} from "tl-creator-contracts/shatter/Shatter.sol";
import {IERC2309Upgradeable} from "openzeppelin-upgradeable/interfaces/IERC2309Upgradeable.sol";
import {IShatter} from "tl-creator-contracts/shatter/IShatter.sol";
import {Strings} from "openzeppelin/utils/Strings.sol";
import {BlockListRegistry} from "tl-blocklist/BlockListRegistry.sol";

contract ShatterUnitTest is IERC2309Upgradeable, Test {
    event Shattered(address indexed user, uint256 indexed numShatters, uint256 indexed shatteredTime);
    event Fused(address indexed user, uint256 indexed fuseTime);
    event Transfer(address indexed _from, address indexed _to, uint256 indexed _tokenId);
    event MetadataUpdate(uint256 tokenId);
    event SynergyStatusChange(
        address indexed from, uint256 indexed tokenId, Shatter.SynergyAction indexed action, string uri
    );

    Shatter public tokenContract;
    address public alice = address(0xcafe);
    address public bob = address(0xbeef);
    address public royaltyRecipient = address(0x1337);
    address public admin = address(0xc0fee);

    using Strings for uint256;

    function setUp() public {
        address[] memory admins = new address[](1);
        admins[0] = admin;
        tokenContract = new Shatter(false);
        tokenContract.initialize("Test721", "T721", royaltyRecipient, 10_00, address(this), admins, true, address(0));
    }

    function testSetUp() public view {
        assert(!tokenContract.isShattered());
        assert(!tokenContract.isFused());
        assert(tokenContract.shatters() == 0);
    }

    function testMintOwner() public {
        tokenContract.mint(address(this), "testURI", 0, 100, block.timestamp + 7200);
        assert(tokenContract.ownerOf(0) == address(this));
        vm.expectRevert("ERC721: invalid token ID");
        tokenContract.ownerOf(1);
        assert(tokenContract.minShatters() == 1);
        assert(tokenContract.maxShatters() == 100);
        assert(tokenContract.shatterTime() == block.timestamp + 7200);
        assert(tokenContract.shatters() == 1);
        assert(tokenContract.totalSupply() == 1);
        assertEq(tokenContract.tokenURI(0), "testURI/0");
    }

    function testMintAdmin() public {
        vm.startPrank(admin, admin);
        tokenContract.mint(address(this), "testURI", 1, 100, block.timestamp + 7200);
        assert(tokenContract.ownerOf(0) == address(this));
        vm.expectRevert("ERC721: invalid token ID");
        tokenContract.ownerOf(1);
        assert(tokenContract.minShatters() == 1);
        assert(tokenContract.maxShatters() == 100);
        assert(tokenContract.shatterTime() == block.timestamp + 7200);
        assert(tokenContract.shatters() == 1);
        assert(tokenContract.totalSupply() == 1);
        assertEq(tokenContract.tokenURI(0), "testURI/0");
        vm.stopPrank();
    }

    function testMintAlreadyMinted() public {
        tokenContract.mint(address(this), "testURI", 1, 100, block.timestamp + 7200);
        vm.expectRevert(AlreadyMinted.selector);
        tokenContract.mint(address(this), "testURI", 1, 100, block.timestamp + 7200);
        assert(tokenContract.shatters() == 1);
    }

    function testMintEmptyUri() public {
        vm.expectRevert(EmptyTokenURI.selector);
        tokenContract.mint(address(this), "", 1, 100, block.timestamp + 7200);
    }

    function testShatter(address recipient, uint256 numShatters) public {
        vm.assume(numShatters > 1);
        if (numShatters > 100) numShatters = numShatters % 99 + 2;
        vm.assume(recipient != address(0));
        vm.assume(recipient != address(this));
        vm.assume(recipient != admin);

        // mint
        tokenContract.mint(recipient, "testURI", 1, 100, block.timestamp + 7200);
        vm.warp(block.timestamp + 7200);

        // verify owner and admin can't shatter
        vm.expectRevert(CallerNotTokenOwner.selector);
        tokenContract.shatter(numShatters);
        vm.startPrank(admin, admin);
        vm.expectRevert(CallerNotTokenOwner.selector);
        tokenContract.shatter(numShatters);
        vm.stopPrank();

        // test shatter
        vm.startPrank(recipient, recipient);
        if (numShatters > 1) {
            // burn event
            vm.expectEmit(true, true, true, true);
            emit Transfer(recipient, address(0), 0);
            // batch mint event
            for (uint256 id = 1; id < numShatters + 1; ++id) {
                vm.expectEmit(true, true, true, false);
                emit Transfer(address(0), recipient, id);
            }
            // shatter event
            vm.expectEmit(true, true, true, true);
            emit Shattered(recipient, numShatters, block.timestamp);
        } else {
            // shatter event
            vm.expectEmit(true, true, true, true);
            emit Shattered(recipient, numShatters, block.timestamp);
            // fuse event
            vm.expectEmit(true, true, true, true);
            emit Fused(recipient, block.timestamp);
        }

        tokenContract.shatter(numShatters);
        assert(tokenContract.shatters() == numShatters);
        assert(tokenContract.isShattered());
        assert(tokenContract.balanceOf(recipient) == numShatters);

        vm.stopPrank();

        if (numShatters == 1) {
            assert(tokenContract.ownerOf(0) == recipient);
            assert(tokenContract.isFused());
        } else {
            vm.expectRevert("ERC721: invalid token ID");
            tokenContract.ownerOf(0);
        }

        for (uint256 i = 1; i < numShatters; i++) {
            assert(tokenContract.ownerOf(i) == recipient);
        }
    }

    function testShatterFail() public {
        tokenContract.mint(address(this), "testURI", 1, 100, block.timestamp + 7200);

        vm.expectRevert(CallPriorToShatterTime.selector);
        tokenContract.shatter(1);

        vm.prank(bob);
        vm.expectRevert(CallerNotTokenOwner.selector);
        tokenContract.shatter(1);

        vm.warp(block.timestamp + 7200);

        vm.expectRevert(InvalidNumShatters.selector);
        tokenContract.shatter(0);
        vm.expectRevert(InvalidNumShatters.selector);
        tokenContract.shatter(101);

        tokenContract.shatter(50);
        vm.expectRevert(IsShattered.selector);
        tokenContract.shatter(1);
    }

    function testShatterUltra(address recipient, uint256 numShatters) public {
        vm.assume(numShatters > 1);
        if (numShatters > 100) numShatters = numShatters % 99 + 2;
        vm.assume(recipient != address(0));
        vm.assume(recipient != address(this));
        vm.assume(recipient != admin);

        // mint
        tokenContract.mint(recipient, "testURI", 1, 100, block.timestamp + 7200);
        vm.warp(block.timestamp + 7200);

        // verify owner and admin can't shatter
        vm.expectRevert(CallerNotTokenOwner.selector);
        tokenContract.shatterUltra(numShatters);
        vm.startPrank(admin, admin);
        vm.expectRevert(CallerNotTokenOwner.selector);
        tokenContract.shatterUltra(numShatters);
        vm.stopPrank();

        // test shatter
        vm.startPrank(recipient, recipient);
        if (numShatters > 1) {
            // burn event
            vm.expectEmit(true, true, true, true);
            emit Transfer(recipient, address(0), 0);
            // batch mint event
            vm.expectEmit(true, true, true, true);
            emit ConsecutiveTransfer(1, numShatters, address(0), recipient);
            // shatter event
            vm.expectEmit(true, true, true, true);
            emit Shattered(recipient, numShatters, block.timestamp);
        } else {
            // shatter event
            vm.expectEmit(true, true, true, true);
            emit Shattered(recipient, numShatters, block.timestamp);
            // fuse event
            vm.expectEmit(true, true, true, true);
            emit Fused(recipient, block.timestamp);
        }

        tokenContract.shatterUltra(numShatters);
        assert(tokenContract.shatters() == numShatters);
        assert(tokenContract.isShattered());
        assert(tokenContract.balanceOf(recipient) == numShatters);

        vm.stopPrank();

        if (numShatters == 1) {
            assert(tokenContract.ownerOf(0) == recipient);
            assert(tokenContract.isFused());
        } else {
            vm.expectRevert("ERC721: invalid token ID");
            tokenContract.ownerOf(0);
        }

        for (uint256 i = 1; i < numShatters; i++) {
            assert(tokenContract.ownerOf(i) == recipient);
        }
    }

    function testShatterUltraFail() public {
        tokenContract.mint(address(this), "testURI", 1, 100, block.timestamp + 7200);

        vm.expectRevert(CallPriorToShatterTime.selector);
        tokenContract.shatterUltra(1);

        vm.prank(bob);
        vm.expectRevert(CallerNotTokenOwner.selector);
        tokenContract.shatterUltra(1);

        vm.warp(block.timestamp + 7200);

        vm.expectRevert(InvalidNumShatters.selector);
        tokenContract.shatterUltra(0);
        vm.expectRevert(InvalidNumShatters.selector);
        tokenContract.shatterUltra(101);

        tokenContract.shatterUltra(50);
        vm.expectRevert(IsShattered.selector);
        tokenContract.shatterUltra(1);
    }

    function testFuse(uint256 numShatters) public {
        vm.assume(numShatters > 1);
        if (numShatters > 100) numShatters = numShatters % 99 + 2;

        // mint and shatter
        tokenContract.mint(address(this), "testURI", 1, 100, 0);
        tokenContract.shatter(numShatters);

        assert(tokenContract.isShattered());
        assert(!tokenContract.isFused());

        for (uint256 i = 0; i < numShatters; i++) {
            vm.expectEmit(true, true, true, true);
            emit Transfer(address(this), address(0), i + 1);
        }

        vm.expectEmit(true, true, true, true);
        emit Fused(address(this), block.timestamp);

        tokenContract.fuse();
    }

    function testFuseFail() public {
        tokenContract.mint(address(this), "testURI", 1, 100, 0);

        vm.expectRevert(NotShattered.selector);
        tokenContract.fuse();

        tokenContract.shatter(100);

        assert(tokenContract.isShattered());
        assert(!tokenContract.isFused());

        tokenContract.transferFrom(address(this), address(0xbeef), 5);
        assert(tokenContract.ownerOf(5) == address(0xbeef));
        assert(tokenContract.balanceOf(address(0xbeef)) == 1);

        vm.expectRevert(CallerDoesNotOwnAllTokens.selector);
        tokenContract.fuse();

        vm.prank(address(0xbeef));
        tokenContract.transferFrom(address(0xbeef), address(this), 5);
        assert(tokenContract.balanceOf(address(0xbeef)) == 0);

        tokenContract.fuse();

        vm.expectRevert(IsFused.selector);
        tokenContract.fuse();
    }

    function testFuseAfterUltra(uint256 numShatters) public {
        vm.assume(numShatters > 1);
        if (numShatters > 100) numShatters = numShatters % 99 + 2;

        // mint and shatter
        tokenContract.mint(address(this), "testURI", 1, 100, 0);
        tokenContract.shatterUltra(numShatters);

        assert(tokenContract.isShattered());
        assert(!tokenContract.isFused());

        for (uint256 i = 0; i < numShatters; i++) {
            vm.expectEmit(true, true, true, true);
            emit Transfer(address(this), address(0), i + 1);
        }

        vm.expectEmit(true, true, true, true);
        emit Fused(address(this), block.timestamp);

        tokenContract.fuse();
    }

    function testFuseAfterUltraFail() public {
        tokenContract.mint(address(this), "testURI", 1, 100, 0);

        vm.expectRevert(NotShattered.selector);
        tokenContract.fuse();

        tokenContract.shatterUltra(100);

        assert(tokenContract.isShattered());
        assert(!tokenContract.isFused());

        tokenContract.transferFrom(address(this), address(0xbeef), 5);
        assert(tokenContract.ownerOf(5) == address(0xbeef));
        assert(tokenContract.balanceOf(address(0xbeef)) == 1);

        vm.expectRevert(CallerDoesNotOwnAllTokens.selector);
        tokenContract.fuse();

        vm.prank(address(0xbeef));
        tokenContract.transferFrom(address(0xbeef), address(this), 5);
        assert(tokenContract.balanceOf(address(0xbeef)) == 0);

        tokenContract.fuse();

        vm.expectRevert(IsFused.selector);
        tokenContract.fuse();
    }

    function testOwnerOf(address recipient, uint256 numShatters) public {
        // tests transfer of tokens prior to shatter, after shatter, and then after fuse
        vm.assume(numShatters > 1);
        if (numShatters > 100) numShatters = numShatters % 99 + 2;
        vm.assume(recipient != address(0));
        vm.assume(recipient != address(this));

        // mint and transfer
        tokenContract.mint(address(this), "tokenUri", 1, 100, 0);
        tokenContract.transferFrom(address(this), recipient, 0);
        assert(tokenContract.ownerOf(0) == recipient);

        vm.startPrank(recipient, recipient);
        tokenContract.transferFrom(recipient, address(this), 0);
        vm.stopPrank();

        // shatter and transfer all to recipient
        tokenContract.shatter(numShatters);
        for (uint256 i = 0; i < numShatters; i++) {
            tokenContract.transferFrom(address(this), recipient, i + 1);
            assert(tokenContract.ownerOf(i + 1) == recipient);
        }

        // fuse and transfer
        vm.startPrank(recipient, recipient);
        tokenContract.fuse();
        assert(tokenContract.ownerOf(0) == recipient);
        tokenContract.transferFrom(recipient, address(this), 0);
        assert(tokenContract.ownerOf(0) == address(this));
        vm.stopPrank();
    }

    function testSetDefaultRoyalty() public {
        // owner can set royalty
        tokenContract.setDefaultRoyalty(bob, 500);
        (address recp, uint256 amt) = tokenContract.royaltyInfo(0, 10_000);
        assert(recp == bob);
        assert(amt == 500);

        // admin can't set royalty
        vm.prank(admin, admin);
        vm.expectRevert();
        tokenContract.setDefaultRoyalty(admin, 1000);

        // alice can't set royalty
        vm.prank(alice, alice);
        vm.expectRevert();
        tokenContract.setDefaultRoyalty(admin, 1000);
    }

    function testTokenRoyaltyOverride() public {
        // owner can set royalty
        tokenContract.setTokenRoyalty(1, bob, 500);
        (address recp, uint256 amt) = tokenContract.royaltyInfo(1, 10_000);
        assert(recp == bob);
        assert(amt == 500);

        // admin can't set royalty
        vm.prank(admin, admin);
        vm.expectRevert();
        tokenContract.setTokenRoyalty(1, admin, 1000);

        // alice can't set royalty
        vm.prank(alice, alice);
        vm.expectRevert();
        tokenContract.setTokenRoyalty(1, admin, 1000);
    }

    function testTokenUri(uint256 numShatters) public {
        vm.assume(numShatters < 101 && numShatters > 0);
        // unminted token
        vm.expectRevert(TokenDoesntExist.selector);
        tokenContract.tokenURI(0);

        // minted 1/1
        tokenContract.mint(address(this), "testUri", 1, 100, 0);
        assertEq(tokenContract.tokenURI(0), "testUri/0");

        // shatter & fuse
        tokenContract.shatter(numShatters);
        if (numShatters > 1) {
            for (uint256 i = 0; i < numShatters; i++) {
                assertEq(tokenContract.tokenURI(i + 1), string(abi.encodePacked("testUri/", (i + 1).toString())));
            }
        } else {
            assertEq(tokenContract.tokenURI(0), "testUri/0");
        }
    }

    function testProposeTokenUri() public {
        tokenContract.mint(address(this), "testUri", 1, 100, 0);

        vm.expectEmit(true, true, true, true);
        emit MetadataUpdate(0);
        tokenContract.proposeNewTokenUri(0, "newUri");
        assertEq(tokenContract.tokenURI(0), "newUri");

        vm.prank(admin);
        vm.expectEmit(true, true, true, true);
        emit MetadataUpdate(0);
        tokenContract.proposeNewTokenUri(0, "newUri1");
        assertEq(tokenContract.tokenURI(0), "newUri1");

        tokenContract.transferFrom(address(this), alice, 0);
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(address(this), 0, Shatter.SynergyAction.Created, "newUri2");
        tokenContract.proposeNewTokenUri(0, "newUri2");
        assertEq(tokenContract.tokenURI(0), "newUri1");
    }

    function testProposeTokenUriFail() public {
        vm.expectRevert(TokenDoesntExist.selector);
        tokenContract.proposeNewTokenUri(0, "newUri");

        tokenContract.mint(address(this), "testUri", 1, 100, 0);
        vm.expectRevert(EmptyTokenURI.selector);
        tokenContract.proposeNewTokenUri(0, "");
    }

    function testAcceptTokenUri(uint256 numShatters) public {
        vm.assume(numShatters > 1);
        if (numShatters > 100) numShatters = numShatters % 99 + 2;

        tokenContract.mint(alice, "testUri", 1, 100, 0);
        assertEq(tokenContract.tokenURI(0), "testUri/0");

        tokenContract.proposeNewTokenUri(0, "newUri");
        assertEq(tokenContract.tokenURI(0), "testUri/0");

        vm.expectEmit(true, true, true, true);
        emit MetadataUpdate(0);
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(alice, 0, Shatter.SynergyAction.Accepted, "newUri");
        vm.prank(alice);
        tokenContract.acceptTokenUriUpdate(0);
        assertEq(tokenContract.tokenURI(0), "newUri");

        vm.prank(alice);
        tokenContract.shatter(numShatters);
        for (uint256 i = 0; i < numShatters; i++) {
            string memory uri = string(abi.encodePacked("newUri/", (i + 1).toString()));
            tokenContract.proposeNewTokenUri(i + 1, uri);
            vm.prank(alice);
            vm.expectEmit(true, true, true, true);
            emit MetadataUpdate(i + 1);
            vm.expectEmit(true, true, true, true);
            emit SynergyStatusChange(alice, i + 1, Shatter.SynergyAction.Accepted, uri);
            tokenContract.acceptTokenUriUpdate(i + 1);
            assertEq(tokenContract.tokenURI(i + 1), uri);
        }

        vm.prank(alice);
        tokenContract.fuse();
        assertEq(tokenContract.tokenURI(0), "newUri");

        tokenContract.proposeNewTokenUri(0, "newUri1");
        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit MetadataUpdate(0);
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(alice, 0, Shatter.SynergyAction.Accepted, "newUri1");
        tokenContract.acceptTokenUriUpdate(0);
        assertEq(tokenContract.tokenURI(0), "newUri1");
    }

    function testAcceptTokenUriFail() public {
        vm.expectRevert("ERC721: invalid token ID");
        tokenContract.acceptTokenUriUpdate(0);

        tokenContract.mint(alice, "testUri", 1, 100, 0);
        vm.expectRevert(CallerNotTokenOwner.selector);
        tokenContract.acceptTokenUriUpdate(0);

        vm.expectRevert(NoTokenUriUpdateAvailable.selector);
        vm.prank(alice);
        tokenContract.acceptTokenUriUpdate(0);
    }

    function testRejectTokenUri(uint256 numShatters) public {
        vm.assume(numShatters > 1);
        if (numShatters > 100) numShatters = numShatters % 99 + 2;

        tokenContract.mint(alice, "testUri", 1, 100, 0);
        assertEq(tokenContract.tokenURI(0), "testUri/0");

        tokenContract.proposeNewTokenUri(0, "newUri");
        assertEq(tokenContract.tokenURI(0), "testUri/0");

        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(alice, 0, Shatter.SynergyAction.Rejected, "");
        vm.prank(alice);
        tokenContract.rejectTokenUriUpdate(0);
        assertEq(tokenContract.tokenURI(0), "testUri/0");

        vm.prank(alice);
        tokenContract.shatter(numShatters);
        for (uint256 i = 0; i < numShatters; i++) {
            string memory uri = string(abi.encodePacked("testUri/", (i + 1).toString()));
            tokenContract.proposeNewTokenUri(i + 1, "newUri");
            vm.prank(alice);
            vm.expectEmit(true, true, true, true);
            emit SynergyStatusChange(alice, i + 1, Shatter.SynergyAction.Rejected, "");
            tokenContract.rejectTokenUriUpdate(i + 1);
            assertEq(tokenContract.tokenURI(i + 1), uri);
        }

        vm.prank(alice);
        tokenContract.fuse();
        assertEq(tokenContract.tokenURI(0), "testUri/0");

        tokenContract.proposeNewTokenUri(0, "newUri1");
        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(alice, 0, Shatter.SynergyAction.Rejected, "");
        tokenContract.rejectTokenUriUpdate(0);
        assertEq(tokenContract.tokenURI(0), "testUri/0");
    }

    function testRejectTokenUriFail() public {
        vm.expectRevert("ERC721: invalid token ID");
        tokenContract.rejectTokenUriUpdate(0);

        tokenContract.mint(alice, "testUri", 1, 100, 0);
        vm.expectRevert(CallerNotTokenOwner.selector);
        tokenContract.rejectTokenUriUpdate(0);

        vm.expectRevert(NoTokenUriUpdateAvailable.selector);
        vm.prank(alice);
        tokenContract.rejectTokenUriUpdate(0);
    }

    function testStoryAccessControl() public {
        assert(tokenContract.storyEnabled());

        tokenContract.setStoryEnabled(false);
        assert(!tokenContract.storyEnabled());

        vm.prank(admin);
        tokenContract.setStoryEnabled(true);
        assert(tokenContract.storyEnabled());

        vm.expectRevert();
        vm.prank(alice);
        tokenContract.setStoryEnabled(false);
    }

    function testCreatorStory(uint256 numShatters) public {
        vm.assume(numShatters > 1);
        if (numShatters > 100) numShatters = numShatters % 99 + 2;

        // token doesn't exist
        vm.expectRevert();
        tokenContract.addCreatorStory(0, "XCOPY", "I AM XCOPY");

        tokenContract.mint(alice, "testUri", 1, 100, 0);
        // test owner
        tokenContract.addCreatorStory(0, "XCOPY", "I AM XCOPY");

        // test admin
        vm.prank(admin);
        tokenContract.addCreatorStory(0, "XCOPY", "I AM XCOPY");

        // test collector
        vm.expectRevert();
        vm.prank(alice);
        tokenContract.addCreatorStory(0, "XCOPY", "I AM XCOPY");

        // shatter and test
        vm.prank(alice);
        tokenContract.shatter(numShatters);
        for (uint256 i = 1; i <= numShatters; i++) {
            tokenContract.addCreatorStory(i, "XCOPY", "I AM XCOPY");
            vm.prank(admin);
            tokenContract.addCreatorStory(i, "XCOPY", "I AM XCOPY");
            vm.expectRevert();
            vm.prank(alice);
            tokenContract.addCreatorStory(i, "XCOPY", "I AM XCOPY");
        }

        // fuse and test
        vm.prank(alice);
        tokenContract.fuse();
        tokenContract.addCreatorStory(0, "XCOPY", "I AM XCOPY");
        vm.prank(admin);
        tokenContract.addCreatorStory(0, "XCOPY", "I AM XCOPY");
        vm.expectRevert();
        vm.prank(alice);
        tokenContract.addCreatorStory(0, "XCOPY", "I AM XCOPY");
    }

    function testCollectorStory(uint256 numShatters) public {
        vm.assume(numShatters > 1);
        if (numShatters > 100) numShatters = numShatters % 99 + 2;

        // token doesn't exist
        vm.expectRevert();
        tokenContract.addStory(0, "XCOPY", "I AM XCOPY");

        tokenContract.mint(alice, "testUri", 1, 100, 0);
        // test owner
        vm.expectRevert();
        tokenContract.addStory(0, "XCOPY", "I AM XCOPY");

        // test admin
        vm.expectRevert();
        vm.prank(admin);
        tokenContract.addStory(0, "XCOPY", "I AM XCOPY");

        // test collector
        vm.prank(alice);
        tokenContract.addStory(0, "XCOPY", "I AM NOT XCOPY");

        // shatter and test
        vm.prank(alice);
        tokenContract.shatter(numShatters);
        for (uint256 i = 1; i <= numShatters; i++) {
            vm.expectRevert();
            tokenContract.addStory(i, "XCOPY", "I AM XCOPY");
            vm.expectRevert();
            vm.prank(admin);
            tokenContract.addStory(i, "XCOPY", "I AM XCOPY");
            vm.prank(alice);
            tokenContract.addStory(i, "XCOPY", "I AM NOT XCOPY");
        }

        // fuse and test
        vm.prank(alice);
        tokenContract.fuse();
        vm.expectRevert();
        tokenContract.addStory(0, "XCOPY", "I AM XCOPY");
        vm.expectRevert();
        vm.prank(admin);
        tokenContract.addStory(0, "XCOPY", "I AM XCOPY");
        vm.prank(alice);
        tokenContract.addStory(0, "XCOPY", "I AM NOT XCOPY");
    }

    function testBlockListAccessControl() public {
        address blocc = address(0xB10CC);
        // make sure only owner can change the blocklist
        tokenContract.updateBlockListRegistry(blocc);

        // not admin
        vm.expectRevert();
        vm.prank(admin);
        tokenContract.updateBlockListRegistry(address(0));

        // not alice
        vm.expectRevert();
        vm.prank(alice);
        tokenContract.updateBlockListRegistry(address(0));
    }

    function testBlockList() public {
        address blocc = address(0xB10CC);

        vm.mockCall(blocc, abi.encodeWithSelector(BlockListRegistry.getBlockListStatus.selector), abi.encode(true));

        tokenContract.updateBlockListRegistry(blocc);
        tokenContract.mint(address(this), "testUri", 1, 100, 0);

        vm.expectRevert();
        tokenContract.approve(blocc, 0);

        vm.expectRevert();
        tokenContract.setApprovalForAll(blocc, true);

        vm.expectRevert();
        tokenContract.setApprovalForAll(blocc, false);
    }

    function testSupportsInterface() public {
        assertTrue(tokenContract.supportsInterface(0x80ac58cd)); // 721
        assertTrue(tokenContract.supportsInterface(0x5b5e139f)); // 721 metadata
        assertTrue(tokenContract.supportsInterface(0x49064906)); // 4906
        assertTrue(tokenContract.supportsInterface(0x2a55205a)); // 2981
        assertTrue(tokenContract.supportsInterface(0x0d23ecb9)); // Story
        assertTrue(tokenContract.supportsInterface(0x01ffc9a7)); // 165
        assertTrue(tokenContract.supportsInterface(type(IShatter).interfaceId)); // Shatter
    }
}

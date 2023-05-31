// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {Shatter} from "tl-creator/shatter/Shatter.sol";
import {IERC2309Upgradeable} from "openzeppelin-upgradeable/interfaces/IERC2309Upgradeable.sol";

contract ShatterV1 is IERC2309Upgradeable, Test {
    event Shattered(address indexed user, uint256 indexed numShatters, uint256 indexed shatteredTime);

    event Fused(address indexed user, uint256 indexed fuseTime);

    Shatter public tokenContract;
    address public alice = address(0xcafe);
    address public bob = address(0xbeef);
    address public royaltyRecipient = address(0x1337);

    function setUp() public {
        address[] memory admins = new address[](0);
        tokenContract = new Shatter(false);
        tokenContract.initialize("Test721", "T721", royaltyRecipient, 10_00, address(this), admins, true, address(0));
    }

    function test_setUp() public view {
        assert(!tokenContract.isShattered());
        assert(!tokenContract.isFused());
        assert(tokenContract.shatters() == 0);
    }

    function test_mint() public {
        tokenContract.mint("testURI://", 1, 100, block.timestamp + 7200);
        assert(tokenContract.minShatters() == 1);
        assert(tokenContract.maxShatters() == 100);
        assert(tokenContract.shatterTime() == block.timestamp + 7200);
        assert(tokenContract.shatters() == 1);
    }

    function test_mint_fail() public {
        tokenContract.mint("testURI://", 1, 100, block.timestamp + 7200);
        vm.expectRevert("Already minted the first piece");
        tokenContract.mint("testURI://", 1, 100, block.timestamp + 7200);
        assert(tokenContract.shatters() == 1);
    }

    function test_shatter(uint256 _numShatters) public {
        vm.assume(_numShatters < 100 && _numShatters > 0);

        tokenContract.mint("testURI://", 1, 100, block.timestamp + 7200);

        vm.warp(block.timestamp + 7200);

        if (_numShatters > 1) {
            vm.expectEmit(true, true, true, true);
            emit ConsecutiveTransfer(1, _numShatters, address(0), address(this));

            vm.expectEmit(true, true, true, true);
            emit Shattered(address(this), _numShatters, block.timestamp);
        } else {
            vm.expectEmit(true, true, true, true);
            emit Shattered(address(this), _numShatters, block.timestamp);

            vm.expectEmit(true, true, true, true);
            emit Fused(address(this), block.timestamp);
        }

        tokenContract.shatter(_numShatters);
        assert(tokenContract.shatters() == _numShatters);
        assert(tokenContract.isShattered());
        assert(tokenContract.balanceOf(address(this)) == _numShatters);

        if (_numShatters == 1) {
            assert(tokenContract.ownerOf(0) == address(this));
            assert(tokenContract.isFused());
        } else {
            vm.expectRevert("ERC721: invalid token ID");
            tokenContract.ownerOf(0);
        }

        for (uint256 i = 1; i < _numShatters; i++) {
            assert(tokenContract.ownerOf(i) == address(this));
        }
    }

    function test_shatter_fail() public {
        tokenContract.mint("testURI://", 1, 100, block.timestamp + 7200);

        vm.expectRevert("Cannot shatter prior to shatterTime");
        tokenContract.shatter(1);

        vm.prank(bob);
        vm.expectRevert("Caller is not owner of token 0");
        tokenContract.shatter(1);

        vm.warp(block.timestamp + 7200);

        vm.expectRevert("Cannot set number of editions above max or below the min");
        tokenContract.shatter(0);
        vm.expectRevert("Cannot set number of editions above max or below the min");
        tokenContract.shatter(101);

        tokenContract.shatter(50);
        vm.expectRevert("Already is shattered");
        tokenContract.shatter(1);
    }

    function test_fuse() public {
        tokenContract.mint("testURI://", 1, 100, block.timestamp + 7200);

        vm.warp(block.timestamp + 7200);

        tokenContract.shatter(100);

        assert(tokenContract.isShattered());
        assert(!tokenContract.isFused());

        tokenContract.fuse();
    }

    function test_fuse_fail() public {
        tokenContract.mint("testURI://", 1, 100, block.timestamp + 7200);

        vm.warp(block.timestamp + 7200);

        vm.expectRevert();
        tokenContract.fuse();

        tokenContract.shatter(100);

        assert(tokenContract.isShattered());
        assert(!tokenContract.isFused());

        tokenContract.transferFrom(address(this), address(0xbeef), 5);
        assert(tokenContract.ownerOf(5) == address(0xbeef));
        assert(tokenContract.balanceOf(address(0xbeef)) == 1);

        vm.expectRevert();
        tokenContract.fuse();

        vm.prank(address(0xbeef));
        tokenContract.transferFrom(address(0xbeef), address(this), 5);
        assert(tokenContract.balanceOf(address(0xbeef)) == 0);

        tokenContract.fuse();

        vm.expectRevert();
        tokenContract.fuse();
    }
}

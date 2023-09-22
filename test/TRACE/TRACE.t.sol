// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {ERC721TL} from "tl-creator-contracts/core/ERC721TL.sol";
import {TRACE} from "tl-creator-contracts/TRACE/TRACE.sol";
import {TRACERSRegistry} from "tl-creator-contracts/TRACE/TRACERSRegistry.sol";
import {TRACESigUtils} from "../utils/TRACESigUtils.sol";

contract TRACETest is Test {
    event Story(uint256 indexed tokenId, address indexed senderAddress, string senderName, string story);

    error InvalidSignature();
    error Unauthorized();
    error NotCreatorOrAdmin();

    TRACE public trace;
    address public creator = makeAddr("creator");
    address public creatorAdmin = makeAddr("admin");
    uint256 public chipPrivateKey = 0x007;
    address public chip;
    address public agent = makeAddr("agent");

    TRACESigUtils public sigUtils;

    TRACERSRegistry public registry;

    function setUp() public {
        // create registry
        registry = new TRACERSRegistry();
        TRACERSRegistry.RegisteredAgent memory ra = TRACERSRegistry.RegisteredAgent(true, 0, "agent");
        registry.setRegisteredAgent(agent, ra);

        // chip
        chip = vm.addr(chipPrivateKey);

        // create implementation nft
        address implementation = address(new ERC721TL(true));

        // create TRACE
        address[] memory admins = new address[](1);
        admins[0] = creatorAdmin;
        trace =
        new TRACE(implementation, "Test TRACE", "TRACE", creator, 1000, creator, admins, true, address(0), address(registry));

        // mint token
        vm.prank(creator);
        ERC721TL(address(trace)).mint(chip, "https://arweave.net/tx_id");

        // set TRACE registry
        vm.prank(creator);
        trace.setTRACERSRegistry(address(registry));

        // sig utils
        sigUtils = new TRACESigUtils("Test TRACE", "1", address(trace));
    }

    /// @dev test setup
    function test_setUp() public view {
        assert(trace.getTRACERSRegistry() == address(registry));
    }

    /// @dev test `setDCOARegistry`
    function test_setTRACERSRegistry(address hacker, address newRegistryOne, address newRegistryTwo) public {
        vm.assume(hacker != creator && hacker != creatorAdmin);

        // expect revert from hacker
        vm.expectRevert(NotCreatorOrAdmin.selector);
        vm.prank(hacker);
        trace.setTRACERSRegistry(newRegistryOne);

        // expect creator pass
        vm.prank(creator);
        trace.setTRACERSRegistry(newRegistryOne);
        assert(trace.getTRACERSRegistry() == newRegistryOne);

        // expect creator admin pass
        vm.prank(creatorAdmin);
        trace.setTRACERSRegistry(newRegistryTwo);
        assert(trace.getTRACERSRegistry() == newRegistryTwo);
    }

    /// @dev test `addVerifiedStory`
    function test_addVerifiedStory(uint256 badSignerPrivateKey, address notAgent) public {
        vm.assume(
            badSignerPrivateKey != chipPrivateKey && badSignerPrivateKey != 0
                && badSignerPrivateKey < 115792089237316195423570985008687907852837564279074904382605163141518161494337
        );
        vm.assume(notAgent != agent);

        uint256 nonce = trace.getTokenNonce(1);

        // sender not registered agent fails
        bytes32 digest = sigUtils.getTypedDataHash(1, nonce, notAgent, "This is a story!");
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(chipPrivateKey, digest);
        bytes memory sig = abi.encodePacked(r, s, v);
        vm.expectRevert(Unauthorized.selector);
        vm.prank(notAgent);
        trace.addVerifiedStory(1, "This is a story!", sig);

        // registry is an EOA fails
        vm.prank(creator);
        trace.setTRACERSRegistry(address(0xC0FFEE));

        vm.expectRevert(Unauthorized.selector);
        vm.prank(notAgent);
        trace.addVerifiedStory(1, "This is a story!", sig);

        vm.prank(creator);
        trace.setTRACERSRegistry(address(registry));

        // bad signer fails
        digest = sigUtils.getTypedDataHash(1, nonce, agent, "This is a story!");
        (v, r, s) = vm.sign(badSignerPrivateKey, digest);
        sig = abi.encodePacked(r, s, v);
        vm.expectRevert(InvalidSignature.selector);
        vm.prank(agent);
        trace.addVerifiedStory(1, "This is a story!", sig);

        // non-existent token fails
        digest = sigUtils.getTypedDataHash(2, nonce, agent, "This is a story!");
        (v, r, s) = vm.sign(chipPrivateKey, digest);
        sig = abi.encodePacked(r, s, v);
        vm.expectRevert(InvalidSignature.selector);
        vm.prank(agent);
        trace.addVerifiedStory(1, "This is a story!", sig);

        // right signer + registered agent passes
        digest = sigUtils.getTypedDataHash(1, nonce, agent, "This is a story!");
        (v, r, s) = vm.sign(chipPrivateKey, digest);
        sig = abi.encodePacked(r, s, v);
        vm.expectEmit(true, true, false, true);
        emit Story(1, agent, "agent", "This is a story!");
        vm.prank(agent);
        trace.addVerifiedStory(1, "This is a story!", sig);
        assert(trace.getTokenNonce(1) == nonce + 1);

        // fails with replay
        vm.expectRevert(InvalidSignature.selector);
        vm.prank(agent);
        trace.addVerifiedStory(1, "This is a story!", sig);
    }

    /// @dev test different cDOA contract/712 names
    function test_addVerifiedStory_diffNames(string memory name) public {
        // create implementation nft
        address implementation = address(new ERC721TL(true));

        // trace
        address[] memory admins = new address[](1);
        admins[0] = creatorAdmin;
        trace =
            new TRACE(implementation, name, "COA", creator, 1000, creator, admins, true, address(0), address(registry));

        // mint token
        vm.prank(creator);
        ERC721TL(address(trace)).mint(chip, "https://arweave.net/tx_id");

        // set TRACE registry
        vm.prank(creator);
        trace.setTRACERSRegistry(address(registry));

        // sig utils
        sigUtils = new TRACESigUtils(name, "1", address(trace));

        // get nonce
        uint256 nonce = trace.getTokenNonce(1);

        // add story
        bytes32 digest = sigUtils.getTypedDataHash(1, nonce, agent, "This is a story!");
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(chipPrivateKey, digest);
        bytes memory sig = abi.encodePacked(r, s, v);
        vm.expectEmit(true, true, false, true);
        emit Story(1, agent, "agent", "This is a story!");
        vm.prank(agent);
        trace.addVerifiedStory(1, "This is a story!", sig);
        assert(trace.getTokenNonce(1) == nonce + 1);
    }
}

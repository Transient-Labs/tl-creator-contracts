// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {ERC721TL} from "tl-creator-contracts/core/ERC721TL.sol";
import {dCOA} from "tl-creator-contracts/dCOA/dCOA.sol";
import {dCOARegistry} from "tl-creator-contracts/dCOA/dCOARegistry.sol";
import {dCOASigUtils} from "../utils/dCOASigUtils.sol";

contract dCOATest is Test {
    event Story(uint256 indexed tokenId, address indexed senderAddress, string senderName, string story);

    error InvalidSignature();
    error Unauthorized();
    error NotCreatorOrAdmin();

    dCOA public coa;
    address public creator = makeAddr("creator");
    address public creatorAdmin = makeAddr("admin");
    uint256 public chipPrivateKey = 0x007;
    address public chip;
    address public agent = makeAddr("agent");

    dCOASigUtils public sigUtils;

    dCOARegistry public registry;

    function setUp() public {
        // create registry
        registry = new dCOARegistry();
        dCOARegistry.RegisteredAgent memory ra = dCOARegistry.RegisteredAgent(true, 0, "agent");
        registry.setRegisteredAgent(agent, ra);

        // chip
        chip = vm.addr(chipPrivateKey);

        // create implementation nft
        address implementation = address(new ERC721TL(true));

        // create dCOA
        address[] memory admins = new address[](1);
        admins[0] = creatorAdmin;
        coa = new dCOA(implementation, "Test dCOA", "COA", creator, 1000, creator, admins, true, address(0));

        // mint token
        vm.prank(creator);
        ERC721TL(address(coa)).mint(chip, "https://arweave.net/tx_id");

        // set dCOA registry
        vm.prank(creator);
        coa.setDCOARegistry(address(registry));

        // sig utils
        sigUtils = new dCOASigUtils("Test dCOA", "1", address(coa));
    }

    /// @dev test `setDCOARegistry`
    function test_setDCOARegistry(address hacker, address newRegistryOne, address newRegistryTwo) public {
        vm.assume(hacker != creator && hacker != creatorAdmin);

        // expect revert from hacker
        vm.expectRevert(NotCreatorOrAdmin.selector);
        vm.prank(hacker);
        coa.setDCOARegistry(newRegistryOne);

        // expect creator pass
        vm.prank(creator);
        coa.setDCOARegistry(newRegistryOne);
        assert(coa.getDCOARegistry() == newRegistryOne);

        // expect creator admin pass
        vm.prank(creatorAdmin);
        coa.setDCOARegistry(newRegistryTwo);
        assert(coa.getDCOARegistry() == newRegistryTwo);
    }

    /// @dev test `addVerifiedStory`
    function test_addVerifiedStory(uint256 badSignerPrivateKey, address notAgent) public {
        vm.assume(
            badSignerPrivateKey != chipPrivateKey && badSignerPrivateKey != 0
                && badSignerPrivateKey < 115792089237316195423570985008687907852837564279074904382605163141518161494337
        );
        vm.assume(notAgent != agent);

        uint256 nonce = coa.getTokenNonce(1);

        // sender not registered agent fails
        bytes32 digest = sigUtils.getTypedDataHash(1, nonce, notAgent, "This is a story!");
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(chipPrivateKey, digest);
        bytes memory sig = abi.encodePacked(r, s, v);
        vm.expectRevert(Unauthorized.selector);
        vm.prank(notAgent);
        coa.addVerifiedStory(1, "This is a story!", sig);

        // registry is an EOA fails
        vm.prank(creator);
        coa.setDCOARegistry(address(0xC0FFEE));

        vm.expectRevert(Unauthorized.selector);
        vm.prank(notAgent);
        coa.addVerifiedStory(1, "This is a story!", sig);

        vm.prank(creator);
        coa.setDCOARegistry(address(registry));

        // bad signer fails
        digest = sigUtils.getTypedDataHash(1, nonce, agent, "This is a story!");
        (v, r, s) = vm.sign(badSignerPrivateKey, digest);
        sig = abi.encodePacked(r, s, v);
        vm.expectRevert(InvalidSignature.selector);
        vm.prank(agent);
        coa.addVerifiedStory(1, "This is a story!", sig);

        // non-existent token fails
        digest = sigUtils.getTypedDataHash(2, nonce, agent, "This is a story!");
        (v, r, s) = vm.sign(chipPrivateKey, digest);
        sig = abi.encodePacked(r, s, v);
        vm.expectRevert(InvalidSignature.selector);
        vm.prank(agent);
        coa.addVerifiedStory(1, "This is a story!", sig);

        // right signer + registered agent passes
        digest = sigUtils.getTypedDataHash(1, nonce, agent, "This is a story!");
        (v, r, s) = vm.sign(chipPrivateKey, digest);
        sig = abi.encodePacked(r, s, v);
        vm.expectEmit(true, true, false, true);
        emit Story(1, agent, "agent", "This is a story!");
        vm.prank(agent);
        coa.addVerifiedStory(1, "This is a story!", sig);
        assert(coa.getTokenNonce(1) == nonce + 1);

        // fails with replay
        vm.expectRevert(InvalidSignature.selector);
        vm.prank(agent);
        coa.addVerifiedStory(1, "This is a story!", sig);
    }

    /// @dev test different cDOA contract/712 names
    function test_addVerifiedStory_diffNames(string memory name) public {
        // create implementation nft
        address implementation = address(new ERC721TL(true));

        // coa
        address[] memory admins = new address[](1);
        admins[0] = creatorAdmin;
        coa = new dCOA(implementation, name, "COA", creator, 1000, creator, admins, true, address(0));

        // mint token
        vm.prank(creator);
        ERC721TL(address(coa)).mint(chip, "https://arweave.net/tx_id");

        // set dCOA registry
        vm.prank(creator);
        coa.setDCOARegistry(address(registry));

        // sig utils
        sigUtils = new dCOASigUtils(name, "1", address(coa));

        // get nonce
        uint256 nonce = coa.getTokenNonce(1);

        // add story
        bytes32 digest = sigUtils.getTypedDataHash(1, nonce, agent, "This is a story!");
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(chipPrivateKey, digest);
        bytes memory sig = abi.encodePacked(r, s, v);
        vm.expectEmit(true, true, false, true);
        emit Story(1, agent, "agent", "This is a story!");
        vm.prank(agent);
        coa.addVerifiedStory(1, "This is a story!", sig);
        assert(coa.getTokenNonce(1) == nonce + 1);
    }
}

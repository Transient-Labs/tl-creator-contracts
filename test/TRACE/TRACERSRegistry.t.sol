// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {ERC721TL} from "tl-creator-contracts/core/ERC721TL.sol";
import {TRACERSRegistry} from "tl-creator-contracts/TRACE/TRACERSRegistry.sol";

contract TRACERSRegistryTest is Test, TRACERSRegistry {
    ERC721TL public nft;
    address public nftOwner = address(0x404);
    address public nftAdmin = address(0xC0FFEE);

    TRACERSRegistry public registry;
    address public tl = makeAddr("build different.");

    function setUp() public {
        // create dCOARegistry
        vm.prank(tl);
        registry = new TRACERSRegistry();

        // create nft contract
        address[] memory admins = new address[](1);
        admins[0] = nftAdmin;
        vm.startPrank(nftOwner);
        nft = new ERC721TL(false);
        nft.initialize("Test NFT", "TEST", nftOwner, 404, nftOwner, admins, true, address(0));
        vm.stopPrank();
    }

    /// @dev test addRegisteredAgent
    function test_addRegisteredAgent(
        address hacker,
        address agent,
        bool isPermanent,
        uint128 numberOfStories,
        string memory name
    ) public {
        vm.assume(hacker != agent);
        vm.assume(hacker != tl);
        vm.assume(agent != address(0));

        RegisteredAgent memory registeredAgent = RegisteredAgent(isPermanent, numberOfStories, name);

        RegisteredAgent memory expectedRegisteredAgent = RegisteredAgent(isPermanent, 0, name);

        // revert for hacker
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(hacker);
        registry.setRegisteredAgent(agent, registeredAgent);

        // registry owner allowed
        vm.expectEmit(true, true, false, true);
        emit RegisteredAgentUpdate(tl, agent, expectedRegisteredAgent);
        vm.prank(tl);
        registry.setRegisteredAgent(agent, registeredAgent);

        RegisteredAgent memory returnedRegisteredAgent = registry.getRegisteredAgent(address(0), agent);
        assert(returnedRegisteredAgent.isPermanent == isPermanent);
        assert(returnedRegisteredAgent.numberOfStories == 0);
        assert(keccak256(bytes(returnedRegisteredAgent.name)) == keccak256(bytes(name)));

        // test `isRegisteredAgent`
        bool tf;
        string memory n;
        vm.prank(address(nft));
        (tf, n) = registry.isRegisteredAgent(agent);
        assert(tf == isPermanent);
        if (isPermanent) {
            assert(keccak256(bytes(n)) == keccak256((bytes(name))));
        } else {
            assert(keccak256(bytes(n)) == keccak256((bytes(""))));
        }
    }

    /// @dev test addRegisteredAgentOverride
    function test_addRegisteredAgentOverride(
        address hacker,
        address agent,
        bool isPermanent,
        uint128 numberOfStories,
        string memory name
    ) public {
        vm.assume(hacker != agent);
        vm.assume(hacker != nftOwner && hacker != nftAdmin);
        vm.assume(agent != address(0));

        RegisteredAgent memory registeredAgent = RegisteredAgent(isPermanent, numberOfStories, name);

        // revert for hacker
        vm.expectRevert(NotCreatorOrAdmin.selector);
        vm.prank(hacker);
        registry.setRegisteredAgentOverride(address(nft), agent, registeredAgent);

        // nft owner allowed
        vm.expectEmit(true, true, true, true);
        emit RegisteredAgentOverrideUpdate(nftOwner, address(nft), agent, registeredAgent);
        vm.prank(nftOwner);
        registry.setRegisteredAgentOverride(address(nft), agent, registeredAgent);

        RegisteredAgent memory returnedRegisteredAgent = registry.getRegisteredAgent(address(nft), agent);
        assert(returnedRegisteredAgent.isPermanent == isPermanent);
        assert(returnedRegisteredAgent.numberOfStories == numberOfStories);
        if (isPermanent || numberOfStories > 0) {
            assert(keccak256(bytes(returnedRegisteredAgent.name)) == keccak256(bytes(name)));
        }

        // test `isRegisteredAgent`
        bool tf;
        string memory n;
        vm.prank(address(nft));
        (tf, n) = registry.isRegisteredAgent(agent);
        assert(tf == (isPermanent || numberOfStories > 0));
        if (tf) {
            assert(keccak256(bytes(n)) == keccak256((bytes(name))));
        } else {
            assert(keccak256(bytes(n)) == keccak256((bytes(""))));
        }
        returnedRegisteredAgent = registry.getRegisteredAgent(address(nft), agent);
        if (numberOfStories > 0 && !isPermanent) {
            assert(returnedRegisteredAgent.numberOfStories == numberOfStories - 1);
        }

        // invert for admin allowed
        registeredAgent.isPermanent = !isPermanent;
        vm.expectEmit(true, true, true, true);
        emit RegisteredAgentOverrideUpdate(nftAdmin, address(nft), agent, registeredAgent);
        vm.prank(nftAdmin);
        registry.setRegisteredAgentOverride(address(nft), agent, registeredAgent);

        returnedRegisteredAgent = registry.getRegisteredAgent(address(nft), agent);
        assert(returnedRegisteredAgent.isPermanent == !isPermanent);
        assert(returnedRegisteredAgent.numberOfStories == numberOfStories);
        if (!isPermanent || numberOfStories > 0) {
            assert(keccak256(bytes(returnedRegisteredAgent.name)) == keccak256(bytes(name)));
        }

        // test `isRegisteredAgent`
        vm.prank(address(nft));
        (tf, n) = registry.isRegisteredAgent(agent);
        assert(tf == (!isPermanent || numberOfStories > 0));
        if (tf) {
            assert(keccak256(bytes(n)) == keccak256((bytes(name))));
        } else {
            assert(keccak256(bytes(n)) == keccak256((bytes(""))));
        }
        returnedRegisteredAgent = registry.getRegisteredAgent(address(nft), agent);
        if (numberOfStories > 0 && !!isPermanent) {
            assert(returnedRegisteredAgent.numberOfStories == numberOfStories - 1);
        }
    }
}

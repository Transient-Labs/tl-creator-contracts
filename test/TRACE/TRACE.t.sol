// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {
    TRACE,
    EmptyTokenURI,
    MintToZeroAddress,
    BatchSizeTooSmall,
    TokenDoesntExist,
    AirdropTooFewAddresses,
    CallerNotApprovedOrOwner,
    CallerNotTokenOwner
} from "tl-creator-contracts/TRACE/TRACE.sol";
import {TRACERSRegistry} from "tl-creator-contracts/TRACE/TRACERSRegistry.sol";
import {NotRoleOrOwner} from "tl-sol-tools/upgradeable/access/OwnableAccessControlUpgradeable.sol";
import {TRACESigUtils} from "../utils/TRACESigUtils.sol";
import {Strings} from "openzeppelin/utils/Strings.sol";

contract TRACETest is Test {
    using Strings for address;
    using Strings for uint256;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event RoleChange(address indexed from, address indexed user, bool indexed approved, bytes32 role);
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event MetadataUpdate(uint256 tokenId);
    event CreatorStory(uint256 indexed tokenId, address indexed creatorAddress, string creatorName, string story);
    event Story(uint256 indexed tokenId, address indexed senderAddress, string senderName, string story);

    error InvalidSignature();
    error Unauthorized();
    error NotCreatorOrAdmin();

    TRACE public trace;
    address public royaltyRecipient = makeAddr("royaltyRecipient");
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

        // create TRACE
        address[] memory admins = new address[](0);
        trace = new TRACE(false);
        trace.initialize("Test TRACE", "TRACE", royaltyRecipient, 1000, address(this), admins, address(registry));

        // sig utils
        sigUtils = new TRACESigUtils("Test TRACE", "1", address(trace));
    }

    /// @notice Initialization Tests
    function testInitialization(
        string memory name,
        string memory symbol,
        address defaultRoyaltyRecipient,
        uint256 defaultRoyaltyPercentage,
        address initOwner,
        address[] memory admins,
        address tracersRegistry
    ) public {
        // ensure royalty guards enabled
        vm.assume(defaultRoyaltyRecipient != address(0));
        if (defaultRoyaltyPercentage >= 10_000) {
            defaultRoyaltyPercentage = defaultRoyaltyPercentage % 10_000;
        }

        // create contract
        trace = new TRACE(false);
        // initialize and verify events thrown (order matters)
        vm.expectEmit(true, true, false, false);
        emit OwnershipTransferred(address(0), address(this));
        vm.expectEmit(true, true, false, false);
        emit OwnershipTransferred(address(this), initOwner);
        for (uint256 i = 0; i < admins.length; i++) {
            vm.expectEmit(true, true, true, true);
            emit RoleChange(address(this), admins[i], true, trace.ADMIN_ROLE());
        }
        trace.initialize(
            name, symbol, defaultRoyaltyRecipient, defaultRoyaltyPercentage, initOwner, admins, tracersRegistry
        );
        assertEq(trace.name(), name);
        assertEq(trace.symbol(), symbol);
        (address recp, uint256 amt) = trace.royaltyInfo(1, 10000);
        assertEq(recp, defaultRoyaltyRecipient);
        assertEq(amt, defaultRoyaltyPercentage);
        assertEq(trace.owner(), initOwner);
        for (uint256 i = 0; i < admins.length; i++) {
            assertTrue(trace.hasRole(trace.ADMIN_ROLE(), admins[i]));
        }
        assertEq(trace.storyEnabled(), true);

        // can't initialize again
        vm.expectRevert(bytes("Initializable: contract is already initialized"));
        trace.initialize(
            name, symbol, defaultRoyaltyRecipient, defaultRoyaltyPercentage, initOwner, admins, tracersRegistry
        );
    }

    /// @notice test non-existent token ownership
    function testNonExistentTokens(uint8 mintNum, uint8 numTokens) public {
        for (uint256 i = 0; i < mintNum; i++) {
            trace.mint(address(this), "uri");
        }
        uint256 nonexistentTokenId = uint256(mintNum) + uint256(numTokens) + 1;
        vm.expectRevert(abi.encodePacked("ERC721: invalid token ID"));
        trace.ownerOf(nonexistentTokenId);
        vm.expectRevert(TokenDoesntExist.selector);
        trace.tokenURI(nonexistentTokenId);
    }

    /// @notice test mint
    // - access control ✅
    // - proper recipient ✅
    // - transfer event ✅
    // - proper token id ✅
    // - ownership ✅
    // - balance ✅
    // - transfer to another address ✅
    // - safe transfer to another address ✅
    // - token uri ✅

    function testMintCustomErrors() public {
        vm.expectRevert(EmptyTokenURI.selector);
        trace.mint(address(this), "");
    }

    function testMintAccessControl(address user) public {
        vm.assume(user != address(this));
        vm.assume(user != address(0));
        // ensure user can't call the mint function
        vm.startPrank(user, user);
        vm.expectRevert(abi.encodeWithSelector(NotRoleOrOwner.selector, trace.ADMIN_ROLE()));
        trace.mint(address(this), "uriOne");
        vm.stopPrank();

        // grant admin access and ensure that the user can call the mint function
        address[] memory admins = new address[](1);
        admins[0] = user;
        trace.setRole(trace.ADMIN_ROLE(), admins, true);
        vm.startPrank(user, user);
        vm.expectEmit(true, true, true, false);
        emit Transfer(address(0), address(this), 1);
        trace.mint(address(this), "uriOne");
        vm.stopPrank();
        assertEq(trace.balanceOf(address(this)), 1);
        assertEq(trace.ownerOf(1), address(this));
        assertEq(trace.tokenURI(1), "uriOne");

        // revoke admin access and ensure that the user can't call the mint function
        trace.setRole(trace.ADMIN_ROLE(), admins, false);
        vm.startPrank(user, user);
        vm.expectRevert(abi.encodeWithSelector(NotRoleOrOwner.selector, trace.ADMIN_ROLE()));
        trace.mint(address(this), "uriOne");
        vm.stopPrank();

    }

    function testMint(uint16 tokenId, address recipient) public {
        vm.assume(tokenId != 0);
        vm.assume(recipient != address(0));
        if (tokenId > 1000) {
            tokenId = tokenId % 1000 + 1; // map to 1000
        }
        for (uint256 i = 1; i <= tokenId; i++) {
            string memory uri = string(abi.encodePacked("uri_", i.toString()));
            vm.expectEmit(true, true, true, false);
            emit Transfer(address(0), recipient, i);
            trace.mint(recipient, uri);
            assertEq(trace.balanceOf(recipient), i);
            assertEq(trace.ownerOf(i), recipient);
            assertEq(trace.tokenURI(i), uri);
        }
    }

    function testMintTokenRoyalty(uint16 tokenId, address recipient, address royaltyAddress, uint16 royaltyPercent)
        public
    {
        vm.assume(tokenId != 0);
        vm.assume(recipient != address(0));
        vm.assume(royaltyAddress != royaltyRecipient);
        vm.assume(royaltyAddress != address(0));
        if (royaltyPercent >= 10_000) royaltyPercent = royaltyPercent % 10_000;
        if (tokenId > 1000) {
            tokenId = tokenId % 1000 + 1; // map to 1000
        }
        for (uint256 i = 1; i <= tokenId; i++) {
            string memory uri = string(abi.encodePacked("uri_", i.toString()));
            vm.expectEmit(true, true, true, false);
            emit Transfer(address(0), recipient, i);
            trace.mint(recipient, uri, royaltyAddress, royaltyPercent);
            assertEq(trace.balanceOf(recipient), i);
            assertEq(trace.ownerOf(i), recipient);
            assertEq(trace.tokenURI(i), uri);
            (address recp, uint256 amt) = trace.royaltyInfo(i, 10_000);
            assertEq(recp, royaltyAddress);
            assertEq(amt, royaltyPercent);
        }
    }

    function testMintTransfers(uint16 tokenId, address recipient, address secondRecipient) public {
        vm.assume(recipient != address(0));
        vm.assume(secondRecipient != address(0));
        vm.assume(recipient != secondRecipient);
        vm.assume(recipient.code.length == 0);
        vm.assume(secondRecipient.code.length == 0);
        vm.assume(tokenId != 0);
        if (tokenId > 1000) {
            tokenId = tokenId % 1000 + 1; // map to 1000
        }
        for (uint256 i = 1; i <= tokenId; i++) {
            // mint
            trace.mint(address(this), "uri");
            // transfer to recipient with transferFrom
            vm.expectEmit(true, true, true, false);
            emit Transfer(address(this), recipient, i);
            trace.transferFrom(address(this), recipient, i);
            assertEq(trace.balanceOf(recipient), 1);
            assertEq(trace.ownerOf(i), recipient);
            // transfer to second recipient with safeTransferFrom
            vm.startPrank(recipient, recipient);
            vm.expectEmit(true, true, true, false);
            emit Transfer(recipient, secondRecipient, i);
            trace.safeTransferFrom(recipient, secondRecipient, i);
            assertEq(trace.balanceOf(secondRecipient), i);
            assertEq(trace.ownerOf(i), secondRecipient);
            vm.stopPrank();
        }
    }

    /// @notice test airdrop
    // - access control ✅
    // - proper recipients ✅
    // - transfer events ✅
    // - proper token ids ✅
    // - ownership ✅
    // - balances ✅
    // - transfer to another address ✅
    // - safe transfer to another address ✅
    // - token uris ✅

    function testAirdropCustomErrors() public {
        address[] memory addresses = new address[](1);
        addresses[0] = address(1);
        vm.expectRevert(EmptyTokenURI.selector);
        trace.airdrop(addresses, "");

        vm.expectRevert(AirdropTooFewAddresses.selector);
        trace.airdrop(addresses, "baseUri");
    }

    function testAirdropAccessControl(address user) public {
        vm.assume(user != address(this));
        vm.assume(user != address(0));
        address[] memory addresses = new address[](2);
        addresses[0] = address(1);
        addresses[1] = address(2);
        // ensure user can't call the airdrop function
        vm.startPrank(user, user);
        vm.expectRevert(abi.encodeWithSelector(NotRoleOrOwner.selector, trace.ADMIN_ROLE()));
        trace.airdrop(addresses, "baseUri");
        vm.stopPrank();

        // grant admin access and ensure that the user can call the airdrop function
        address[] memory admins = new address[](1);
        admins[0] = user;
        trace.setRole(trace.ADMIN_ROLE(), admins, true);
        vm.startPrank(user, user);
        vm.expectEmit(true, true, true, false);
        emit Transfer(address(0), address(1), 1);
        vm.expectEmit(true, true, true, false);
        emit Transfer(address(0), address(2), 2);
        trace.airdrop(addresses, "baseUri");
        vm.stopPrank();
        assertEq(trace.balanceOf(address(1)), 1);
        assertEq(trace.balanceOf(address(2)), 1);
        assertEq(trace.ownerOf(1), address(1));
        assertEq(trace.ownerOf(2), address(2));
        assertEq(trace.tokenURI(1), "baseUri/0");
        assertEq(trace.tokenURI(2), "baseUri/1");

        // revoke admin access and ensure that the user can't call the airdrop function
        trace.setRole(trace.ADMIN_ROLE(), admins, false);
        vm.startPrank(user, user);
        vm.expectRevert(abi.encodeWithSelector(NotRoleOrOwner.selector, trace.ADMIN_ROLE()));
        trace.airdrop(addresses, "baseUri");
        vm.stopPrank();

    }

    function testAirdrop(uint16 numAddresses) public {
        vm.assume(numAddresses > 1);
        if (numAddresses > 1000) {
            numAddresses = numAddresses % 999 + 2; // map to 300
        }
        address[] memory addresses = new address[](numAddresses);
        for (uint256 i = 0; i < numAddresses; i++) {
            addresses[i] = makeAddr(i.toString());
        }
        for (uint256 i = 1; i <= numAddresses; i++) {
            vm.expectEmit(true, true, true, false);
            emit Transfer(address(0), addresses[i - 1], i);
        }
        trace.airdrop(addresses, "baseUri");
        for (uint256 i = 1; i <= numAddresses; i++) {
            string memory uri = string(abi.encodePacked("baseUri/", (i - 1).toString()));
            assertEq(trace.balanceOf(addresses[i - 1]), 1);
            assertEq(trace.ownerOf(i), addresses[i - 1]);
            assertEq(trace.tokenURI(i), uri);
        }
    }

    function testAirdropTransfers(uint16 numAddresses, address recipient) public {
        vm.assume(numAddresses > 1);
        vm.assume(recipient != address(0));
        vm.assume(recipient.code.length == 0);
        if (numAddresses > 1000) {
            numAddresses = numAddresses % 999 + 2; // map to 300
        }
        address[] memory addresses = new address[](numAddresses);
        for (uint256 i = 0; i < numAddresses; i++) {
            if (makeAddr(i.toString()) == recipient) {
                addresses[i] = makeAddr("hello");
            } else {
                addresses[i] = makeAddr(i.toString());
            }
        }
        trace.airdrop(addresses, "baseUri");
        for (uint256 i = 1; i < numAddresses / 2; i++) {
            vm.startPrank(addresses[i - 1], addresses[i - 1]);
            vm.expectEmit(true, true, true, false);
            emit Transfer(addresses[i - 1], recipient, i);
            trace.transferFrom(addresses[i - 1], recipient, i);
            vm.stopPrank();
            assertEq(trace.balanceOf(recipient), i);
            assertEq(trace.balanceOf(addresses[i - 1]), 0);
            assertEq(trace.ownerOf(i), recipient);
        }
        for (uint256 i = numAddresses / 2; i <= numAddresses; i++) {
            vm.startPrank(addresses[i - 1], addresses[i - 1]);
            vm.expectEmit(true, true, true, false);
            emit Transfer(addresses[i - 1], recipient, i);
            trace.safeTransferFrom(addresses[i - 1], recipient, i);
            vm.stopPrank();
            assertEq(trace.balanceOf(recipient), i);
            assertEq(trace.balanceOf(addresses[i - 1]), 0);
            assertEq(trace.ownerOf(i), recipient);
        }
    }

    /// @notice test TRACE functions
    // - access control ✅
    // - transfer tokens 
    // - set tracers registry ✅
    // - add verified story

    function testTransferToken(address user, uint256 numAddresses) public {
        vm.assume(user != address(this) && user != address(0));
        address[] memory users = new address[](1);
        users[0] = user;

        vm.assume(numAddresses > 1);
        if (numAddresses > 1000) {
            numAddresses = numAddresses % 999 + 2; // map to 300
        }
        address[] memory addresses = new address[](numAddresses);
        for (uint256 i = 0; i < numAddresses; i++) {
            addresses[i] = makeAddr(i.toString());
        }

        // regular mint
        trace.mint(address(1), "hiii");
        assert(trace.ownerOf(1) == address(1));

        // airdrop
        trace.airdrop(addresses, "baseUri");
        for (uint256 i = 2; i <= numAddresses + 1; i++) {
            assertEq(trace.ownerOf(i), addresses[i-2]);
        }

        // transfer tokens
        vm.expectEmit(true, true, true, false);
        emit Transfer(address(1), address(this), 1);
        trace.transferToken(address(1), address(this), 1);
        assert(trace.ownerOf(1) == address(this));

        for (uint256 i = 2; i <= numAddresses + 1; i++) {
            vm.expectEmit(true, true, true, false);
            emit Transfer(addresses[i-2], address(this), i);
            trace.transferToken(addresses[i-2], address(this), i);
            assert(trace.ownerOf(i) == address(this));
        }
    }

    function testSetTracersRegistry(address user, address newRegistryOne, address newRegistryTwo) public {
        vm.assume(user != address(this));
        address[] memory users = new address[](1);
        users[0] = user;

        // expect revert from hacker
        vm.expectRevert();
        vm.prank(user);
        trace.setTracersRegistry(newRegistryOne);

        // expect creator pass
        trace.setTracersRegistry(newRegistryOne);
        assert(address(trace.tracersRegistry()) == newRegistryOne);

        // set admin
        trace.setRole(trace.ADMIN_ROLE(), users, true);

        // expect admin pass
        vm.prank(user);
        trace.setTracersRegistry(newRegistryTwo);
        assert(address(trace.tracersRegistry()) == newRegistryTwo);
    }

    function testAddVerifiedStoryRegularMint(uint256 badSignerPrivateKey, address notAgent) public {
        vm.assume(
            badSignerPrivateKey != chipPrivateKey && badSignerPrivateKey != 0
                && badSignerPrivateKey < 115792089237316195423570985008687907852837564279074904382605163141518161494337
        );
        vm.assume(notAgent != agent);

        uint256 nonce = trace.getTokenNonce(1);

        // mint
        trace.mint(chip, "https://arweave.net/tx_id");

        // sender not registered agent fails
        bytes32 digest = sigUtils.getTypedDataHash(1, nonce, notAgent, "This is a story!");
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(chipPrivateKey, digest);
        bytes memory sig = abi.encodePacked(r, s, v);
        vm.expectRevert(Unauthorized.selector);
        vm.prank(notAgent);
        trace.addVerifiedStory(1, "This is a story!", sig);

        // registry is an EOA fails
        trace.setTracersRegistry(address(0xC0FFEE));

        vm.expectRevert(Unauthorized.selector);
        vm.prank(notAgent);
        trace.addVerifiedStory(1, "This is a story!", sig);

        trace.setTracersRegistry(address(registry));

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

    function testAddVerifiedStoryAirdrop(uint256 badSignerPrivateKey, address notAgent) public {
        vm.assume(
            badSignerPrivateKey != chipPrivateKey && badSignerPrivateKey != 0
                && badSignerPrivateKey < 115792089237316195423570985008687907852837564279074904382605163141518161494337
        );
        vm.assume(notAgent != agent);

        uint256 nonce = trace.getTokenNonce(1);

        // airdrop
        address[] memory addresses = new address[](2);
        addresses[0] = chip;
        addresses[1] = chip;
        trace.airdrop(addresses, "baseUri");

        // sender not registered agent fails
        bytes32 digest = sigUtils.getTypedDataHash(1, nonce, notAgent, "This is a story!");
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(chipPrivateKey, digest);
        bytes memory sig = abi.encodePacked(r, s, v);
        vm.expectRevert(Unauthorized.selector);
        vm.prank(notAgent);
        trace.addVerifiedStory(1, "This is a story!", sig);

        // registry is an EOA fails
        trace.setTracersRegistry(address(0xC0FFEE));

        vm.expectRevert(Unauthorized.selector);
        vm.prank(notAgent);
        trace.addVerifiedStory(1, "This is a story!", sig);

        trace.setTracersRegistry(address(registry));

        // bad signer fails
        digest = sigUtils.getTypedDataHash(1, nonce, agent, "This is a story!");
        (v, r, s) = vm.sign(badSignerPrivateKey, digest);
        sig = abi.encodePacked(r, s, v);
        vm.expectRevert(InvalidSignature.selector);
        vm.prank(agent);
        trace.addVerifiedStory(1, "This is a story!", sig);

        // non-existent token fails
        digest = sigUtils.getTypedDataHash(3, nonce, agent, "This is a story!");
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

    function testAddVerifiedStoryDiffNames(string memory name) public {
        // trace
        address[] memory admins = new address[](1);
        admins[0] = creatorAdmin;
        trace = new TRACE(false);
        trace.initialize(name, "COA", royaltyRecipient, 1000, address(this), admins, address(registry));

        // mint token
        trace.mint(chip, "https://arweave.net/tx_id");

        // set TRACE registry
        trace.setTracersRegistry(address(registry));

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

    function testAddVerifiedStoryNoRegisteredAgents(address sender) public {
        // change registry to zero address
        trace.setTracersRegistry(address(0));

        // mint
        trace.mint(chip, "https://arweave.net/tx_id");

        // test add story
        uint256 nonce = trace.getTokenNonce(1);
        bytes32 digest = sigUtils.getTypedDataHash(1, nonce, sender, "This is a story!");
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(chipPrivateKey, digest);
        bytes memory sig = abi.encodePacked(r, s, v);
        vm.expectEmit(true, true, false, true);
        emit Story(1, sender, sender.toHexString(), "This is a story!");
        vm.prank(sender);
        trace.addVerifiedStory(1, "This is a story!", sig);
        assert(trace.getTokenNonce(1) == nonce + 1);

        // test replay protection
        vm.expectRevert(InvalidSignature.selector);
        vm.prank(sender);
        trace.addVerifiedStory(1, "This is a story!", sig);
    }

    /// @notice test royalty functions
    // - access control ✅

    function testRoyaltyAccessControl(address user) public {
        vm.assume(user != address(this) && user != address(0));
        address[] memory users = new address[](1);
        users[0] = user;

        trace.mint(user, "https://arweave.net/tx_id");

        // verify user can't set default royalty
        vm.prank(user);
        vm.expectRevert();
        trace.setDefaultRoyalty(user, 1000);

        // verify user can't set token royalty
        vm.prank(user);
        vm.expectRevert();
        trace.setTokenRoyalty(1, user, 1000);

        // verify owner can set default royalty
        trace.setDefaultRoyalty(address(1), 100);
        (address recp, uint256 amt) = trace.royaltyInfo(1, 10000);
        assert(recp == address(1));
        assert(amt == 100);

        // set admins
        trace.setRole(trace.ADMIN_ROLE(), users, true);

        // verify admin can set default royalty
        vm.prank(user);
        trace.setDefaultRoyalty(address(2), 1000);
        (recp, amt) = trace.royaltyInfo(1, 10000);
        assert(recp == address(2));
        assert(amt == 1000);
        
        // verify owner can set token royalty
        trace.setTokenRoyalty(1, address(1), 100);
        (recp, amt) = trace.royaltyInfo(1, 10000);
        assert(recp == address(1));
        assert(amt == 100);

        // verify admin can set token royalty
        vm.prank(user);
        trace.setTokenRoyalty(1, address(2), 1000);
        (recp, amt) = trace.royaltyInfo(1, 10000);
        assert(recp == address(2));
        assert(amt == 1000);
    }

    /// @notice test metadata update function
    // - custom errors
    // - access control
    // - regular mint
    // - airdrop

    function testMetadataUpdateCustomErrors() public {
        // token doesn't exist
        vm.expectRevert(TokenDoesntExist.selector);
        trace.updateTokenUri(1, "hiiii");

        // empty uri
        trace.mint(address(1), "hiii");
        vm.expectRevert(EmptyTokenURI.selector);
        trace.updateTokenUri(1, "");
    }

    function testMetadataUpdateAccessControl(address user) public {
        vm.assume(user != address(this) && user != address(0));
        address[] memory users = new address[](1);
        users[0] = user;

        trace.mint(user, "https://arweave.net/tx_id");

        // verify user can't update metadata
        vm.prank(user);
        vm.expectRevert();
        trace.updateTokenUri(1, "ipfs://cid");

        // verify owner can update metadata
        vm.expectEmit(false, false, false, true);
        emit MetadataUpdate(1);
        trace.updateTokenUri(1, "ipfs://cid");
        assertEq(trace.tokenURI(1), "ipfs://cid");

        // set admins
        trace.setRole(trace.ADMIN_ROLE(), users, true);

        // verify admin can update metadata
        vm.expectEmit(false, false, false, true);
        emit MetadataUpdate(1);
        vm.prank(user);
        trace.updateTokenUri(1, "https://arweave.net/tx_id");
        assertEq(trace.tokenURI(1), "https://arweave.net/tx_id");
    }

    function testMetadataUpdateAirdrop(uint256 numAddresses) public {
        vm.assume(numAddresses > 1);
        if (numAddresses > 1000) {
            numAddresses = numAddresses % 999 + 2; // map to 300
        }

        address[] memory addresses = new address[](numAddresses);
        for (uint256 i = 0; i < numAddresses; i++) {
            addresses[i] = makeAddr(i.toString());
        }

        trace.airdrop(addresses, "baseUri");

        for (uint256 i = 1; i <= numAddresses; i++) {
            string memory uri = string(abi.encodePacked("baseUri/", (i - 1).toString()));
            assertEq(trace.tokenURI(i), uri);
        }

        for (uint256 i = 1; i <= numAddresses; i++) {
            string memory uri = string(abi.encodePacked("ipfs://", (i-1).toString()));
            trace.updateTokenUri(i, uri);
            assertEq(trace.tokenURI(i), uri);
        }
    }
    
    /// @notice test story functions
    // - enable/disable story access control ✅
    // - regular mint ✅
    // - airdrop ✅
    // - write creator story to existing token w/ proper acccess ✅
    // - write collector story to existing token w/ proper access ✅
    // - write creator story to non-existent token (reverts) ✅
    // - write collector story to non-existent token (reverts) ✅

    function testStoryAccessControl(address user) public {
        vm.assume(user != address(this));
        address[] memory users = new address[](1);
        users[0] = user;

        // verify user can't enable/disable
        vm.startPrank(user, user);
        vm.expectRevert();
        trace.setStoryEnabled(false);
        vm.stopPrank();

        // verify admin can enable/disable
        trace.setRole(trace.ADMIN_ROLE(), users, true);
        vm.startPrank(user, user);
        trace.setStoryEnabled(false);
        vm.stopPrank();
        trace.setRole(trace.ADMIN_ROLE(), users, false);

        // verify owner can enable/disable
        trace.setStoryEnabled(false);
        assertFalse(trace.storyEnabled());
        trace.setStoryEnabled(true);
        assertTrue(trace.storyEnabled());
    }

    function testStoryNonExistentTokens() public {
        vm.expectRevert();
        trace.addCreatorStory(1, "XCOPY", "I AM XCOPY");
        vm.expectRevert();
        trace.addStory(1, "NOT XCOPY", "I AM NOT XCOPY");
    }

    function testStoryWithMint(address collector) public {
        vm.assume(collector != address(0));
        vm.assume(collector != address(this));
        trace.mint(collector, "uri");

        // test creator story
        vm.expectEmit(true, true, true, true);
        emit CreatorStory(1, address(this), "XCOPY", "I AM XCOPY");
        trace.addCreatorStory(1, "XCOPY", "I AM XCOPY");

        // test collector can't add creator story
        vm.startPrank(collector, collector);
        vm.expectRevert();
        trace.addCreatorStory(1, "XCOPY", "I AM XCOPY");

        // test collector story
        vm.expectEmit(true, true, true, true);
        emit Story(1, collector, "NOT XCOPY", "I AM NOT XCOPY");
        trace.addStory(1, "NOT XCOPY", "I AM NOT XCOPY");
        vm.stopPrank();

        // test that owner can't add collector story
        vm.expectRevert();
        trace.addStory(1, "NOT XCOPY", "I AM NOT XCOPY");
    }

    function testStoryWithAirdrop(address collector) public {
        vm.assume(collector != address(0));
        vm.assume(collector != address(this));
        address[] memory addresses = new address[](2);
        addresses[0] = collector;
        addresses[1] = collector;
        trace.airdrop(addresses, "uri");

        // test creator story
        vm.expectEmit(true, true, true, true);
        emit CreatorStory(1, address(this), "XCOPY", "I AM XCOPY");
        trace.addCreatorStory(1, "XCOPY", "I AM XCOPY");
        vm.expectEmit(true, true, true, true);
        emit CreatorStory(2, address(this), "XCOPY", "I AM XCOPY");
        trace.addCreatorStory(2, "XCOPY", "I AM XCOPY");

        // test collector can't add creator story
        vm.startPrank(collector, collector);
        vm.expectRevert();
        trace.addCreatorStory(1, "XCOPY", "I AM XCOPY");
        vm.expectRevert();
        trace.addCreatorStory(2, "XCOPY", "I AM XCOPY");

        // test collector story
        vm.expectEmit(true, true, true, true);
        emit Story(1, collector, "NOT XCOPY", "I AM NOT XCOPY");
        trace.addStory(1, "NOT XCOPY", "I AM NOT XCOPY");
        vm.expectEmit(true, true, true, true);
        emit Story(2, collector, "NOT XCOPY", "I AM NOT XCOPY");
        trace.addStory(2, "NOT XCOPY", "I AM NOT XCOPY");
        vm.stopPrank();

        // test that owner can't add collector story
        vm.expectRevert();
        trace.addStory(1, "NOT XCOPY", "I AM NOT XCOPY");
        vm.expectRevert();
        trace.addStory(2, "NOT XCOPY", "I AM NOT XCOPY");
    }

}

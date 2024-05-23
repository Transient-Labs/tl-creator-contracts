// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import "forge-std/Test.sol";
import {TRACE} from "src/erc-721/trace/TRACE.sol";
import {ITRACERSRegistry} from "src/interfaces/ITRACERSRegistry.sol";
import {IERC721Errors} from "openzeppelin/interfaces/draft-IERC6093.sol";
import {Initializable} from "openzeppelin/proxy/utils/Initializable.sol";
import {OwnableAccessControlUpgradeable} from "tl-sol-tools/upgradeable/access/OwnableAccessControlUpgradeable.sol";
import {TRACESigUtils} from "test/utils/TRACESigUtils.sol";
import {Strings} from "openzeppelin/utils/Strings.sol";

contract TRACETest is Test {
    using Strings for address;
    using Strings for uint256;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event RoleChange(address indexed from, address indexed user, bool indexed approved, bytes32 role);
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event MetadataUpdate(uint256 tokenId);
    event CollectionStory(address indexed creatorAddress, string creatorName, string story);
    event CreatorStory(uint256 indexed tokenId, address indexed creatorAddress, string creatorName, string story);
    event Story(uint256 indexed tokenId, address indexed senderAddress, string senderName, string story);
    event TRACERSRegistryUpdated(
        address indexed sender, address indexed oldTracersRegistry, address indexed newTracersRegistry
    );

    TRACE public trace;
    address public royaltyRecipient = makeAddr("royaltyRecipient");
    address public creatorAdmin = makeAddr("admin");
    uint256 public chipPrivateKey = 0x007;
    address public chip;
    address public agent = makeAddr("agent");
    address tracersRegistry = makeAddr("tracersRegistry");

    TRACESigUtils public sigUtils;

    function setUp() public {
        // chip
        chip = vm.addr(chipPrivateKey);

        // create TRACE
        address[] memory admins = new address[](0);
        trace = new TRACE(false);
        trace.initialize("Test TRACE", "TRACE", "", royaltyRecipient, 1000, address(this), admins, tracersRegistry);

        // sig utils
        sigUtils = new TRACESigUtils("3", address(trace));
    }

    /// @notice initialization Tests
    function test_initialize(
        string memory name,
        string memory symbol,
        string memory personalization,
        address defaultRoyaltyRecipient,
        uint256 defaultRoyaltyPercentage,
        address initOwner,
        address[] memory admins,
        address tracersRegistry_
    ) public {
        // limit fuzz
        vm.assume(defaultRoyaltyRecipient != address(0));
        if (defaultRoyaltyPercentage >= 10_000) {
            defaultRoyaltyPercentage = defaultRoyaltyPercentage % 10_000;
        }
        vm.assume(initOwner != address(0));

        vm.startPrank(address(this), address(this));

        // create contract
        trace = new TRACE(false);

        // initialize and verify events thrown (order matters)
        vm.expectEmit(true, true, true, true);
        emit OwnershipTransferred(address(0), initOwner);
        for (uint256 i = 0; i < admins.length; i++) {
            vm.expectEmit(true, true, true, true);
            emit RoleChange(address(this), admins[i], true, trace.ADMIN_ROLE());
        }
        if (bytes(personalization).length > 0) {
            vm.expectEmit(true, true, true, true);
            emit CollectionStory(initOwner, initOwner.toHexString(), personalization);
        }
        trace.initialize(
            name,
            symbol,
            personalization,
            defaultRoyaltyRecipient,
            defaultRoyaltyPercentage,
            initOwner,
            admins,
            tracersRegistry_
        );

        // assert intial values
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
        assertEq(address(trace.blocklistRegistry()), address(0));
        assertEq(address(trace.tlNftDelegationRegistry()), address(0));
        assertEq(address(trace.tracersRegistry()), tracersRegistry_);

        // can't initialize again
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        trace.initialize(
            name,
            symbol,
            personalization,
            defaultRoyaltyRecipient,
            defaultRoyaltyPercentage,
            initOwner,
            admins,
            tracersRegistry
        );

        // can't get by initializers disableed
        trace = new TRACE(true);

        vm.expectRevert(Initializable.InvalidInitialization.selector);
        trace.initialize(
            name,
            symbol,
            personalization,
            defaultRoyaltyRecipient,
            defaultRoyaltyPercentage,
            initOwner,
            admins,
            tracersRegistry
        );

        vm.stopPrank();
    }

    /// @notice test ERC-165 support
    function test_supportsInterface() public {
        assertTrue(trace.supportsInterface(0x1c8e024d)); // ICreatorBase
        assertTrue(trace.supportsInterface(0xcfec4f64)); // ITRACE
        assertTrue(trace.supportsInterface(0x2464f17b)); // IStory
        assertTrue(trace.supportsInterface(0x0d23ecb9)); // IStory (old)
        assertTrue(trace.supportsInterface(0x01ffc9a7)); // ERC-165
        assertTrue(trace.supportsInterface(0x80ac58cd)); // ERC-721
        assertTrue(trace.supportsInterface(0x2a55205a)); // ERC-2981
        assertTrue(trace.supportsInterface(0x49064906)); // ERC-4906
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
    function test_mint_customErrors() public {
        vm.expectRevert(TRACE.EmptyTokenURI.selector);
        trace.mint(address(this), "");

        vm.expectRevert(TRACE.EmptyTokenURI.selector);
        trace.mint(address(this), "", address(1), 10);
    }

    function test_mint_accessControl(address user) public {
        // limit fuzz input
        vm.assume(user != address(this));
        vm.assume(user != address(0));

        // ensure user can't call the mint function
        vm.startPrank(user, user);
        vm.expectRevert(
            abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, trace.ADMIN_ROLE())
        );
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
        vm.expectRevert(
            abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, trace.ADMIN_ROLE())
        );
        trace.mint(address(this), "uriOne");
        vm.stopPrank();
    }

    function test_mint(uint16 tokenId, address recipient) public {
        // limit fuzz input
        vm.assume(tokenId != 0);
        vm.assume(recipient != address(0));
        if (tokenId > 1000) {
            tokenId = tokenId % 1000 + 1; // map to 1000
        }

        // mint token and check ownership
        for (uint256 i = 1; i <= tokenId; i++) {
            string memory uri = string(abi.encodePacked("uri_", i.toString()));
            vm.expectEmit(true, true, true, false);
            emit Transfer(address(0), recipient, i);
            vm.expectEmit(true, true, false, false);
            emit CreatorStory(i, address(this), "", "{\n\"trace\": {\"type\": \"trace_authentication\"}\n}");
            trace.mint(recipient, uri);
            assertEq(trace.balanceOf(recipient), i);
            assertEq(trace.ownerOf(i), recipient);
            assertEq(trace.tokenURI(i), uri);
        }

        // ensure ownership throws for non-existent token
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, tokenId + 1));
        trace.ownerOf(tokenId + 1);
        vm.expectRevert(TRACE.TokenDoesntExist.selector);
        trace.tokenURI(tokenId + 1);
    }

    function test_mint_withTokenRoyalty(
        uint16 tokenId,
        address recipient,
        address royaltyAddress,
        uint16 royaltyPercent
    ) public {
        // limit fuzz input
        vm.assume(tokenId != 0);
        vm.assume(recipient != address(0));
        vm.assume(royaltyAddress != royaltyRecipient);
        vm.assume(royaltyAddress != address(0));
        if (royaltyPercent >= 10_000) royaltyPercent = royaltyPercent % 10_000;
        if (tokenId > 1000) {
            tokenId = tokenId % 1000 + 1; // map to 1000
        }

        // mint token and check ownership
        for (uint256 i = 1; i <= tokenId; i++) {
            string memory uri = string(abi.encodePacked("uri_", i.toString()));
            vm.expectEmit(true, true, true, false);
            emit Transfer(address(0), recipient, i);
            vm.expectEmit(true, true, false, false);
            emit CreatorStory(i, address(this), "", "{\n\"trace\": {\"type\": \"trace_authentication\"}\n}");
            trace.mint(recipient, uri, royaltyAddress, royaltyPercent);
            assertEq(trace.balanceOf(recipient), i);
            assertEq(trace.ownerOf(i), recipient);
            assertEq(trace.tokenURI(i), uri);
            (address recp, uint256 amt) = trace.royaltyInfo(i, 10_000);
            assertEq(recp, royaltyAddress);
            assertEq(amt, royaltyPercent);
        }

        // ensure ownership throws for non-existent token
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, tokenId + 1));
        trace.ownerOf(tokenId + 1);
        vm.expectRevert(TRACE.TokenDoesntExist.selector);
        trace.tokenURI(tokenId + 1);
    }

    function test_mint_thenTransfer(uint16 tokenId, address recipient, address secondRecipient) public {
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
    function test_airdrop_customErrors() public {
        address[] memory addresses = new address[](1);
        addresses[0] = address(1);
        vm.expectRevert(TRACE.EmptyTokenURI.selector);
        trace.airdrop(addresses, "");

        vm.expectRevert(TRACE.AirdropTooFewAddresses.selector);
        trace.airdrop(addresses, "baseUri");
    }

    function test_airdrop_accessControl(address user) public {
        vm.assume(user != address(this));
        vm.assume(user != address(0));
        address[] memory addresses = new address[](2);
        addresses[0] = address(1);
        addresses[1] = address(2);
        // ensure user can't call the airdrop function
        vm.startPrank(user, user);
        vm.expectRevert(
            abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, trace.ADMIN_ROLE())
        );
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
        vm.expectRevert(
            abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, trace.ADMIN_ROLE())
        );
        trace.airdrop(addresses, "baseUri");
        vm.stopPrank();
    }

    function test_airdrop(uint16 numAddresses) public {
        // limit fuzz
        vm.assume(numAddresses > 1);
        if (numAddresses > 1000) {
            numAddresses = numAddresses % 999 + 2; // map to 300
        }

        // create addresses
        address[] memory addresses = new address[](numAddresses);
        for (uint256 i = 0; i < numAddresses; i++) {
            addresses[i] = makeAddr(i.toString());
        }

        // verify airdrop
        for (uint256 i = 1; i <= numAddresses; i++) {
            vm.expectEmit(true, true, true, false);
            emit Transfer(address(0), addresses[i - 1], i);
            vm.expectEmit(true, true, false, false);
            emit CreatorStory(i, address(this), "", "{\n\"trace\": {\"type\": \"trace_authentication\"}\n}");
        }
        trace.airdrop(addresses, "baseUri");
        for (uint256 i = 1; i <= numAddresses; i++) {
            string memory uri = string(abi.encodePacked("baseUri/", (i - 1).toString()));
            assertEq(trace.balanceOf(addresses[i - 1]), 1);
            assertEq(trace.ownerOf(i), addresses[i - 1]);
            assertEq(trace.tokenURI(i), uri);
        }

        // ensure ownership throws for non-existent token
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, numAddresses + 1));
        trace.ownerOf(numAddresses + 1);
        vm.expectRevert(TRACE.TokenDoesntExist.selector);
        trace.tokenURI(numAddresses + 1);

        // test mint after metadata
        trace.mint(address(this), "newUri");
        assertEq(trace.ownerOf(numAddresses + 1), address(this));
        assertEq(trace.tokenURI(numAddresses + 1), "newUri");
    }

    function test_airdrop_thenTransfer(uint16 numAddresses, address recipient) public {
        // limit fuzz
        vm.assume(numAddresses > 1);
        vm.assume(recipient != address(0));
        vm.assume(recipient.code.length == 0);
        if (numAddresses > 1000) {
            numAddresses = numAddresses % 999 + 2; // map to 300
        }

        // create addresses
        address[] memory addresses = new address[](numAddresses);
        for (uint256 i = 0; i < numAddresses; i++) {
            if (makeAddr(i.toString()) == recipient) {
                addresses[i] = makeAddr("hello");
            } else {
                addresses[i] = makeAddr(i.toString());
            }
        }

        // airdrop
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

        // transfer
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

    /// @notice test externalMint
    // - access control ✅
    // - proper recipient ✅
    // - transfer event ✅
    // - proper token id ✅
    // - ownership ✅
    // - balance ✅
    // - transfer to another address ✅
    // - safe transfer to another address ✅
    // - token uris ✅
    function test_externalMint_customErrors() public {
        address[] memory minters = new address[](1);
        minters[0] = address(this);
        trace.setRole(trace.APPROVED_MINT_CONTRACT(), minters, true);
        vm.expectRevert(TRACE.EmptyTokenURI.selector);
        trace.externalMint(address(this), "");
    }

    function test_externalMint_accessControl(address user) public {
        // limit fuzz
        vm.assume(user != address(this));
        vm.assume(user != address(0));
        address[] memory addresses = new address[](2);
        addresses[0] = address(1);
        addresses[1] = address(2);

        // ensure user can't call the airdrop function
        vm.startPrank(user, user);
        vm.expectRevert(
            abi.encodeWithSelector(
                OwnableAccessControlUpgradeable.NotSpecifiedRole.selector, trace.APPROVED_MINT_CONTRACT()
            )
        );
        trace.externalMint(address(this), "uri");
        vm.stopPrank();

        // grant minter access and ensure that the user can call the external mint function
        address[] memory minters = new address[](1);
        minters[0] = user;
        trace.setRole(trace.APPROVED_MINT_CONTRACT(), minters, true);
        vm.startPrank(user, user);
        vm.expectEmit(true, true, true, false);
        emit Transfer(address(0), address(this), 1);
        trace.externalMint(address(this), "uri");
        vm.stopPrank();
        assertEq(trace.balanceOf(address(this)), 1);
        assertEq(trace.ownerOf(1), address(this));
        assertEq(trace.tokenURI(1), "uri");

        // revoke mint access and ensure that the user can't call the external mint function
        trace.setRole(trace.APPROVED_MINT_CONTRACT(), minters, false);
        vm.startPrank(user, user);
        vm.expectRevert(
            abi.encodeWithSelector(
                OwnableAccessControlUpgradeable.NotSpecifiedRole.selector, trace.APPROVED_MINT_CONTRACT()
            )
        );
        trace.externalMint(address(this), "uri");
        vm.stopPrank();

        // grant admin role and ensure that the user can't call the external mint function
        trace.setRole(trace.ADMIN_ROLE(), minters, true);
        vm.startPrank(user, user);
        vm.expectRevert(
            abi.encodeWithSelector(
                OwnableAccessControlUpgradeable.NotSpecifiedRole.selector, trace.APPROVED_MINT_CONTRACT()
            )
        );
        trace.externalMint(address(this), "uri");
        vm.stopPrank();

        // revoke admin role and ensure that the user can't call the external mint function
        trace.setRole(trace.ADMIN_ROLE(), minters, false);
        vm.startPrank(user, user);
        vm.expectRevert(
            abi.encodeWithSelector(
                OwnableAccessControlUpgradeable.NotSpecifiedRole.selector, trace.APPROVED_MINT_CONTRACT()
            )
        );
        trace.externalMint(address(this), "uri");
        vm.stopPrank();
    }

    function test_externalMint(address recipient, string memory uri, uint16 numTokens) public {
        // limit fuzz
        vm.assume(recipient != address(0));
        vm.assume(recipient != address(1));
        vm.assume(bytes(uri).length > 0);
        vm.assume(numTokens > 0);
        if (numTokens > 1000) {
            numTokens = numTokens % 1000 + 1;
        }

        // set mint contract
        address[] memory minters = new address[](1);
        minters[0] = address(1);
        trace.setRole(trace.APPROVED_MINT_CONTRACT(), minters, true);

        // mint
        for (uint256 i = 1; i <= numTokens; i++) {
            vm.startPrank(address(1), address(1));
            vm.expectEmit(true, true, true, false);
            emit Transfer(address(0), recipient, i);
            trace.externalMint(recipient, uri);
            vm.stopPrank();
            assertEq(trace.balanceOf(recipient), i);
            assertEq(trace.ownerOf(i), recipient);
            assertEq(trace.tokenURI(i), uri);
        }

        // ensure ownership throws for non-existent token
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, numTokens + 1));
        trace.ownerOf(numTokens + 1);
        vm.expectRevert(TRACE.TokenDoesntExist.selector);
        trace.tokenURI(numTokens + 1);
    }

    function test_externalMint_thenTransfer(
        address recipient,
        string memory uri,
        uint16 numTokens,
        address transferRecipient
    ) public {
        // limit fuzz
        vm.assume(recipient != address(0));
        vm.assume(recipient != address(1));
        vm.assume(transferRecipient != address(0));
        vm.assume(transferRecipient != address(1));
        vm.assume(transferRecipient.code.length == 0);
        vm.assume(bytes(uri).length > 0);
        vm.assume(numTokens > 0);
        if (numTokens > 1000) {
            numTokens = numTokens % 1000 + 1;
        }

        // approve mint contract
        address[] memory minters = new address[](1);
        minters[0] = address(1);
        trace.setRole(trace.APPROVED_MINT_CONTRACT(), minters, true);

        // mint
        for (uint256 i = 1; i <= numTokens; i++) {
            vm.startPrank(address(1), address(1));
            trace.externalMint(recipient, uri);
            vm.stopPrank();
            vm.startPrank(recipient, recipient);
            vm.expectEmit(true, true, true, false);
            emit Transfer(recipient, transferRecipient, i);
            trace.transferFrom(recipient, transferRecipient, i);
            vm.stopPrank();
            assertEq(trace.balanceOf(transferRecipient), 1);
            assertEq(trace.ownerOf(i), transferRecipient);
            vm.startPrank(transferRecipient, transferRecipient);
            vm.expectEmit(true, true, true, false);
            emit Transfer(transferRecipient, address(1), i);
            trace.safeTransferFrom(transferRecipient, address(1), i);
            vm.stopPrank();
            assertEq(trace.balanceOf(address(1)), i);
            assertEq(trace.ownerOf(i), address(1));
        }
    }

    /// @notice test TRACE functions
    // - access control ✅
    // - transfer tokens ✅
    // - set tracers registry ✅
    // - add verified story ✅
    // - add verified story batch ✅
    function test_transferToken_accessControl(address user) public {
        // limit fuzz
        vm.assume(user != address(this));

        // mint token
        trace.mint(address(this), "hii");

        // ensure the user can't transfer the token
        vm.expectRevert(
            abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, trace.ADMIN_ROLE())
        );
        vm.prank(user);
        trace.transferToken(address(this), user, 1);
    }

    function test_transferToken(address user, uint256 numAddresses) public {
        // limit fuzz
        vm.assume(user != address(this) && user != address(0));
        address[] memory users = new address[](1);
        users[0] = user;
        vm.assume(numAddresses > 1);
        if (numAddresses > 1000) {
            numAddresses = numAddresses % 999 + 2; // map to 300
        }

        // create addresses
        address[] memory addresses = new address[](numAddresses);
        for (uint256 i = 0; i < numAddresses; i++) {
            addresses[i] = makeAddr(i.toString());
        }

        // regular mint
        trace.mint(user, "hiii");
        assert(trace.ownerOf(1) == user);

        // airdrop
        trace.airdrop(addresses, "baseUri");
        for (uint256 i = 2; i <= numAddresses + 1; i++) {
            assertEq(trace.ownerOf(i), addresses[i - 2]);
        }

        // transfer tokens
        vm.expectEmit(true, true, true, false);
        emit Transfer(user, address(this), 1);
        vm.expectEmit(true, true, false, false);
        emit CreatorStory(1, address(this), "", "{\n\"trace\": {\"type\": \"trace_authentication\"}\n}");
        trace.transferToken(user, address(this), 1);
        assert(trace.ownerOf(1) == address(this));

        for (uint256 i = 2; i <= numAddresses + 1; i++) {
            vm.expectEmit(true, true, true, false);
            emit Transfer(addresses[i - 2], address(this), i);
            vm.expectEmit(true, true, false, false);
            emit CreatorStory(i, address(this), "", "{\n\"trace\": {\"type\": \"trace_authentication\"}\n}");
            trace.transferToken(addresses[i - 2], address(this), i);
            assert(trace.ownerOf(i) == address(this));
        }
    }

    function test_setTracersRegistry(address user, address newRegistryOne, address newRegistryTwo) public {
        vm.assume(user != address(this));
        address[] memory users = new address[](1);
        users[0] = user;

        // expect revert from user
        vm.expectRevert(
            abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, trace.ADMIN_ROLE())
        );
        vm.prank(user);
        trace.setTracersRegistry(newRegistryOne);

        // expect creator pass
        vm.expectEmit(true, true, true, true);
        emit TRACERSRegistryUpdated(address(this), tracersRegistry, newRegistryOne);
        trace.setTracersRegistry(newRegistryOne);
        assert(address(trace.tracersRegistry()) == newRegistryOne);

        // set admin
        trace.setRole(trace.ADMIN_ROLE(), users, true);

        // expect admin pass
        vm.expectEmit(true, true, true, true);
        emit TRACERSRegistryUpdated(user, newRegistryOne, newRegistryTwo);
        vm.prank(user);
        trace.setTracersRegistry(newRegistryTwo);
        assert(address(trace.tracersRegistry()) == newRegistryTwo);
    }

    function test_addVerifiedStory_customErrors(uint256 len1, uint256 len2, uint256 len3) public {
        // limit fuzz
        if (len1 > 200) {
            len1 = len1 % 200;
        }
        if (len2 > 200) {
            len2 = len2 % 200;
        }
        if (len3 > 200) {
            len3 = len3 % 200;
        }
        uint256[] memory tokenIds = new uint256[](len1);
        string[] memory stories = new string[](len2);
        bytes[] memory sigs = new bytes[](len3);
        if (len1 != len2 || len2 != len3 || len1 != len3) {
            vm.expectRevert(TRACE.ArrayLengthMismatch.selector);
            trace.addVerifiedStory(tokenIds, stories, sigs);
        }
    }

    function test_addVerifiedStory_mint(uint256 badSignerPrivateKey, address notAgent) public {
        // limit fuzz
        vm.assume(
            badSignerPrivateKey != chipPrivateKey && badSignerPrivateKey != 0
                && badSignerPrivateKey < 115792089237316195423570985008687907852837564279074904382605163141518161494337
        );
        vm.assume(notAgent != agent);

        // set mocks
        vm.mockCall(
            tracersRegistry,
            abi.encodeWithSelector(ITRACERSRegistry.isRegisteredAgent.selector, notAgent),
            abi.encode(false, "")
        );
        vm.mockCall(
            tracersRegistry,
            abi.encodeWithSelector(ITRACERSRegistry.isRegisteredAgent.selector, agent),
            abi.encode(true, "agent")
        );

        // variables
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;
        string[] memory stories = new string[](1);
        stories[0] = "This is a story!";
        bytes[] memory sigs = new bytes[](1);

        // mint
        trace.mint(chip, "https://arweave.net/tx_id");

        // sender not registered agent fails
        bytes32 digest = sigUtils.getTypedDataHash(address(trace), 1, "This is a story!");
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(chipPrivateKey, digest);
        sigs[0] = abi.encodePacked(r, s, v);
        vm.expectRevert(TRACE.Unauthorized.selector);
        vm.prank(notAgent);
        trace.addVerifiedStory(tokenIds, stories, sigs);

        // registry is an EOA fails
        trace.setTracersRegistry(address(0xC0FFEE));

        // expect EOA registry to fail
        vm.expectRevert();
        vm.prank(notAgent);
        trace.addVerifiedStory(tokenIds, stories, sigs);
        vm.expectRevert();
        vm.prank(agent);
        trace.addVerifiedStory(tokenIds, stories, sigs);

        trace.setTracersRegistry(tracersRegistry);

        // bad signer fails
        (v, r, s) = vm.sign(badSignerPrivateKey, digest);
        sigs[0] = abi.encodePacked(r, s, v);
        vm.expectRevert(TRACE.InvalidSignature.selector);
        vm.prank(agent);
        trace.addVerifiedStory(tokenIds, stories, sigs);

        // sign for wrong token
        digest = sigUtils.getTypedDataHash(address(trace), 2, "This is a story!");
        (v, r, s) = vm.sign(chipPrivateKey, digest);
        sigs[0] = abi.encodePacked(r, s, v);
        vm.expectRevert(TRACE.InvalidSignature.selector);
        vm.prank(agent);
        trace.addVerifiedStory(tokenIds, stories, sigs);

        // sign for wrong nft contract
        digest = sigUtils.getTypedDataHash(tracersRegistry, 1, "This is a story!");
        (v, r, s) = vm.sign(chipPrivateKey, digest);
        sigs[0] = abi.encodePacked(r, s, v);
        vm.expectRevert(TRACE.InvalidSignature.selector);
        vm.prank(agent);
        trace.addVerifiedStory(tokenIds, stories, sigs);

        // sign for non-existent token
        digest = sigUtils.getTypedDataHash(address(trace), 2, "This is a story!");
        (v, r, s) = vm.sign(chipPrivateKey, digest);
        sigs[0] = abi.encodePacked(r, s, v);
        tokenIds[0] = 2;
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, 2));
        vm.prank(agent);
        trace.addVerifiedStory(tokenIds, stories, sigs);

        // right signer + registered agent passes
        digest = sigUtils.getTypedDataHash(address(trace), 1, "This is a story!");
        (v, r, s) = vm.sign(chipPrivateKey, digest);
        sigs[0] = abi.encodePacked(r, s, v);
        tokenIds[0] = 1;
        vm.expectEmit(true, true, true, true);
        emit Story(1, agent, "agent", "This is a story!");
        vm.prank(agent);
        trace.addVerifiedStory(tokenIds, stories, sigs);

        // fails with replay
        vm.expectRevert(TRACE.VerifiedStoryAlreadyWritten.selector);
        vm.prank(agent);
        trace.addVerifiedStory(tokenIds, stories, sigs);

        // clear mocks
        vm.clearMockedCalls();
    }

    function test_addVerifiedStory_airdrop(uint256 badSignerPrivateKey, address notAgent) public {
        // limit fuzz
        vm.assume(
            badSignerPrivateKey != chipPrivateKey && badSignerPrivateKey != 0
                && badSignerPrivateKey < 115792089237316195423570985008687907852837564279074904382605163141518161494337
        );
        vm.assume(notAgent != agent);

        // set mocks
        vm.mockCall(
            tracersRegistry,
            abi.encodeWithSelector(ITRACERSRegistry.isRegisteredAgent.selector, notAgent),
            abi.encode(false, "")
        );
        vm.mockCall(
            tracersRegistry,
            abi.encodeWithSelector(ITRACERSRegistry.isRegisteredAgent.selector, agent),
            abi.encode(true, "agent")
        );

        // variables
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;
        string[] memory stories = new string[](1);
        stories[0] = "This is a story!";
        bytes[] memory sigs = new bytes[](1);

        // airdrop
        address[] memory addresses = new address[](2);
        addresses[0] = chip;
        addresses[1] = chip;
        trace.airdrop(addresses, "baseUri");

        // sender not registered agent fails
        bytes32 digest = sigUtils.getTypedDataHash(address(trace), 1, "This is a story!");
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(chipPrivateKey, digest);
        sigs[0] = abi.encodePacked(r, s, v);
        vm.expectRevert(TRACE.Unauthorized.selector);
        vm.prank(notAgent);
        trace.addVerifiedStory(tokenIds, stories, sigs);

        // registry is an EOA fails
        trace.setTracersRegistry(address(0xC0FFEE));

        // expect EOA registry to fail
        vm.expectRevert();
        vm.prank(notAgent);
        trace.addVerifiedStory(tokenIds, stories, sigs);
        vm.expectRevert();
        vm.prank(agent);
        trace.addVerifiedStory(tokenIds, stories, sigs);

        trace.setTracersRegistry(tracersRegistry);

        // bad signer fails
        (v, r, s) = vm.sign(badSignerPrivateKey, digest);
        sigs[0] = abi.encodePacked(r, s, v);
        vm.expectRevert(TRACE.InvalidSignature.selector);
        vm.prank(agent);
        trace.addVerifiedStory(tokenIds, stories, sigs);

        // sign for wrong token
        digest = sigUtils.getTypedDataHash(address(trace), 2, "This is a story!");
        (v, r, s) = vm.sign(chipPrivateKey, digest);
        sigs[0] = abi.encodePacked(r, s, v);
        vm.expectRevert(TRACE.InvalidSignature.selector);
        vm.prank(agent);
        trace.addVerifiedStory(tokenIds, stories, sigs);

        // sign for wrong nft contract
        digest = sigUtils.getTypedDataHash(tracersRegistry, 1, "This is a story!");
        (v, r, s) = vm.sign(chipPrivateKey, digest);
        sigs[0] = abi.encodePacked(r, s, v);
        vm.expectRevert(TRACE.InvalidSignature.selector);
        vm.prank(agent);
        trace.addVerifiedStory(tokenIds, stories, sigs);

        // sign for non-existent token
        digest = sigUtils.getTypedDataHash(address(trace), 3, "This is a story!");
        (v, r, s) = vm.sign(chipPrivateKey, digest);
        sigs[0] = abi.encodePacked(r, s, v);
        tokenIds[0] = 3;
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, 3));
        vm.prank(agent);
        trace.addVerifiedStory(tokenIds, stories, sigs);

        // right signer + registered agent passes
        digest = sigUtils.getTypedDataHash(address(trace), 1, "This is a story!");
        (v, r, s) = vm.sign(chipPrivateKey, digest);
        sigs[0] = abi.encodePacked(r, s, v);
        tokenIds[0] = 1;
        vm.expectEmit(true, true, true, true);
        emit Story(1, agent, "agent", "This is a story!");
        vm.prank(agent);
        trace.addVerifiedStory(tokenIds, stories, sigs);

        // fails with replay
        vm.expectRevert(TRACE.VerifiedStoryAlreadyWritten.selector);
        vm.prank(agent);
        trace.addVerifiedStory(tokenIds, stories, sigs);

        // clear mocks
        vm.clearMockedCalls();
    }

    function test_addVerifiedStory_multipleForSameToken() public {
        // set mock
        vm.mockCall(
            tracersRegistry,
            abi.encodeWithSelector(ITRACERSRegistry.isRegisteredAgent.selector, agent),
            abi.encode(true, "agent")
        );

        // variables
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 1;
        tokenIds[1] = 1;
        string[] memory stories = new string[](2);
        stories[0] = "This is the first story!";
        stories[1] = "This is the second story!";
        bytes[] memory sigs = new bytes[](2);

        // mint
        trace.mint(chip, "https://arweave.net/tx_id1");

        // sender not registered agent fails
        bytes32 digest = sigUtils.getTypedDataHash(address(trace), tokenIds[0], stories[0]);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(chipPrivateKey, digest);
        sigs[0] = abi.encodePacked(r, s, v);
        digest = sigUtils.getTypedDataHash(address(trace), tokenIds[1], stories[1]);
        (v, r, s) = vm.sign(chipPrivateKey, digest);
        sigs[1] = abi.encodePacked(r, s, v);
        vm.expectEmit(true, true, true, true);
        emit Story(tokenIds[0], agent, "agent", stories[0]);
        vm.expectEmit(true, true, true, true);
        emit Story(tokenIds[1], agent, "agent", stories[1]);
        vm.prank(agent);
        trace.addVerifiedStory(tokenIds, stories, sigs);

        // fails with replay
        vm.expectRevert(TRACE.VerifiedStoryAlreadyWritten.selector);
        vm.prank(agent);
        trace.addVerifiedStory(tokenIds, stories, sigs);

        // clear mocks
        vm.clearMockedCalls();
    }

    function test_addVerifiedStory_multipleForDiffTokens() public {
        // set mock
        vm.mockCall(
            tracersRegistry,
            abi.encodeWithSelector(ITRACERSRegistry.isRegisteredAgent.selector, agent),
            abi.encode(true, "agent")
        );

        // variables
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 1;
        tokenIds[1] = 2;
        string[] memory stories = new string[](2);
        stories[0] = "This is the first story!";
        stories[1] = "This is the second story!";
        bytes[] memory sigs = new bytes[](2);

        // mint
        trace.mint(chip, "https://arweave.net/tx_id1");
        trace.mint(chip, "https://arweave.net/tx_id2");

        // sender not registered agent fails
        bytes32 digest = sigUtils.getTypedDataHash(address(trace), tokenIds[0], stories[0]);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(chipPrivateKey, digest);
        sigs[0] = abi.encodePacked(r, s, v);
        digest = sigUtils.getTypedDataHash(address(trace), tokenIds[1], stories[1]);
        (v, r, s) = vm.sign(chipPrivateKey, digest);
        sigs[1] = abi.encodePacked(r, s, v);
        vm.expectEmit(true, true, true, true);
        emit Story(tokenIds[0], agent, "agent", stories[0]);
        vm.expectEmit(true, true, true, true);
        emit Story(tokenIds[1], agent, "agent", stories[1]);
        vm.prank(agent);
        trace.addVerifiedStory(tokenIds, stories, sigs);

        // fails with replay
        vm.expectRevert(TRACE.VerifiedStoryAlreadyWritten.selector);
        vm.prank(agent);
        trace.addVerifiedStory(tokenIds, stories, sigs);

        // clear mocks
        vm.clearMockedCalls();
    }

    function test_addVerifiedStory_traceRegistryZeroAddress(address sender) public {
        // change registry to zero address
        trace.setTracersRegistry(address(0));

        // mint
        trace.mint(chip, "https://arweave.net/tx_id");

        // variables
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;
        string[] memory stories = new string[](1);
        stories[0] = "This is a story!";
        bytes[] memory sigs = new bytes[](1);

        // test add story
        bytes32 digest = sigUtils.getTypedDataHash(address(trace), 1, "This is a story!");
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(chipPrivateKey, digest);
        sigs[0] = abi.encodePacked(r, s, v);
        vm.expectEmit(true, true, true, true);
        emit Story(1, sender, sender.toHexString(), "This is a story!");
        vm.prank(sender);
        trace.addVerifiedStory(tokenIds, stories, sigs);

        // test replay protection
        vm.expectRevert(TRACE.VerifiedStoryAlreadyWritten.selector);
        vm.prank(sender);
        trace.addVerifiedStory(tokenIds, stories, sigs);
    }

    /// @notice test royalty functions
    // - access control ✅

    function test_royalty_accessControl(address user) public {
        // limit fuzz
        vm.assume(user != address(this) && user != address(0));
        address[] memory users = new address[](1);
        users[0] = user;

        // mint token
        trace.mint(user, "https://arweave.net/tx_id");

        // verify user can't set default royalty
        vm.expectRevert(
            abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, trace.ADMIN_ROLE())
        );
        vm.prank(user);
        trace.setDefaultRoyalty(user, 1000);

        // verify user can't set token royalty
        vm.expectRevert(
            abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, trace.ADMIN_ROLE())
        );
        vm.prank(user);
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
    // - custom errors ✅
    // - access control
    // - regular mint
    // - airdrop
    function test_setTokenUri_customErrors() public {
        // token doesn't exist
        vm.expectRevert(TRACE.TokenDoesntExist.selector);
        trace.setTokenUri(1, "hiiii");

        // empty uri
        trace.mint(address(1), "hiii");
        vm.expectRevert(TRACE.EmptyTokenURI.selector);
        trace.setTokenUri(1, "");
    }

    function test_setTokenUri_accessControl(address user) public {
        vm.assume(user != address(this) && user != address(0));
        address[] memory users = new address[](1);
        users[0] = user;

        trace.mint(user, "https://arweave.net/tx_id");

        // verify user can't update metadata
        vm.prank(user);
        vm.expectRevert();
        trace.setTokenUri(1, "ipfs://cid");

        // verify owner can update metadata
        vm.expectEmit(true, true, true, true);
        emit MetadataUpdate(1);
        trace.setTokenUri(1, "ipfs://cid");
        assertEq(trace.tokenURI(1), "ipfs://cid");

        // set admins
        trace.setRole(trace.ADMIN_ROLE(), users, true);

        // verify admin can update metadata
        vm.expectEmit(true, true, true, true);
        emit MetadataUpdate(1);
        vm.prank(user);
        trace.setTokenUri(1, "https://arweave.net/tx_id");
        assertEq(trace.tokenURI(1), "https://arweave.net/tx_id");
    }

    function test_setTokenUri_airdrop(uint256 numAddresses) public {
        // limit fuzz
        vm.assume(numAddresses > 1);
        if (numAddresses > 1000) {
            numAddresses = numAddresses % 999 + 2; // map to 300
        }

        // create addresses
        address[] memory addresses = new address[](numAddresses);
        for (uint256 i = 0; i < numAddresses; i++) {
            addresses[i] = makeAddr(i.toString());
        }

        // airdrop
        trace.airdrop(addresses, "baseUri");

        // create new uris
        for (uint256 i = 1; i <= numAddresses; i++) {
            string memory uri = string(abi.encodePacked("baseUri/", (i - 1).toString()));
            assertEq(trace.tokenURI(i), uri);
        }

        // set token uris
        for (uint256 i = 1; i <= numAddresses; i++) {
            string memory uri = string(abi.encodePacked("ipfs://", (i - 1).toString()));
            trace.setTokenUri(i, uri);
            assertEq(trace.tokenURI(i), uri);
        }
    }

    /// @notice test story functions
    // - regular mint ✅
    // - airdrop ✅
    // - write creator story to existing token w/ proper acccess ✅
    // - write collection story to existing token w/ proper access ✅
    // - write creator story to non-existent token (reverts) ✅
    // - write collection story to non-existent token (reverts) ✅
    // - write collector story reverts
    // - set story status reverts
    function test_story_always_reverts(address user) public {
        vm.expectRevert();
        vm.prank(user);
        trace.setStoryStatus(false);

        vm.expectRevert();
        vm.prank(user);
        trace.addStory(1, "", "hello");
    }

    function test_addCreatorStory_nonExistentTokens() public {
        vm.expectRevert(TRACE.TokenDoesntExist.selector);
        trace.addCreatorStory(1, "XCOPY", "I AM XCOPY");
    }

    function test_story_mint(address collector, address hacker) public {
        // limit fuzz
        vm.assume(collector != address(this) && collector != address(0));
        vm.assume(hacker != address(this));
        trace.mint(collector, "uri");

        // test creator story
        vm.expectEmit(true, true, true, true);
        emit CreatorStory(1, address(this), address(this).toHexString(), "I AM XCOPY");
        trace.addCreatorStory(1, "XCOPY", "I AM XCOPY");

        // test collector can't add creator story
        vm.expectRevert(
            abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, trace.ADMIN_ROLE())
        );
        vm.prank(collector);
        trace.addCreatorStory(1, "XCOPY", "I AM XCOPY");

        // test hacker can't add creator story
        vm.expectRevert(
            abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, trace.ADMIN_ROLE())
        );
        vm.prank(hacker);
        trace.addCreatorStory(1, "XCOPY", "I AM XCOPY");

        // test collection story
        vm.expectEmit(true, true, true, true);
        emit CollectionStory(address(this), address(this).toHexString(), "I AM NOT XCOPY");
        trace.addCollectionStory("NOT XCOPY", "I AM NOT XCOPY");

        // test that collector can't add collection story
        vm.expectRevert(
            abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, trace.ADMIN_ROLE())
        );
        vm.prank(collector);
        trace.addCollectionStory("NOT XCOPY", "I AM NOT XCOPY");

        // test that hacker can't add collection story
        vm.expectRevert(
            abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, trace.ADMIN_ROLE())
        );
        vm.prank(hacker);
        trace.addCollectionStory("NOT XCOPY", "I AM NOT XCOPY");
    }

    function test_story_airdrop(address collector, address hacker) public {
        // limit fuzz
        vm.assume(collector != address(this) && collector != address(0));
        vm.assume(hacker != address(this));
        address[] memory addresses = new address[](2);
        addresses[0] = collector;
        addresses[1] = collector;
        trace.airdrop(addresses, "uri");

        // test creator story
        vm.expectEmit(true, true, true, true);
        emit CreatorStory(1, address(this), address(this).toHexString(), "I AM XCOPY");
        trace.addCreatorStory(1, "XCOPY", "I AM XCOPY");
        vm.expectEmit(true, true, true, true);
        emit CreatorStory(2, address(this), address(this).toHexString(), "I AM XCOPY");
        trace.addCreatorStory(2, "XCOPY", "I AM XCOPY");

        // test collector can't add creator story
        vm.startPrank(collector);
        vm.expectRevert(
            abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, trace.ADMIN_ROLE())
        );
        trace.addCreatorStory(1, "XCOPY", "I AM XCOPY");
        vm.expectRevert(
            abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, trace.ADMIN_ROLE())
        );
        trace.addCreatorStory(2, "XCOPY", "I AM XCOPY");
        vm.stopPrank();

        // test hacker can't add creator story
        vm.startPrank(hacker);
        vm.expectRevert(
            abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, trace.ADMIN_ROLE())
        );
        trace.addCreatorStory(1, "XCOPY", "I AM XCOPY");
        vm.expectRevert(
            abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, trace.ADMIN_ROLE())
        );
        trace.addCreatorStory(2, "XCOPY", "I AM XCOPY");
        vm.stopPrank();

        // test collection story
        vm.expectEmit(true, true, true, true);
        emit CollectionStory(address(this), address(this).toHexString(), "I AM NOT XCOPY");
        trace.addCollectionStory("XCOPY", "I AM NOT XCOPY");
        vm.expectEmit(true, true, true, true);
        emit CollectionStory(address(this), address(this).toHexString(), "I AM NOT XCOPY");
        trace.addCollectionStory("XCOPY", "I AM NOT XCOPY");

        // test that collector can't add collection story
        vm.startPrank(collector);
        vm.expectRevert(
            abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, trace.ADMIN_ROLE())
        );
        trace.addCollectionStory("NOT XCOPY", "I AM NOT XCOPY");
        vm.expectRevert(
            abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, trace.ADMIN_ROLE())
        );
        trace.addCollectionStory("NOT XCOPY", "I AM NOT XCOPY");
        vm.stopPrank();

        // test that hacker can't add collection story
        vm.startPrank(hacker);
        vm.expectRevert(
            abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, trace.ADMIN_ROLE())
        );
        trace.addCollectionStory("NOT XCOPY", "I AM NOT XCOPY");
        vm.expectRevert(
            abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, trace.ADMIN_ROLE())
        );
        trace.addCollectionStory("NOT XCOPY", "I AM NOT XCOPY");
        vm.stopPrank();
    }

    /// @notice blocklist and delegation registry tests
    function test_blocklist(address user, address registry) public {
        vm.expectRevert();
        vm.prank(user);
        trace.setBlockListRegistry(registry);

        assertEq(address(trace.blocklistRegistry()), address(0));
    }

    function test_tlNftDelegationRegistry(address user, address registry) public {
        vm.expectRevert();
        vm.prank(user);
        trace.setNftDelegationRegistry(registry);

        assertEq(address(trace.tlNftDelegationRegistry()), address(0));
    }
}

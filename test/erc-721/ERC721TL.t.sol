// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import "forge-std/Test.sol";
import {Strings} from "openzeppelin/utils/Strings.sol";
import {ERC721TL, ISynergy} from "src/erc-721/ERC721TL.sol";
import {IERC721Errors} from "openzeppelin/interfaces/draft-IERC6093.sol";
import {Initializable} from "openzeppelin/proxy/utils/Initializable.sol";
import {OwnableAccessControlUpgradeable} from "tl-sol-tools/upgradeable/access/OwnableAccessControlUpgradeable.sol";
import {IBlockListRegistry} from "src/interfaces/IBlockListRegistry.sol";
import {ITLNftDelegationRegistry} from "src/interfaces/ITLNftDelegationRegistry.sol";

contract ERC721TLTest is Test {
    using Strings for uint256;
    using Strings for address;

    ERC721TL public tokenContract;
    address public royaltyRecipient = makeAddr("royaltyRecipient");
    address public blocklistRegistry = makeAddr("blocklistRegistry");
    address public nftDelegationRegistry = makeAddr("nftDelegationRegistry");

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event RoleChange(address indexed from, address indexed user, bool indexed approved, bytes32 role);
    event StoryStatusUpdate(address indexed sender, bool indexed status);
    event BlockListRegistryUpdate(
        address indexed sender, address indexed prevBlockListRegistry, address indexed newBlockListRegistry
    );
    event NftDelegationRegistryUpdate(
        address indexed sender, address indexed prevNftDelegationRegistry, address indexed newNftDelegationRegistry
    );
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event MetadataUpdate(uint256 tokenId);
    event SynergyStatusChange(
        address indexed from, uint256 indexed tokenId, ISynergy.SynergyAction indexed action, string uri
    );
    event CollectionStory(address indexed creatorAddress, string creatorName, string story);
    event CreatorStory(uint256 indexed tokenId, address indexed creatorAddress, string creatorName, string story);
    event Story(uint256 indexed tokenId, address indexed collectorAddress, string collectorName, string story);

    function setUp() public {
        address[] memory admins = new address[](0);
        tokenContract = new ERC721TL(false);
        tokenContract.initialize("Test721", "T721", "", royaltyRecipient, 1000, address(this), admins, true, address(0), address(0));
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
        bool enableStory,
        address blockListRegistry,
        address tlNftDelegationRegistry
    ) public {
        // limit fuzz
        vm.assume(defaultRoyaltyRecipient != address(0));
        if (defaultRoyaltyPercentage >= 10_000) {
            defaultRoyaltyPercentage = defaultRoyaltyPercentage % 10_000;
        }
        vm.assume(initOwner != address(0));

        // create contract
        tokenContract = new ERC721TL(false);
        // initialize and verify events thrown (order matters)
        vm.expectEmit(true, true, false, true);
        emit OwnershipTransferred(address(0), initOwner);
        for (uint256 i = 0; i < admins.length; i++) {
            vm.expectEmit(true, true, true, true);
            emit RoleChange(address(this), admins[i], true, tokenContract.ADMIN_ROLE());
        }
        vm.expectEmit(true, true, true, true);
        emit StoryStatusUpdate(address(this), enableStory);
        vm.expectEmit(true, true, true, true);
        emit BlockListRegistryUpdate(address(this), address(0), blockListRegistry);
        vm.expectEmit(true, true, true, true);
        emit NftDelegationRegistryUpdate(address(this), address(0), tlNftDelegationRegistry);
        if (bytes(personalization).length > 0) {
            vm.expectEmit(true, true, true, true);
            emit CollectionStory(address(this), address(this).toHexString(), personalization);
        }
        tokenContract.initialize(
            name,
            symbol,
            personalization,
            defaultRoyaltyRecipient,
            defaultRoyaltyPercentage,
            initOwner,
            admins,
            enableStory,
            blockListRegistry,
            tlNftDelegationRegistry
        );
        assertEq(tokenContract.name(), name);
        assertEq(tokenContract.symbol(), symbol);
        (address recp, uint256 amt) = tokenContract.royaltyInfo(1, 10000);
        assertEq(recp, defaultRoyaltyRecipient);
        assertEq(amt, defaultRoyaltyPercentage);
        assertEq(tokenContract.owner(), initOwner);
        for (uint256 i = 0; i < admins.length; i++) {
            assertTrue(tokenContract.hasRole(tokenContract.ADMIN_ROLE(), admins[i]));
        }
        assertEq(tokenContract.storyEnabled(), enableStory);
        assertEq(address(tokenContract.blocklistRegistry()), blockListRegistry);
        assertEq(address(tokenContract.tlNftDelegationRegistry()), tlNftDelegationRegistry);

        // can't initialize again
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        tokenContract.initialize(
            name,
            symbol,
            personalization,
            defaultRoyaltyRecipient,
            defaultRoyaltyPercentage,
            initOwner,
            admins,
            enableStory,
            blockListRegistry,
            tlNftDelegationRegistry
        );

        // can't get by initializers disabled
        tokenContract = new ERC721TL(true);

        vm.expectRevert(Initializable.InvalidInitialization.selector);
        tokenContract.initialize(
            name,
            symbol,
            personalization,
            defaultRoyaltyRecipient,
            defaultRoyaltyPercentage,
            initOwner,
            admins,
            enableStory,
            blockListRegistry,
            tlNftDelegationRegistry
        );
    }

    /// @notice test ERC-165 support
    function test_supportsInterface() public {
        assertTrue(tokenContract.supportsInterface(0x1c8e024d)); // ICreatorBase
        assertTrue(tokenContract.supportsInterface(0xc74089ae)); // IERC721TL
        assertTrue(tokenContract.supportsInterface(0x8193ebea)); // ISynergy
        assertTrue(tokenContract.supportsInterface(0x2464f17b)); // IStory
        assertTrue(tokenContract.supportsInterface(0x0d23ecb9)); // IStory (old)
        assertTrue(tokenContract.supportsInterface(0x01ffc9a7)); // ERC-165
        assertTrue(tokenContract.supportsInterface(0x80ac58cd)); // ERC-721
        assertTrue(tokenContract.supportsInterface(0x2a55205a)); // ERC-2981
        assertTrue(tokenContract.supportsInterface(0x49064906)); // ERC-4906
    }

    /// @notice test mint contract access approvals
    function test_setApprovedMintContracts(address hacker) public {
        // limit fuzz
        vm.assume(hacker != address(1) && hacker != address(2) && hacker != address(this));

        // variables
        address[] memory minters = new address[](1);
        minters[0] = address(1);
        address[] memory admins = new address[](1);
        admins[0] = address(2);

        // verify rando can't access
        vm.startPrank(hacker);
        vm.expectRevert(abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE()));
        tokenContract.setApprovedMintContracts(minters, true);
        vm.stopPrank();

        // verify admin can access
        tokenContract.setRole(tokenContract.ADMIN_ROLE(), admins, true);
        vm.startPrank(address(2), address(2));
        tokenContract.setApprovedMintContracts(minters, true);
        vm.stopPrank();
        tokenContract.setRole(tokenContract.ADMIN_ROLE(), admins, false);
        assertTrue(tokenContract.hasRole(tokenContract.APPROVED_MINT_CONTRACT(), address(1)));

        // verify minters can't access
        vm.startPrank(address(1));
        vm.expectRevert();
        tokenContract.setApprovedMintContracts(minters, true);
        vm.stopPrank();

        // verify owner can access
        tokenContract.setApprovedMintContracts(minters, false);
        assertFalse(tokenContract.hasRole(tokenContract.APPROVED_MINT_CONTRACT(), address(1)));
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
        vm.expectRevert(ERC721TL.EmptyTokenURI.selector);
        tokenContract.mint(address(this), "");

        vm.expectRevert(ERC721TL.EmptyTokenURI.selector);
        tokenContract.mint(address(this), "", address(1), 10);
    }

    function test_mint_accessControl(address user) public {
        // limit fuzz
        vm.assume(user != address(this));
        vm.assume(user != address(0));

        // ensure user can't call the mint function
        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE()));
        tokenContract.mint(address(this), "uriOne");
        vm.expectRevert(abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE()));
        tokenContract.mint(address(this), "uriOne", address(1), 10);
        vm.stopPrank();

        // grant admin access and ensure that the user can call the mint functions
        address[] memory admins = new address[](1);
        admins[0] = user;
        tokenContract.setRole(tokenContract.ADMIN_ROLE(), admins, true);
        vm.startPrank(user, user);
        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0), address(this), 1);
        tokenContract.mint(address(this), "uriOne");
        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0), address(this), 2);
        tokenContract.mint(address(this), "uriTwo", address(1), 10);
        vm.stopPrank();
        assertEq(tokenContract.balanceOf(address(this)), 2);
        assertEq(tokenContract.ownerOf(1), address(this));
        assertEq(tokenContract.tokenURI(1), "uriOne");
        assertEq(tokenContract.ownerOf(2), address(this));
        assertEq(tokenContract.tokenURI(2), "uriTwo");

        // revoke admin access and ensure that the user can't call the mint function
        tokenContract.setRole(tokenContract.ADMIN_ROLE(), admins, false);
        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE()));
        tokenContract.mint(address(this), "uriOne");
        vm.expectRevert(abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE()));
        tokenContract.mint(address(this), "uriTwo", address(1), 10);
        vm.stopPrank();

        // grant mint contract role and ensure that the user can't call the mint function
        tokenContract.setRole(tokenContract.APPROVED_MINT_CONTRACT(), admins, true);
        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE()));
        tokenContract.mint(address(this), "uriOne");
        vm.expectRevert(abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE()));
        tokenContract.mint(address(this), "uriTwo", address(1), 10);
        vm.stopPrank();

        // revoke mint contract role and ensure that the user can't call the mint function
        tokenContract.setRole(tokenContract.APPROVED_MINT_CONTRACT(), admins, false);
        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE()));
        tokenContract.mint(address(this), "uriOne");
        vm.expectRevert(abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE()));
        tokenContract.mint(address(this), "uriTwo", address(1), 10);
        vm.stopPrank();
    }

    function test_mint(uint16 tokenId, address recipient) public {
        vm.assume(tokenId != 0);
        vm.assume(recipient != address(0));
        if (tokenId > 1000) {
            tokenId = tokenId % 1000 + 1; // map to 1000
        }
        for (uint256 i = 1; i <= tokenId; i++) {
            string memory uri = string(abi.encodePacked("uri_", i.toString()));
            vm.expectEmit(true, true, true, true);
            emit Transfer(address(0), recipient, i);
            tokenContract.mint(recipient, uri);
            assertEq(tokenContract.balanceOf(recipient), i);
            assertEq(tokenContract.ownerOf(i), recipient);
            assertEq(tokenContract.tokenURI(i), uri);
        }

        // ensure ownership throws for non-existent token
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, tokenId + 1));
        tokenContract.ownerOf(tokenId + 1);
        vm.expectRevert(ERC721TL.TokenDoesntExist.selector);
        tokenContract.tokenURI(tokenId + 1);
    }

    function test_mint_withTokenRoyalty(uint16 tokenId, address recipient, address royaltyAddress, uint16 royaltyPercent)
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
            tokenContract.mint(recipient, uri, royaltyAddress, royaltyPercent);
            assertEq(tokenContract.balanceOf(recipient), i);
            assertEq(tokenContract.ownerOf(i), recipient);
            assertEq(tokenContract.tokenURI(i), uri);
            (address recp, uint256 amt) = tokenContract.royaltyInfo(i, 10_000);
            assertEq(recp, royaltyAddress);
            assertEq(amt, royaltyPercent);
        }

        // ensure ownership throws for non-existent token
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, tokenId + 1));
        tokenContract.ownerOf(tokenId + 1);
        vm.expectRevert(ERC721TL.TokenDoesntExist.selector);
        tokenContract.tokenURI(tokenId + 1);
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
            tokenContract.mint(address(this), "uri");
            // transfer to recipient with transferFrom
            vm.expectEmit(true, true, true, true);
            emit Transfer(address(this), recipient, i);
            tokenContract.transferFrom(address(this), recipient, i);
            assertEq(tokenContract.balanceOf(recipient), 1);
            assertEq(tokenContract.ownerOf(i), recipient);
            // transfer to second recipient with safeTransferFrom
            vm.startPrank(recipient, recipient);
            vm.expectEmit(true, true, true, true);
            emit Transfer(recipient, secondRecipient, i);
            tokenContract.safeTransferFrom(recipient, secondRecipient, i);
            assertEq(tokenContract.balanceOf(secondRecipient), i);
            assertEq(tokenContract.ownerOf(i), secondRecipient);
            vm.stopPrank();
        }
    }

    /// @notice test batch mint
    // - access control ✅
    // - proper recipient ✅
    // - transfer event ✅
    // - proper token ids ✅
    // - ownership ✅
    // - balance ✅
    // - transfer to another address ✅
    // - safe transfer to another address ✅
    // - token uris ✅
    function test_batchMint_customErrors() public {
        vm.expectRevert(ERC721TL.MintToZeroAddress.selector);
        tokenContract.batchMint(address(0), 2, "uri");

        vm.expectRevert(ERC721TL.EmptyTokenURI.selector);
        tokenContract.batchMint(address(this), 2, "");

        vm.expectRevert(ERC721TL.BatchSizeTooSmall.selector);
        tokenContract.batchMint(address(this), 1, "baseUri");
    }

    function test_batchMint_accessControl(address user) public {
        vm.assume(user != address(this));
        vm.assume(user != address(0));
        // ensure user can't call the mint function
        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE()));
        tokenContract.batchMint(address(this), 2, "baseUri");
        vm.stopPrank();

        // grant admin access and ensure that the user can call the mint function
        address[] memory admins = new address[](1);
        admins[0] = user;
        tokenContract.setRole(tokenContract.ADMIN_ROLE(), admins, true);
        vm.startPrank(user);
        uint256 start = tokenContract.totalSupply() + 1;
        uint256 end = start + 1;
        for (uint256 id = start; id < end + 1; ++id) {
            vm.expectEmit(true, true, true, true);
            emit Transfer(address(0), address(this), id);
        }
        tokenContract.batchMint(address(this), 2, "baseUri");
        vm.stopPrank();
        assertEq(tokenContract.balanceOf(address(this)), 2);
        assertEq(tokenContract.ownerOf(1), address(this));
        assertEq(tokenContract.ownerOf(2), address(this));
        assertEq(tokenContract.tokenURI(1), "baseUri/0");
        assertEq(tokenContract.tokenURI(2), "baseUri/1");

        // revoke admin access and ensure that the user can't call the mint function
        tokenContract.setRole(tokenContract.ADMIN_ROLE(), admins, false);
        vm.startPrank(user, user);
        vm.expectRevert(abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE()));
        tokenContract.batchMint(address(this), 2, "baseUri");
        vm.stopPrank();

        // grant mint contract role and ensure that the user can't call the mint function
        tokenContract.setRole(tokenContract.APPROVED_MINT_CONTRACT(), admins, true);
        vm.startPrank(user, user);
        vm.expectRevert(abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE()));
        tokenContract.batchMint(address(this), 2, "baseUri");
        vm.stopPrank();

        // revoke mint contract role and ensure that the user can't call the mint function
        tokenContract.setRole(tokenContract.APPROVED_MINT_CONTRACT(), admins, false);
        vm.startPrank(user, user);
        vm.expectRevert(abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE()));
        tokenContract.batchMint(address(this), 2, "baseUri");
        vm.stopPrank();
    }

    function test_batchMint(uint128 numTokens, address recipient) public {
        vm.assume(numTokens > 1);
        vm.assume(recipient != address(0));
        if (numTokens > 1000) {
            numTokens = numTokens % 1000 + 2; // map to 1000
        }
        uint256 start = tokenContract.totalSupply() + 1;
        uint256 end = start + numTokens - 1;
        for (uint256 id = start; id < end + 1; ++id) {
            vm.expectEmit(true, true, true, false);
            emit Transfer(address(0), recipient, id);
        }
        tokenContract.batchMint(recipient, numTokens, "baseUri");
        assertEq(tokenContract.balanceOf(recipient), numTokens);
        for (uint256 i = 1; i <= numTokens; i++) {
            string memory uri = string(abi.encodePacked("baseUri/", (i - start).toString()));
            assertEq(tokenContract.ownerOf(i), recipient);
            assertEq(tokenContract.tokenURI(i), uri);
        }

        // ensure ownership throws for non-existent token
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, numTokens + 1));
        tokenContract.ownerOf(numTokens + 1);
        vm.expectRevert(ERC721TL.TokenDoesntExist.selector);
        tokenContract.tokenURI(numTokens + 1);

        // test mint after metadata
        tokenContract.mint(address(this), "newUri");
        assertEq(tokenContract.ownerOf(numTokens + 1), address(this));
        assertEq(tokenContract.tokenURI(numTokens + 1), "newUri");
    }

    function test_batchMint_thenTransfer(uint128 numTokens, address recipient, address secondRecipient) public {
        vm.assume(recipient != address(0));
        vm.assume(secondRecipient != address(0));
        vm.assume(recipient != secondRecipient);
        vm.assume(recipient.code.length == 0);
        vm.assume(secondRecipient.code.length == 0);
        vm.assume(numTokens > 1);
        if (numTokens > 1000) {
            numTokens = numTokens % 1000 + 2; // map to 1000
        }
        tokenContract.batchMint(address(this), numTokens, "baseUri");
        // test transferFrom on first half of tokens
        for (uint256 i = 1; i < numTokens / 2; i++) {
            // transfer to recipient with transferFrom
            vm.expectEmit(true, true, true, false);
            emit Transfer(address(this), recipient, i);
            tokenContract.transferFrom(address(this), recipient, i);
            assertEq(tokenContract.balanceOf(recipient), 1);
            assertEq(tokenContract.ownerOf(i), recipient);
            // transfer to second recipient with safeTransferFrom
            vm.startPrank(recipient, recipient);
            vm.expectEmit(true, true, true, false);
            emit Transfer(recipient, secondRecipient, i);
            tokenContract.safeTransferFrom(recipient, secondRecipient, i);
            assertEq(tokenContract.balanceOf(secondRecipient), i);
            assertEq(tokenContract.ownerOf(i), secondRecipient);
            vm.stopPrank();
        }
        // test safeTransferFrom on second half of tokens
        for (uint256 i = numTokens / 2; i <= numTokens; i++) {
            // transfer to recipient with transferFrom
            vm.expectEmit(true, true, true, false);
            emit Transfer(address(this), recipient, i);
            tokenContract.safeTransferFrom(address(this), recipient, i);
            assertEq(tokenContract.balanceOf(recipient), 1);
            assertEq(tokenContract.ownerOf(i), recipient);
            // transfer to second recipient with safeTransferFrom
            vm.startPrank(recipient, recipient);
            vm.expectEmit(true, true, true, false);
            emit Transfer(recipient, secondRecipient, i);
            tokenContract.safeTransferFrom(recipient, secondRecipient, i);
            assertEq(tokenContract.balanceOf(secondRecipient), i);
            assertEq(tokenContract.ownerOf(i), secondRecipient);
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
        vm.expectRevert(ERC721TL.EmptyTokenURI.selector);
        tokenContract.airdrop(addresses, "");

        vm.expectRevert(ERC721TL.AirdropTooFewAddresses.selector);
        tokenContract.airdrop(addresses, "baseUri");
    }

    function test_airdrop_accessControl(address user) public {
        vm.assume(user != address(this));
        vm.assume(user != address(0));
        address[] memory addresses = new address[](2);
        addresses[0] = address(1);
        addresses[1] = address(2);
        // ensure user can't call the airdrop function
        vm.startPrank(user, user);
        vm.expectRevert(abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE()));
        tokenContract.airdrop(addresses, "baseUri");
        vm.stopPrank();

        // grant admin access and ensure that the user can call the airdrop function
        address[] memory admins = new address[](1);
        admins[0] = user;
        tokenContract.setRole(tokenContract.ADMIN_ROLE(), admins, true);
        vm.startPrank(user, user);
        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0), address(1), 1);
        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0), address(2), 2);
        tokenContract.airdrop(addresses, "baseUri");
        vm.stopPrank();
        assertEq(tokenContract.balanceOf(address(1)), 1);
        assertEq(tokenContract.balanceOf(address(2)), 1);
        assertEq(tokenContract.ownerOf(1), address(1));
        assertEq(tokenContract.ownerOf(2), address(2));
        assertEq(tokenContract.tokenURI(1), "baseUri/0");
        assertEq(tokenContract.tokenURI(2), "baseUri/1");

        // revoke admin access and ensure that the user can't call the airdrop function
        tokenContract.setRole(tokenContract.ADMIN_ROLE(), admins, false);
        vm.startPrank(user, user);
        vm.expectRevert(abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE()));
        tokenContract.airdrop(addresses, "baseUri");
        vm.stopPrank();

        // grant mint contract role and ensure that the user can't call the airdrop function
        tokenContract.setRole(tokenContract.APPROVED_MINT_CONTRACT(), admins, true);
        vm.startPrank(user, user);
        vm.expectRevert(abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE()));
        tokenContract.airdrop(addresses, "baseUri");
        vm.stopPrank();

        // revoke mint contract role and ensure that the user can't call the airdrop function
        tokenContract.setRole(tokenContract.APPROVED_MINT_CONTRACT(), admins, false);
        vm.startPrank(user, user);
        vm.expectRevert(abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE()));
        tokenContract.airdrop(addresses, "baseUri");
        vm.stopPrank();
    }

    function test_airdrop(uint16 numAddresses) public {
        vm.assume(numAddresses > 1);
        if (numAddresses > 1000) {
            numAddresses = numAddresses % 299 + 2; // map to 300
        }
        address[] memory addresses = new address[](numAddresses);
        for (uint256 i = 0; i < numAddresses; i++) {
            addresses[i] = makeAddr(i.toString());
        }
        for (uint256 i = 1; i <= numAddresses; i++) {
            vm.expectEmit(true, true, true, true);
            emit Transfer(address(0), addresses[i - 1], i);
        }
        tokenContract.airdrop(addresses, "baseUri");
        for (uint256 i = 1; i <= numAddresses; i++) {
            string memory uri = string(abi.encodePacked("baseUri/", (i - 1).toString()));
            assertEq(tokenContract.balanceOf(addresses[i - 1]), 1);
            assertEq(tokenContract.ownerOf(i), addresses[i - 1]);
            assertEq(tokenContract.tokenURI(i), uri);
        }

        // ensure ownership throws for non-existent token
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, numAddresses + 1));
        tokenContract.ownerOf(numAddresses + 1);
        vm.expectRevert(ERC721TL.TokenDoesntExist.selector);
        tokenContract.tokenURI(numAddresses + 1);

        // test mint after metadata
        tokenContract.mint(address(this), "newUri");
        assertEq(tokenContract.ownerOf(numAddresses + 1), address(this));
        assertEq(tokenContract.tokenURI(numAddresses + 1), "newUri");
    }

    function test_airdrop_thenTransfer(uint16 numAddresses, address recipient) public {
        vm.assume(numAddresses > 1);
        vm.assume(recipient != address(0));
        vm.assume(recipient.code.length == 0);
        if (numAddresses > 1000) {
            numAddresses = numAddresses % 299 + 2; // map to 300
        }
        address[] memory addresses = new address[](numAddresses);
        for (uint256 i = 0; i < numAddresses; i++) {
            if (makeAddr(i.toString()) == recipient) {
                addresses[i] = makeAddr("hello");
            } else {
                addresses[i] = makeAddr(i.toString());
            }
        }
        tokenContract.airdrop(addresses, "baseUri");
        for (uint256 i = 1; i < numAddresses / 2; i++) {
            vm.startPrank(addresses[i - 1], addresses[i - 1]);
            vm.expectEmit(true, true, true, false);
            emit Transfer(addresses[i - 1], recipient, i);
            tokenContract.transferFrom(addresses[i - 1], recipient, i);
            vm.stopPrank();
            assertEq(tokenContract.balanceOf(recipient), i);
            assertEq(tokenContract.balanceOf(addresses[i - 1]), 0);
            assertEq(tokenContract.ownerOf(i), recipient);
        }
        for (uint256 i = numAddresses / 2; i <= numAddresses; i++) {
            vm.startPrank(addresses[i - 1], addresses[i - 1]);
            vm.expectEmit(true, true, true, false);
            emit Transfer(addresses[i - 1], recipient, i);
            tokenContract.safeTransferFrom(addresses[i - 1], recipient, i);
            vm.stopPrank();
            assertEq(tokenContract.balanceOf(recipient), i);
            assertEq(tokenContract.balanceOf(addresses[i - 1]), 0);
            assertEq(tokenContract.ownerOf(i), recipient);
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
        tokenContract.setRole(tokenContract.APPROVED_MINT_CONTRACT(), minters, true);
        vm.expectRevert(ERC721TL.EmptyTokenURI.selector);
        tokenContract.externalMint(address(this), "");
    }

    function test_external_mintAccessControl(address user) public {
        vm.assume(user != address(this));
        vm.assume(user != address(0));
        address[] memory addresses = new address[](2);
        addresses[0] = address(1);
        addresses[1] = address(2);
        // ensure user can't call the airdrop function
        vm.startPrank(user, user);
        vm.expectRevert(abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotSpecifiedRole.selector, tokenContract.APPROVED_MINT_CONTRACT()));
        tokenContract.externalMint(address(this), "uri");
        vm.stopPrank();

        // grant minter access and ensure that the user can call the airdrop function
        address[] memory minters = new address[](1);
        minters[0] = user;
        tokenContract.setRole(tokenContract.APPROVED_MINT_CONTRACT(), minters, true);
        vm.startPrank(user, user);
        vm.expectEmit(true, true, true, false);
        emit Transfer(address(0), address(this), 1);
        tokenContract.externalMint(address(this), "uri");
        vm.stopPrank();
        assertEq(tokenContract.balanceOf(address(this)), 1);
        assertEq(tokenContract.ownerOf(1), address(this));
        assertEq(tokenContract.tokenURI(1), "uri");

        // revoke mint access and ensure that the user can't call the airdrop function
        tokenContract.setRole(tokenContract.APPROVED_MINT_CONTRACT(), minters, false);
        vm.startPrank(user, user);
        vm.expectRevert(abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotSpecifiedRole.selector, tokenContract.APPROVED_MINT_CONTRACT()));
        tokenContract.externalMint(address(this), "uri");
        vm.stopPrank();

        // grant admin role and ensure that the user can't call the airdrop function
        tokenContract.setRole(tokenContract.ADMIN_ROLE(), minters, true);
        vm.startPrank(user, user);
        vm.expectRevert(abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotSpecifiedRole.selector, tokenContract.APPROVED_MINT_CONTRACT()));
        tokenContract.externalMint(address(this), "uri");
        vm.stopPrank();

        // revoke admin role and ensure that the user can't call the airdrop function
        tokenContract.setRole(tokenContract.ADMIN_ROLE(), minters, false);
        vm.startPrank(user, user);
        vm.expectRevert(abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotSpecifiedRole.selector, tokenContract.APPROVED_MINT_CONTRACT()));
        tokenContract.externalMint(address(this), "uri");
        vm.stopPrank();
    }

    function test_externalMint(address recipient, string memory uri, uint16 numTokens) public {
        vm.assume(recipient != address(0));
        vm.assume(recipient != address(1));
        vm.assume(bytes(uri).length > 0);
        vm.assume(numTokens > 0);
        if (numTokens > 1000) {
            numTokens = numTokens % 1000 + 1;
        }
        address[] memory minters = new address[](1);
        minters[0] = address(1);
        tokenContract.setRole(tokenContract.APPROVED_MINT_CONTRACT(), minters, true);
        for (uint256 i = 1; i <= numTokens; i++) {
            vm.startPrank(address(1), address(1));
            vm.expectEmit(true, true, true, false);
            emit Transfer(address(0), recipient, i);
            tokenContract.externalMint(recipient, uri);
            vm.stopPrank();
            assertEq(tokenContract.balanceOf(recipient), i);
            assertEq(tokenContract.ownerOf(i), recipient);
            assertEq(tokenContract.tokenURI(i), uri);
        }

        // ensure ownership throws for non-existent token
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, numTokens + 1));
        tokenContract.ownerOf(numTokens + 1);
        vm.expectRevert(ERC721TL.TokenDoesntExist.selector);
        tokenContract.tokenURI(numTokens + 1);
    }

    function test_externalMint_thenTransfer(
        address recipient,
        string memory uri,
        uint16 numTokens,
        address transferRecipient
    ) public {
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
        address[] memory minters = new address[](1);
        minters[0] = address(1);
        tokenContract.setRole(tokenContract.APPROVED_MINT_CONTRACT(), minters, true);
        for (uint256 i = 1; i <= numTokens; i++) {
            vm.startPrank(address(1), address(1));
            tokenContract.externalMint(recipient, uri);
            vm.stopPrank();
            vm.startPrank(recipient, recipient);
            vm.expectEmit(true, true, true, false);
            emit Transfer(recipient, transferRecipient, i);
            tokenContract.transferFrom(recipient, transferRecipient, i);
            vm.stopPrank();
            assertEq(tokenContract.balanceOf(transferRecipient), 1);
            assertEq(tokenContract.ownerOf(i), transferRecipient);
            vm.startPrank(transferRecipient, transferRecipient);
            vm.expectEmit(true, true, true, false);
            emit Transfer(transferRecipient, address(1), i);
            tokenContract.safeTransferFrom(transferRecipient, address(1), i);
            vm.stopPrank();
            assertEq(tokenContract.balanceOf(address(1)), i);
            assertEq(tokenContract.ownerOf(i), address(1));
        }
    }

    /// @notice test mint options in a row
    // - randomly make sure that can mint in a row and that there aren't overlapping token ids ✅
    function test_mints_combined(uint8 n1, uint8 n2, uint8 n3, uint8 n4, uint16 batchSize, uint16 numAddresses)
        public
    {
        address[] memory minters = new address[](1);
        minters[0] = address(1);
        tokenContract.setRole(tokenContract.APPROVED_MINT_CONTRACT(), minters, true);
        vm.assume(batchSize > 1);
        vm.assume(numAddresses > 1);
        if (numAddresses > 1000) {
            numAddresses = numAddresses % 299 + 2; // map to 300
        }
        address[] memory addresses = new address[](numAddresses);
        for (uint256 i = 0; i < numAddresses; i++) {
            addresses[i] = makeAddr(i.toString());
        }
        n1 = n1 % 4;
        n2 = n2 % 4;
        n3 = n3 % 4;
        n4 = n4 % 4;

        uint256 id = tokenContract.totalSupply();
        if (n1 == 0) {
            tokenContract.mint(address(this), "uri");
            assertEq(tokenContract.totalSupply(), id + 1);
            id += 1;
        } else if (n1 == 1) {
            tokenContract.batchMint(address(this), batchSize, "uri");
            assertEq(tokenContract.totalSupply(), id + batchSize);
            id += batchSize;
        } else if (n1 == 2) {
            tokenContract.airdrop(addresses, "uri");
            assertEq(tokenContract.totalSupply(), id + numAddresses);
            id += numAddresses;
        } else {
            vm.startPrank(address(1), address(1));
            tokenContract.externalMint(address(this), "uri");
            vm.stopPrank();
            assertEq(tokenContract.totalSupply(), id + 1);
            id += 1;
        }

        if (n2 == 0) {
            tokenContract.mint(address(this), "uri");
            assertEq(tokenContract.totalSupply(), id + 1);
            id += 1;
        } else if (n2 == 1) {
            tokenContract.batchMint(address(this), batchSize, "uri");
            assertEq(tokenContract.totalSupply(), id + batchSize);
            id += batchSize;
        } else if (n2 == 2) {
            tokenContract.airdrop(addresses, "uri");
            assertEq(tokenContract.totalSupply(), id + numAddresses);
            id += numAddresses;
        } else {
            vm.startPrank(address(1), address(1));
            tokenContract.externalMint(address(this), "uri");
            vm.stopPrank();
            assertEq(tokenContract.totalSupply(), id + 1);
            id += 1;
        }

        if (n3 == 0) {
            tokenContract.mint(address(this), "uri");
            assertEq(tokenContract.totalSupply(), id + 1);
            id += 1;
        } else if (n3 == 1) {
            tokenContract.batchMint(address(this), batchSize, "uri");
            assertEq(tokenContract.totalSupply(), id + batchSize);
            id += batchSize;
        } else if (n3 == 2) {
            tokenContract.airdrop(addresses, "uri");
            assertEq(tokenContract.totalSupply(), id + numAddresses);
            id += numAddresses;
        } else {
            vm.startPrank(address(1), address(1));
            tokenContract.externalMint(address(this), "uri");
            vm.stopPrank();
            assertEq(tokenContract.totalSupply(), id + 1);
            id += 1;
        }

        if (n4 == 0) {
            tokenContract.mint(address(this), "uri");
            assertEq(tokenContract.totalSupply(), id + 1);
            id += 1;
        } else if (n4 == 1) {
            tokenContract.batchMint(address(this), batchSize, "uri");
            assertEq(tokenContract.totalSupply(), id + batchSize);
            id += batchSize;
        } else if (n4 == 2) {
            tokenContract.airdrop(addresses, "uri");
            assertEq(tokenContract.totalSupply(), id + numAddresses);
            id += numAddresses;
        } else {
            vm.startPrank(address(1), address(1));
            tokenContract.externalMint(address(this), "uri");
            vm.stopPrank();
            assertEq(tokenContract.totalSupply(), id + 1);
            id += 1;
        }

        // ensure ownership throws for non-existent token
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, id + 1));
        tokenContract.ownerOf(id + 1);
        vm.expectRevert(ERC721TL.TokenDoesntExist.selector);
        tokenContract.tokenURI(id + 1);
    }

    /// @notice test burn
    // - access control ✅
    // - token uri (non-existent) ✅
    // - burn from regular mint ✅
    // - burn from batch mint ✅
    // - burn from airdrop ✅
    // - burn from external mint ✅
    // - burn after transfer ✅
    // - burn after safe transfer ✅
    // - transfer event ✅
    // - ownership ✅
    // - balance ✅
    function test_burn_nonExistentToken(uint16 tokenId) public {
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, tokenId));
        tokenContract.burn(tokenId);
    }

    function test_burn_accessControl(uint16 tokenId, address collector, address hacker) public {
        vm.assume(tokenId != 0);
        vm.assume(collector != address(0));
        vm.assume(collector != address(this));
        vm.assume(collector != hacker);
        vm.assume(hacker != address(0));
        // mint spare tokens to this address
        if (tokenId > 2) {
            tokenContract.batchMint(address(this), tokenId - 1, "uri");
            assertEq(tokenContract.totalSupply(), tokenId - 1);
        } else if (tokenId == 2) {
            tokenContract.mint(address(this), "uri");
        }
        // mint tokenId to collector
        tokenContract.mint(collector, "uriTokenId");
        assertEq(tokenContract.balanceOf(collector), 1);
        assertEq(tokenContract.tokenURI(tokenId), "uriTokenId");
        assertEq(tokenContract.ownerOf(tokenId), collector);

        // verify hacker can't burn
        vm.startPrank(hacker, hacker);
        vm.expectRevert(ERC721TL.CallerNotApprovedOrOwner.selector);
        tokenContract.burn(tokenId);
        vm.stopPrank();

        // verify hacker with admin access can't burn
        address[] memory addys = new address[](1);
        addys[0] = hacker;
        tokenContract.setRole(tokenContract.ADMIN_ROLE(), addys, true);
        vm.startPrank(hacker, hacker);
        vm.expectRevert(ERC721TL.CallerNotApprovedOrOwner.selector);
        tokenContract.burn(tokenId);
        vm.stopPrank();
        tokenContract.setRole(tokenContract.ADMIN_ROLE(), addys, false);

        // verify hacker with minter access can't burn
        tokenContract.setRole(tokenContract.APPROVED_MINT_CONTRACT(), addys, true);
        vm.startPrank(hacker, hacker);
        vm.expectRevert(ERC721TL.CallerNotApprovedOrOwner.selector);
        tokenContract.burn(tokenId);
        vm.stopPrank();
        tokenContract.setRole(tokenContract.APPROVED_MINT_CONTRACT(), addys, false);

        // veirfy owner can't burn
        vm.expectRevert(ERC721TL.CallerNotApprovedOrOwner.selector);
        tokenContract.burn(tokenId);

        // verify collector can burn tokenId
        vm.expectEmit(true, true, true, true);
        emit Transfer(collector, address(0), tokenId);
        vm.startPrank(collector, collector);
        tokenContract.burn(tokenId);
        vm.stopPrank();

        // ensure 
        vm.expectRevert(ERC721TL.TokenDoesntExist.selector);
        tokenContract.tokenURI(tokenId);
        vm.expectRevert();
        tokenContract.ownerOf(tokenId);
        assertEq(tokenContract.balanceOf(collector), 0);
    }

    function test_burn_mint(uint16 tokenId, address collector, address operator) public {
        vm.assume(tokenId != 0);
        vm.assume(collector != address(this));
        vm.assume(collector != address(0));
        vm.assume(collector != operator);
        vm.assume(operator != address(0));
        if (tokenId > 1000) {
            tokenId = tokenId % 1000 + 1;
        }

        // mint spare tokens to this address
        if (tokenId > 2) {
            tokenContract.batchMint(address(this), tokenId - 1, "uri");
            assertEq(tokenContract.totalSupply(), tokenId - 1);
        } else if (tokenId == 2) {
            tokenContract.mint(address(this), "uri");
        }

        // mint tokenId & tokenId + 1 to collector
        tokenContract.mint(collector, "uriOne");
        tokenContract.mint(collector, "uriTwo");
        tokenContract.mint(collector, "uriThree");

        // verify collector can burn tokenId
        vm.startPrank(collector, collector);
        vm.expectEmit(true, true, true, true);
        emit Transfer(collector, address(0), tokenId);
        tokenContract.burn(tokenId);
        vm.stopPrank();
        assertEq(tokenContract.balanceOf(collector), 2);
        vm.expectRevert(ERC721TL.TokenDoesntExist.selector);
        tokenContract.tokenURI(tokenId);
        vm.expectRevert();
        tokenContract.ownerOf(tokenId);

        // verify operator can't burn
        vm.startPrank(operator, operator);
        vm.expectRevert(ERC721TL.CallerNotApprovedOrOwner.selector);
        tokenContract.burn(tokenId + 1);
        vm.stopPrank();

        // grant operator rights and verify can burn tokenId + 1 &  + 2
        vm.startPrank(collector, collector);
        tokenContract.approve(operator, tokenId + 1);
        vm.stopPrank();

        // can burn tokenId + 1
        vm.startPrank(operator, operator);
        vm.expectEmit(true, true, true, true);
        emit Transfer(collector, address(0), tokenId + 1);
        tokenContract.burn(tokenId + 1);
        vm.stopPrank();
        assertEq(tokenContract.balanceOf(collector), 1);
        vm.expectRevert(ERC721TL.TokenDoesntExist.selector);
        tokenContract.tokenURI(tokenId + 1);
        vm.expectRevert();
        tokenContract.ownerOf(tokenId + 1);

        // set approval for all
        vm.startPrank(collector, collector);
        tokenContract.setApprovalForAll(operator, true);
        vm.stopPrank();

        // can burn tokenId + 2
        vm.startPrank(operator, operator);
        vm.expectEmit(true, true, true, false);
        emit Transfer(collector, address(0), tokenId + 2);
        tokenContract.burn(tokenId + 2);
        vm.stopPrank();
        assertEq(tokenContract.balanceOf(collector), 0);
        vm.expectRevert(ERC721TL.TokenDoesntExist.selector);
        tokenContract.tokenURI(tokenId + 2);
        vm.expectRevert();
        tokenContract.ownerOf(tokenId + 2);
    }

    function test_burn_batchMint(uint16 batchSize, address collector, address operator) public {
        vm.assume(collector != address(0) && collector != operator && operator != address(0));
        if (batchSize < 2) {
            batchSize = 2;
        }
        if (batchSize > 300) {
            batchSize = batchSize % 299 + 2;
        }
        // batch mint to collector
        tokenContract.batchMint(collector, batchSize, "baseUri");
        // verify collector can burn the batch
        for (uint256 i = 1; i <= batchSize; i++) {
            vm.startPrank(collector, collector);
            vm.expectEmit(true, true, true, false);
            emit Transfer(collector, address(0), i);
            tokenContract.burn(i);
            vm.stopPrank();
            assertEq(tokenContract.balanceOf(collector), batchSize - i);
            vm.expectRevert(ERC721TL.TokenDoesntExist.selector);
            tokenContract.tokenURI(i);
            vm.expectRevert();
            tokenContract.ownerOf(i);
        }

        // batch mint again to collector
        tokenContract.batchMint(collector, batchSize, "baseUri");

        // verify that operator can't burn
        for (uint256 i = batchSize + 1; i <= 2 * batchSize; i++) {
            vm.startPrank(operator, operator);
            vm.expectRevert(ERC721TL.CallerNotApprovedOrOwner.selector);
            tokenContract.burn(i);
            vm.stopPrank();
        }

        // grant operator rights for each token and burn
        for (uint256 i = batchSize + 1; i <= 2 * batchSize; i++) {
            vm.startPrank(collector, collector);
            tokenContract.approve(operator, i);
            vm.stopPrank();
            vm.startPrank(collector, collector);
            vm.expectEmit(true, true, true, true);
            emit Transfer(collector, address(0), i);
            tokenContract.burn(i);
            vm.stopPrank();
            assertEq(tokenContract.balanceOf(collector), 2 * batchSize - i);
            vm.expectRevert(ERC721TL.TokenDoesntExist.selector);
            tokenContract.tokenURI(i);
            vm.expectRevert();
            tokenContract.ownerOf(i);
        }

        // mint batch again
        tokenContract.batchMint(collector, batchSize, "baseUri");
        vm.startPrank(collector, collector);
        tokenContract.setApprovalForAll(operator, true);
        vm.stopPrank();

        // verify operator can burn the batch
        for (uint256 i = 2 * batchSize + 1; i <= 3 * batchSize; i++) {
            vm.startPrank(collector, collector);
            vm.expectEmit(true, true, true, true);
            emit Transfer(collector, address(0), i);
            tokenContract.burn(i);
            vm.stopPrank();
            assertEq(tokenContract.balanceOf(collector), 3 * batchSize - i);
            vm.expectRevert(ERC721TL.TokenDoesntExist.selector);
            tokenContract.tokenURI(i);
            vm.expectRevert();
            tokenContract.ownerOf(i);
        }
    }

    function test_burn_airdrop(uint16 numAddresses, address operator) public {
        vm.assume(numAddresses > 1);
        if (numAddresses > 300) {
            numAddresses = numAddresses % 299 + 2; // map to 300
        }
        address[] memory addresses = new address[](numAddresses);
        for (uint256 i = 0; i < numAddresses; i++) {
            if (makeAddr(i.toString()) == operator) {
                addresses[i] = makeAddr("hello");
            } else {
                addresses[i] = makeAddr(i.toString());
            }
        }
        vm.assume(operator != address(0));

        // airdrop to addresses
        tokenContract.airdrop(addresses, "baseUri");

        // verify address can burn
        uint256 limit = numAddresses;
        uint256 offset = 1;
        for (uint256 i = 0; i < limit; i++) {
            uint256 id = i + offset;
            vm.startPrank(addresses[i], addresses[i]);
            vm.expectEmit(true, true, true, true);
            emit Transfer(addresses[i], address(0), id);
            tokenContract.burn(id);
            vm.stopPrank();
            assertEq(tokenContract.balanceOf(addresses[i]), 0);
            vm.expectRevert(ERC721TL.TokenDoesntExist.selector);
            tokenContract.tokenURI(id);
            vm.expectRevert();
            tokenContract.ownerOf(id);
        }

        // airdrop again
        tokenContract.airdrop(addresses, "baseUri");

        // verify operator can't burn
        limit = numAddresses;
        offset = numAddresses + 1;
        for (uint256 i = 0; i < limit; i++) {
            uint256 id = i + offset;
            vm.startPrank(operator, operator);
            vm.expectRevert(ERC721TL.CallerNotApprovedOrOwner.selector);
            tokenContract.burn(id);
            vm.stopPrank();
        }

        // grant operator rights for each token and burn
        for (uint256 i = 0; i < limit; i++) {
            uint256 id = i + offset;
            vm.startPrank(addresses[i], addresses[i]);
            tokenContract.approve(operator, id);
            vm.stopPrank();
            vm.startPrank(addresses[i], addresses[i]);
            vm.expectEmit(true, true, true, true);
            emit Transfer(addresses[i], address(0), id);
            tokenContract.burn(id);
            vm.stopPrank();
            assertEq(tokenContract.balanceOf(addresses[i]), 0);
            vm.expectRevert(ERC721TL.TokenDoesntExist.selector);
            tokenContract.tokenURI(id);
            vm.expectRevert();
            tokenContract.ownerOf(id);
        }

        // airdrop again
        tokenContract.airdrop(addresses, "baseUri");

        // verify operator can burn the batch
        limit = numAddresses;
        offset = 2 * numAddresses + 1;
        for (uint256 i = 0; i < limit; i++) {
            uint256 id = i + offset;
            vm.startPrank(addresses[i], addresses[i]);
            tokenContract.setApprovalForAll(operator, true);
            vm.stopPrank();
            vm.startPrank(addresses[i], addresses[i]);
            vm.expectEmit(true, true, true, false);
            emit Transfer(addresses[i], address(0), id);
            tokenContract.burn(id);
            vm.stopPrank();
            assertEq(tokenContract.balanceOf(addresses[i]), 0);
            vm.expectRevert(ERC721TL.TokenDoesntExist.selector);
            tokenContract.tokenURI(id);
            vm.expectRevert();
            tokenContract.ownerOf(id);
        }
    }

    function test_burn_externalMint(uint16 tokenId, address collector, address operator) public {
        vm.assume(tokenId != 0);
        vm.assume(collector != address(this));
        vm.assume(collector != address(0));
        vm.assume(collector != operator);
        vm.assume(operator != address(0));
        if (tokenId > 1000) {
            tokenId = tokenId % 1000 + 1;
        }

        // mint spare tokens to this address
        if (tokenId > 2) {
            tokenContract.batchMint(address(this), tokenId - 1, "uri");
            assertEq(tokenContract.totalSupply(), tokenId - 1);
        } else if (tokenId == 2) {
            tokenContract.mint(address(this), "uri");
        }
        address[] memory minters = new address[](1);
        minters[0] = address(1);
        tokenContract.setRole(tokenContract.APPROVED_MINT_CONTRACT(), minters, true);

        // mint tokenId & tokenId + 1 to collector
        vm.startPrank(address(1), address(1));
        tokenContract.externalMint(collector, "uriOne");
        tokenContract.externalMint(collector, "uriTwo");
        tokenContract.externalMint(collector, "uriThree");
        vm.stopPrank();

        // verify collector can burn tokenId
        vm.startPrank(collector, collector);
        vm.expectEmit(true, true, true, false);
        emit Transfer(collector, address(0), tokenId);
        tokenContract.burn(tokenId);
        vm.stopPrank();
        assertEq(tokenContract.balanceOf(collector), 2);
        vm.expectRevert(ERC721TL.TokenDoesntExist.selector);
        tokenContract.tokenURI(tokenId);
        vm.expectRevert();
        tokenContract.ownerOf(tokenId);

        // verify operator can't burn
        vm.startPrank(operator, operator);
        vm.expectRevert(ERC721TL.CallerNotApprovedOrOwner.selector);
        tokenContract.burn(tokenId + 1);
        vm.stopPrank();

        // grant operator rights and verify can burn
        vm.startPrank(collector, collector);
        tokenContract.approve(operator, tokenId + 1);
        vm.stopPrank();

        // verify operator can burn tokenId + 1
        vm.startPrank(operator, operator);
        vm.expectEmit(true, true, true, true);
        emit Transfer(collector, address(0), tokenId + 1);
        tokenContract.burn(tokenId + 1);
        vm.stopPrank();
        assertEq(tokenContract.balanceOf(collector), 1);
        vm.expectRevert(ERC721TL.TokenDoesntExist.selector);
        tokenContract.tokenURI(tokenId + 1);
        vm.expectRevert();
        tokenContract.ownerOf(tokenId + 1);

        // set approval for all
        vm.startPrank(collector, collector);
        tokenContract.setApprovalForAll(operator, true);
        vm.stopPrank();

        // ensure operator can burn tokenId + 2
        vm.startPrank(operator, operator);
        vm.expectEmit(true, true, true, false);
        emit Transfer(collector, address(0), tokenId + 2);
        tokenContract.burn(tokenId + 2);
        vm.stopPrank();
        assertEq(tokenContract.balanceOf(collector), 0);
        vm.expectRevert(ERC721TL.TokenDoesntExist.selector);
        tokenContract.tokenURI(tokenId + 2);
        vm.expectRevert();
        tokenContract.ownerOf(tokenId + 2);
    }

    function test_burn_afterTransfer(uint16 tokenId, address collector, address operator) public {
        vm.assume(tokenId != 0);
        vm.assume(collector != address(this));
        vm.assume(collector != address(0));
        vm.assume(collector != operator);
        vm.assume(operator != address(0));
        if (tokenId > 1000) {
            tokenId = tokenId % 1000 + 1;
        }

        // mint spare tokens to this address
        if (tokenId > 2) {
            tokenContract.batchMint(address(this), tokenId - 1, "uri");
            assertEq(tokenContract.totalSupply(), tokenId - 1);
        } else if (tokenId == 2) {
            tokenContract.mint(address(this), "uri");
        }

        // mint tokenId & tokenId + 1 to collector
        tokenContract.mint(address(this), "uriOne");
        tokenContract.mint(address(this), "uriTwo");
        tokenContract.mint(address(this), "uriThree");

        // transfer tokens
        tokenContract.transferFrom(address(this), collector, tokenId);
        tokenContract.transferFrom(address(this), collector, tokenId + 1);
        tokenContract.transferFrom(address(this), collector, tokenId + 2);

        // verify collector can burn tokenId
        vm.startPrank(collector, collector);
        vm.expectEmit(true, true, true, false);
        emit Transfer(collector, address(0), tokenId);
        tokenContract.burn(tokenId);
        vm.stopPrank();
        assertEq(tokenContract.balanceOf(collector), 2);
        vm.expectRevert(ERC721TL.TokenDoesntExist.selector);
        tokenContract.tokenURI(tokenId);
        vm.expectRevert();
        tokenContract.ownerOf(tokenId);

        // verify operator can't burn
        vm.startPrank(operator, operator);
        vm.expectRevert(ERC721TL.CallerNotApprovedOrOwner.selector);
        tokenContract.burn(tokenId + 1);
        vm.stopPrank();

        // grant operator rights and verify can burn tokenId + 1
        vm.startPrank(collector, collector);
        tokenContract.approve(operator, tokenId + 1);
        vm.stopPrank();
        vm.startPrank(operator, operator);
        vm.expectEmit(true, true, true, false);
        emit Transfer(collector, address(0), tokenId + 1);
        tokenContract.burn(tokenId + 1);
        vm.stopPrank();
        assertEq(tokenContract.balanceOf(collector), 1);
        vm.expectRevert(ERC721TL.TokenDoesntExist.selector);
        tokenContract.tokenURI(tokenId + 1);
        vm.expectRevert();
        tokenContract.ownerOf(tokenId + 1);

        // set approval for all and verify can burn tokenId + 2
        vm.startPrank(collector, collector);
        tokenContract.setApprovalForAll(operator, true);
        vm.stopPrank();
        vm.startPrank(operator, operator);
        vm.expectEmit(true, true, true, false);
        emit Transfer(collector, address(0), tokenId + 2);
        tokenContract.burn(tokenId + 2);
        vm.stopPrank();
        assertEq(tokenContract.balanceOf(collector), 0);
        vm.expectRevert(ERC721TL.TokenDoesntExist.selector);
        tokenContract.tokenURI(tokenId + 2);
        vm.expectRevert();
        tokenContract.ownerOf(tokenId + 2);
    }

    function test_burn_afterSafeTransfer(uint16 tokenId, address collector, address operator) public {
        vm.assume(tokenId != 0);
        vm.assume(collector != address(this));
        vm.assume(collector != address(0));
        vm.assume(collector != operator);
        vm.assume(operator != address(0));
        vm.assume(operator.code.length == 0);
        vm.assume(collector.code.length == 0);
        if (tokenId > 1000) {
            tokenId = tokenId % 1000 + 1;
        }

        // mint spare tokens to this address
        if (tokenId > 2) {
            tokenContract.batchMint(address(this), tokenId - 1, "uri");
            assertEq(tokenContract.totalSupply(), tokenId - 1);
        } else if (tokenId == 2) {
            tokenContract.mint(address(this), "uri");
        }

        // mint tokenId & tokenId + 1 to collector
        tokenContract.mint(address(this), "uriOne");
        tokenContract.mint(address(this), "uriTwo");
        tokenContract.mint(address(this), "uriThree");

        // transfer tokens
        tokenContract.safeTransferFrom(address(this), collector, tokenId);
        tokenContract.safeTransferFrom(address(this), collector, tokenId + 1);
        tokenContract.safeTransferFrom(address(this), collector, tokenId + 2);

        // verify collector can burn tokenId
        vm.startPrank(collector, collector);
        vm.expectEmit(true, true, true, false);
        emit Transfer(collector, address(0), tokenId);
        tokenContract.burn(tokenId);
        vm.stopPrank();
        assertEq(tokenContract.balanceOf(collector), 2);
        vm.expectRevert(ERC721TL.TokenDoesntExist.selector);
        tokenContract.tokenURI(tokenId);
        vm.expectRevert();
        tokenContract.ownerOf(tokenId);

        // verify operator can't burn
        vm.startPrank(operator, operator);
        vm.expectRevert(ERC721TL.CallerNotApprovedOrOwner.selector);
        tokenContract.burn(tokenId + 1);
        vm.stopPrank();

        // grant operator rights and verify can burn tokenId + 1
        vm.startPrank(collector, collector);
        tokenContract.approve(operator, tokenId + 1);
        vm.stopPrank();
        vm.startPrank(operator, operator);
        vm.expectEmit(true, true, true, true);
        emit Transfer(collector, address(0), tokenId + 1);
        tokenContract.burn(tokenId + 1);
        vm.stopPrank();
        assertEq(tokenContract.balanceOf(collector), 1);
        vm.expectRevert(ERC721TL.TokenDoesntExist.selector);
        tokenContract.tokenURI(tokenId + 1);
        vm.expectRevert();
        tokenContract.ownerOf(tokenId + 1);

        // set approval for all and verify can burn tokenId + 2
        vm.startPrank(collector, collector);
        tokenContract.setApprovalForAll(operator, true);
        vm.stopPrank();
        vm.startPrank(operator, operator);
        vm.expectEmit(true, true, true, true);
        emit Transfer(collector, address(0), tokenId + 2);
        tokenContract.burn(tokenId + 2);
        vm.stopPrank();
        assertEq(tokenContract.balanceOf(collector), 0);
        vm.expectRevert(ERC721TL.TokenDoesntExist.selector);
        tokenContract.tokenURI(tokenId + 2);
        vm.expectRevert();
        tokenContract.ownerOf(tokenId + 2);
    }

    /// @notice test royalty functions
    // - set default royalty ✅
    // - override token royalty ✅
    // - access control ✅
    function test_setDefaultRoyalty(address newRecipient, uint256 newPercentage, address user) public {
        vm.assume(newRecipient != address(0));
        vm.assume(user != address(0) && user != address(this));
        if (newPercentage >= 10_000) {
            newPercentage = newPercentage % 10_000;
        }
        address[] memory users = new address[](1);
        users[0] = user;

        // verify that user can't set royalty
        vm.startPrank(user, user);
        vm.expectRevert(abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE()));
        tokenContract.setDefaultRoyalty(newRecipient, newPercentage);
        vm.stopPrank();

        // verify that admin can set royalty
        tokenContract.setRole(tokenContract.ADMIN_ROLE(), users, true);
        vm.startPrank(user, user);
        tokenContract.setDefaultRoyalty(newRecipient, newPercentage);
        (address recp, uint256 amt) = tokenContract.royaltyInfo(1, 10_000);
        assertEq(recp, newRecipient);
        assertEq(amt, newPercentage);
        vm.stopPrank();
        tokenContract.setRole(tokenContract.ADMIN_ROLE(), users, false);

        // verify that minters can't set royalty
        tokenContract.setRole(tokenContract.APPROVED_MINT_CONTRACT(), users, true);
        vm.startPrank(user, user);
        vm.expectRevert(abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE()));
        tokenContract.setDefaultRoyalty(newRecipient, newPercentage);
        vm.stopPrank();
        tokenContract.setRole(tokenContract.APPROVED_MINT_CONTRACT(), users, false);

        // verify owner of the contract can set royalty
        tokenContract.setDefaultRoyalty(royaltyRecipient, 0);
        (recp, amt) = tokenContract.royaltyInfo(1, 10_000);
        assertEq(recp, royaltyRecipient);
        assertEq(amt, 0);
    }

    function test_setTokenRoyalty(uint256 tokenId, address newRecipient, uint256 newPercentage, address user) public {
        vm.assume(newRecipient != address(0));
        vm.assume(user != address(0) && user != address(this));
        if (newPercentage >= 10_000) {
            newPercentage = newPercentage % 10_000;
        }
        address[] memory users = new address[](1);
        users[0] = user;

        // verify that user can't set royalty
        vm.startPrank(user, user);
        vm.expectRevert(abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE()));
        tokenContract.setTokenRoyalty(tokenId, newRecipient, newPercentage);
        vm.stopPrank();

        // verify that admin can set royalty
        tokenContract.setRole(tokenContract.ADMIN_ROLE(), users, true);
        vm.startPrank(user, user);
        tokenContract.setTokenRoyalty(tokenId, newRecipient, newPercentage);
        (address recp, uint256 amt) = tokenContract.royaltyInfo(tokenId, 10_000);
        assertEq(recp, newRecipient);
        assertEq(amt, newPercentage);
        vm.stopPrank();
        tokenContract.setRole(tokenContract.ADMIN_ROLE(), users, false);

        // verify that minters can't set royalty
        tokenContract.setRole(tokenContract.APPROVED_MINT_CONTRACT(), users, true);
        vm.startPrank(user, user);
        vm.expectRevert(abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE()));
        tokenContract.setTokenRoyalty(tokenId, newRecipient, newPercentage);
        vm.stopPrank();
        tokenContract.setRole(tokenContract.APPROVED_MINT_CONTRACT(), users, false);

        // verify owner of the contract can set royalty
        tokenContract.setTokenRoyalty(tokenId, royaltyRecipient, 0);
        (recp, amt) = tokenContract.royaltyInfo(tokenId, 10_000);
        assertEq(recp, royaltyRecipient);
        assertEq(amt, 0);
    }

    /// @notice test synergy functions
    // - access control ✅
    // - regular mint ✅
    // - batch mint ✅
    // - airdrop ✅
    // - external mint ✅
    // - propose token uri as owner of token ✅
    // - propose token uri for collector ✅
    // - proper events ✅
    // - accept update with proper event as token owner and delegate ✅
    // - reject update with proper event as token owner and delegate ✅
    function test_synergy_customErrors() public {
        vm.expectRevert(ERC721TL.TokenDoesntExist.selector);
        tokenContract.proposeNewTokenUri(1, "uri");
        tokenContract.mint(address(this), "uri");
        vm.expectRevert(ERC721TL.EmptyTokenURI.selector);
        tokenContract.proposeNewTokenUri(1, "");
        vm.expectRevert(ERC721TL.NoTokenUriUpdateAvailable.selector);
        tokenContract.acceptTokenUriUpdate(1);
        vm.expectRevert(ERC721TL.NoTokenUriUpdateAvailable.selector);
        tokenContract.rejectTokenUriUpdate(1);
        vm.startPrank(address(1), address(1));
        vm.expectRevert(ERC721TL.CallerNotTokenOwnerOrDelegate.selector);
        tokenContract.acceptTokenUriUpdate(1);
        vm.expectRevert(ERC721TL.CallerNotTokenOwnerOrDelegate.selector);
        tokenContract.rejectTokenUriUpdate(1);
        vm.stopPrank();
    }

    function test_proposeNewTokenUri_accessControl() public {
        tokenContract.mint(address(this), "uri");
        address[] memory users = new address[](1);
        users[0] = address(1);

        // verify that user can't propose
        vm.startPrank(address(1), address(1));
        vm.expectRevert();
        tokenContract.proposeNewTokenUri(1, "newUri");
        vm.stopPrank();

        // verify that admin can propose
        tokenContract.setRole(tokenContract.ADMIN_ROLE(), users, true);
        vm.startPrank(address(1), address(1));
        tokenContract.proposeNewTokenUri(1, "newUri");
        assertEq(tokenContract.tokenURI(1), "newUri");
        vm.stopPrank();
        tokenContract.setRole(tokenContract.ADMIN_ROLE(), users, false);

        // verify that minters can't propose
        tokenContract.setRole(tokenContract.APPROVED_MINT_CONTRACT(), users, true);
        vm.startPrank(address(1), address(1));
        vm.expectRevert(abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE()));
        tokenContract.proposeNewTokenUri(1, "newUri");
        vm.stopPrank();
        tokenContract.setRole(tokenContract.APPROVED_MINT_CONTRACT(), users, false);

        // verify owner can propose
        tokenContract.proposeNewTokenUri(1, "newUriAgain");
        assertEq(tokenContract.tokenURI(1), "newUriAgain");
    }

    function test_proposeNewTokenUri_creatorIsOwner() public {
        address[] memory addresses = new address[](2);
        addresses[0] = address(this);
        addresses[1] = address(this);
        address[] memory users = new address[](1);
        users[0] = address(3);
        tokenContract.setRole(tokenContract.APPROVED_MINT_CONTRACT(), users, true);

        // mint
        tokenContract.mint(address(this), "uri");
        vm.expectEmit(true, true, true, true);
        emit MetadataUpdate(1);
        tokenContract.proposeNewTokenUri(1, "newUri");
        assertEq(tokenContract.tokenURI(1), "newUri");

        // batch mint
        tokenContract.batchMint(address(this), 2, "uri");
        vm.expectEmit(true, true, true, true);
        emit MetadataUpdate(2);
        tokenContract.proposeNewTokenUri(2, "newUri2");
        assertEq(tokenContract.tokenURI(2), "newUri2");
        vm.expectEmit(true, true, true, true);
        emit MetadataUpdate(3);
        tokenContract.proposeNewTokenUri(3, "newUri3");
        assertEq(tokenContract.tokenURI(3), "newUri3");

        // airdrop
        tokenContract.airdrop(addresses, "uri");
        vm.expectEmit(true, true, true, true);
        emit MetadataUpdate(4);
        tokenContract.proposeNewTokenUri(4, "newUri4");
        assertEq(tokenContract.tokenURI(4), "newUri4");
        vm.expectEmit(true, true, true, true);
        emit MetadataUpdate(5);
        tokenContract.proposeNewTokenUri(5, "newUri5");
        assertEq(tokenContract.tokenURI(5), "newUri5");

        // external mint
        vm.startPrank(address(3), address(3));
        tokenContract.externalMint(address(this), "uri");
        vm.stopPrank();
        vm.expectEmit(true, true, true, true);
        emit MetadataUpdate(6);
        tokenContract.proposeNewTokenUri(6, "newUri6");
        assertEq(tokenContract.tokenURI(6), "newUri6");
    }

    function test_proposeNewTokenUri_creatorIsNotOwner() public {
        address[] memory addresses = new address[](2);
        addresses[0] = address(1);
        addresses[1] = address(2);
        address[] memory users = new address[](1);
        users[0] = address(3);
        tokenContract.setRole(tokenContract.APPROVED_MINT_CONTRACT(), users, true);

        // mint
        tokenContract.mint(address(1), "uri");
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(address(this), 1, ISynergy.SynergyAction.Created, "newUri");
        tokenContract.proposeNewTokenUri(1, "newUri");
        assertEq(tokenContract.tokenURI(1), "uri");

        // batch mint
        tokenContract.batchMint(address(1), 2, "uri");
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(address(this), 2, ISynergy.SynergyAction.Created, "newUri2");
        tokenContract.proposeNewTokenUri(2, "newUri2");
        assertEq(tokenContract.tokenURI(2), "uri/0");
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(address(this), 3, ISynergy.SynergyAction.Created, "newUri3");
        tokenContract.proposeNewTokenUri(3, "newUri3");
        assertEq(tokenContract.tokenURI(3), "uri/1");

        // airdrop
        tokenContract.airdrop(addresses, "uri");
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(address(this), 4, ISynergy.SynergyAction.Created, "newUri4");
        tokenContract.proposeNewTokenUri(4, "newUri4");
        assertEq(tokenContract.tokenURI(4), "uri/0");
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(address(this), 5, ISynergy.SynergyAction.Created, "newUri5");
        tokenContract.proposeNewTokenUri(5, "newUri5");
        assertEq(tokenContract.tokenURI(5), "uri/1");

        // external mint
        vm.startPrank(address(3), address(3));
        tokenContract.externalMint(address(1), "uri");
        vm.stopPrank();
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(address(this), 6, ISynergy.SynergyAction.Created, "newUri6");
        tokenContract.proposeNewTokenUri(6, "newUri6");
        assertEq(tokenContract.tokenURI(6), "uri");
    }

    function test_acceptTokenUriUpdate_tokenOwner() public {
        // set variables
        address[] memory addresses = new address[](2);
        addresses[0] = address(1);
        addresses[1] = address(2);
        address[] memory users = new address[](1);
        users[0] = address(3);
        tokenContract.setRole(tokenContract.APPROVED_MINT_CONTRACT(), users, true);

        // ensure not token owner can't accept
        vm.expectRevert(ERC721TL.CallerNotTokenOwnerOrDelegate.selector);
        vm.prank(address(4));
        tokenContract.acceptTokenUriUpdate(1);

        // mint
        tokenContract.mint(address(1), "uri");
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(address(this), 1, ISynergy.SynergyAction.Created, "newUri");
        tokenContract.proposeNewTokenUri(1, "newUri");
        assertEq(tokenContract.tokenURI(1), "uri");
        vm.startPrank(address(1), address(1));
        vm.expectEmit(true, true, true, true);
        emit MetadataUpdate(1);
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(address(1), 1, ISynergy.SynergyAction.Accepted, "newUri");
        tokenContract.acceptTokenUriUpdate(1);
        vm.expectRevert(ERC721TL.NoTokenUriUpdateAvailable.selector);
        tokenContract.acceptTokenUriUpdate(1);
        vm.stopPrank();
        assertEq(tokenContract.tokenURI(1), "newUri");

        // batch mint
        tokenContract.batchMint(address(1), 2, "uri");
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(address(this), 2, ISynergy.SynergyAction.Created, "newUri2");
        tokenContract.proposeNewTokenUri(2, "newUri2");
        assertEq(tokenContract.tokenURI(2), "uri/0");
        vm.startPrank(address(1), address(1));
        vm.expectEmit(true, true, true, true);
        emit MetadataUpdate(2);
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(address(1), 2, ISynergy.SynergyAction.Accepted, "newUri2");
        tokenContract.acceptTokenUriUpdate(2);
        vm.expectRevert(ERC721TL.NoTokenUriUpdateAvailable.selector);
        tokenContract.acceptTokenUriUpdate(2);
        vm.stopPrank();
        assertEq(tokenContract.tokenURI(2), "newUri2");
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(address(this), 3, ISynergy.SynergyAction.Created, "newUri3");
        tokenContract.proposeNewTokenUri(3, "newUri3");
        assertEq(tokenContract.tokenURI(3), "uri/1");
        vm.startPrank(address(1), address(1));
        vm.expectEmit(true, true, true, true);
        emit MetadataUpdate(3);
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(address(1), 3, ISynergy.SynergyAction.Accepted, "newUri3");
        tokenContract.acceptTokenUriUpdate(3);
        vm.expectRevert(ERC721TL.NoTokenUriUpdateAvailable.selector);
        tokenContract.acceptTokenUriUpdate(3);
        vm.stopPrank();
        assertEq(tokenContract.tokenURI(3), "newUri3");

        // airdrop
        tokenContract.airdrop(addresses, "uri");
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(address(this), 4, ISynergy.SynergyAction.Created, "newUri4");
        tokenContract.proposeNewTokenUri(4, "newUri4");
        assertEq(tokenContract.tokenURI(4), "uri/0");
        vm.startPrank(address(1), address(1));
        vm.expectEmit(true, true, true, true);
        emit MetadataUpdate(4);
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(address(1), 4, ISynergy.SynergyAction.Accepted, "newUri4");
        tokenContract.acceptTokenUriUpdate(4);
        vm.expectRevert(ERC721TL.NoTokenUriUpdateAvailable.selector);
        tokenContract.acceptTokenUriUpdate(4);
        vm.stopPrank();
        assertEq(tokenContract.tokenURI(4), "newUri4");
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(address(this), 5, ISynergy.SynergyAction.Created, "newUri5");
        tokenContract.proposeNewTokenUri(5, "newUri5");
        assertEq(tokenContract.tokenURI(5), "uri/1");
        vm.startPrank(address(2), address(2));
        vm.expectEmit(true, true, true, true);
        emit MetadataUpdate(5);
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(address(2), 5, ISynergy.SynergyAction.Accepted, "newUri5");
        tokenContract.acceptTokenUriUpdate(5);
        vm.expectRevert(ERC721TL.NoTokenUriUpdateAvailable.selector);
        tokenContract.acceptTokenUriUpdate(5);
        vm.stopPrank();
        assertEq(tokenContract.tokenURI(5), "newUri5");

        // external mint
        vm.startPrank(address(3), address(3));
        tokenContract.externalMint(address(1), "uri");
        vm.stopPrank();
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(address(this), 6, ISynergy.SynergyAction.Created, "newUri6");
        tokenContract.proposeNewTokenUri(6, "newUri6");
        assertEq(tokenContract.tokenURI(6), "uri");
        vm.startPrank(address(1), address(1));
        vm.expectEmit(true, true, true, true);
        emit MetadataUpdate(6);
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(address(1), 6, ISynergy.SynergyAction.Accepted, "newUri6");
        tokenContract.acceptTokenUriUpdate(6);
        vm.expectRevert(ERC721TL.NoTokenUriUpdateAvailable.selector);
        tokenContract.acceptTokenUriUpdate(6);
        vm.stopPrank();
        assertEq(tokenContract.tokenURI(6), "newUri6");
    }

    function test_acceptTokenUriUpdate_delegate() public {
        // set delegate registry
        tokenContract.setNftDelegationRegistry(nftDelegationRegistry);

        // reverts for EOA
        vm.expectRevert();
        vm.prank(address(4));
        tokenContract.acceptTokenUriUpdate(1);

        // set mocks
        vm.mockCall(
            nftDelegationRegistry,
            abi.encodeWithSelector(
                ITLNftDelegationRegistry.checkDelegateForERC721.selector
            ),
            abi.encode(false)
        );
        vm.mockCall(
            nftDelegationRegistry,
            abi.encodeWithSelector(
                ITLNftDelegationRegistry.checkDelegateForERC721.selector,
                address(0),
                address(1),
                address(tokenContract)
            ),
            abi.encode(true)
        );
        vm.mockCall(
            nftDelegationRegistry,
            abi.encodeWithSelector(
                ITLNftDelegationRegistry.checkDelegateForERC721.selector,
                address(0),
                address(2),
                address(tokenContract)
            ),
            abi.encode(true)
        );

        // set variables
        address[] memory addresses = new address[](2);
        addresses[0] = address(1);
        addresses[1] = address(2);
        address[] memory users = new address[](1);
        users[0] = address(3);
        tokenContract.setRole(tokenContract.APPROVED_MINT_CONTRACT(), users, true);

        // ensure not delegate or token owner can't accept
        vm.expectRevert(ERC721TL.CallerNotTokenOwnerOrDelegate.selector);
        vm.prank(address(4));
        tokenContract.acceptTokenUriUpdate(1);

        // mint
        tokenContract.mint(address(1), "uri");
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(address(this), 1, ISynergy.SynergyAction.Created, "newUri");
        tokenContract.proposeNewTokenUri(1, "newUri");
        assertEq(tokenContract.tokenURI(1), "uri");
        vm.startPrank(address(0), address(0));
        vm.expectEmit(true, true, true, true);
        emit MetadataUpdate(1);
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(address(0), 1, ISynergy.SynergyAction.Accepted, "newUri");
        tokenContract.acceptTokenUriUpdate(1);
        vm.expectRevert(ERC721TL.NoTokenUriUpdateAvailable.selector);
        tokenContract.acceptTokenUriUpdate(1);
        vm.stopPrank();
        assertEq(tokenContract.tokenURI(1), "newUri");

        // batch mint
        tokenContract.batchMint(address(1), 2, "uri");
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(address(this), 2, ISynergy.SynergyAction.Created, "newUri2");
        tokenContract.proposeNewTokenUri(2, "newUri2");
        assertEq(tokenContract.tokenURI(2), "uri/0");
        vm.startPrank(address(0), address(0));
        vm.expectEmit(true, true, true, true);
        emit MetadataUpdate(2);
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(address(0), 2, ISynergy.SynergyAction.Accepted, "newUri2");
        tokenContract.acceptTokenUriUpdate(2);
        vm.expectRevert(ERC721TL.NoTokenUriUpdateAvailable.selector);
        tokenContract.acceptTokenUriUpdate(2);
        vm.stopPrank();
        assertEq(tokenContract.tokenURI(2), "newUri2");
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(address(this), 3, ISynergy.SynergyAction.Created, "newUri3");
        tokenContract.proposeNewTokenUri(3, "newUri3");
        assertEq(tokenContract.tokenURI(3), "uri/1");
        vm.startPrank(address(0), address(0));
        vm.expectEmit(true, true, true, true);
        emit MetadataUpdate(3);
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(address(0), 3, ISynergy.SynergyAction.Accepted, "newUri3");
        tokenContract.acceptTokenUriUpdate(3);
        vm.expectRevert(ERC721TL.NoTokenUriUpdateAvailable.selector);
        tokenContract.acceptTokenUriUpdate(3);
        vm.stopPrank();
        assertEq(tokenContract.tokenURI(3), "newUri3");

        // airdrop
        tokenContract.airdrop(addresses, "uri");
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(address(this), 4, ISynergy.SynergyAction.Created, "newUri4");
        tokenContract.proposeNewTokenUri(4, "newUri4");
        assertEq(tokenContract.tokenURI(4), "uri/0");
        vm.startPrank(address(0), address(0));
        vm.expectEmit(true, true, true, true);
        emit MetadataUpdate(4);
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(address(0), 4, ISynergy.SynergyAction.Accepted, "newUri4");
        tokenContract.acceptTokenUriUpdate(4);
        vm.expectRevert(ERC721TL.NoTokenUriUpdateAvailable.selector);
        tokenContract.acceptTokenUriUpdate(4);
        vm.stopPrank();
        assertEq(tokenContract.tokenURI(4), "newUri4");
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(address(this), 5, ISynergy.SynergyAction.Created, "newUri5");
        tokenContract.proposeNewTokenUri(5, "newUri5");
        assertEq(tokenContract.tokenURI(5), "uri/1");
        vm.startPrank(address(0), address(0));
        vm.expectEmit(true, true, true, true);
        emit MetadataUpdate(5);
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(address(0), 5, ISynergy.SynergyAction.Accepted, "newUri5");
        tokenContract.acceptTokenUriUpdate(5);
        vm.expectRevert(ERC721TL.NoTokenUriUpdateAvailable.selector);
        tokenContract.acceptTokenUriUpdate(5);
        vm.stopPrank();
        assertEq(tokenContract.tokenURI(5), "newUri5");

        // external mint
        vm.startPrank(address(3), address(3));
        tokenContract.externalMint(address(1), "uri");
        vm.stopPrank();
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(address(this), 6, ISynergy.SynergyAction.Created, "newUri6");
        tokenContract.proposeNewTokenUri(6, "newUri6");
        assertEq(tokenContract.tokenURI(6), "uri");
        vm.startPrank(address(0), address(0));
        vm.expectEmit(true, true, true, true);
        emit MetadataUpdate(6);
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(address(0), 6, ISynergy.SynergyAction.Accepted, "newUri6");
        tokenContract.acceptTokenUriUpdate(6);
        vm.expectRevert(ERC721TL.NoTokenUriUpdateAvailable.selector);
        tokenContract.acceptTokenUriUpdate(6);
        vm.stopPrank();
        assertEq(tokenContract.tokenURI(6), "newUri6");

        // clear mocked calls
        vm.clearMockedCalls();
    }

    function test_rejectTokenUriUpdate_tokenOwner() public {
        address[] memory addresses = new address[](2);
        addresses[0] = address(1);
        addresses[1] = address(2);
        address[] memory users = new address[](1);
        users[0] = address(3);
        tokenContract.setRole(tokenContract.APPROVED_MINT_CONTRACT(), users, true);

        // ensure not delegate or token owner can't accept
        vm.expectRevert(ERC721TL.CallerNotTokenOwnerOrDelegate.selector);
        vm.prank(address(4));
        tokenContract.rejectTokenUriUpdate(1);

        // mint
        tokenContract.mint(address(1), "uri");
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(address(this), 1, ISynergy.SynergyAction.Created, "newUri");
        tokenContract.proposeNewTokenUri(1, "newUri");
        assertEq(tokenContract.tokenURI(1), "uri");
        vm.startPrank(address(1), address(1));
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(address(1), 1, ISynergy.SynergyAction.Rejected, "");
        tokenContract.rejectTokenUriUpdate(1);
        vm.expectRevert(ERC721TL.NoTokenUriUpdateAvailable.selector);
        tokenContract.rejectTokenUriUpdate(1);
        vm.stopPrank();
        assertEq(tokenContract.tokenURI(1), "uri");

        // batch mint
        tokenContract.batchMint(address(1), 2, "uri");
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(address(this), 2, ISynergy.SynergyAction.Created, "newUri2");
        tokenContract.proposeNewTokenUri(2, "newUri2");
        assertEq(tokenContract.tokenURI(2), "uri/0");
        vm.startPrank(address(1), address(1));
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(address(1), 2, ISynergy.SynergyAction.Rejected, "");
        tokenContract.rejectTokenUriUpdate(2);
        vm.expectRevert(ERC721TL.NoTokenUriUpdateAvailable.selector);
        tokenContract.rejectTokenUriUpdate(2);
        vm.stopPrank();
        assertEq(tokenContract.tokenURI(2), "uri/0");
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(address(this), 3, ISynergy.SynergyAction.Created, "newUri3");
        tokenContract.proposeNewTokenUri(3, "newUri3");
        assertEq(tokenContract.tokenURI(3), "uri/1");
        vm.startPrank(address(1), address(1));
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(address(1), 3, ISynergy.SynergyAction.Rejected, "");
        tokenContract.rejectTokenUriUpdate(3);
        vm.expectRevert(ERC721TL.NoTokenUriUpdateAvailable.selector);
        tokenContract.rejectTokenUriUpdate(3);
        vm.stopPrank();
        assertEq(tokenContract.tokenURI(3), "uri/1");

        // airdrop
        tokenContract.airdrop(addresses, "uri");
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(address(this), 4, ISynergy.SynergyAction.Created, "newUri4");
        tokenContract.proposeNewTokenUri(4, "newUri4");
        assertEq(tokenContract.tokenURI(4), "uri/0");
        vm.startPrank(address(1), address(1));
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(address(1), 4, ISynergy.SynergyAction.Rejected, "");
        tokenContract.rejectTokenUriUpdate(4);
        vm.expectRevert(ERC721TL.NoTokenUriUpdateAvailable.selector);
        tokenContract.rejectTokenUriUpdate(4);
        vm.stopPrank();
        assertEq(tokenContract.tokenURI(4), "uri/0");
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(address(this), 5, ISynergy.SynergyAction.Created, "newUri5");
        tokenContract.proposeNewTokenUri(5, "newUri5");
        assertEq(tokenContract.tokenURI(5), "uri/1");
        vm.startPrank(address(2), address(2));
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(address(2), 5, ISynergy.SynergyAction.Rejected, "");
        tokenContract.rejectTokenUriUpdate(5);
        vm.expectRevert(ERC721TL.NoTokenUriUpdateAvailable.selector);
        tokenContract.rejectTokenUriUpdate(5);
        vm.stopPrank();
        assertEq(tokenContract.tokenURI(5), "uri/1");

        // external mint
        vm.startPrank(address(3), address(3));
        tokenContract.externalMint(address(1), "uri");
        vm.stopPrank();
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(address(this), 6, ISynergy.SynergyAction.Created, "newUri6");
        tokenContract.proposeNewTokenUri(6, "newUri6");
        assertEq(tokenContract.tokenURI(6), "uri");
        vm.startPrank(address(1), address(1));
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(address(1), 6, ISynergy.SynergyAction.Rejected, "");
        tokenContract.rejectTokenUriUpdate(6);
        vm.expectRevert(ERC721TL.NoTokenUriUpdateAvailable.selector);
        tokenContract.rejectTokenUriUpdate(6);
        vm.stopPrank();
        assertEq(tokenContract.tokenURI(6), "uri");
    }

    function test_rejectTokenUriUpdate_delegate() public {
        // set delegate registry
        tokenContract.setNftDelegationRegistry(nftDelegationRegistry);

        // reverts for EOA
        vm.expectRevert();
        vm.prank(address(4));
        tokenContract.rejectTokenUriUpdate(1);

        // set mocks
        vm.mockCall(
            nftDelegationRegistry,
            abi.encodeWithSelector(
                ITLNftDelegationRegistry.checkDelegateForERC721.selector
            ),
            abi.encode(false)
        );
        vm.mockCall(
            nftDelegationRegistry,
            abi.encodeWithSelector(
                ITLNftDelegationRegistry.checkDelegateForERC721.selector,
                address(0),
                address(1),
                address(tokenContract)
            ),
            abi.encode(true)
        );
        vm.mockCall(
            nftDelegationRegistry,
            abi.encodeWithSelector(
                ITLNftDelegationRegistry.checkDelegateForERC721.selector,
                address(0),
                address(2),
                address(tokenContract)
            ),
            abi.encode(true)
        );

        // set variables
        address[] memory addresses = new address[](2);
        addresses[0] = address(1);
        addresses[1] = address(2);
        address[] memory users = new address[](1);
        users[0] = address(3);
        tokenContract.setRole(tokenContract.APPROVED_MINT_CONTRACT(), users, true);

        // ensure not delegate or token owner can't accept
        vm.expectRevert(ERC721TL.CallerNotTokenOwnerOrDelegate.selector);
        vm.prank(address(4));
        tokenContract.rejectTokenUriUpdate(1);

        // mint
        tokenContract.mint(address(1), "uri");
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(address(this), 1, ISynergy.SynergyAction.Created, "newUri");
        tokenContract.proposeNewTokenUri(1, "newUri");
        assertEq(tokenContract.tokenURI(1), "uri");
        vm.startPrank(address(0), address(0));
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(address(0), 1, ISynergy.SynergyAction.Rejected, "");
        tokenContract.rejectTokenUriUpdate(1);
        vm.expectRevert(ERC721TL.NoTokenUriUpdateAvailable.selector);
        tokenContract.rejectTokenUriUpdate(1);
        vm.stopPrank();
        assertEq(tokenContract.tokenURI(1), "uri");

        // batch mint
        tokenContract.batchMint(address(1), 2, "uri");
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(address(this), 2, ISynergy.SynergyAction.Created, "newUri2");
        tokenContract.proposeNewTokenUri(2, "newUri2");
        assertEq(tokenContract.tokenURI(2), "uri/0");
        vm.startPrank(address(0), address(0));
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(address(0), 2, ISynergy.SynergyAction.Rejected, "");
        tokenContract.rejectTokenUriUpdate(2);
        vm.expectRevert(ERC721TL.NoTokenUriUpdateAvailable.selector);
        tokenContract.rejectTokenUriUpdate(2);
        vm.stopPrank();
        assertEq(tokenContract.tokenURI(2), "uri/0");
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(address(this), 3, ISynergy.SynergyAction.Created, "newUri3");
        tokenContract.proposeNewTokenUri(3, "newUri3");
        assertEq(tokenContract.tokenURI(3), "uri/1");
        vm.startPrank(address(0), address(0));
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(address(0), 3, ISynergy.SynergyAction.Rejected, "");
        tokenContract.rejectTokenUriUpdate(3);
        vm.expectRevert(ERC721TL.NoTokenUriUpdateAvailable.selector);
        tokenContract.rejectTokenUriUpdate(3);
        vm.stopPrank();
        assertEq(tokenContract.tokenURI(3), "uri/1");

        // airdrop
        tokenContract.airdrop(addresses, "uri");
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(address(this), 4, ISynergy.SynergyAction.Created, "newUri4");
        tokenContract.proposeNewTokenUri(4, "newUri4");
        assertEq(tokenContract.tokenURI(4), "uri/0");
        vm.startPrank(address(0), address(0));
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(address(0), 4, ISynergy.SynergyAction.Rejected, "");
        tokenContract.rejectTokenUriUpdate(4);
        vm.expectRevert(ERC721TL.NoTokenUriUpdateAvailable.selector);
        tokenContract.rejectTokenUriUpdate(4);
        vm.stopPrank();
        assertEq(tokenContract.tokenURI(4), "uri/0");
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(address(this), 5, ISynergy.SynergyAction.Created, "newUri5");
        tokenContract.proposeNewTokenUri(5, "newUri5");
        assertEq(tokenContract.tokenURI(5), "uri/1");
        vm.startPrank(address(0), address(0));
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(address(0), 5, ISynergy.SynergyAction.Rejected, "");
        tokenContract.rejectTokenUriUpdate(5);
        vm.expectRevert(ERC721TL.NoTokenUriUpdateAvailable.selector);
        tokenContract.rejectTokenUriUpdate(5);
        vm.stopPrank();
        assertEq(tokenContract.tokenURI(5), "uri/1");

        // external mint
        vm.startPrank(address(3), address(3));
        tokenContract.externalMint(address(1), "uri");
        vm.stopPrank();
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(address(this), 6, ISynergy.SynergyAction.Created, "newUri6");
        tokenContract.proposeNewTokenUri(6, "newUri6");
        assertEq(tokenContract.tokenURI(6), "uri");
        vm.startPrank(address(0), address(0));
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(address(0), 6, ISynergy.SynergyAction.Rejected, "");
        tokenContract.rejectTokenUriUpdate(6);
        vm.expectRevert(ERC721TL.NoTokenUriUpdateAvailable.selector);
        tokenContract.rejectTokenUriUpdate(6);
        vm.stopPrank();
        assertEq(tokenContract.tokenURI(6), "uri");

        // clear mocked calls
        vm.clearMockedCalls();
    }

    /// @notice test story functions
    // - enable/disable story access control ✅
    // - regular mint ✅
    // - batch mint ✅
    // - airdrop ✅
    // - external mint ✅
    // - write collection story w/ proper acccess 
    // - write creator story to existing token w/ proper acccess ✅
    // - write collector story to existing token w/ proper access 
    // - write creator story to non-existent token (reverts) ✅
    // - write collector story to non-existent token (reverts) 
    function test_story_accessControl(address user) public {
        vm.assume(user != address(this));
        address[] memory users = new address[](1);
        users[0] = user;

        tokenContract.mint(address(this), "uri");

        // verify user can't enable/disable and can't add collection and creator stories
        vm.startPrank(user, user);
        vm.expectRevert(abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE()));
        tokenContract.setStoryStatus(false);
        vm.expectRevert(abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE()));
        tokenContract.addCollectionStory("", "my story!");
        vm.expectRevert(abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE()));
        tokenContract.addCreatorStory(1, "", "my story!");
        vm.stopPrank();

        // verify admin can enable/disable  and can add collection and creator stories
        tokenContract.setRole(tokenContract.ADMIN_ROLE(), users, true);
        vm.startPrank(user, user);
        vm.expectEmit(true, true, true, true);
        emit StoryStatusUpdate(user, false);
        tokenContract.setStoryStatus(false);
        assertFalse(tokenContract.storyEnabled());
        vm.expectEmit(true, true, true, true);
        emit StoryStatusUpdate(user, true);
        tokenContract.setStoryStatus(true);
        assertTrue(tokenContract.storyEnabled());
        vm.expectEmit(true, true, true, true);
        emit CollectionStory(user, user.toHexString(), "my story!");
        tokenContract.addCollectionStory("", "my story!");
        vm.expectEmit(true, true, true, true);
        emit CreatorStory(1, user, user.toHexString(), "my story!");
        tokenContract.addCreatorStory(1, "", "my story!");
        vm.stopPrank();
        tokenContract.setRole(tokenContract.ADMIN_ROLE(), users, false);

        // verify minter can't enable/disable and can't add collection and creator stories
        tokenContract.setRole(tokenContract.APPROVED_MINT_CONTRACT(), users, true);
        vm.startPrank(user, user);
        vm.expectRevert(abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE()));
        tokenContract.setStoryStatus(false);
        vm.expectRevert(abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE()));
        tokenContract.addCollectionStory("", "my story!");
        vm.expectRevert(abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE()));
        tokenContract.addCreatorStory(1, "", "my story!");
        vm.stopPrank();
        tokenContract.setRole(tokenContract.APPROVED_MINT_CONTRACT(), users, false);

        // verify owner can enable/disable and can add collection and creator stories
        vm.expectEmit(true, true, true, true);
        emit StoryStatusUpdate(address(this), false);
        tokenContract.setStoryStatus(false);
        assertFalse(tokenContract.storyEnabled());
        vm.expectEmit(true, true, true, true);
        emit StoryStatusUpdate(address(this), true);
        tokenContract.setStoryStatus(true);
        assertTrue(tokenContract.storyEnabled());
        vm.expectEmit(true, true, true, true);
        emit CollectionStory(address(this), address(this).toHexString(), "my story!");
        tokenContract.addCollectionStory("", "my story!");
        vm.expectEmit(true, true, true, true);
        emit CreatorStory(1, address(this), address(this).toHexString(), "my story!");
        tokenContract.addCreatorStory(1, "", "my story!");
    }

    function test_addCollectionStory(address user, string memory name, string memory story) public {
        // add user as admin
        address[] memory users = new address[](1);
        users[0] = user;
        tokenContract.setRole(tokenContract.ADMIN_ROLE(), users, true);

        // add collection story and ensure the event matches
        vm.startPrank(user);
        vm.expectEmit(true, true, true, true);
        emit CollectionStory(user, user.toHexString(), story);
        tokenContract.addCollectionStory(name, story);
    }

    function test_story_nonExistentTokens() public {
        vm.expectRevert(ERC721TL.TokenDoesntExist.selector);
        tokenContract.addCreatorStory(1, "XCOPY", "I AM XCOPY");
        vm.expectRevert(ERC721TL.CallerNotTokenOwnerOrDelegate.selector);
        tokenContract.addStory(1, "NOT XCOPY", "I AM NOT XCOPY");
    }

    function test_story_mint(address collector) public {
        vm.assume(collector != address(0));
        vm.assume(collector != address(this));
        tokenContract.mint(collector, "uri");

        // test creator story
        vm.expectEmit(true, true, true, true);
        emit CreatorStory(1, address(this), address(this).toHexString(), "I AM XCOPY");
        tokenContract.addCreatorStory(1, "XCOPY", "I AM XCOPY");

        // test collector can't add creator story
        vm.startPrank(collector, collector);
        vm.expectRevert(abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE()));
        tokenContract.addCreatorStory(1, "XCOPY", "I AM XCOPY");

        // test collector story
        vm.expectEmit(true, true, true, true);
        emit Story(1, collector, collector.toHexString(), "I AM NOT XCOPY");
        tokenContract.addStory(1, "NOT XCOPY", "I AM NOT XCOPY");
        vm.stopPrank();

        // test that owner can't add collector story
        vm.expectRevert(ERC721TL.CallerNotTokenOwnerOrDelegate.selector);
        tokenContract.addStory(1, "NOT XCOPY", "I AM NOT XCOPY");
    }

    function test_story_batchMint(address collector) public {
        vm.assume(collector != address(0));
        vm.assume(collector != address(this));
        tokenContract.batchMint(collector, 2, "uri");

        // test creator story
        vm.expectEmit(true, true, true, true);
        emit CreatorStory(1, address(this), address(this).toHexString(), "I AM XCOPY");
        tokenContract.addCreatorStory(1, "XCOPY", "I AM XCOPY");
        vm.expectEmit(true, true, true, true);
        emit CreatorStory(2, address(this), address(this).toHexString(), "I AM XCOPY");
        tokenContract.addCreatorStory(2, "XCOPY", "I AM XCOPY");

        // test collector can't add creator story
        vm.startPrank(collector, collector);
        vm.expectRevert(abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE()));
        tokenContract.addCreatorStory(1, "XCOPY", "I AM XCOPY");
        vm.expectRevert(abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE()));
        tokenContract.addCreatorStory(2, "XCOPY", "I AM XCOPY");

        // test collector story
        vm.expectEmit(true, true, true, true);
        emit Story(1, collector, collector.toHexString(), "I AM NOT XCOPY");
        tokenContract.addStory(1, "NOT XCOPY", "I AM NOT XCOPY");
        vm.expectEmit(true, true, true, true);
        emit Story(2, collector, collector.toHexString(), "I AM NOT XCOPY");
        tokenContract.addStory(2, "NOT XCOPY", "I AM NOT XCOPY");
        vm.stopPrank();

        // test that owner can't add collector story
        vm.expectRevert(ERC721TL.CallerNotTokenOwnerOrDelegate.selector);
        tokenContract.addStory(1, "NOT XCOPY", "I AM NOT XCOPY");
        vm.expectRevert(ERC721TL.CallerNotTokenOwnerOrDelegate.selector);
        tokenContract.addStory(2, "NOT XCOPY", "I AM NOT XCOPY");
    }

    function test_story_airdrop(address collector) public {
        vm.assume(collector != address(0));
        vm.assume(collector != address(this));
        address[] memory addresses = new address[](2);
        addresses[0] = collector;
        addresses[1] = collector;
        tokenContract.airdrop(addresses, "uri");

        // test creator story
        vm.expectEmit(true, true, true, true);
        emit CreatorStory(1, address(this), address(this).toHexString(), "I AM XCOPY");
        tokenContract.addCreatorStory(1, "XCOPY", "I AM XCOPY");
        vm.expectEmit(true, true, true, true);
        emit CreatorStory(2, address(this), address(this).toHexString(), "I AM XCOPY");
        tokenContract.addCreatorStory(2, "XCOPY", "I AM XCOPY");

        // test collector can't add creator story
        vm.startPrank(collector, collector);
        vm.expectRevert(abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE()));
        tokenContract.addCreatorStory(1, "XCOPY", "I AM XCOPY");
        vm.expectRevert(abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE()));
        tokenContract.addCreatorStory(2, "XCOPY", "I AM XCOPY");

        // test collector story
        vm.expectEmit(true, true, true, true);
        emit Story(1, collector, collector.toHexString(), "I AM NOT XCOPY");
        tokenContract.addStory(1, "NOT XCOPY", "I AM NOT XCOPY");
        vm.expectEmit(true, true, true, true);
        emit Story(2, collector, collector.toHexString(), "I AM NOT XCOPY");
        tokenContract.addStory(2, "NOT XCOPY", "I AM NOT XCOPY");
        vm.stopPrank();

        // test that owner can't add collector story
        vm.expectRevert(ERC721TL.CallerNotTokenOwnerOrDelegate.selector);
        tokenContract.addStory(1, "NOT XCOPY", "I AM NOT XCOPY");
        vm.expectRevert(ERC721TL.CallerNotTokenOwnerOrDelegate.selector);
        tokenContract.addStory(2, "NOT XCOPY", "I AM NOT XCOPY");
    }

    function test_story_externalMint(address collector) public {
        vm.assume(collector != address(0));
        vm.assume(collector != address(1));
        vm.assume(collector != address(this));
        address[] memory users = new address[](1);
        users[0] = address(1);
        tokenContract.setRole(tokenContract.APPROVED_MINT_CONTRACT(), users, true);
        vm.startPrank(address(1), address(1));
        tokenContract.externalMint(collector, "uri");
        vm.stopPrank();

        // test creator story
        vm.expectEmit(true, true, true, true);
        emit CreatorStory(1, address(this), address(this).toHexString(), "I AM XCOPY");
        tokenContract.addCreatorStory(1, "XCOPY", "I AM XCOPY");

        // test collector can't add creator story
        vm.startPrank(collector, collector);
        vm.expectRevert(abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE()));
        tokenContract.addCreatorStory(1, "XCOPY", "I AM XCOPY");

        // test collector story
        vm.expectEmit(true, true, true, true);
        emit Story(1, collector, collector.toHexString(), "I AM NOT XCOPY");
        tokenContract.addStory(1, "NOT XCOPY", "I AM NOT XCOPY");
        vm.stopPrank();

        // test that owner can't add collector story
        vm.expectRevert(ERC721TL.CallerNotTokenOwnerOrDelegate.selector);
        tokenContract.addStory(1, "NOT XCOPY", "I AM NOT XCOPY");
    }

    function test_addStory_delegate(address delegate) public {
        // limit fuzz and mint
        vm.assume(delegate != address(this));
        tokenContract.mint(address(this), "uri");

        // set delegation registry
        tokenContract.setNftDelegationRegistry(nftDelegationRegistry);

        // mock calls
        vm.mockCall(
            nftDelegationRegistry,
            abi.encodeWithSelector(
                ITLNftDelegationRegistry.checkDelegateForERC721.selector
            ),
            abi.encode(false)
        );
        vm.mockCall(
            nftDelegationRegistry,
            abi.encodeWithSelector(
                ITLNftDelegationRegistry.checkDelegateForERC721.selector,
                delegate,
                address(this),
                address(tokenContract)
            ),
            abi.encode(true)
        );

        // test creator story
        vm.expectEmit(true, true, true, true);
        emit CreatorStory(1, address(this), address(this).toHexString(), "I AM XCOPY");
        tokenContract.addCreatorStory(1, "XCOPY", "I AM XCOPY");

        // test delegate can't add creator story
        vm.startPrank(delegate, delegate);
        vm.expectRevert(abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE()));
        tokenContract.addCreatorStory(1, "XCOPY", "I AM XCOPY");

        // test story
        vm.expectEmit(true, true, true, true);
        emit Story(1, delegate, delegate.toHexString(), "I AM NOT XCOPY");
        tokenContract.addStory(1, "NOT XCOPY", "I AM NOT XCOPY");
        vm.stopPrank();

        // clear mocked calls
        vm.clearMockedCalls();
    }

    function test_story_disabled(address collector) public {
        vm.assume(collector != address(0));
        vm.assume(collector != address(this));
        tokenContract.mint(collector, "uri");

        // disable story
        tokenContract.setStoryStatus(false);

        // test creator story
        vm.expectEmit(true, true, true, true);
        emit CreatorStory(1, address(this), address(this).toHexString(), "I AM XCOPY");
        tokenContract.addCreatorStory(1, "XCOPY", "I AM XCOPY");

        // test collector can't add creator story
        vm.startPrank(collector, collector);
        vm.expectRevert(abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE()));
        tokenContract.addCreatorStory(1, "XCOPY", "I AM XCOPY");

        // test collector story reverts
        vm.expectRevert(ERC721TL.StoryNotEnabled.selector);
        tokenContract.addStory(1, "NOT XCOPY", "I AM NOT XCOPY");
        vm.stopPrank();

        // test that owner can't add collector story
        vm.expectRevert(ERC721TL.StoryNotEnabled.selector);
        tokenContract.addStory(1, "NOT XCOPY", "I AM NOT XCOPY");
    }

    /// @notice test blocklist functions
    // - regular mint ✅
    // - batch mint ✅
    // - airdrop ✅
    // - external mint ✅
    // - test blocked ✅
    // - test not blocked
    // - test access control for changing the registry ✅
    function test_setBlockListRegistry_accessControl(address user) public {
        vm.assume(user != address(this));
        address[] memory users = new address[](1);
        users[0] = user;

        // verify user can't access
        vm.startPrank(user, user);
        vm.expectRevert(abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE()));
        tokenContract.setBlockListRegistry(address(1));
        vm.stopPrank();

        // verify admin can access
        tokenContract.setRole(tokenContract.ADMIN_ROLE(), users, true);
        vm.startPrank(user, user);
        vm.expectEmit(true, true, true, true);
        emit BlockListRegistryUpdate(user, address(0), address(1));
        tokenContract.setBlockListRegistry(address(1));
        assertEq(address(tokenContract.blocklistRegistry()), address(1));
        vm.stopPrank();
        tokenContract.setRole(tokenContract.ADMIN_ROLE(), users, false);

        // verify minter can't access
        tokenContract.setRole(tokenContract.APPROVED_MINT_CONTRACT(), users, true);
        vm.startPrank(user, user);
        vm.expectRevert(abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE()));
        tokenContract.setBlockListRegistry(address(1));
        vm.stopPrank();
        tokenContract.setRole(tokenContract.APPROVED_MINT_CONTRACT(), users, false);

        // verify owner can access
        vm.expectEmit(true, true, true, true);
        emit BlockListRegistryUpdate(address(this), address(1), blocklistRegistry);
        tokenContract.setBlockListRegistry(blocklistRegistry);
        assertEq(address(tokenContract.blocklistRegistry()), blocklistRegistry);
    }

    function test_blocklist_eoa() public {
        // update blocklist registry to EOA
        tokenContract.setBlockListRegistry(blocklistRegistry);

        // mint
        tokenContract.mint(address(this), "uri");

        // expect revert
        vm.expectRevert();
        tokenContract.approve(address(10), 1);
        vm.expectRevert();
        tokenContract.setApprovalForAll(address(10), true);

        // expect can set approval for all to false regardless
        tokenContract.setApprovalForAll(address(10), false);
    }

    function test_blocklist_mint(address collector, address operator) public {
        // limit fuzz
        vm.assume(collector != address(0));
        vm.assume(collector != operator);
        vm.assume(operator != address(0));

        // mock call
        vm.mockCall(
            blocklistRegistry,
            abi.encodeWithSelector(
                IBlockListRegistry.getBlockListStatus.selector
            ),
            abi.encode(true)
        );

        // update blocklist registry
        tokenContract.setBlockListRegistry(blocklistRegistry);

        // mint and verify blocked operator
        tokenContract.mint(collector, "uri");
        vm.startPrank(collector, collector);
        vm.expectRevert(ERC721TL.OperatorBlocked.selector);
        tokenContract.approve(operator, 1);
        vm.expectRevert(ERC721TL.OperatorBlocked.selector);
        tokenContract.setApprovalForAll(operator, true);
        vm.stopPrank();

        // unblock operator and verify approvals
        vm.mockCall(
            blocklistRegistry,
            abi.encodeWithSelector(
                IBlockListRegistry.getBlockListStatus.selector
            ),
            abi.encode(false)
        );
        vm.startPrank(collector, collector);
        tokenContract.approve(operator, 1);
        assertEq(tokenContract.getApproved(1), operator);
        tokenContract.setApprovalForAll(operator, true);
        assertTrue(tokenContract.isApprovedForAll(collector, operator));
        vm.stopPrank();

        // clear mocked call
        vm.clearMockedCalls();
    }

    function test_blocklist_batchMint(address collector, address operator) public {
        // limit fuzz
        vm.assume(collector != address(0));
        vm.assume(collector != operator);
        vm.assume(operator != address(0));

        // mock call
        vm.mockCall(
            blocklistRegistry,
            abi.encodeWithSelector(
                IBlockListRegistry.getBlockListStatus.selector
            ),
            abi.encode(true)
        );

        // update blocklist registry
        tokenContract.setBlockListRegistry(blocklistRegistry);

        // mint and verify blocked operator
        tokenContract.batchMint(collector, 2, "uri");
        vm.startPrank(collector, collector);
        vm.expectRevert(ERC721TL.OperatorBlocked.selector);
        tokenContract.approve(operator, 1);
        vm.expectRevert(ERC721TL.OperatorBlocked.selector);
        tokenContract.approve(operator, 2);
        vm.expectRevert(ERC721TL.OperatorBlocked.selector);
        tokenContract.setApprovalForAll(operator, true);
        vm.stopPrank();

        // unblock operator and verify approvals
        vm.mockCall(
            blocklistRegistry,
            abi.encodeWithSelector(
                IBlockListRegistry.getBlockListStatus.selector
            ),
            abi.encode(false)
        );
        vm.startPrank(collector, collector);
        tokenContract.approve(operator, 1);
        assertEq(tokenContract.getApproved(1), operator);
        tokenContract.approve(operator, 2);
        assertEq(tokenContract.getApproved(2), operator);
        tokenContract.setApprovalForAll(operator, true);
        assertTrue(tokenContract.isApprovedForAll(collector, operator));
        vm.stopPrank();

        // clear mocked call
        vm.clearMockedCalls();
    }

    function testBlockListAirdrop(address collector, address operator) public {
        // limit fuzz
        vm.assume(collector != address(0));
        vm.assume(collector != operator);
        vm.assume(operator != address(0));

        // variables
        address[] memory addresses = new address[](2);
        addresses[0] = collector;
        addresses[1] = collector;

        // mock call
        vm.mockCall(
            blocklistRegistry,
            abi.encodeWithSelector(
                IBlockListRegistry.getBlockListStatus.selector
            ),
            abi.encode(true)
        );

        // update blocklist registry
        tokenContract.setBlockListRegistry(blocklistRegistry);

        // mint and verify blocked operator
        tokenContract.airdrop(addresses, "uri");
        vm.startPrank(collector, collector);
        vm.expectRevert(ERC721TL.OperatorBlocked.selector);
        tokenContract.approve(operator, 1);
        vm.expectRevert(ERC721TL.OperatorBlocked.selector);
        tokenContract.approve(operator, 2);
        vm.expectRevert(ERC721TL.OperatorBlocked.selector);
        tokenContract.setApprovalForAll(operator, true);
        vm.stopPrank();

        // unblock operator and verify approvals
        vm.mockCall(
            blocklistRegistry,
            abi.encodeWithSelector(
                IBlockListRegistry.getBlockListStatus.selector
            ),
            abi.encode(false)
        );
        vm.startPrank(collector, collector);
        tokenContract.approve(operator, 1);
        assertEq(tokenContract.getApproved(1), operator);
        tokenContract.approve(operator, 2);
        assertEq(tokenContract.getApproved(2), operator);
        tokenContract.setApprovalForAll(operator, true);
        assertTrue(tokenContract.isApprovedForAll(collector, operator));
        vm.stopPrank();

        // clear mocked call
        vm.clearMockedCalls();
    }

    function testBlockListExternalMint(address collector, address operator) public {
        // limit fuzz
        vm.assume(collector != address(0));
        vm.assume(collector != address(1));
        vm.assume(collector != operator);
        vm.assume(operator != address(0));

        // variables
        address[] memory users = new address[](1);
        users[0] = address(1);
        tokenContract.setRole(tokenContract.APPROVED_MINT_CONTRACT(), users, true);
        
        // mock call
        vm.mockCall(
            blocklistRegistry,
            abi.encodeWithSelector(
                IBlockListRegistry.getBlockListStatus.selector
            ),
            abi.encode(true)
        );

        // update blocklist registry
        tokenContract.setBlockListRegistry(blocklistRegistry);

        // mint and verify blocked operator
        vm.startPrank(address(1), address(1));
        tokenContract.externalMint(collector, "uri");
        vm.stopPrank();
        vm.startPrank(collector, collector);
        vm.expectRevert(ERC721TL.OperatorBlocked.selector);
        tokenContract.approve(operator, 1);
        vm.expectRevert(ERC721TL.OperatorBlocked.selector);
        tokenContract.setApprovalForAll(operator, true);
        vm.stopPrank();

        // unblock operator and verify approvals
        vm.mockCall(
            blocklistRegistry,
            abi.encodeWithSelector(
                IBlockListRegistry.getBlockListStatus.selector
            ),
            abi.encode(false)
        );
        vm.startPrank(collector, collector);
        tokenContract.approve(operator, 1);
        assertEq(tokenContract.getApproved(1), operator);
        tokenContract.setApprovalForAll(operator, true);
        assertTrue(tokenContract.isApprovedForAll(collector, operator));
        vm.stopPrank();

        // clear mocked call
        vm.clearMockedCalls();
    }

    /// @notice test TL Nft Delegation Registry functions
    // - test access control for changing the registry 

    function test_setNftDelegationRegistry_accessControl(address user) public {
        vm.assume(user != address(this));
        address[] memory users = new address[](1);
        users[0] = user;

        // verify user can't access
        vm.startPrank(user, user);
        vm.expectRevert(abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE()));
        tokenContract.setNftDelegationRegistry(address(1));
        vm.stopPrank();

        // verify admin can access
        tokenContract.setRole(tokenContract.ADMIN_ROLE(), users, true);
        vm.startPrank(user, user);
        vm.expectEmit(true, true, true, true);
        emit NftDelegationRegistryUpdate(user, address(0), address(1));
        tokenContract.setNftDelegationRegistry(address(1));
        assertEq(address(tokenContract.tlNftDelegationRegistry()), address(1));
        vm.stopPrank();
        tokenContract.setRole(tokenContract.ADMIN_ROLE(), users, false);

        // verify minter can't access
        tokenContract.setRole(tokenContract.APPROVED_MINT_CONTRACT(), users, true);
        vm.startPrank(user, user);
        vm.expectRevert(abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE()));
        tokenContract.setNftDelegationRegistry(address(1));
        vm.stopPrank();
        tokenContract.setRole(tokenContract.APPROVED_MINT_CONTRACT(), users, false);

        // verify owner can access
        vm.expectEmit(true, true, true, true);
        emit NftDelegationRegistryUpdate(address(this), address(1), nftDelegationRegistry);
        tokenContract.setNftDelegationRegistry(nftDelegationRegistry);
        assertEq(address(tokenContract.tlNftDelegationRegistry()), nftDelegationRegistry);
    }

    function test_delegation_eoa() public {
        // set delegation registry to eoa
        tokenContract.setNftDelegationRegistry(nftDelegationRegistry);

        // mint
        tokenContract.mint(address(1), "uri");

        // add story reverts for delegate but not collector
        vm.expectRevert();
        vm.prank(address(2));
        tokenContract.addStory(1, "", "story");

        vm.prank(address(1));
        tokenContract.addStory(1, "", "story");

        // synergy reverts open for delegate but deterministic for collector
        vm.expectRevert();
        vm.prank(address(2));
        tokenContract.acceptTokenUriUpdate(1);
        vm.expectRevert();
        vm.prank(address(2));
        tokenContract.rejectTokenUriUpdate(1);

        vm.expectRevert(ERC721TL.NoTokenUriUpdateAvailable.selector);
        vm.prank(address(1));
        tokenContract.acceptTokenUriUpdate(1);
        vm.expectRevert(ERC721TL.NoTokenUriUpdateAvailable.selector);
        vm.prank(address(1));
        tokenContract.rejectTokenUriUpdate(1);
    }
}

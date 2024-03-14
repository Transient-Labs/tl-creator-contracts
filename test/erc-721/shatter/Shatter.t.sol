// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import "forge-std/Test.sol";
import {Strings} from "openzeppelin/utils/Strings.sol";
import {Shatter, IShatter, ISynergy} from "src/erc-721/shatter/Shatter.sol";
import {IERC721Errors} from "openzeppelin/interfaces/draft-IERC6093.sol";
import {Initializable} from "openzeppelin/proxy/utils/Initializable.sol";
import {OwnableAccessControlUpgradeable} from "tl-sol-tools/upgradeable/access/OwnableAccessControlUpgradeable.sol";
import {IBlockListRegistry} from "src/interfaces/IBlockListRegistry.sol";
import {ITLNftDelegationRegistry} from "src/interfaces/ITLNftDelegationRegistry.sol";

contract ShatterTest is Test {
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event RoleChange(address indexed from, address indexed user, bool indexed approved, bytes32 role);
    event Shattered(address indexed user, uint256 indexed numShatters, uint256 indexed shatteredTime);
    event Fused(address indexed user, uint256 indexed fuseTime);
    event Transfer(address indexed _from, address indexed _to, uint256 indexed _tokenId);
    event MetadataUpdate(uint256 tokenId);
    event SynergyStatusChange(
        address indexed from, uint256 indexed tokenId, Shatter.SynergyAction indexed action, string uri
    );
    event StoryStatusUpdate(address indexed sender, bool indexed status);
    event BlockListRegistryUpdate(
        address indexed sender, address indexed prevBlockListRegistry, address indexed newBlockListRegistry
    );
    event NftDelegationRegistryUpdate(
        address indexed sender, address indexed prevNftDelegationRegistry, address indexed newNftDelegationRegistry
    );
    event CollectionStory(address indexed creatorAddress, string creatorName, string story);
    event CreatorStory(uint256 indexed tokenId, address indexed creatorAddress, string creatorName, string story);
    event Story(uint256 indexed tokenId, address indexed collectorAddress, string collectorName, string story);

    Shatter public tokenContract;
    address public alice = address(0xcafe);
    address public bob = address(0xbeef);
    address public royaltyRecipient = address(0x1337);
    address public admin = address(0xc0fee);
    address public blocklistRegistry = makeAddr("blocklistRegistry");
    address public nftDelegationRegistry = makeAddr("nftDelegationRegistry");

    using Strings for uint256;
    using Strings for address;

    function setUp() public {
        address[] memory admins = new address[](1);
        admins[0] = admin;
        tokenContract = new Shatter(false);
        tokenContract.initialize(
            "Test721", "T721", "", royaltyRecipient, 10_00, address(this), admins, true, address(0), address(0)
        );
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

        vm.startPrank(address(this), address(this));

        // create contract
        tokenContract = new Shatter(false);
        // initialize and verify events thrown (order matters)
        vm.expectEmit(true, true, true, true);
        emit OwnershipTransferred(address(0), initOwner);
        for (uint256 i = 0; i < admins.length; i++) {
            vm.expectEmit(true, true, true, true);
            emit RoleChange(address(this), admins[i], true, tokenContract.ADMIN_ROLE());
        }
        vm.expectEmit(true, true, true, true);
        emit StoryStatusUpdate(initOwner, enableStory);
        vm.expectEmit(true, true, true, true);
        emit BlockListRegistryUpdate(initOwner, address(0), blockListRegistry);
        vm.expectEmit(true, true, true, true);
        emit NftDelegationRegistryUpdate(initOwner, address(0), tlNftDelegationRegistry);
        if (bytes(personalization).length > 0) {
            vm.expectEmit(true, true, true, true);
            emit CollectionStory(initOwner, initOwner.toHexString(), personalization);
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
        assert(!tokenContract.isShattered());
        assert(!tokenContract.isFused());
        assert(tokenContract.shatters() == 0);

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
        tokenContract = new Shatter(true);

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

        vm.stopPrank();
    }

    /// @notice test ERC-165 support
    function test_supportsInterface() public {
        assertTrue(tokenContract.supportsInterface(0x1c8e024d)); // ICreatorBase
        assertTrue(tokenContract.supportsInterface(0xf2528cbb)); // IShatter
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
        // variables
        address[] memory minters = new address[](1);
        minters[0] = address(1);

        // expect revert always
        vm.expectRevert();
        vm.prank(hacker);
        tokenContract.setApprovedMintContracts(minters, true);
    }

    function test_mint_owner(address hacker) public {
        // limit fuzz
        vm.assume(hacker != address(this) && hacker != admin);

        // test access control
        vm.expectRevert(
            abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE())
        );
        vm.prank(hacker);
        tokenContract.mint(address(this), "testURI", 0, 100, block.timestamp + 7200);

        // owner can mint
        tokenContract.mint(address(this), "testURI", 0, 100, block.timestamp + 7200);
        assert(tokenContract.ownerOf(0) == address(this));
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, 1));
        tokenContract.ownerOf(1);
        assert(tokenContract.minShatters() == 1);
        assert(tokenContract.maxShatters() == 100);
        assert(tokenContract.shatterTime() == block.timestamp + 7200);
        assert(tokenContract.shatters() == 1);
        assert(tokenContract.totalSupply() == 1);
        assertEq(tokenContract.tokenURI(0), "testURI/0");
    }

    function test_mint_admin(address hacker) public {
        // limit fuzz
        vm.assume(hacker != address(this) && hacker != admin);

        // test access control
        vm.expectRevert(
            abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE())
        );
        vm.prank(hacker);
        tokenContract.mint(address(this), "testURI", 0, 100, block.timestamp + 7200);

        // admin can mint
        vm.startPrank(admin, admin);
        tokenContract.mint(address(this), "testURI", 1, 100, block.timestamp + 7200);
        assert(tokenContract.ownerOf(0) == address(this));
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, 1));
        tokenContract.ownerOf(1);
        assert(tokenContract.minShatters() == 1);
        assert(tokenContract.maxShatters() == 100);
        assert(tokenContract.shatterTime() == block.timestamp + 7200);
        assert(tokenContract.shatters() == 1);
        assert(tokenContract.totalSupply() == 1);
        assertEq(tokenContract.tokenURI(0), "testURI/0");
        vm.stopPrank();
    }

    function test_mint_alreadyMinted() public {
        tokenContract.mint(address(this), "testURI", 1, 100, block.timestamp + 7200);
        vm.expectRevert(Shatter.AlreadyMinted.selector);
        tokenContract.mint(address(this), "testURI", 1, 100, block.timestamp + 7200);
        assert(tokenContract.shatters() == 1);
    }

    function testMint_emptyUri() public {
        vm.expectRevert(Shatter.EmptyTokenURI.selector);
        tokenContract.mint(address(this), "", 1, 100, block.timestamp + 7200);
    }

    function test_shatter(address recipient, uint128 numShatters) public {
        vm.assume(numShatters > 1);
        if (numShatters > 100) numShatters = numShatters % 100 + 1;
        vm.assume(recipient != address(0));
        vm.assume(recipient != address(this));
        vm.assume(recipient != admin);

        // mint
        tokenContract.mint(recipient, "testURI", 1, 100, block.timestamp + 7200);
        vm.warp(block.timestamp + 7200);

        // verify owner and admin can't shatter
        vm.expectRevert(Shatter.CallerNotTokenOwner.selector);
        tokenContract.shatter(numShatters);
        vm.startPrank(admin, admin);
        vm.expectRevert(Shatter.CallerNotTokenOwner.selector);
        tokenContract.shatter(numShatters);
        vm.stopPrank();

        // test shatter
        vm.startPrank(recipient, recipient);
        // burn event
        vm.expectEmit(true, true, true, true);
        emit Transfer(recipient, address(0), 0);
        // batch mint event
        for (uint256 id = 1; id < numShatters + 1; ++id) {
            vm.expectEmit(true, true, true, true);
            emit Transfer(address(0), recipient, id);
        }
        // shatter event
        vm.expectEmit(true, true, true, true);
        emit Shattered(recipient, numShatters, block.timestamp);

        tokenContract.shatter(numShatters);
        assert(tokenContract.shatters() == numShatters);
        assert(tokenContract.isShattered());
        assert(tokenContract.balanceOf(recipient) == numShatters);

        vm.stopPrank();

        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, 0));
        tokenContract.ownerOf(0);

        for (uint256 i = 1; i < numShatters; i++) {
            assert(tokenContract.ownerOf(i) == recipient);
        }
    }

    function test_shatter_errors() public {
        tokenContract.mint(address(this), "testURI", 1, 100, block.timestamp + 7200);

        vm.expectRevert(Shatter.CallPriorToShatterTime.selector);
        tokenContract.shatter(1);

        vm.prank(bob);
        vm.expectRevert(Shatter.CallerNotTokenOwner.selector);
        tokenContract.shatter(1);

        vm.warp(block.timestamp + 7200);

        vm.expectRevert(Shatter.InvalidNumShatters.selector);
        tokenContract.shatter(0);
        vm.expectRevert(Shatter.InvalidNumShatters.selector);
        tokenContract.shatter(101);

        tokenContract.shatter(50);
        vm.expectRevert(Shatter.IsShattered.selector);
        tokenContract.shatter(1);
    }

    function test_fuse(uint128 numShatters) public {
        vm.assume(numShatters > 0);
        if (numShatters > 100) numShatters = numShatters % 100 + 1;

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

    function test_fuse_errors() public {
        tokenContract.mint(address(this), "testURI", 1, 100, 0);

        vm.expectRevert(Shatter.NotShattered.selector);
        tokenContract.fuse();

        tokenContract.shatter(100);

        assert(tokenContract.isShattered());
        assert(!tokenContract.isFused());

        tokenContract.transferFrom(address(this), address(0xbeef), 5);
        assert(tokenContract.ownerOf(5) == address(0xbeef));
        assert(tokenContract.balanceOf(address(0xbeef)) == 1);

        vm.expectRevert(Shatter.CallerDoesNotOwnAllTokens.selector);
        tokenContract.fuse();

        vm.prank(address(0xbeef));
        tokenContract.transferFrom(address(0xbeef), address(this), 5);
        assert(tokenContract.balanceOf(address(0xbeef)) == 0);

        tokenContract.fuse();

        vm.expectRevert(Shatter.IsFused.selector);
        tokenContract.fuse();
    }

    function test_ownerOf(address recipient, uint128 numShatters) public {
        // tests transfer of tokens prior to shatter, after shatter, and then after fuse
        vm.assume(numShatters > 1);
        if (numShatters > 100) numShatters = numShatters % 99 + 2;
        vm.assume(recipient != address(0));
        vm.assume(recipient != address(this));
        vm.assume(recipient != admin);

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

    /// @notice test royalty functions
    // - set default royalty ✅
    // - override token royalty ✅
    // - access control ✅
    function test_setDefaultRoyalty(address newRecipient, uint256 newPercentage, address user) public {
        vm.assume(newRecipient != address(0));
        vm.assume(user != admin && user != address(this));
        if (newPercentage >= 10_000) {
            newPercentage = newPercentage % 10_000;
        }
        address[] memory users = new address[](1);
        users[0] = user;

        // verify that user can't set royalty
        vm.startPrank(user, user);
        vm.expectRevert(
            abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE())
        );
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

        // verify owner of the contract can set royalty
        tokenContract.setDefaultRoyalty(royaltyRecipient, 0);
        (recp, amt) = tokenContract.royaltyInfo(1, 10_000);
        assertEq(recp, royaltyRecipient);
        assertEq(amt, 0);
    }

    function test_setTokenRoyalty(uint256 tokenId, address newRecipient, uint256 newPercentage, address user) public {
        vm.assume(newRecipient != address(0));
        vm.assume(user != admin && user != address(this));
        if (newPercentage >= 10_000) {
            newPercentage = newPercentage % 10_000;
        }
        address[] memory users = new address[](1);
        users[0] = user;

        // verify that user can't set royalty
        vm.startPrank(user, user);
        vm.expectRevert(
            abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE())
        );
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

        // verify owner of the contract can set royalty
        tokenContract.setTokenRoyalty(tokenId, royaltyRecipient, 0);
        (recp, amt) = tokenContract.royaltyInfo(tokenId, 10_000);
        assertEq(recp, royaltyRecipient);
        assertEq(amt, 0);
    }

    function test_tokenURI(uint128 numShatters) public {
        if (numShatters > 100) {
            numShatters = numShatters % 100 + 1;
        }
        if (numShatters == 0) {
            numShatters = 1;
        }
        // unminted token
        vm.expectRevert(Shatter.TokenDoesntExist.selector);
        tokenContract.tokenURI(0);

        // minted 1/1
        tokenContract.mint(address(this), "testUri", 1, 100, 0);
        assertEq(tokenContract.tokenURI(0), "testUri/0");

        // shatter & fuse
        tokenContract.shatter(numShatters);
        for (uint256 i = 0; i < numShatters; i++) {
            assertEq(tokenContract.tokenURI(i + 1), string(abi.encodePacked("testUri/", (i + 1).toString())));
        }
    }

    /// @notice test synergy functions
    // - access control ✅
    // - propose token uri as owner of token ✅
    // - propose token uri for collector ✅
    // - proper events ✅
    // - accept update with proper event as token owner and delegate ✅
    // - reject update with proper event as token owner and delegate ✅
    function test_synergy_customErrors() public {
        vm.expectRevert(Shatter.TokenDoesntExist.selector);
        tokenContract.proposeNewTokenUri(0, "uri");
        tokenContract.mint(address(this), "uri", 1, 2, 0);
        vm.expectRevert(Shatter.EmptyTokenURI.selector);
        tokenContract.proposeNewTokenUri(0, "");
        vm.expectRevert(Shatter.NoTokenUriUpdateAvailable.selector);
        tokenContract.acceptTokenUriUpdate(0);
        vm.expectRevert(Shatter.NoTokenUriUpdateAvailable.selector);
        tokenContract.rejectTokenUriUpdate(0);
        vm.startPrank(address(1), address(1));
        vm.expectRevert(Shatter.CallerNotTokenOwnerOrDelegate.selector);
        tokenContract.acceptTokenUriUpdate(0);
        vm.expectRevert(Shatter.CallerNotTokenOwnerOrDelegate.selector);
        tokenContract.rejectTokenUriUpdate(0);
        vm.stopPrank();
    }

    function test_proposeNewTokenUri_accessControl() public {
        tokenContract.mint(address(this), "uri", 1, 2, 0);
        address[] memory users = new address[](1);
        users[0] = address(1);

        // verify that user can't propose
        vm.startPrank(address(1), address(1));
        vm.expectRevert();
        tokenContract.proposeNewTokenUri(0, "newUri");
        vm.stopPrank();

        // verify that admin can propose
        tokenContract.setRole(tokenContract.ADMIN_ROLE(), users, true);
        vm.startPrank(address(1), address(1));
        tokenContract.proposeNewTokenUri(0, "newUri");
        assertEq(tokenContract.tokenURI(0), "newUri");
        vm.stopPrank();
        tokenContract.setRole(tokenContract.ADMIN_ROLE(), users, false);

        // verify owner can propose
        tokenContract.proposeNewTokenUri(0, "newUriAgain");
        assertEq(tokenContract.tokenURI(0), "newUriAgain");
    }

    function test_proposeNewTokenUri_creatorIsOwner() public {
        // mint
        tokenContract.mint(address(this), "uri", 1, 2, 0);
        vm.expectEmit(true, true, true, true);
        emit MetadataUpdate(0);
        tokenContract.proposeNewTokenUri(0, "newUri");
        assertEq(tokenContract.tokenURI(0), "newUri");

        // shatter
        tokenContract.shatter(2);
        assertEq(tokenContract.tokenURI(1), "uri/1");
        assertEq(tokenContract.tokenURI(2), "uri/2");
        vm.expectEmit(true, true, true, true);
        emit MetadataUpdate(1);
        tokenContract.proposeNewTokenUri(1, "newUri");
        assertEq(tokenContract.tokenURI(1), "newUri");
        vm.expectEmit(true, true, true, true);
        emit MetadataUpdate(2);
        tokenContract.proposeNewTokenUri(2, "newUri");
        assertEq(tokenContract.tokenURI(2), "newUri");
    }

    function test_proposeNewTokenUri_creatorIsNotOwner() public {
        // mint
        tokenContract.mint(address(1), "uri", 1, 2, 0);
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(address(this), 0, ISynergy.SynergyAction.Created, "newUri");
        tokenContract.proposeNewTokenUri(0, "newUri");
        assertEq(tokenContract.tokenURI(0), "uri/0");

        // shatter
        vm.prank(address(1));
        tokenContract.shatter(2);
        assertEq(tokenContract.tokenURI(1), "uri/1");
        assertEq(tokenContract.tokenURI(2), "uri/2");
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(address(this), 1, ISynergy.SynergyAction.Created, "newUri");
        tokenContract.proposeNewTokenUri(1, "newUri");
        assertEq(tokenContract.tokenURI(1), "uri/1");
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(address(this), 2, ISynergy.SynergyAction.Created, "newUri");
        tokenContract.proposeNewTokenUri(2, "newUri");
        assertEq(tokenContract.tokenURI(2), "uri/2");
    }

    function test_acceptTokenUriUpdate_tokenOwner() public {
        // ensure not token owner can't accept
        vm.expectRevert(Shatter.CallerNotTokenOwnerOrDelegate.selector);
        vm.prank(address(4));
        tokenContract.acceptTokenUriUpdate(1);

        // mint
        tokenContract.mint(address(1), "uri", 1, 2, 0);
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(address(this), 0, ISynergy.SynergyAction.Created, "newUri");
        tokenContract.proposeNewTokenUri(0, "newUri");
        assertEq(tokenContract.tokenURI(0), "uri/0");
        vm.startPrank(address(1), address(1));
        vm.expectEmit(true, true, true, true);
        emit MetadataUpdate(0);
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(address(1), 0, ISynergy.SynergyAction.Accepted, "newUri");
        tokenContract.acceptTokenUriUpdate(0);
        vm.expectRevert(Shatter.NoTokenUriUpdateAvailable.selector);
        tokenContract.acceptTokenUriUpdate(0);
        vm.stopPrank();
        assertEq(tokenContract.tokenURI(0), "newUri");

        // shatter
        vm.prank(address(1));
        tokenContract.shatter(2);
        assertEq(tokenContract.tokenURI(1), "uri/1");
        assertEq(tokenContract.tokenURI(2), "uri/2");
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(address(this), 1, ISynergy.SynergyAction.Created, "newUri");
        tokenContract.proposeNewTokenUri(1, "newUri");
        assertEq(tokenContract.tokenURI(1), "uri/1");
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(address(this), 2, ISynergy.SynergyAction.Created, "newUri");
        tokenContract.proposeNewTokenUri(2, "newUri");
        assertEq(tokenContract.tokenURI(2), "uri/2");
        vm.startPrank(address(1), address(1));
        vm.expectEmit(true, true, true, true);
        emit MetadataUpdate(1);
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(address(1), 1, ISynergy.SynergyAction.Accepted, "newUri");
        tokenContract.acceptTokenUriUpdate(1);
        vm.expectRevert(Shatter.NoTokenUriUpdateAvailable.selector);
        tokenContract.acceptTokenUriUpdate(1);
        vm.stopPrank();
        assertEq(tokenContract.tokenURI(1), "newUri");
        vm.startPrank(address(1), address(1));
        vm.expectEmit(true, true, true, true);
        emit MetadataUpdate(2);
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(address(1), 2, ISynergy.SynergyAction.Accepted, "newUri");
        tokenContract.acceptTokenUriUpdate(2);
        vm.expectRevert(Shatter.NoTokenUriUpdateAvailable.selector);
        tokenContract.acceptTokenUriUpdate(2);
        vm.stopPrank();
        assertEq(tokenContract.tokenURI(2), "newUri");
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
            abi.encodeWithSelector(ITLNftDelegationRegistry.checkDelegateForERC721.selector),
            abi.encode(false)
        );
        vm.mockCall(
            nftDelegationRegistry,
            abi.encodeWithSelector(
                ITLNftDelegationRegistry.checkDelegateForERC721.selector, address(0), address(1), address(tokenContract)
            ),
            abi.encode(true)
        );

        // ensure not delegate or token owner can't accept
        vm.expectRevert(Shatter.CallerNotTokenOwnerOrDelegate.selector);
        vm.prank(address(4));
        tokenContract.acceptTokenUriUpdate(1);

        // mint
        tokenContract.mint(address(1), "uri", 1, 2, 0);
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(address(this), 0, ISynergy.SynergyAction.Created, "newUri");
        tokenContract.proposeNewTokenUri(0, "newUri");
        assertEq(tokenContract.tokenURI(0), "uri/0");
        vm.startPrank(address(0), address(0));
        vm.expectEmit(true, true, true, true);
        emit MetadataUpdate(0);
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(address(0), 0, ISynergy.SynergyAction.Accepted, "newUri");
        tokenContract.acceptTokenUriUpdate(0);
        vm.expectRevert(Shatter.NoTokenUriUpdateAvailable.selector);
        tokenContract.acceptTokenUriUpdate(0);
        vm.stopPrank();
        assertEq(tokenContract.tokenURI(0), "newUri");

        // shatter
        vm.prank(address(1));
        tokenContract.shatter(2);
        assertEq(tokenContract.tokenURI(1), "uri/1");
        assertEq(tokenContract.tokenURI(2), "uri/2");
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(address(this), 1, ISynergy.SynergyAction.Created, "newUri");
        tokenContract.proposeNewTokenUri(1, "newUri");
        assertEq(tokenContract.tokenURI(1), "uri/1");
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(address(this), 2, ISynergy.SynergyAction.Created, "newUri");
        tokenContract.proposeNewTokenUri(2, "newUri");
        assertEq(tokenContract.tokenURI(2), "uri/2");
        vm.startPrank(address(0), address(0));
        vm.expectEmit(true, true, true, true);
        emit MetadataUpdate(1);
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(address(0), 1, ISynergy.SynergyAction.Accepted, "newUri");
        tokenContract.acceptTokenUriUpdate(1);
        vm.expectRevert(Shatter.NoTokenUriUpdateAvailable.selector);
        tokenContract.acceptTokenUriUpdate(1);
        vm.stopPrank();
        assertEq(tokenContract.tokenURI(1), "newUri");
        vm.startPrank(address(0), address(0));
        vm.expectEmit(true, true, true, true);
        emit MetadataUpdate(2);
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(address(0), 2, ISynergy.SynergyAction.Accepted, "newUri");
        tokenContract.acceptTokenUriUpdate(2);
        vm.expectRevert(Shatter.NoTokenUriUpdateAvailable.selector);
        tokenContract.acceptTokenUriUpdate(2);
        vm.stopPrank();
        assertEq(tokenContract.tokenURI(2), "newUri");

        // clear mocked calls
        vm.clearMockedCalls();
    }

    function test_rejectTokenUriUpdate_tokenOwner() public {
        // ensure not delegate or token owner can't accept
        vm.expectRevert(Shatter.CallerNotTokenOwnerOrDelegate.selector);
        vm.prank(address(4));
        tokenContract.rejectTokenUriUpdate(1);

        // mint
        tokenContract.mint(address(1), "uri", 1, 2, 0);
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(address(this), 0, ISynergy.SynergyAction.Created, "newUri");
        tokenContract.proposeNewTokenUri(0, "newUri");
        assertEq(tokenContract.tokenURI(0), "uri/0");
        vm.startPrank(address(1), address(1));
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(address(1), 0, ISynergy.SynergyAction.Rejected, "");
        tokenContract.rejectTokenUriUpdate(0);
        vm.expectRevert(Shatter.NoTokenUriUpdateAvailable.selector);
        tokenContract.rejectTokenUriUpdate(0);
        vm.stopPrank();
        assertEq(tokenContract.tokenURI(0), "uri/0");

        // shatter
        vm.prank(address(1));
        tokenContract.shatter(2);
        assertEq(tokenContract.tokenURI(1), "uri/1");
        assertEq(tokenContract.tokenURI(2), "uri/2");
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(address(this), 1, ISynergy.SynergyAction.Created, "newUri");
        tokenContract.proposeNewTokenUri(1, "newUri");
        assertEq(tokenContract.tokenURI(1), "uri/1");
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(address(this), 2, ISynergy.SynergyAction.Created, "newUri");
        tokenContract.proposeNewTokenUri(2, "newUri");
        assertEq(tokenContract.tokenURI(2), "uri/2");
        vm.startPrank(address(1), address(1));
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(address(1), 1, ISynergy.SynergyAction.Rejected, "");
        tokenContract.rejectTokenUriUpdate(1);
        vm.expectRevert(Shatter.NoTokenUriUpdateAvailable.selector);
        tokenContract.rejectTokenUriUpdate(1);
        vm.stopPrank();
        assertEq(tokenContract.tokenURI(1), "uri/1");
        vm.startPrank(address(1), address(1));
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(address(1), 2, ISynergy.SynergyAction.Rejected, "");
        tokenContract.rejectTokenUriUpdate(2);
        vm.expectRevert(Shatter.NoTokenUriUpdateAvailable.selector);
        tokenContract.rejectTokenUriUpdate(2);
        vm.stopPrank();
        assertEq(tokenContract.tokenURI(2), "uri/2");
    }

    function test_rejectTokenUriUpdate_delegate() public {
        // set delegate registry
        tokenContract.setNftDelegationRegistry(nftDelegationRegistry);

        // reverts for EOA
        vm.expectRevert();
        vm.prank(address(4));
        tokenContract.acceptTokenUriUpdate(1);

        // set mocks
        vm.mockCall(
            nftDelegationRegistry,
            abi.encodeWithSelector(ITLNftDelegationRegistry.checkDelegateForERC721.selector),
            abi.encode(false)
        );
        vm.mockCall(
            nftDelegationRegistry,
            abi.encodeWithSelector(
                ITLNftDelegationRegistry.checkDelegateForERC721.selector, address(0), address(1), address(tokenContract)
            ),
            abi.encode(true)
        );

        // ensure not delegate or token owner can't accept
        vm.expectRevert(Shatter.CallerNotTokenOwnerOrDelegate.selector);
        vm.prank(address(4));
        tokenContract.acceptTokenUriUpdate(1);

        // mint
        tokenContract.mint(address(1), "uri", 1, 2, 0);
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(address(this), 0, ISynergy.SynergyAction.Created, "newUri");
        tokenContract.proposeNewTokenUri(0, "newUri");
        assertEq(tokenContract.tokenURI(0), "uri/0");
        vm.startPrank(address(0), address(0));
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(address(0), 0, ISynergy.SynergyAction.Rejected, "");
        tokenContract.rejectTokenUriUpdate(0);
        vm.expectRevert(Shatter.NoTokenUriUpdateAvailable.selector);
        tokenContract.rejectTokenUriUpdate(0);
        vm.stopPrank();
        assertEq(tokenContract.tokenURI(0), "uri/0");

        // shatter
        vm.prank(address(1));
        tokenContract.shatter(2);
        assertEq(tokenContract.tokenURI(1), "uri/1");
        assertEq(tokenContract.tokenURI(2), "uri/2");
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(address(this), 1, ISynergy.SynergyAction.Created, "newUri");
        tokenContract.proposeNewTokenUri(1, "newUri");
        assertEq(tokenContract.tokenURI(1), "uri/1");
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(address(this), 2, ISynergy.SynergyAction.Created, "newUri");
        tokenContract.proposeNewTokenUri(2, "newUri");
        assertEq(tokenContract.tokenURI(2), "uri/2");
        vm.startPrank(address(0), address(0));
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(address(0), 1, ISynergy.SynergyAction.Rejected, "");
        tokenContract.rejectTokenUriUpdate(1);
        vm.expectRevert(Shatter.NoTokenUriUpdateAvailable.selector);
        tokenContract.rejectTokenUriUpdate(1);
        vm.stopPrank();
        assertEq(tokenContract.tokenURI(1), "uri/1");
        vm.startPrank(address(0), address(0));
        vm.expectEmit(true, true, true, true);
        emit SynergyStatusChange(address(0), 2, ISynergy.SynergyAction.Rejected, "");
        tokenContract.rejectTokenUriUpdate(2);
        vm.expectRevert(Shatter.NoTokenUriUpdateAvailable.selector);
        tokenContract.rejectTokenUriUpdate(2);
        vm.stopPrank();
        assertEq(tokenContract.tokenURI(2), "uri/2");

        // clear mocked calls
        vm.clearMockedCalls();
    }

    /// @notice test story functions
    // - enable/disable story access control ✅
    // - write collection story w/ proper acccess ✅
    // - write creator story to existing token w/ proper acccess ✅
    // - write collector story to existing token w/ proper access ✅
    // - write creator story to non-existent token (reverts) ✅
    // - write collector story to non-existent token (reverts) ✅
    function test_story_accessControl(address user) public {
        vm.assume(user != address(this) && user != admin);
        address[] memory users = new address[](1);
        users[0] = user;

        tokenContract.mint(address(this), "uri", 1, 2, 0);

        // verify user can't enable/disable and can't add collection and creator stories
        vm.startPrank(user, user);
        vm.expectRevert(
            abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE())
        );
        tokenContract.setStoryStatus(false);
        vm.expectRevert(
            abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE())
        );
        tokenContract.addCollectionStory("", "my story!");
        vm.expectRevert(
            abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE())
        );
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
        emit CreatorStory(0, user, user.toHexString(), "my story!");
        tokenContract.addCreatorStory(0, "", "my story!");
        vm.stopPrank();
        tokenContract.setRole(tokenContract.ADMIN_ROLE(), users, false);

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
        emit CreatorStory(0, address(this), address(this).toHexString(), "my story!");
        tokenContract.addCreatorStory(0, "", "my story!");
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
        vm.expectRevert(Shatter.TokenDoesntExist.selector);
        tokenContract.addCreatorStory(1, "XCOPY", "I AM XCOPY");
        vm.expectRevert(Shatter.CallerNotTokenOwnerOrDelegate.selector);
        tokenContract.addStory(1, "NOT XCOPY", "I AM NOT XCOPY");
    }

    function test_addStory(address collector) public {
        vm.assume(collector != address(0));
        vm.assume(collector != address(this));
        vm.assume(collector != admin);
        tokenContract.mint(collector, "uri", 1, 2, 0);

        // test creator story
        vm.expectEmit(true, true, true, true);
        emit CreatorStory(0, address(this), address(this).toHexString(), "I AM XCOPY");
        tokenContract.addCreatorStory(0, "XCOPY", "I AM XCOPY");

        // test collector can't add creator story
        vm.startPrank(collector, collector);
        vm.expectRevert(
            abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE())
        );
        tokenContract.addCreatorStory(0, "XCOPY", "I AM XCOPY");

        // test collector story
        vm.expectEmit(true, true, true, true);
        emit Story(0, collector, collector.toHexString(), "I AM NOT XCOPY");
        tokenContract.addStory(0, "NOT XCOPY", "I AM NOT XCOPY");
        vm.stopPrank();

        // test that owner can't add collector story
        vm.expectRevert(Shatter.CallerNotTokenOwnerOrDelegate.selector);
        tokenContract.addStory(0, "NOT XCOPY", "I AM NOT XCOPY");

        // shatter and test again on new token
        vm.prank(collector);
        tokenContract.shatter(1);

        // test creator story
        vm.expectEmit(true, true, true, true);
        emit CreatorStory(1, address(this), address(this).toHexString(), "I AM XCOPY");
        tokenContract.addCreatorStory(1, "XCOPY", "I AM XCOPY");

        // test collector can't add creator story
        vm.startPrank(collector, collector);
        vm.expectRevert(
            abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE())
        );
        tokenContract.addCreatorStory(1, "XCOPY", "I AM XCOPY");

        // test collector story
        vm.expectEmit(true, true, true, true);
        emit Story(1, collector, collector.toHexString(), "I AM NOT XCOPY");
        tokenContract.addStory(1, "NOT XCOPY", "I AM NOT XCOPY");
        vm.stopPrank();

        // test that owner can't add collector story
        vm.expectRevert(Shatter.CallerNotTokenOwnerOrDelegate.selector);
        tokenContract.addStory(1, "NOT XCOPY", "I AM NOT XCOPY");
    }

    function test_addStory_delegate(address delegate) public {
        // limit fuzz and mint
        vm.assume(delegate != address(this));
        vm.assume(delegate != admin);
        tokenContract.mint(address(this), "uri", 1, 2, 0);

        // set delegation registry
        tokenContract.setNftDelegationRegistry(nftDelegationRegistry);

        // mock calls
        vm.mockCall(
            nftDelegationRegistry,
            abi.encodeWithSelector(ITLNftDelegationRegistry.checkDelegateForERC721.selector),
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
        emit CreatorStory(0, address(this), address(this).toHexString(), "I AM XCOPY");
        tokenContract.addCreatorStory(0, "XCOPY", "I AM XCOPY");

        // test delegate can't add creator story
        vm.startPrank(delegate, delegate);
        vm.expectRevert(
            abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE())
        );
        tokenContract.addCreatorStory(0, "XCOPY", "I AM XCOPY");

        // test story
        vm.expectEmit(true, true, true, true);
        emit Story(0, delegate, delegate.toHexString(), "I AM NOT XCOPY");
        tokenContract.addStory(0, "NOT XCOPY", "I AM NOT XCOPY");
        vm.stopPrank();

        // shatter and test again
        tokenContract.shatter(1);

        // test creator story
        vm.expectEmit(true, true, true, true);
        emit CreatorStory(1, address(this), address(this).toHexString(), "I AM XCOPY");
        tokenContract.addCreatorStory(1, "XCOPY", "I AM XCOPY");

        // test delegate can't add creator story
        vm.startPrank(delegate, delegate);
        vm.expectRevert(
            abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE())
        );
        tokenContract.addCreatorStory(1, "XCOPY", "I AM XCOPY");

        // test story
        vm.expectEmit(true, true, true, true);
        emit Story(1, delegate, delegate.toHexString(), "I AM NOT XCOPY");
        tokenContract.addStory(1, "NOT XCOPY", "I AM NOT XCOPY");
        vm.stopPrank();

        // clear mocked calls
        vm.clearMockedCalls();
    }

    function test_addStory_disabled(address collector) public {
        vm.assume(collector != address(0));
        vm.assume(collector != address(this));
        tokenContract.mint(collector, "uri", 1, 2, 0);

        // disable story
        tokenContract.setStoryStatus(false);

        // test creator story
        vm.expectEmit(true, true, true, true);
        emit CreatorStory(0, address(this), address(this).toHexString(), "I AM XCOPY");
        tokenContract.addCreatorStory(0, "XCOPY", "I AM XCOPY");

        // test collector can't add creator story
        vm.startPrank(collector, collector);
        vm.expectRevert(
            abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE())
        );
        tokenContract.addCreatorStory(0, "XCOPY", "I AM XCOPY");

        // test collector story reverts
        vm.expectRevert(Shatter.StoryNotEnabled.selector);
        tokenContract.addStory(0, "NOT XCOPY", "I AM NOT XCOPY");
        vm.stopPrank();

        // test that owner can't add collector story
        vm.expectRevert(Shatter.StoryNotEnabled.selector);
        tokenContract.addStory(0, "NOT XCOPY", "I AM NOT XCOPY");

        // shatter and test again
        vm.prank(collector);
        tokenContract.shatter(1);

        // test creator story
        vm.expectEmit(true, true, true, true);
        emit CreatorStory(1, address(this), address(this).toHexString(), "I AM XCOPY");
        tokenContract.addCreatorStory(1, "XCOPY", "I AM XCOPY");

        // test collector can't add creator story
        vm.startPrank(collector, collector);
        vm.expectRevert(
            abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE())
        );
        tokenContract.addCreatorStory(1, "XCOPY", "I AM XCOPY");

        // test collector story reverts
        vm.expectRevert(Shatter.StoryNotEnabled.selector);
        tokenContract.addStory(1, "NOT XCOPY", "I AM NOT XCOPY");
        vm.stopPrank();

        // test that owner can't add collector story
        vm.expectRevert(Shatter.StoryNotEnabled.selector);
        tokenContract.addStory(1, "NOT XCOPY", "I AM NOT XCOPY");
    }

    /// @notice test blocklist functions
    // - test blocked ✅
    // - test not blocked ✅
    // - test access control for changing the registry ✅
    function test_setBlockListRegistry_accessControl(address user) public {
        vm.assume(user != address(this) && user != admin);
        address[] memory users = new address[](1);
        users[0] = user;

        // verify user can't access
        vm.startPrank(user, user);
        vm.expectRevert(
            abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE())
        );
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
        tokenContract.mint(address(this), "uri", 1, 2, 0);

        // expect revert
        vm.expectRevert();
        tokenContract.approve(address(10), 0);
        vm.expectRevert();
        tokenContract.setApprovalForAll(address(10), true);

        // expect can set approval for all to false regardless
        tokenContract.setApprovalForAll(address(10), false);
    }

    function test_blocklist_not_shattered(address collector, address operator) public {
        // limit fuzz
        vm.assume(collector != address(0));
        vm.assume(collector != operator);
        vm.assume(operator != address(0));

        // mock call
        vm.mockCall(
            blocklistRegistry, abi.encodeWithSelector(IBlockListRegistry.getBlockListStatus.selector), abi.encode(true)
        );

        // update blocklist registry
        tokenContract.setBlockListRegistry(blocklistRegistry);

        // mint and verify blocked operator
        tokenContract.mint(collector, "uri", 1, 2, 0);
        vm.startPrank(collector, collector);
        vm.expectRevert(Shatter.OperatorBlocked.selector);
        tokenContract.approve(operator, 0);
        vm.expectRevert(Shatter.OperatorBlocked.selector);
        tokenContract.setApprovalForAll(operator, true);
        vm.stopPrank();

        // unblock operator and verify approvals
        vm.mockCall(
            blocklistRegistry, abi.encodeWithSelector(IBlockListRegistry.getBlockListStatus.selector), abi.encode(false)
        );
        vm.startPrank(collector, collector);
        tokenContract.approve(operator, 0);
        assertEq(tokenContract.getApproved(0), operator);
        tokenContract.setApprovalForAll(operator, true);
        assertTrue(tokenContract.isApprovedForAll(collector, operator));
        vm.stopPrank();

        // clear mocked call
        vm.clearMockedCalls();
    }

    function test_blocklist_shattered(address collector, address operator) public {
        // limit fuzz
        vm.assume(collector != address(0));
        vm.assume(collector != operator);
        vm.assume(operator != address(0));

        // mock call
        vm.mockCall(
            blocklistRegistry, abi.encodeWithSelector(IBlockListRegistry.getBlockListStatus.selector), abi.encode(true)
        );

        // update blocklist registry
        tokenContract.setBlockListRegistry(blocklistRegistry);

        // mint and verify blocked operator
        tokenContract.mint(collector, "uri", 1, 2, 0);
        vm.startPrank(collector, collector);
        tokenContract.shatter(1);
        vm.expectRevert(Shatter.OperatorBlocked.selector);
        tokenContract.approve(operator, 1);
        vm.expectRevert(Shatter.OperatorBlocked.selector);
        tokenContract.setApprovalForAll(operator, true);
        vm.stopPrank();

        // unblock operator and verify approvals
        vm.mockCall(
            blocklistRegistry, abi.encodeWithSelector(IBlockListRegistry.getBlockListStatus.selector), abi.encode(false)
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

    function test_blocklist_fused(address collector, address operator) public {
        // limit fuzz
        vm.assume(collector != address(0));
        vm.assume(collector != operator);
        vm.assume(operator != address(0));

        // mock call
        vm.mockCall(
            blocklistRegistry, abi.encodeWithSelector(IBlockListRegistry.getBlockListStatus.selector), abi.encode(true)
        );

        // update blocklist registry
        tokenContract.setBlockListRegistry(blocklistRegistry);

        // mint and verify blocked operator
        tokenContract.mint(collector, "uri", 1, 2, 0);
        vm.startPrank(collector, collector);
        tokenContract.shatter(1);
        tokenContract.fuse();
        vm.expectRevert(Shatter.OperatorBlocked.selector);
        tokenContract.approve(operator, 0);
        vm.expectRevert(Shatter.OperatorBlocked.selector);
        tokenContract.setApprovalForAll(operator, true);
        vm.stopPrank();

        // unblock operator and verify approvals
        vm.mockCall(
            blocklistRegistry, abi.encodeWithSelector(IBlockListRegistry.getBlockListStatus.selector), abi.encode(false)
        );
        vm.startPrank(collector, collector);
        tokenContract.approve(operator, 0);
        assertEq(tokenContract.getApproved(0), operator);
        tokenContract.setApprovalForAll(operator, true);
        assertTrue(tokenContract.isApprovedForAll(collector, operator));
        vm.stopPrank();

        // clear mocked call
        vm.clearMockedCalls();
    }

    /// @notice test TL Nft Delegation Registry functions
    // - test access control for changing the registry

    function test_setNftDelegationRegistry_accessControl(address user) public {
        vm.assume(user != address(this) && user != admin);
        address[] memory users = new address[](1);
        users[0] = user;

        // verify user can't access
        vm.startPrank(user, user);
        vm.expectRevert(
            abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE())
        );
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
        tokenContract.mint(address(1), "uri", 1, 2, 0);

        // add story reverts for delegate but not collector
        vm.expectRevert();
        vm.prank(address(2));
        tokenContract.addStory(0, "", "story");

        vm.prank(address(1));
        tokenContract.addStory(0, "", "story");

        // synergy reverts open for delegate but deterministic for collector
        vm.expectRevert();
        vm.prank(address(2));
        tokenContract.acceptTokenUriUpdate(0);
        vm.expectRevert();
        vm.prank(address(2));
        tokenContract.rejectTokenUriUpdate(0);

        vm.expectRevert(Shatter.NoTokenUriUpdateAvailable.selector);
        vm.prank(address(1));
        tokenContract.acceptTokenUriUpdate(0);
        vm.expectRevert(Shatter.NoTokenUriUpdateAvailable.selector);
        vm.prank(address(1));
        tokenContract.rejectTokenUriUpdate(0);
    }
}

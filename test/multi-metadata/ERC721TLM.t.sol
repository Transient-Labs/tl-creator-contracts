// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import "forge-std/Test.sol";
import {IERC2309Upgradeable} from "openzeppelin-upgradeable/interfaces/IERC2309Upgradeable.sol";
import {Strings} from "openzeppelin/utils/Strings.sol";
import {
    ERC721TLM,
    OwnableAccessControlUpgradeable,
    EmptyTokenURI,
    MintToZeroAddress,
    BatchSizeTooSmall,
    TokenDoesntExist,
    AirdropTooFewAddresses,
    CallerNotApprovedOrOwner,
    CallerNotTokenOwner,
    InvalidTokenURIIndex,
    NoTokensSpecified
} from "tl-creator-contracts/multi-metadata/ERC721TLM.sol";
import {NotRoleOrOwner, NotSpecifiedRole} from "tl-sol-tools/upgradeable/access/OwnableAccessControlUpgradeable.sol";
import {BlockListRegistry} from "tl-blocklist/BlockListRegistry.sol";

contract ERC721TLMUnitTest is IERC2309Upgradeable, Test {
    using Strings for uint256;

    ERC721TLM public tokenContract;
    address public royaltyRecipient = makeAddr("royaltyRecipient");

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event RoleChange(address indexed from, address indexed user, bool indexed approved, bytes32 role);
    event BlockListRegistryUpdated(address indexed caller, address indexed oldRegistry, address indexed newRegistry);
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event MetadataUpdate(uint256 tokenId);
    event TokenUriPinned(uint256 indexed tokenId, uint256 indexed index);
    event TokenUriUnpinned(uint256 indexed tokenId);
    event CreatorStory(uint256 indexed tokenId, address indexed creatorAddress, string creatorName, string story);
    event Story(uint256 indexed tokenId, address indexed collectorAddress, string collectorName, string story);

    function setUp() public {
        address[] memory admins = new address[](0);
        tokenContract = new ERC721TLM(false);
        tokenContract.initialize("Test721", "T721", royaltyRecipient, 1000, address(this), admins, true, address(0));
    }

    /// @notice Initialization Tests
    function testInitialization(
        string memory name,
        string memory symbol,
        address defaultRoyaltyRecipient,
        uint256 defaultRoyaltyPercentage,
        address initOwner,
        address[] memory admins,
        bool enableStory,
        address blockListRegistry
    ) public {
        // ensure royalty guards enabled
        vm.assume(defaultRoyaltyRecipient != address(0));
        if (defaultRoyaltyPercentage >= 10_000) {
            defaultRoyaltyPercentage = defaultRoyaltyPercentage % 10_000;
        }

        // create contract
        tokenContract = new ERC721TLM(false);
        // initialize and verify events thrown (order matters)
        vm.expectEmit(true, true, false, false);
        emit OwnershipTransferred(address(0), address(this));
        vm.expectEmit(true, true, false, false);
        emit OwnershipTransferred(address(this), initOwner);
        vm.expectEmit(true, true, true, false);
        emit BlockListRegistryUpdated(address(this), address(0), blockListRegistry);
        for (uint256 i = 0; i < admins.length; i++) {
            vm.expectEmit(true, true, true, true);
            emit RoleChange(address(this), admins[i], true, tokenContract.ADMIN_ROLE());
        }
        tokenContract.initialize(
            name,
            symbol,
            defaultRoyaltyRecipient,
            defaultRoyaltyPercentage,
            initOwner,
            admins,
            enableStory,
            blockListRegistry
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
        assertEq(address(tokenContract.blockListRegistry()), blockListRegistry);

        // can't initialize again
        vm.expectRevert(bytes("Initializable: contract is already initialized"));
        tokenContract.initialize(
            name,
            symbol,
            defaultRoyaltyRecipient,
            defaultRoyaltyPercentage,
            initOwner,
            admins,
            enableStory,
            blockListRegistry
        );
    }

    /// @notice test mint contract access approvals
    function testSetApprovedMintContracts() public {
        address[] memory minters = new address[](1);
        minters[0] = address(1);
        address[] memory admins = new address[](1);
        admins[0] = address(2);

        // verify rando can't access
        vm.startPrank(address(3), address(3));
        vm.expectRevert();
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
        vm.startPrank(address(1), address(1));
        vm.expectRevert();
        tokenContract.setApprovedMintContracts(minters, true);
        vm.stopPrank();

        // verify owner can access
        tokenContract.setApprovedMintContracts(minters, false);
        assertFalse(tokenContract.hasRole(tokenContract.APPROVED_MINT_CONTRACT(), address(1)));
    }

    /// @notice test non-existent token ownership
    function testNonExistentTokens(uint8 mintNum, uint8 numTokens) public {
        for (uint256 i = 0; i < mintNum; i++) {
            tokenContract.mint(address(this), "uri");
        }
        if (numTokens > 1) {
            tokenContract.batchMint(address(this), numTokens, "uri");
        }
        uint256 nonexistentTokenId = uint256(mintNum) + uint256(numTokens) + 1;
        vm.expectRevert(abi.encodePacked("ERC721: invalid token ID"));
        tokenContract.ownerOf(nonexistentTokenId);
        vm.expectRevert(TokenDoesntExist.selector);
        tokenContract.tokenURI(nonexistentTokenId);
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
        tokenContract.mint(address(this), "");
    }

    function testMintAccessControl(address user) public {
        vm.assume(user != address(this));
        vm.assume(user != address(0));
        // ensure user can't call the mint function
        vm.startPrank(user, user);
        vm.expectRevert(abi.encodeWithSelector(NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE()));
        tokenContract.mint(address(this), "uriOne");
        vm.stopPrank();

        // grant admin access and ensure that the user can call the mint function
        address[] memory admins = new address[](1);
        admins[0] = user;
        tokenContract.setRole(tokenContract.ADMIN_ROLE(), admins, true);
        vm.startPrank(user, user);
        vm.expectEmit(true, true, true, false);
        emit Transfer(address(0), address(this), 1);
        tokenContract.mint(address(this), "uriOne");
        vm.stopPrank();
        assertEq(tokenContract.balanceOf(address(this)), 1);
        assertEq(tokenContract.ownerOf(1), address(this));
        assertEq(tokenContract.tokenURI(1), "uriOne");

        // revoke admin access and ensure that the user can't call the mint function
        tokenContract.setRole(tokenContract.ADMIN_ROLE(), admins, false);
        vm.startPrank(user, user);
        vm.expectRevert(abi.encodeWithSelector(NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE()));
        tokenContract.mint(address(this), "uriOne");
        vm.stopPrank();

        // grant mint contract role and ensure that the user can't call the mint function
        tokenContract.setRole(tokenContract.APPROVED_MINT_CONTRACT(), admins, true);
        vm.startPrank(user, user);
        vm.expectRevert(abi.encodeWithSelector(NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE()));
        tokenContract.mint(address(this), "uriOne");
        vm.stopPrank();

        // revoke mint contract role and ensure that the user can't call the mint function
        tokenContract.setRole(tokenContract.APPROVED_MINT_CONTRACT(), admins, false);
        vm.startPrank(user, user);
        vm.expectRevert(abi.encodeWithSelector(NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE()));
        tokenContract.mint(address(this), "uriOne");
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
            tokenContract.mint(recipient, uri);
            assertEq(tokenContract.balanceOf(recipient), i);
            assertEq(tokenContract.ownerOf(i), recipient);
            assertEq(tokenContract.tokenURI(i), uri);
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
            tokenContract.mint(recipient, uri, royaltyAddress, royaltyPercent);
            assertEq(tokenContract.balanceOf(recipient), i);
            assertEq(tokenContract.ownerOf(i), recipient);
            assertEq(tokenContract.tokenURI(i), uri);
            (address recp, uint256 amt) = tokenContract.royaltyInfo(i, 10_000);
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
            tokenContract.mint(address(this), "uri");
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
    function testBatchMintCustomErrors() public {
        vm.expectRevert(MintToZeroAddress.selector);
        tokenContract.batchMint(address(0), 2, "uri");

        vm.expectRevert(EmptyTokenURI.selector);
        tokenContract.batchMint(address(this), 2, "");

        vm.expectRevert(BatchSizeTooSmall.selector);
        tokenContract.batchMint(address(this), 1, "baseUri");
    }

    function testBatchMintAccessControl(address user) public {
        vm.assume(user != address(this));
        vm.assume(user != address(0));
        // ensure user can't call the mint function
        vm.startPrank(user, user);
        vm.expectRevert(abi.encodeWithSelector(NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE()));
        tokenContract.batchMint(address(this), 2, "baseUri");
        vm.stopPrank();

        // grant admin access and ensure that the user can call the mint function
        address[] memory admins = new address[](1);
        admins[0] = user;
        tokenContract.setRole(tokenContract.ADMIN_ROLE(), admins, true);
        vm.startPrank(user, user);
        uint256 start = tokenContract.totalSupply() + 1;
        uint256 end = start + 1;
        for (uint256 id = start; id < end + 1; ++id) {
            vm.expectEmit(true, true, true, false);
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
        vm.expectRevert(abi.encodeWithSelector(NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE()));
        tokenContract.batchMint(address(this), 2, "baseUri");
        vm.stopPrank();

        // grant mint contract role and ensure that the user can't call the mint function
        tokenContract.setRole(tokenContract.APPROVED_MINT_CONTRACT(), admins, true);
        vm.startPrank(user, user);
        vm.expectRevert(abi.encodeWithSelector(NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE()));
        tokenContract.batchMint(address(this), 2, "baseUri");
        vm.stopPrank();

        // revoke mint contract role and ensure that the user can't call the mint function
        tokenContract.setRole(tokenContract.APPROVED_MINT_CONTRACT(), admins, false);
        vm.startPrank(user, user);
        vm.expectRevert(abi.encodeWithSelector(NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE()));
        tokenContract.batchMint(address(this), 2, "baseUri");
        vm.stopPrank();
    }

    function testBatchMint(uint256 numTokens, address recipient) public {
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

        // test mint after metadata
        tokenContract.mint(address(this), "newUri");
        assertEq(tokenContract.ownerOf(numTokens + 1), address(this));
        assertEq(tokenContract.tokenURI(numTokens + 1), "newUri");
    }

    function testBatchMintTransfers(uint256 numTokens, address recipient, address secondRecipient) public {
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

    /// @notice test batch mint ultra
    // - access control ✅
    // - proper recipient ✅
    // - consectuive transfer event ✅
    // - proper token ids ✅
    // - ownership ✅
    // - balance ✅
    // - transfer to another address ✅
    // - safe transfer to another address ✅
    // - token uris ✅
    function testBatchMintUltraCustomErrors() public {
        vm.expectRevert(MintToZeroAddress.selector);
        tokenContract.batchMintUltra(address(0), 2, "uri");

        vm.expectRevert(EmptyTokenURI.selector);
        tokenContract.batchMintUltra(address(this), 2, "");

        vm.expectRevert(BatchSizeTooSmall.selector);
        tokenContract.batchMintUltra(address(this), 1, "baseUri");
    }

    function testBatchMintUltraAccessControl(address user) public {
        vm.assume(user != address(this));
        vm.assume(user != address(0));
        // ensure user can't call the mint function
        vm.startPrank(user, user);
        vm.expectRevert(abi.encodeWithSelector(NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE()));
        tokenContract.batchMintUltra(address(this), 2, "baseUri");
        vm.stopPrank();

        // grant admin access and ensure that the user can call the mint function
        address[] memory admins = new address[](1);
        admins[0] = user;
        tokenContract.setRole(tokenContract.ADMIN_ROLE(), admins, true);
        vm.startPrank(user, user);
        uint256 start = tokenContract.totalSupply() + 1;
        uint256 end = start + 1;
        vm.expectEmit(true, true, true, true);
        emit ConsecutiveTransfer(start, end, address(0), address(this));
        tokenContract.batchMintUltra(address(this), 2, "baseUri");
        vm.stopPrank();
        assertEq(tokenContract.balanceOf(address(this)), 2);
        assertEq(tokenContract.ownerOf(1), address(this));
        assertEq(tokenContract.ownerOf(2), address(this));
        assertEq(tokenContract.tokenURI(1), "baseUri/0");
        assertEq(tokenContract.tokenURI(2), "baseUri/1");

        // revoke admin access and ensure that the user can't call the mint function
        tokenContract.setRole(tokenContract.ADMIN_ROLE(), admins, false);
        vm.startPrank(user, user);
        vm.expectRevert(abi.encodeWithSelector(NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE()));
        tokenContract.batchMintUltra(address(this), 2, "baseUri");
        vm.stopPrank();

        // grant mint contract role and ensure that the user can't call the mint function
        tokenContract.setRole(tokenContract.APPROVED_MINT_CONTRACT(), admins, true);
        vm.startPrank(user, user);
        vm.expectRevert(abi.encodeWithSelector(NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE()));
        tokenContract.batchMintUltra(address(this), 2, "baseUri");
        vm.stopPrank();

        // revoke mint contract role and ensure that the user can't call the mint function
        tokenContract.setRole(tokenContract.APPROVED_MINT_CONTRACT(), admins, false);
        vm.startPrank(user, user);
        vm.expectRevert(abi.encodeWithSelector(NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE()));
        tokenContract.batchMintUltra(address(this), 2, "baseUri");
        vm.stopPrank();
    }

    function testBatchMintUltra(uint256 numTokens, address recipient) public {
        vm.assume(numTokens > 1);
        vm.assume(recipient != address(0));
        if (numTokens > 1000) {
            numTokens = numTokens % 1000 + 2; // map to 1000
        }
        uint256 start = tokenContract.totalSupply() + 1;
        uint256 end = start + numTokens - 1;
        vm.expectEmit(true, true, true, true);
        emit ConsecutiveTransfer(start, end, address(0), recipient);
        tokenContract.batchMintUltra(recipient, numTokens, "baseUri");
        assertEq(tokenContract.balanceOf(recipient), numTokens);
        for (uint256 i = 1; i <= numTokens; i++) {
            string memory uri = string(abi.encodePacked("baseUri/", (i - start).toString()));
            assertEq(tokenContract.ownerOf(i), recipient);
            assertEq(tokenContract.tokenURI(i), uri);
        }

        // test mint after metadata
        tokenContract.mint(address(this), "newUri");
        assertEq(tokenContract.ownerOf(numTokens + 1), address(this));
        assertEq(tokenContract.tokenURI(numTokens + 1), "newUri");
    }

    function testBatchMintUltraTransfers(uint256 numTokens, address recipient, address secondRecipient) public {
        vm.assume(recipient != address(0));
        vm.assume(secondRecipient != address(0));
        vm.assume(recipient != secondRecipient);
        vm.assume(recipient.code.length == 0);
        vm.assume(secondRecipient.code.length == 0);
        vm.assume(numTokens > 1);
        if (numTokens > 1000) {
            numTokens = numTokens % 1000 + 2; // map to 1000
        }
        tokenContract.batchMintUltra(address(this), numTokens, "baseUri");
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
    function testAirdropCustomErrors() public {
        address[] memory addresses = new address[](1);
        addresses[0] = address(1);
        vm.expectRevert(EmptyTokenURI.selector);
        tokenContract.airdrop(addresses, "");

        vm.expectRevert(AirdropTooFewAddresses.selector);
        tokenContract.airdrop(addresses, "baseUri");
    }

    function testAirdropAccessControl(address user) public {
        vm.assume(user != address(this));
        vm.assume(user != address(0));
        address[] memory addresses = new address[](2);
        addresses[0] = address(1);
        addresses[1] = address(2);
        // ensure user can't call the airdrop function
        vm.startPrank(user, user);
        vm.expectRevert(abi.encodeWithSelector(NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE()));
        tokenContract.airdrop(addresses, "baseUri");
        vm.stopPrank();

        // grant admin access and ensure that the user can call the airdrop function
        address[] memory admins = new address[](1);
        admins[0] = user;
        tokenContract.setRole(tokenContract.ADMIN_ROLE(), admins, true);
        vm.startPrank(user, user);
        vm.expectEmit(true, true, true, false);
        emit Transfer(address(0), address(1), 1);
        vm.expectEmit(true, true, true, false);
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
        vm.expectRevert(abi.encodeWithSelector(NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE()));
        tokenContract.airdrop(addresses, "baseUri");
        vm.stopPrank();

        // grant mint contract role and ensure that the user can't call the airdrop function
        tokenContract.setRole(tokenContract.APPROVED_MINT_CONTRACT(), admins, true);
        vm.startPrank(user, user);
        vm.expectRevert(abi.encodeWithSelector(NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE()));
        tokenContract.airdrop(addresses, "baseUri");
        vm.stopPrank();

        // revoke mint contract role and ensure that the user can't call the airdrop function
        tokenContract.setRole(tokenContract.APPROVED_MINT_CONTRACT(), admins, false);
        vm.startPrank(user, user);
        vm.expectRevert(abi.encodeWithSelector(NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE()));
        tokenContract.airdrop(addresses, "baseUri");
        vm.stopPrank();
    }

    function testAirdrop(uint16 numAddresses) public {
        vm.assume(numAddresses > 1);
        if (numAddresses > 1000) {
            numAddresses = numAddresses % 299 + 2; // map to 300
        }
        address[] memory addresses = new address[](numAddresses);
        for (uint256 i = 0; i < numAddresses; i++) {
            addresses[i] = makeAddr(i.toString());
        }
        for (uint256 i = 1; i <= numAddresses; i++) {
            vm.expectEmit(true, true, true, false);
            emit Transfer(address(0), addresses[i - 1], i);
        }
        tokenContract.airdrop(addresses, "baseUri");
        for (uint256 i = 1; i <= numAddresses; i++) {
            string memory uri = string(abi.encodePacked("baseUri/", (i - 1).toString()));
            assertEq(tokenContract.balanceOf(addresses[i - 1]), 1);
            assertEq(tokenContract.ownerOf(i), addresses[i - 1]);
            assertEq(tokenContract.tokenURI(i), uri);
        }

        // test mint after metadata
        tokenContract.mint(address(this), "newUri");
        assertEq(tokenContract.ownerOf(numAddresses + 1), address(this));
        assertEq(tokenContract.tokenURI(numAddresses + 1), "newUri");
    }

    function testAirdropTransfers(uint16 numAddresses, address recipient) public {
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
    function testExternalMintCustomErrors() public {
        address[] memory minters = new address[](1);
        minters[0] = address(this);
        tokenContract.setRole(tokenContract.APPROVED_MINT_CONTRACT(), minters, true);
        vm.expectRevert(EmptyTokenURI.selector);
        tokenContract.externalMint(address(this), "");
    }

    function testExternalMintAccessControl(address user) public {
        vm.assume(user != address(this));
        vm.assume(user != address(0));
        address[] memory addresses = new address[](2);
        addresses[0] = address(1);
        addresses[1] = address(2);
        // ensure user can't call the airdrop function
        vm.startPrank(user, user);
        vm.expectRevert(abi.encodeWithSelector(NotSpecifiedRole.selector, tokenContract.APPROVED_MINT_CONTRACT()));
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
        vm.expectRevert(abi.encodeWithSelector(NotSpecifiedRole.selector, tokenContract.APPROVED_MINT_CONTRACT()));
        tokenContract.externalMint(address(this), "uri");
        vm.stopPrank();

        // grant admin role and ensure that the user can't call the airdrop function
        tokenContract.setRole(tokenContract.ADMIN_ROLE(), minters, true);
        vm.startPrank(user, user);
        vm.expectRevert(abi.encodeWithSelector(NotSpecifiedRole.selector, tokenContract.APPROVED_MINT_CONTRACT()));
        tokenContract.externalMint(address(this), "uri");
        vm.stopPrank();

        // revoke admin role and ensure that the user can't call the airdrop function
        tokenContract.setRole(tokenContract.ADMIN_ROLE(), minters, false);
        vm.startPrank(user, user);
        vm.expectRevert(abi.encodeWithSelector(NotSpecifiedRole.selector, tokenContract.APPROVED_MINT_CONTRACT()));
        tokenContract.externalMint(address(this), "uri");
        vm.stopPrank();
    }

    function testExternalMint(address recipient, string memory uri, uint16 numTokens) public {
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
    }

    function testExternalMintTransfers(
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
    function testMintsCombined(uint8 n1, uint8 n2, uint8 n3, uint8 n4, uint8 n5, uint16 batchSize, uint16 numAddresses)
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
        n1 = n1 % 5;
        n2 = n2 % 5;
        n3 = n3 % 5;
        n4 = n4 % 5;
        n5 = n5 % 5;

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
            tokenContract.batchMintUltra(address(this), batchSize, "uri");
            assertEq(tokenContract.totalSupply(), id + batchSize);
            id += batchSize;
        } else if (n1 == 3) {
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
            tokenContract.batchMintUltra(address(this), batchSize, "uri");
            assertEq(tokenContract.totalSupply(), id + batchSize);
            id += batchSize;
        } else if (n2 == 3) {
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
            tokenContract.batchMintUltra(address(this), batchSize, "uri");
            assertEq(tokenContract.totalSupply(), id + batchSize);
            id += batchSize;
        } else if (n3 == 3) {
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
            tokenContract.batchMintUltra(address(this), batchSize, "uri");
            assertEq(tokenContract.totalSupply(), id + batchSize);
            id += batchSize;
        } else if (n4 == 3) {
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

        if (n5 == 0) {
            tokenContract.mint(address(this), "uri");
            assertEq(tokenContract.totalSupply(), id + 1);
            id += 1;
        } else if (n5 == 1) {
            tokenContract.batchMint(address(this), batchSize, "uri");
            assertEq(tokenContract.totalSupply(), id + batchSize);
            id += batchSize;
        } else if (n5 == 2) {
            tokenContract.batchMintUltra(address(this), batchSize, "uri");
            assertEq(tokenContract.totalSupply(), id + batchSize);
            id += batchSize;
        } else if (n5 == 3) {
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
    function testBurnNonExistentToken(uint16 tokenId) public {
        vm.expectRevert(abi.encodePacked("ERC721: invalid token ID"));
        tokenContract.burn(tokenId);
    }

    function testBurnAccessControl(uint16 tokenId, address collector, address hacker) public {
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
        vm.expectRevert(CallerNotApprovedOrOwner.selector);
        tokenContract.burn(tokenId);
        vm.stopPrank();
        // verify hacker with admin access can't burn
        address[] memory addys = new address[](1);
        addys[0] = hacker;
        tokenContract.setRole(tokenContract.ADMIN_ROLE(), addys, true);
        vm.startPrank(hacker, hacker);
        vm.expectRevert(CallerNotApprovedOrOwner.selector);
        tokenContract.burn(tokenId);
        vm.stopPrank();
        tokenContract.setRole(tokenContract.ADMIN_ROLE(), addys, false);
        // verify hacker with minter access can't burn
        tokenContract.setRole(tokenContract.APPROVED_MINT_CONTRACT(), addys, true);
        vm.startPrank(hacker, hacker);
        vm.expectRevert(CallerNotApprovedOrOwner.selector);
        tokenContract.burn(tokenId);
        vm.stopPrank();
        tokenContract.setRole(tokenContract.APPROVED_MINT_CONTRACT(), addys, false);
        // veirfy owner can't burn
        vm.expectRevert(CallerNotApprovedOrOwner.selector);
        tokenContract.burn(tokenId);
        // verify collector can burn tokenId
        vm.expectEmit(true, true, true, false);
        emit Transfer(collector, address(0), tokenId);
        vm.startPrank(collector, collector);
        tokenContract.burn(tokenId);
        vm.stopPrank();
        vm.expectRevert(TokenDoesntExist.selector);
        tokenContract.tokenURI(tokenId);
        vm.expectRevert();
        tokenContract.ownerOf(tokenId);
        assertEq(tokenContract.balanceOf(collector), 0);
    }

    function testBurnMint(uint16 tokenId, address collector, address operator) public {
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
        vm.expectEmit(true, true, true, false);
        emit Transfer(collector, address(0), tokenId);
        tokenContract.burn(tokenId);
        vm.stopPrank();
        assertEq(tokenContract.balanceOf(collector), 2);
        vm.expectRevert(TokenDoesntExist.selector);
        tokenContract.tokenURI(tokenId);
        vm.expectRevert();
        tokenContract.ownerOf(tokenId);
        // verify operator can't burn
        vm.startPrank(operator, operator);
        vm.expectRevert(CallerNotApprovedOrOwner.selector);
        tokenContract.burn(tokenId + 1);
        vm.stopPrank();
        // grant operator rights and verify can burn tokenId + 1 &  + 2
        vm.startPrank(collector, collector);
        tokenContract.approve(operator, tokenId + 1);
        vm.stopPrank();
        vm.startPrank(operator, operator);
        vm.expectEmit(true, true, true, false);
        emit Transfer(collector, address(0), tokenId + 1);
        tokenContract.burn(tokenId + 1);
        vm.stopPrank();
        assertEq(tokenContract.balanceOf(collector), 1);
        vm.expectRevert(TokenDoesntExist.selector);
        tokenContract.tokenURI(tokenId + 1);
        vm.expectRevert();
        tokenContract.ownerOf(tokenId + 1);
        // set approval for all
        vm.startPrank(collector, collector);
        tokenContract.setApprovalForAll(operator, true);
        vm.stopPrank();
        vm.startPrank(operator, operator);
        vm.expectEmit(true, true, true, false);
        emit Transfer(collector, address(0), tokenId + 2);
        tokenContract.burn(tokenId + 2);
        vm.stopPrank();
        assertEq(tokenContract.balanceOf(collector), 0);
        vm.expectRevert(TokenDoesntExist.selector);
        tokenContract.tokenURI(tokenId + 2);
        vm.expectRevert();
        tokenContract.ownerOf(tokenId + 2);
    }

    function testBurnBatchMint(uint16 batchSize, address collector, address operator) public {
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
            vm.expectRevert(TokenDoesntExist.selector);
            tokenContract.tokenURI(i);
            vm.expectRevert();
            tokenContract.ownerOf(i);
        }
        // batch mint again to collector
        tokenContract.batchMint(collector, batchSize, "baseUri");
        // verify that operator can't burn
        for (uint256 i = batchSize + 1; i <= 2 * batchSize; i++) {
            vm.startPrank(operator, operator);
            vm.expectRevert(CallerNotApprovedOrOwner.selector);
            tokenContract.burn(i);
            vm.stopPrank();
        }
        // grant operator rights for each token and burn
        for (uint256 i = batchSize + 1; i <= 2 * batchSize; i++) {
            vm.startPrank(collector, collector);
            tokenContract.approve(operator, i);
            vm.stopPrank();
            vm.startPrank(collector, collector);
            vm.expectEmit(true, true, true, false);
            emit Transfer(collector, address(0), i);
            tokenContract.burn(i);
            vm.stopPrank();
            assertEq(tokenContract.balanceOf(collector), 2 * batchSize - i);
            vm.expectRevert(TokenDoesntExist.selector);
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
            vm.expectEmit(true, true, true, false);
            emit Transfer(collector, address(0), i);
            tokenContract.burn(i);
            vm.stopPrank();
            assertEq(tokenContract.balanceOf(collector), 3 * batchSize - i);
            vm.expectRevert(TokenDoesntExist.selector);
            tokenContract.tokenURI(i);
            vm.expectRevert();
            tokenContract.ownerOf(i);
        }
    }

    function testBurnBatchMintUltra(uint16 batchSize, address collector, address operator) public {
        vm.assume(collector != address(0) && collector != operator && operator != address(0));
        if (batchSize < 2) {
            batchSize = 2;
        }
        if (batchSize > 300) {
            batchSize = batchSize % 299 + 2;
        }
        // batch mint to collector
        tokenContract.batchMintUltra(collector, batchSize, "baseUri");
        // verify collector can burn the batch
        for (uint256 i = 1; i <= batchSize; i++) {
            vm.startPrank(collector, collector);
            vm.expectEmit(true, true, true, false);
            emit Transfer(collector, address(0), i);
            tokenContract.burn(i);
            vm.stopPrank();
            assertEq(tokenContract.balanceOf(collector), batchSize - i);
            vm.expectRevert(TokenDoesntExist.selector);
            tokenContract.tokenURI(i);
            vm.expectRevert();
            tokenContract.ownerOf(i);
        }
        // batch mint again to collector
        tokenContract.batchMintUltra(collector, batchSize, "baseUri");
        // verify that operator can't burn
        for (uint256 i = batchSize + 1; i <= 2 * batchSize; i++) {
            vm.startPrank(operator, operator);
            vm.expectRevert(CallerNotApprovedOrOwner.selector);
            tokenContract.burn(i);
            vm.stopPrank();
        }
        // grant operator rights for each token and burn
        for (uint256 i = batchSize + 1; i <= 2 * batchSize; i++) {
            vm.startPrank(collector, collector);
            tokenContract.approve(operator, i);
            vm.stopPrank();
            vm.startPrank(collector, collector);
            vm.expectEmit(true, true, true, false);
            emit Transfer(collector, address(0), i);
            tokenContract.burn(i);
            vm.stopPrank();
            assertEq(tokenContract.balanceOf(collector), 2 * batchSize - i);
            vm.expectRevert(TokenDoesntExist.selector);
            tokenContract.tokenURI(i);
            vm.expectRevert();
            tokenContract.ownerOf(i);
        }
        // mint batch again
        tokenContract.batchMintUltra(collector, batchSize, "baseUri");
        vm.startPrank(collector, collector);
        tokenContract.setApprovalForAll(operator, true);
        vm.stopPrank();
        // verify operator can burn the batch
        for (uint256 i = 2 * batchSize + 1; i <= 3 * batchSize; i++) {
            vm.startPrank(collector, collector);
            vm.expectEmit(true, true, true, false);
            emit Transfer(collector, address(0), i);
            tokenContract.burn(i);
            vm.stopPrank();
            assertEq(tokenContract.balanceOf(collector), 3 * batchSize - i);
            vm.expectRevert(TokenDoesntExist.selector);
            tokenContract.tokenURI(i);
            vm.expectRevert();
            tokenContract.ownerOf(i);
        }
    }

    function testBurnAirdrop(uint16 numAddresses, address operator) public {
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
            vm.expectEmit(true, true, true, false);
            emit Transfer(addresses[i], address(0), id);
            tokenContract.burn(id);
            vm.stopPrank();
            assertEq(tokenContract.balanceOf(addresses[i]), 0);
            vm.expectRevert(TokenDoesntExist.selector);
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
            vm.expectRevert(CallerNotApprovedOrOwner.selector);
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
            vm.expectEmit(true, true, true, false);
            emit Transfer(addresses[i], address(0), id);
            tokenContract.burn(id);
            vm.stopPrank();
            assertEq(tokenContract.balanceOf(addresses[i]), 0);
            vm.expectRevert(TokenDoesntExist.selector);
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
            vm.expectRevert(TokenDoesntExist.selector);
            tokenContract.tokenURI(id);
            vm.expectRevert();
            tokenContract.ownerOf(id);
        }
    }

    function testBurnExternalMint(uint16 tokenId, address collector, address operator) public {
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
        vm.expectRevert(TokenDoesntExist.selector);
        tokenContract.tokenURI(tokenId);
        vm.expectRevert();
        tokenContract.ownerOf(tokenId);
        // verify operator can't burn
        vm.startPrank(operator, operator);
        vm.expectRevert(CallerNotApprovedOrOwner.selector);
        tokenContract.burn(tokenId + 1);
        vm.stopPrank();
        // grant operator rights and verify can burn tokenId + 1 &  + 2
        vm.startPrank(collector, collector);
        tokenContract.approve(operator, tokenId + 1);
        vm.stopPrank();
        vm.startPrank(operator, operator);
        vm.expectEmit(true, true, true, false);
        emit Transfer(collector, address(0), tokenId + 1);
        tokenContract.burn(tokenId + 1);
        vm.stopPrank();
        assertEq(tokenContract.balanceOf(collector), 1);
        vm.expectRevert(TokenDoesntExist.selector);
        tokenContract.tokenURI(tokenId + 1);
        vm.expectRevert();
        tokenContract.ownerOf(tokenId + 1);
        // set approval for all
        vm.startPrank(collector, collector);
        tokenContract.setApprovalForAll(operator, true);
        vm.stopPrank();
        vm.startPrank(operator, operator);
        vm.expectEmit(true, true, true, false);
        emit Transfer(collector, address(0), tokenId + 2);
        tokenContract.burn(tokenId + 2);
        vm.stopPrank();
        assertEq(tokenContract.balanceOf(collector), 0);
        vm.expectRevert(TokenDoesntExist.selector);
        tokenContract.tokenURI(tokenId + 2);
        vm.expectRevert();
        tokenContract.ownerOf(tokenId + 2);
    }

    function testTransferThenBurn(uint16 tokenId, address collector, address operator) public {
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
        vm.expectRevert(TokenDoesntExist.selector);
        tokenContract.tokenURI(tokenId);
        vm.expectRevert();
        tokenContract.ownerOf(tokenId);
        // verify operator can't burn
        vm.startPrank(operator, operator);
        vm.expectRevert(CallerNotApprovedOrOwner.selector);
        tokenContract.burn(tokenId + 1);
        vm.stopPrank();
        // grant operator rights and verify can burn tokenId + 1 &  + 2
        vm.startPrank(collector, collector);
        tokenContract.approve(operator, tokenId + 1);
        vm.stopPrank();
        vm.startPrank(operator, operator);
        vm.expectEmit(true, true, true, false);
        emit Transfer(collector, address(0), tokenId + 1);
        tokenContract.burn(tokenId + 1);
        vm.stopPrank();
        assertEq(tokenContract.balanceOf(collector), 1);
        vm.expectRevert(TokenDoesntExist.selector);
        tokenContract.tokenURI(tokenId + 1);
        vm.expectRevert();
        tokenContract.ownerOf(tokenId + 1);
        // set approval for all
        vm.startPrank(collector, collector);
        tokenContract.setApprovalForAll(operator, true);
        vm.stopPrank();
        vm.startPrank(operator, operator);
        vm.expectEmit(true, true, true, false);
        emit Transfer(collector, address(0), tokenId + 2);
        tokenContract.burn(tokenId + 2);
        vm.stopPrank();
        assertEq(tokenContract.balanceOf(collector), 0);
        vm.expectRevert(TokenDoesntExist.selector);
        tokenContract.tokenURI(tokenId + 2);
        vm.expectRevert();
        tokenContract.ownerOf(tokenId + 2);
    }

    function testSafeTransferThenBurn(uint16 tokenId, address collector, address operator) public {
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
        vm.expectRevert(TokenDoesntExist.selector);
        tokenContract.tokenURI(tokenId);
        vm.expectRevert();
        tokenContract.ownerOf(tokenId);
        // verify operator can't burn
        vm.startPrank(operator, operator);
        vm.expectRevert(CallerNotApprovedOrOwner.selector);
        tokenContract.burn(tokenId + 1);
        vm.stopPrank();
        // grant operator rights and verify can burn tokenId + 1 &  + 2
        vm.startPrank(collector, collector);
        tokenContract.approve(operator, tokenId + 1);
        vm.stopPrank();
        vm.startPrank(operator, operator);
        vm.expectEmit(true, true, true, false);
        emit Transfer(collector, address(0), tokenId + 1);
        tokenContract.burn(tokenId + 1);
        vm.stopPrank();
        assertEq(tokenContract.balanceOf(collector), 1);
        vm.expectRevert(TokenDoesntExist.selector);
        tokenContract.tokenURI(tokenId + 1);
        vm.expectRevert();
        tokenContract.ownerOf(tokenId + 1);
        // set approval for all
        vm.startPrank(collector, collector);
        tokenContract.setApprovalForAll(operator, true);
        vm.stopPrank();
        vm.startPrank(operator, operator);
        vm.expectEmit(true, true, true, false);
        emit Transfer(collector, address(0), tokenId + 2);
        tokenContract.burn(tokenId + 2);
        vm.stopPrank();
        assertEq(tokenContract.balanceOf(collector), 0);
        vm.expectRevert(TokenDoesntExist.selector);
        tokenContract.tokenURI(tokenId + 2);
        vm.expectRevert();
        tokenContract.ownerOf(tokenId + 2);
    }

    /// @notice test royalty functions
    // - set default royalty ✅
    // - override token royalty ✅
    // - access control ✅
    function testDefaultRoyalty(address newRecipient, uint256 newPercentage, address user) public {
        vm.assume(newRecipient != address(0));
        vm.assume(user != address(0) && user != address(this));
        if (newPercentage >= 10_000) {
            newPercentage = newPercentage % 10_000;
        }
        address[] memory users = new address[](1);
        users[0] = user;
        // verify that user can't set royalty
        vm.startPrank(user, user);
        vm.expectRevert();
        tokenContract.setDefaultRoyalty(newRecipient, newPercentage);
        vm.stopPrank();
        // verify that admin can't set royalty
        tokenContract.setRole(tokenContract.ADMIN_ROLE(), users, true);
        vm.startPrank(user, user);
        vm.expectRevert();
        tokenContract.setDefaultRoyalty(newRecipient, newPercentage);
        vm.stopPrank();
        tokenContract.setRole(tokenContract.ADMIN_ROLE(), users, false);
        // verify that minters can't set royalty
        tokenContract.setRole(tokenContract.APPROVED_MINT_CONTRACT(), users, true);
        vm.startPrank(user, user);
        vm.expectRevert();
        tokenContract.setDefaultRoyalty(newRecipient, newPercentage);
        vm.stopPrank();
        tokenContract.setRole(tokenContract.APPROVED_MINT_CONTRACT(), users, false);
        // verify owner of the contract can set royalty
        tokenContract.setDefaultRoyalty(newRecipient, newPercentage);
        (address recp, uint256 amt) = tokenContract.royaltyInfo(1, 10_000);
        assertEq(recp, newRecipient);
        assertEq(amt, newPercentage);
    }

    function testTokenRoyalty(uint256 tokenId, address newRecipient, uint256 newPercentage, address user) public {
        vm.assume(newRecipient != address(0));
        vm.assume(user != address(0) && user != address(this));
        if (newPercentage >= 10_000) {
            newPercentage = newPercentage % 10_000;
        }
        address[] memory users = new address[](1);
        users[0] = user;
        // verify that user can't set royalty
        vm.startPrank(user, user);
        vm.expectRevert();
        tokenContract.setTokenRoyalty(tokenId, newRecipient, newPercentage);
        vm.stopPrank();
        // verify that admin can't set royalty
        tokenContract.setRole(tokenContract.ADMIN_ROLE(), users, true);
        vm.startPrank(user, user);
        vm.expectRevert();
        tokenContract.setTokenRoyalty(tokenId, newRecipient, newPercentage);
        vm.stopPrank();
        tokenContract.setRole(tokenContract.ADMIN_ROLE(), users, false);
        // verify that minters can't set royalty
        tokenContract.setRole(tokenContract.APPROVED_MINT_CONTRACT(), users, true);
        vm.startPrank(user, user);
        vm.expectRevert();
        tokenContract.setTokenRoyalty(tokenId, newRecipient, newPercentage);
        vm.stopPrank();
        tokenContract.setRole(tokenContract.APPROVED_MINT_CONTRACT(), users, false);
        // verify owner of the contract can set royalty
        tokenContract.setTokenRoyalty(tokenId, newRecipient, newPercentage);
        (address recp, uint256 amt) = tokenContract.royaltyInfo(tokenId, 10_000);
        assertEq(recp, newRecipient);
        assertEq(amt, newPercentage);
    }

    /// @notice test multi-metadata functions
    //  - add token uris access control ✅
    //  - add token uris errors ✅
    //  - tokenUris errors ✅
    //  - pinTokenUri access control ✅
    //  - pinTokenUri errors ✅
    //  - unpinTokenUri access control ✅
    //  - unpinTokenUri errors ✅
    //  - hasPinnedTokenUri errors ✅
    //  - multi metadata with regular mint ✅
    //  - multi metadata with batch mint ✅
    //  - multi metadata with batch mint ultra ✅
    //  - multi metadata with airdrop ✅
    //  - multi metadata with external mint ✅
    function testAddTokenUrisAccessControl(address user) public {
        vm.assume(user != address(this) && user != address(0));
        address[] memory users = new address[](1);
        users[0] = user;

        // token uris
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;
        string memory baseUri = "uri2";

        // mint token
        tokenContract.mint(user, "uri1");

        // verify user can't add
        vm.prank(user);
        vm.expectRevert();
        tokenContract.addTokenUris(tokenIds, baseUri);

        // verify admin can add
        tokenContract.setRole(tokenContract.ADMIN_ROLE(), users, true);
        vm.prank(user);
        vm.expectEmit(true, false, false, false);
        emit MetadataUpdate(1);
        tokenContract.addTokenUris(tokenIds, baseUri);
        tokenContract.setRole(tokenContract.ADMIN_ROLE(), users, false);

        // verify minter can't add
        tokenContract.setRole(tokenContract.APPROVED_MINT_CONTRACT(), users, true);
        vm.prank(user);
        vm.expectRevert();
        tokenContract.addTokenUris(tokenIds, baseUri);
        tokenContract.setRole(tokenContract.APPROVED_MINT_CONTRACT(), users, false);

        // verify contract owner can add
        vm.expectEmit(true, false, false, false);
        emit MetadataUpdate(1);
        tokenContract.addTokenUris(tokenIds, baseUri);

        // check tokenUris
        string[] memory expectedUris = new string[](3);
        expectedUris[0] = "uri1";
        expectedUris[1] = "uri2/0";
        expectedUris[2] = "uri2/0";

        (uint256 index, string[] memory rUris, bool isPinned) = tokenContract.tokenURIs(1);
        assertEq(index, 2);
        assertFalse(isPinned);
        assertEq(rUris.length, 3);
        for (uint256 i = 0; i < rUris.length; i++) {
            assertEq(keccak256(bytes(expectedUris[i])), keccak256(bytes(rUris[i])));
        }
    }

    function testAddTokenUrisErrors() public {
        // token uris
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;
        string memory baseUri = "baseUri";

        // token doesn't exist
        vm.expectRevert(TokenDoesntExist.selector);
        tokenContract.addTokenUris(tokenIds, baseUri);

        // mint token
        tokenContract.mint(address(this), "uri1");

        // empty token uri
        baseUri = "";
        vm.expectRevert(EmptyTokenURI.selector);
        tokenContract.addTokenUris(tokenIds, baseUri);

        // empty tokenIds list
        baseUri = "baseUri";
        tokenIds = new uint256[](0);
        vm.expectRevert(NoTokensSpecified.selector);
        tokenContract.addTokenUris(tokenIds, baseUri);
    }

    function testTokenUrisErrors() public {
        vm.expectRevert(TokenDoesntExist.selector);
        tokenContract.tokenURIs(1);
    }

    function testPinTokenUriErrors(address user) public {
        vm.assume(user != address(this));

        // token doesn't exist
        vm.expectRevert(TokenDoesntExist.selector);
        tokenContract.pinTokenURI(1, 0);

        // mint token
        tokenContract.mint(address(this), "uri1");

        // not token owner
        vm.prank(user);
        vm.expectRevert(CallerNotTokenOwner.selector);
        tokenContract.pinTokenURI(1, 0);

        // invalid token uri index
        vm.expectRevert(InvalidTokenURIIndex.selector);
        tokenContract.pinTokenURI(1, 1);
    }

    function testUnpinTokenUriErrors(address user) public {
        vm.assume(user != address(this));

        // token doesn't exist
        vm.expectRevert(TokenDoesntExist.selector);
        tokenContract.unpinTokenURI(1);

        // mint token
        tokenContract.mint(address(this), "uri1");

        // not token owner
        vm.prank(user);
        vm.expectRevert(CallerNotTokenOwner.selector);
        tokenContract.unpinTokenURI(1);
    }

    function testHasPinnedTokenURIErrors() public {
        // token doesn't exist
        vm.expectRevert(TokenDoesntExist.selector);
        tokenContract.hasPinnedTokenURI(1);
    }

    function testMultiMetadataWithRegularMint(uint256 numTokens, address collector) public {
        // limit inputs
        vm.assume(collector != address(0));
        if (numTokens > 300) numTokens = numTokens % 300;
        vm.assume(numTokens > 0);

        // mint tokens
        string memory baseUri = "newuri";
        uint256[] memory tokenIds = new uint256[](numTokens);
        string[] memory uris = new string[](numTokens);
        string[] memory newUris = new string[](numTokens);
        for (uint256 i = 0; i < numTokens; i++) {
            tokenIds[i] = i + 1;
            uris[i] = string(abi.encodePacked("uri", i.toString()));
            newUris[i] = string(abi.encodePacked(baseUri, "/", (i).toString()));
            tokenContract.mint(collector, uris[i]);
            // token uri
            assert(keccak256(bytes(tokenContract.tokenURI(tokenIds[i]))) == keccak256(bytes(uris[i])));
        }

        // add token uri to each
        for (uint256 i = 0; i < numTokens; i++) {
            vm.expectEmit(true, false, false, false);
            emit MetadataUpdate(tokenIds[i]);
        }
        tokenContract.addTokenUris(tokenIds, baseUri);

        // get token uris and check
        uint256 index;
        bool isPinned;
        string[] memory rUris = new string[](0);
        for (uint256 i = 0; i < numTokens; i++) {
            (index, rUris, isPinned) = tokenContract.tokenURIs(tokenIds[i]);
            assertEq(index, 1);
            assertFalse(isPinned);
            assertFalse(tokenContract.hasPinnedTokenURI(tokenIds[i]));
            assert(keccak256(bytes(rUris[0])) == keccak256(bytes(uris[i])));
            assert(keccak256(bytes(rUris[1])) == keccak256(bytes(newUris[i])));
            // token uri
            assert(keccak256(bytes(tokenContract.tokenURI(tokenIds[i]))) == keccak256(bytes(newUris[i])));
        }

        // pin token uri to 1
        for (uint256 i = 0; i < numTokens; i++) {
            vm.prank(collector);
            vm.expectEmit(true, true, false, false);
            emit TokenUriPinned(tokenIds[i], 1);
            vm.expectEmit(true, false, false, false);
            emit MetadataUpdate(tokenIds[i]);
            tokenContract.pinTokenURI(tokenIds[i], 1);

            (index, rUris, isPinned) = tokenContract.tokenURIs(tokenIds[i]);
            assertEq(index, 1);
            assertTrue(isPinned);
            assertTrue(tokenContract.hasPinnedTokenURI(tokenIds[i]));
            assert(keccak256(bytes(rUris[0])) == keccak256(bytes(uris[i])));
            assert(keccak256(bytes(rUris[1])) == keccak256(bytes(newUris[i])));
            // token uri
            assert(keccak256(bytes(tokenContract.tokenURI(tokenIds[i]))) == keccak256(bytes(newUris[i])));
        }

        // pin token uri to 0
        for (uint256 i = 0; i < numTokens; i++) {
            vm.prank(collector);
            vm.expectEmit(true, true, false, false);
            emit TokenUriPinned(tokenIds[i], 0);
            vm.expectEmit(true, false, false, false);
            emit MetadataUpdate(tokenIds[i]);
            tokenContract.pinTokenURI(tokenIds[i], 0);

            (index, rUris, isPinned) = tokenContract.tokenURIs(tokenIds[i]);
            assertEq(index, 0);
            assertTrue(isPinned);
            assertTrue(tokenContract.hasPinnedTokenURI(tokenIds[i]));
            assert(keccak256(bytes(rUris[0])) == keccak256(bytes(uris[i])));
            assert(keccak256(bytes(rUris[1])) == keccak256(bytes(newUris[i])));
            // token uri
            assert(keccak256(bytes(tokenContract.tokenURI(tokenIds[i]))) == keccak256(bytes(uris[i])));
        }

        // unpin token uri
        for (uint256 i = 0; i < numTokens; i++) {
            vm.prank(collector);
            vm.expectEmit(true, false, false, false);
            emit TokenUriUnpinned(tokenIds[i]);
            vm.expectEmit(true, false, false, false);
            emit MetadataUpdate(tokenIds[i]);
            tokenContract.unpinTokenURI(tokenIds[i]);

            (index, rUris, isPinned) = tokenContract.tokenURIs(tokenIds[i]);
            assertEq(index, 1);
            assertFalse(isPinned);
            assertFalse(tokenContract.hasPinnedTokenURI(tokenIds[i]));
            assert(keccak256(bytes(rUris[0])) == keccak256(bytes(uris[i])));
            assert(keccak256(bytes(rUris[1])) == keccak256(bytes(newUris[i])));

            // token uri
            assert(keccak256(bytes(tokenContract.tokenURI(tokenIds[i]))) == keccak256(bytes(newUris[i])));
        }
    }

    function testMultiMetdataWithBatchMint(uint256 numTokens, address collector) public {
        // limit inputs
        vm.assume(collector != address(0));
        if (numTokens > 300) numTokens = numTokens % 300;
        if (numTokens < 2) numTokens = 2;

        // mint tokens
        string memory baseUri = "newuri";
        uint256[] memory tokenIds = new uint256[](numTokens);
        string[] memory uris = new string[](numTokens);
        string[] memory newUris = new string[](numTokens);
        for (uint256 i = 0; i < numTokens; i++) {
            tokenIds[i] = i + 1;
            uris[i] = string(abi.encodePacked("uri/", i.toString()));
            newUris[i] = string(abi.encodePacked(baseUri, "/", (i).toString()));
        }
        tokenContract.batchMint(collector, numTokens, "uri");

        for (uint256 i = 0; i < numTokens; i++) {
            // token uri
            assert(keccak256(bytes(tokenContract.tokenURI(tokenIds[i]))) == keccak256(bytes(uris[i])));
        }

        // add token uri to each
        for (uint256 i = 0; i < numTokens; i++) {
            vm.expectEmit(true, false, false, false);
            emit MetadataUpdate(tokenIds[i]);
        }
        tokenContract.addTokenUris(tokenIds, baseUri);

        // get token uris and check
        uint256 index;
        bool isPinned;
        string[] memory rUris = new string[](0);
        for (uint256 i = 0; i < numTokens; i++) {
            (index, rUris, isPinned) = tokenContract.tokenURIs(tokenIds[i]);
            assertEq(index, 1);
            assertFalse(isPinned);
            assertFalse(tokenContract.hasPinnedTokenURI(tokenIds[i]));
            assert(keccak256(bytes(rUris[0])) == keccak256(bytes(uris[i])));
            assert(keccak256(bytes(rUris[1])) == keccak256(bytes(newUris[i])));
            // token uri
            assert(keccak256(bytes(tokenContract.tokenURI(tokenIds[i]))) == keccak256(bytes(newUris[i])));
        }

        // pin token uri to 1
        for (uint256 i = 0; i < numTokens; i++) {
            vm.prank(collector);
            vm.expectEmit(true, true, false, false);
            emit TokenUriPinned(tokenIds[i], 1);
            vm.expectEmit(true, false, false, false);
            emit MetadataUpdate(tokenIds[i]);
            tokenContract.pinTokenURI(tokenIds[i], 1);

            (index, rUris, isPinned) = tokenContract.tokenURIs(tokenIds[i]);
            assertEq(index, 1);
            assertTrue(isPinned);
            assertTrue(tokenContract.hasPinnedTokenURI(tokenIds[i]));
            assert(keccak256(bytes(rUris[0])) == keccak256(bytes(uris[i])));
            assert(keccak256(bytes(rUris[1])) == keccak256(bytes(newUris[i])));
            // token uri
            assert(keccak256(bytes(tokenContract.tokenURI(tokenIds[i]))) == keccak256(bytes(newUris[i])));
        }

        // pin token uri to 0
        for (uint256 i = 0; i < numTokens; i++) {
            vm.prank(collector);
            vm.expectEmit(true, true, false, false);
            emit TokenUriPinned(tokenIds[i], 0);
            vm.expectEmit(true, false, false, false);
            emit MetadataUpdate(tokenIds[i]);
            tokenContract.pinTokenURI(tokenIds[i], 0);

            (index, rUris, isPinned) = tokenContract.tokenURIs(tokenIds[i]);
            assertEq(index, 0);
            assertTrue(isPinned);
            assertTrue(tokenContract.hasPinnedTokenURI(tokenIds[i]));
            assert(keccak256(bytes(rUris[0])) == keccak256(bytes(uris[i])));
            assert(keccak256(bytes(rUris[1])) == keccak256(bytes(newUris[i])));
            // token uri
            assert(keccak256(bytes(tokenContract.tokenURI(tokenIds[i]))) == keccak256(bytes(uris[i])));
        }

        // unpin token uri
        for (uint256 i = 0; i < numTokens; i++) {
            vm.prank(collector);
            vm.expectEmit(true, false, false, false);
            emit TokenUriUnpinned(tokenIds[i]);
            vm.expectEmit(true, false, false, false);
            emit MetadataUpdate(tokenIds[i]);
            tokenContract.unpinTokenURI(tokenIds[i]);

            (index, rUris, isPinned) = tokenContract.tokenURIs(tokenIds[i]);
            assertEq(index, 1);
            assertFalse(isPinned);
            assertFalse(tokenContract.hasPinnedTokenURI(tokenIds[i]));
            assert(keccak256(bytes(rUris[0])) == keccak256(bytes(uris[i])));
            assert(keccak256(bytes(rUris[1])) == keccak256(bytes(newUris[i])));

            // token uri
            assert(keccak256(bytes(tokenContract.tokenURI(tokenIds[i]))) == keccak256(bytes(newUris[i])));
        }
    }

    function testMultiMetadataWithBatchMintUltra(uint256 numTokens, address collector) public {
        // limit inputs
        vm.assume(collector != address(0));
        if (numTokens > 300) numTokens = numTokens % 300;
        if (numTokens < 2) numTokens = 2;

        // mint tokens
        string memory baseUri = "newuri";
        uint256[] memory tokenIds = new uint256[](numTokens);
        string[] memory uris = new string[](numTokens);
        string[] memory newUris = new string[](numTokens);
        for (uint256 i = 0; i < numTokens; i++) {
            tokenIds[i] = i + 1;
            uris[i] = string(abi.encodePacked("uri/", i.toString()));
            newUris[i] = string(abi.encodePacked(baseUri, "/", (i).toString()));
        }
        tokenContract.batchMintUltra(collector, numTokens, "uri");

        for (uint256 i = 0; i < numTokens; i++) {
            // token uri
            assert(keccak256(bytes(tokenContract.tokenURI(tokenIds[i]))) == keccak256(bytes(uris[i])));
        }

        // add token uri to each
        for (uint256 i = 0; i < numTokens; i++) {
            vm.expectEmit(true, false, false, false);
            emit MetadataUpdate(tokenIds[i]);
        }
        tokenContract.addTokenUris(tokenIds, baseUri);

        // get token uris and check
        uint256 index;
        bool isPinned;
        string[] memory rUris = new string[](0);
        for (uint256 i = 0; i < numTokens; i++) {
            (index, rUris, isPinned) = tokenContract.tokenURIs(tokenIds[i]);
            assertEq(index, 1);
            assertFalse(isPinned);
            assertFalse(tokenContract.hasPinnedTokenURI(tokenIds[i]));
            assert(keccak256(bytes(rUris[0])) == keccak256(bytes(uris[i])));
            assert(keccak256(bytes(rUris[1])) == keccak256(bytes(newUris[i])));
            // token uri
            assert(keccak256(bytes(tokenContract.tokenURI(tokenIds[i]))) == keccak256(bytes(newUris[i])));
        }

        // pin token uri to 1
        for (uint256 i = 0; i < numTokens; i++) {
            vm.prank(collector);
            vm.expectEmit(true, true, false, false);
            emit TokenUriPinned(tokenIds[i], 1);
            vm.expectEmit(true, false, false, false);
            emit MetadataUpdate(tokenIds[i]);
            tokenContract.pinTokenURI(tokenIds[i], 1);

            (index, rUris, isPinned) = tokenContract.tokenURIs(tokenIds[i]);
            assertEq(index, 1);
            assertTrue(isPinned);
            assertTrue(tokenContract.hasPinnedTokenURI(tokenIds[i]));
            assert(keccak256(bytes(rUris[0])) == keccak256(bytes(uris[i])));
            assert(keccak256(bytes(rUris[1])) == keccak256(bytes(newUris[i])));
            // token uri
            assert(keccak256(bytes(tokenContract.tokenURI(tokenIds[i]))) == keccak256(bytes(newUris[i])));
        }

        // pin token uri to 0
        for (uint256 i = 0; i < numTokens; i++) {
            vm.prank(collector);
            vm.expectEmit(true, true, false, false);
            emit TokenUriPinned(tokenIds[i], 0);
            vm.expectEmit(true, false, false, false);
            emit MetadataUpdate(tokenIds[i]);
            tokenContract.pinTokenURI(tokenIds[i], 0);

            (index, rUris, isPinned) = tokenContract.tokenURIs(tokenIds[i]);
            assertEq(index, 0);
            assertTrue(isPinned);
            assertTrue(tokenContract.hasPinnedTokenURI(tokenIds[i]));
            assert(keccak256(bytes(rUris[0])) == keccak256(bytes(uris[i])));
            assert(keccak256(bytes(rUris[1])) == keccak256(bytes(newUris[i])));
            // token uri
            assert(keccak256(bytes(tokenContract.tokenURI(tokenIds[i]))) == keccak256(bytes(uris[i])));
        }

        // unpin token uri
        for (uint256 i = 0; i < numTokens; i++) {
            vm.prank(collector);
            vm.expectEmit(true, false, false, false);
            emit TokenUriUnpinned(tokenIds[i]);
            vm.expectEmit(true, false, false, false);
            emit MetadataUpdate(tokenIds[i]);
            tokenContract.unpinTokenURI(tokenIds[i]);

            (index, rUris, isPinned) = tokenContract.tokenURIs(tokenIds[i]);
            assertEq(index, 1);
            assertFalse(isPinned);
            assertFalse(tokenContract.hasPinnedTokenURI(tokenIds[i]));
            assert(keccak256(bytes(rUris[0])) == keccak256(bytes(uris[i])));
            assert(keccak256(bytes(rUris[1])) == keccak256(bytes(newUris[i])));

            // token uri
            assert(keccak256(bytes(tokenContract.tokenURI(tokenIds[i]))) == keccak256(bytes(newUris[i])));
        }
    }

    function testMultiMetadataWithAirdrop(uint256 numTokens) public {
        // limit inputs
        if (numTokens > 300) numTokens = numTokens % 300;
        if (numTokens < 2) numTokens = 2;

        // mint tokens
        string memory baseUri = "newuri";
        address[] memory collectors = new address[](numTokens);
        uint256[] memory tokenIds = new uint256[](numTokens);
        string[] memory uris = new string[](numTokens);
        string[] memory newUris = new string[](numTokens);
        for (uint256 i = 0; i < numTokens; i++) {
            tokenIds[i] = i + 1;
            uris[i] = string(abi.encodePacked("uri/", i.toString()));
            newUris[i] = string(abi.encodePacked(baseUri, "/", (i).toString()));
            collectors[i] = makeAddr(i.toString());
        }
        tokenContract.airdrop(collectors, "uri");

        for (uint256 i = 0; i < numTokens; i++) {
            // token uri
            assert(keccak256(bytes(tokenContract.tokenURI(tokenIds[i]))) == keccak256(bytes(uris[i])));
        }

        // add token uri to each
        for (uint256 i = 0; i < numTokens; i++) {
            vm.expectEmit(true, false, false, false);
            emit MetadataUpdate(tokenIds[i]);
        }
        tokenContract.addTokenUris(tokenIds, baseUri);

        // get token uris and check
        uint256 index;
        bool isPinned;
        string[] memory rUris = new string[](0);
        for (uint256 i = 0; i < numTokens; i++) {
            (index, rUris, isPinned) = tokenContract.tokenURIs(tokenIds[i]);
            assertEq(index, 1);
            assertFalse(isPinned);
            assertFalse(tokenContract.hasPinnedTokenURI(tokenIds[i]));
            assert(keccak256(bytes(rUris[0])) == keccak256(bytes(uris[i])));
            assert(keccak256(bytes(rUris[1])) == keccak256(bytes(newUris[i])));
            // token uri
            assert(keccak256(bytes(tokenContract.tokenURI(tokenIds[i]))) == keccak256(bytes(newUris[i])));
        }

        // pin token uri to 1
        for (uint256 i = 0; i < numTokens; i++) {
            vm.prank(collectors[i]);
            vm.expectEmit(true, true, false, false);
            emit TokenUriPinned(tokenIds[i], 1);
            vm.expectEmit(true, false, false, false);
            emit MetadataUpdate(tokenIds[i]);
            tokenContract.pinTokenURI(tokenIds[i], 1);

            (index, rUris, isPinned) = tokenContract.tokenURIs(tokenIds[i]);
            assertEq(index, 1);
            assertTrue(isPinned);
            assertTrue(tokenContract.hasPinnedTokenURI(tokenIds[i]));
            assert(keccak256(bytes(rUris[0])) == keccak256(bytes(uris[i])));
            assert(keccak256(bytes(rUris[1])) == keccak256(bytes(newUris[i])));
            // token uri
            assert(keccak256(bytes(tokenContract.tokenURI(tokenIds[i]))) == keccak256(bytes(newUris[i])));
        }

        // pin token uri to 0
        for (uint256 i = 0; i < numTokens; i++) {
            vm.prank(collectors[i]);
            vm.expectEmit(true, true, false, false);
            emit TokenUriPinned(tokenIds[i], 0);
            vm.expectEmit(true, false, false, false);
            emit MetadataUpdate(tokenIds[i]);
            tokenContract.pinTokenURI(tokenIds[i], 0);

            (index, rUris, isPinned) = tokenContract.tokenURIs(tokenIds[i]);
            assertEq(index, 0);
            assertTrue(isPinned);
            assertTrue(tokenContract.hasPinnedTokenURI(tokenIds[i]));
            assert(keccak256(bytes(rUris[0])) == keccak256(bytes(uris[i])));
            assert(keccak256(bytes(rUris[1])) == keccak256(bytes(newUris[i])));
            // token uri
            assert(keccak256(bytes(tokenContract.tokenURI(tokenIds[i]))) == keccak256(bytes(uris[i])));
        }

        // unpin token uri
        for (uint256 i = 0; i < numTokens; i++) {
            vm.prank(collectors[i]);
            vm.expectEmit(true, false, false, false);
            emit TokenUriUnpinned(tokenIds[i]);
            vm.expectEmit(true, false, false, false);
            emit MetadataUpdate(tokenIds[i]);
            tokenContract.unpinTokenURI(tokenIds[i]);

            (index, rUris, isPinned) = tokenContract.tokenURIs(tokenIds[i]);
            assertEq(index, 1);
            assertFalse(isPinned);
            assertFalse(tokenContract.hasPinnedTokenURI(tokenIds[i]));
            assert(keccak256(bytes(rUris[0])) == keccak256(bytes(uris[i])));
            assert(keccak256(bytes(rUris[1])) == keccak256(bytes(newUris[i])));

            // token uri
            assert(keccak256(bytes(tokenContract.tokenURI(tokenIds[i]))) == keccak256(bytes(newUris[i])));
        }
    }

    function testMultiMetadataWithExternalMint(uint256 numTokens, address collector) public {
        // limit inputs
        vm.assume(collector != address(0));
        if (numTokens > 300) numTokens = numTokens % 300;
        vm.assume(numTokens > 0);

        // add mint contract
        address[] memory users = new address[](1);
        users[0] = address(1);
        tokenContract.setRole(tokenContract.APPROVED_MINT_CONTRACT(), users, true);

        // mint tokens
        string memory baseUri = "newuri";
        uint256[] memory tokenIds = new uint256[](numTokens);
        string[] memory uris = new string[](numTokens);
        string[] memory newUris = new string[](numTokens);
        for (uint256 i = 0; i < numTokens; i++) {
            tokenIds[i] = i + 1;
            uris[i] = string(abi.encodePacked("uri", i.toString()));
            newUris[i] = string(abi.encodePacked(baseUri, "/", (i).toString()));
            vm.prank(address(1));
            tokenContract.externalMint(collector, uris[i]);
            // token uri
            assert(keccak256(bytes(tokenContract.tokenURI(tokenIds[i]))) == keccak256(bytes(uris[i])));
        }

        // add token uri to each
        for (uint256 i = 0; i < numTokens; i++) {
            vm.expectEmit(true, false, false, false);
            emit MetadataUpdate(tokenIds[i]);
        }
        tokenContract.addTokenUris(tokenIds, baseUri);

        // get token uris and check
        uint256 index;
        bool isPinned;
        string[] memory rUris = new string[](0);
        for (uint256 i = 0; i < numTokens; i++) {
            (index, rUris, isPinned) = tokenContract.tokenURIs(tokenIds[i]);
            assertEq(index, 1);
            assertFalse(isPinned);
            assertFalse(tokenContract.hasPinnedTokenURI(tokenIds[i]));
            assert(keccak256(bytes(rUris[0])) == keccak256(bytes(uris[i])));
            assert(keccak256(bytes(rUris[1])) == keccak256(bytes(newUris[i])));
            // token uri
            assert(keccak256(bytes(tokenContract.tokenURI(tokenIds[i]))) == keccak256(bytes(newUris[i])));
        }

        // pin token uri to 1
        for (uint256 i = 0; i < numTokens; i++) {
            vm.prank(collector);
            vm.expectEmit(true, true, false, false);
            emit TokenUriPinned(tokenIds[i], 1);
            vm.expectEmit(true, false, false, false);
            emit MetadataUpdate(tokenIds[i]);
            tokenContract.pinTokenURI(tokenIds[i], 1);

            (index, rUris, isPinned) = tokenContract.tokenURIs(tokenIds[i]);
            assertEq(index, 1);
            assertTrue(isPinned);
            assertTrue(tokenContract.hasPinnedTokenURI(tokenIds[i]));
            assert(keccak256(bytes(rUris[0])) == keccak256(bytes(uris[i])));
            assert(keccak256(bytes(rUris[1])) == keccak256(bytes(newUris[i])));
            // token uri
            assert(keccak256(bytes(tokenContract.tokenURI(tokenIds[i]))) == keccak256(bytes(newUris[i])));
        }

        // pin token uri to 0
        for (uint256 i = 0; i < numTokens; i++) {
            vm.prank(collector);
            vm.expectEmit(true, true, false, false);
            emit TokenUriPinned(tokenIds[i], 0);
            vm.expectEmit(true, false, false, false);
            emit MetadataUpdate(tokenIds[i]);
            tokenContract.pinTokenURI(tokenIds[i], 0);

            (index, rUris, isPinned) = tokenContract.tokenURIs(tokenIds[i]);
            assertEq(index, 0);
            assertTrue(isPinned);
            assertTrue(tokenContract.hasPinnedTokenURI(tokenIds[i]));
            assert(keccak256(bytes(rUris[0])) == keccak256(bytes(uris[i])));
            assert(keccak256(bytes(rUris[1])) == keccak256(bytes(newUris[i])));
            // token uri
            assert(keccak256(bytes(tokenContract.tokenURI(tokenIds[i]))) == keccak256(bytes(uris[i])));
        }

        // unpin token uri
        for (uint256 i = 0; i < numTokens; i++) {
            vm.prank(collector);
            vm.expectEmit(true, false, false, false);
            emit TokenUriUnpinned(tokenIds[i]);
            vm.expectEmit(true, false, false, false);
            emit MetadataUpdate(tokenIds[i]);
            tokenContract.unpinTokenURI(tokenIds[i]);

            (index, rUris, isPinned) = tokenContract.tokenURIs(tokenIds[i]);
            assertEq(index, 1);
            assertFalse(isPinned);
            assertFalse(tokenContract.hasPinnedTokenURI(tokenIds[i]));
            assert(keccak256(bytes(rUris[0])) == keccak256(bytes(uris[i])));
            assert(keccak256(bytes(rUris[1])) == keccak256(bytes(newUris[i])));

            // token uri
            assert(keccak256(bytes(tokenContract.tokenURI(tokenIds[i]))) == keccak256(bytes(newUris[i])));
        }
    }

    function testMultiMetadataSameToken(uint256 numUris, address collector) public {
        // limit inputs
        vm.assume(collector != address(0));
        if (numUris > 300) numUris = numUris % 300;
        vm.assume(numUris > 0);

        // mint tokens
        string memory baseUri = "newuri";
        uint256[] memory tokenIds = new uint256[](numUris);
        string[] memory newUris = new string[](numUris);
        for (uint256 i = 0; i < numUris; i++) {
            tokenIds[i] = 1;
            newUris[i] = string(abi.encodePacked(baseUri, "/", (i).toString()));
        }
        tokenContract.mint(collector, "uri");

        // token uri
        assert(keccak256(bytes(tokenContract.tokenURI(1))) == keccak256(bytes("uri")));

        // add token uris
        for (uint256 i = 0; i < numUris; i++) {
            vm.expectEmit(true, false, false, false);
            emit MetadataUpdate(1);
        }
        tokenContract.addTokenUris(tokenIds, baseUri);

        // get token uris and check
        uint256 index;
        bool isPinned;
        string[] memory rUris = new string[](0);
        (index, rUris, isPinned) = tokenContract.tokenURIs(1);
        assertEq(index, rUris.length - 1);
        assertFalse(isPinned);
        assertFalse(tokenContract.hasPinnedTokenURI(1));
        assert(keccak256(bytes(rUris[0])) == keccak256(bytes("uri")));
        assert(keccak256(bytes(tokenContract.tokenURI(1))) == keccak256(bytes(newUris[numUris-1])));
        for (uint256 i = 1; i <= numUris; i++) {
            assert(keccak256(bytes(rUris[i])) == keccak256(bytes(newUris[i-1])));
        }

        // pin token uri to 1
        vm.prank(collector);
        vm.expectEmit(true, true, false, false);
        emit TokenUriPinned(1, 1);
        vm.expectEmit(true, false, false, false);
        emit MetadataUpdate(1);
        tokenContract.pinTokenURI(1, 1);
        (index, rUris, isPinned) = tokenContract.tokenURIs(1);
        assertEq(index, 1);
        assertTrue(isPinned);
        assertTrue(tokenContract.hasPinnedTokenURI(1));
        assert(keccak256(bytes(rUris[0])) == keccak256(bytes("uri")));
        assert(keccak256(bytes(tokenContract.tokenURI(1))) == keccak256(bytes(newUris[0])));
        for (uint256 i = 1; i <= numUris; i++) {
            assert(keccak256(bytes(rUris[i])) == keccak256(bytes(newUris[i-1])));
        }

        // pin token uri to 0
        vm.prank(collector);
        vm.expectEmit(true, true, false, false);
        emit TokenUriPinned(1, 0);
        vm.expectEmit(true, false, false, false);
        emit MetadataUpdate(1);
        tokenContract.pinTokenURI(1, 0);
        (index, rUris, isPinned) = tokenContract.tokenURIs(1);
        assertEq(index, 0);
        assertTrue(isPinned);
        assertTrue(tokenContract.hasPinnedTokenURI(1));
        assert(keccak256(bytes(rUris[0])) == keccak256(bytes("uri")));
        assert(keccak256(bytes(tokenContract.tokenURI(1))) == keccak256("uri"));
        for (uint256 i = 1; i <= numUris; i++) {
            assert(keccak256(bytes(rUris[i])) == keccak256(bytes(newUris[i-1])));
        }

        // unpin token uri
        vm.prank(collector);
        vm.expectEmit(true, false, false, false);
        emit TokenUriUnpinned(1);
        vm.expectEmit(true, false, false, false);
        emit MetadataUpdate(1);
        tokenContract.unpinTokenURI(1);
        (index, rUris, isPinned) = tokenContract.tokenURIs(1);
        assertEq(index, rUris.length - 1);
        assertFalse(isPinned);
        assertFalse(tokenContract.hasPinnedTokenURI(1));
        assert(keccak256(bytes(rUris[0])) == keccak256(bytes("uri")));
        assert(keccak256(bytes(tokenContract.tokenURI(1))) == keccak256(bytes(newUris[numUris-1])));
        for (uint256 i = 1; i <= numUris; i++) {
            assert(keccak256(bytes(rUris[i])) == keccak256(bytes(newUris[i-1])));
        }
    }

    /// @notice test story functions
    // - enable/disable story access control ✅
    // - regular mint ✅
    // - batch mint ✅
    // - airdrop ✅
    // - external mint ✅
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
        tokenContract.setStoryEnabled(false);
        vm.stopPrank();

        // verify admin can enable/disable
        tokenContract.setRole(tokenContract.ADMIN_ROLE(), users, true);
        vm.startPrank(user, user);
        tokenContract.setStoryEnabled(false);
        vm.stopPrank();
        tokenContract.setRole(tokenContract.ADMIN_ROLE(), users, false);

        // verify minter can't enable/disable
        tokenContract.setRole(tokenContract.APPROVED_MINT_CONTRACT(), users, true);
        vm.startPrank(user, user);
        vm.expectRevert();
        tokenContract.setStoryEnabled(false);
        vm.stopPrank();
        tokenContract.setRole(tokenContract.APPROVED_MINT_CONTRACT(), users, false);

        // verify owner can enable/disable
        tokenContract.setStoryEnabled(false);
        assertFalse(tokenContract.storyEnabled());
        tokenContract.setStoryEnabled(true);
        assertTrue(tokenContract.storyEnabled());
    }

    function testStoryNonExistentTokens() public {
        vm.expectRevert();
        tokenContract.addCreatorStory(1, "XCOPY", "I AM XCOPY");
        vm.expectRevert();
        tokenContract.addStory(1, "NOT XCOPY", "I AM NOT XCOPY");
    }

    function testStoryWithMint(address collector) public {
        vm.assume(collector != address(0));
        vm.assume(collector != address(this));
        tokenContract.mint(collector, "uri");

        // test creator story
        vm.expectEmit(true, true, true, true);
        emit CreatorStory(1, address(this), "XCOPY", "I AM XCOPY");
        tokenContract.addCreatorStory(1, "XCOPY", "I AM XCOPY");

        // test collector can't add creator story
        vm.startPrank(collector, collector);
        vm.expectRevert();
        tokenContract.addCreatorStory(1, "XCOPY", "I AM XCOPY");

        // test collector story
        vm.expectEmit(true, true, true, true);
        emit Story(1, collector, "NOT XCOPY", "I AM NOT XCOPY");
        tokenContract.addStory(1, "NOT XCOPY", "I AM NOT XCOPY");
        vm.stopPrank();

        // test that owner can't add collector story
        vm.expectRevert();
        tokenContract.addStory(1, "NOT XCOPY", "I AM NOT XCOPY");
    }

    function testStoryWithBatchMint(address collector) public {
        vm.assume(collector != address(0));
        vm.assume(collector != address(this));
        tokenContract.batchMint(collector, 2, "uri");

        // test creator story
        vm.expectEmit(true, true, true, true);
        emit CreatorStory(1, address(this), "XCOPY", "I AM XCOPY");
        tokenContract.addCreatorStory(1, "XCOPY", "I AM XCOPY");
        vm.expectEmit(true, true, true, true);
        emit CreatorStory(2, address(this), "XCOPY", "I AM XCOPY");
        tokenContract.addCreatorStory(2, "XCOPY", "I AM XCOPY");

        // test collector can't add creator story
        vm.startPrank(collector, collector);
        vm.expectRevert();
        tokenContract.addCreatorStory(1, "XCOPY", "I AM XCOPY");
        vm.expectRevert();
        tokenContract.addCreatorStory(2, "XCOPY", "I AM XCOPY");

        // test collector story
        vm.expectEmit(true, true, true, true);
        emit Story(1, collector, "NOT XCOPY", "I AM NOT XCOPY");
        tokenContract.addStory(1, "NOT XCOPY", "I AM NOT XCOPY");
        vm.expectEmit(true, true, true, true);
        emit Story(2, collector, "NOT XCOPY", "I AM NOT XCOPY");
        tokenContract.addStory(2, "NOT XCOPY", "I AM NOT XCOPY");
        vm.stopPrank();

        // test that owner can't add collector story
        vm.expectRevert();
        tokenContract.addStory(1, "NOT XCOPY", "I AM NOT XCOPY");
        vm.expectRevert();
        tokenContract.addStory(2, "NOT XCOPY", "I AM NOT XCOPY");
    }

    function testStoryWithBatchMintUltra(address collector) public {
        vm.assume(collector != address(0));
        vm.assume(collector != address(this));
        tokenContract.batchMintUltra(collector, 2, "uri");

        // test creator story
        vm.expectEmit(true, true, true, true);
        emit CreatorStory(1, address(this), "XCOPY", "I AM XCOPY");
        tokenContract.addCreatorStory(1, "XCOPY", "I AM XCOPY");
        vm.expectEmit(true, true, true, true);
        emit CreatorStory(2, address(this), "XCOPY", "I AM XCOPY");
        tokenContract.addCreatorStory(2, "XCOPY", "I AM XCOPY");

        // test collector can't add creator story
        vm.startPrank(collector, collector);
        vm.expectRevert();
        tokenContract.addCreatorStory(1, "XCOPY", "I AM XCOPY");
        vm.expectRevert();
        tokenContract.addCreatorStory(2, "XCOPY", "I AM XCOPY");

        // test collector story
        vm.expectEmit(true, true, true, true);
        emit Story(1, collector, "NOT XCOPY", "I AM NOT XCOPY");
        tokenContract.addStory(1, "NOT XCOPY", "I AM NOT XCOPY");
        vm.expectEmit(true, true, true, true);
        emit Story(2, collector, "NOT XCOPY", "I AM NOT XCOPY");
        tokenContract.addStory(2, "NOT XCOPY", "I AM NOT XCOPY");
        vm.stopPrank();

        // test that owner can't add collector story
        vm.expectRevert();
        tokenContract.addStory(1, "NOT XCOPY", "I AM NOT XCOPY");
        vm.expectRevert();
        tokenContract.addStory(2, "NOT XCOPY", "I AM NOT XCOPY");
    }

    function testStoryWithAirdrop(address collector) public {
        vm.assume(collector != address(0));
        vm.assume(collector != address(this));
        address[] memory addresses = new address[](2);
        addresses[0] = collector;
        addresses[1] = collector;
        tokenContract.airdrop(addresses, "uri");

        // test creator story
        vm.expectEmit(true, true, true, true);
        emit CreatorStory(1, address(this), "XCOPY", "I AM XCOPY");
        tokenContract.addCreatorStory(1, "XCOPY", "I AM XCOPY");
        vm.expectEmit(true, true, true, true);
        emit CreatorStory(2, address(this), "XCOPY", "I AM XCOPY");
        tokenContract.addCreatorStory(2, "XCOPY", "I AM XCOPY");

        // test collector can't add creator story
        vm.startPrank(collector, collector);
        vm.expectRevert();
        tokenContract.addCreatorStory(1, "XCOPY", "I AM XCOPY");
        vm.expectRevert();
        tokenContract.addCreatorStory(2, "XCOPY", "I AM XCOPY");

        // test collector story
        vm.expectEmit(true, true, true, true);
        emit Story(1, collector, "NOT XCOPY", "I AM NOT XCOPY");
        tokenContract.addStory(1, "NOT XCOPY", "I AM NOT XCOPY");
        vm.expectEmit(true, true, true, true);
        emit Story(2, collector, "NOT XCOPY", "I AM NOT XCOPY");
        tokenContract.addStory(2, "NOT XCOPY", "I AM NOT XCOPY");
        vm.stopPrank();

        // test that owner can't add collector story
        vm.expectRevert();
        tokenContract.addStory(1, "NOT XCOPY", "I AM NOT XCOPY");
        vm.expectRevert();
        tokenContract.addStory(2, "NOT XCOPY", "I AM NOT XCOPY");
    }

    function testStoryWithExternalMint(address collector) public {
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
        emit CreatorStory(1, address(this), "XCOPY", "I AM XCOPY");
        tokenContract.addCreatorStory(1, "XCOPY", "I AM XCOPY");

        // test collector can't add creator story
        vm.startPrank(collector, collector);
        vm.expectRevert();
        tokenContract.addCreatorStory(1, "XCOPY", "I AM XCOPY");

        // test collector story
        vm.expectEmit(true, true, true, true);
        emit Story(1, collector, "NOT XCOPY", "I AM NOT XCOPY");
        tokenContract.addStory(1, "NOT XCOPY", "I AM NOT XCOPY");
        vm.stopPrank();

        // test that owner can't add collector story
        vm.expectRevert();
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
    function testBlockListAccessControl(address user) public {
        vm.assume(user != address(this));
        address[] memory users = new address[](1);
        users[0] = user;

        // verify user can't access
        vm.startPrank(user, user);
        vm.expectRevert();
        tokenContract.updateBlockListRegistry(address(1));
        vm.stopPrank();

        // verify admin can't access
        tokenContract.setRole(tokenContract.ADMIN_ROLE(), users, true);
        vm.startPrank(user, user);
        vm.expectRevert();
        tokenContract.updateBlockListRegistry(address(1));
        vm.stopPrank();
        tokenContract.setRole(tokenContract.ADMIN_ROLE(), users, false);

        // verify minter can't access
        tokenContract.setRole(tokenContract.APPROVED_MINT_CONTRACT(), users, true);
        vm.startPrank(user, user);
        vm.expectRevert();
        tokenContract.updateBlockListRegistry(address(1));
        vm.stopPrank();
        tokenContract.setRole(tokenContract.APPROVED_MINT_CONTRACT(), users, false);

        // verify owner can access
        tokenContract.updateBlockListRegistry(address(1));
        assertEq(address(tokenContract.blockListRegistry()), address(1));
    }

    function testBlockListMint(address collector, address operator) public {
        vm.assume(collector != address(0));
        vm.assume(collector != operator);
        vm.assume(operator != address(0));
        address[] memory blocked = new address[](1);
        blocked[0] = operator;
        BlockListRegistry registry = new BlockListRegistry(false);
        registry.initialize(address(this), blocked);
        tokenContract.updateBlockListRegistry(address(registry));

        // mint and verify blocked operator
        tokenContract.mint(collector, "uri");
        vm.startPrank(collector, collector);
        vm.expectRevert();
        tokenContract.approve(operator, 1);
        vm.expectRevert();
        tokenContract.setApprovalForAll(operator, true);
        vm.stopPrank();

        // unblock operator and verify approvals
        registry.clearBlockList();
        vm.startPrank(collector, collector);
        tokenContract.approve(operator, 1);
        assertEq(tokenContract.getApproved(1), operator);
        tokenContract.setApprovalForAll(operator, true);
        assertTrue(tokenContract.isApprovedForAll(collector, operator));
        vm.stopPrank();
    }

    function testBlockListBatchMint(address collector, address operator) public {
        vm.assume(collector != address(0));
        vm.assume(collector != operator);
        vm.assume(operator != address(0));
        address[] memory blocked = new address[](1);
        blocked[0] = operator;
        BlockListRegistry registry = new BlockListRegistry(false);
        registry.initialize(address(this), blocked);
        tokenContract.updateBlockListRegistry(address(registry));

        // mint and verify blocked operator
        tokenContract.batchMint(collector, 2, "uri");
        vm.startPrank(collector, collector);
        vm.expectRevert();
        tokenContract.approve(operator, 1);
        vm.expectRevert();
        tokenContract.approve(operator, 2);
        vm.expectRevert();
        tokenContract.setApprovalForAll(operator, true);
        vm.stopPrank();

        // unblock operator and verify approvals
        registry.clearBlockList();
        vm.startPrank(collector, collector);
        tokenContract.approve(operator, 1);
        assertEq(tokenContract.getApproved(1), operator);
        tokenContract.approve(operator, 2);
        assertEq(tokenContract.getApproved(2), operator);
        tokenContract.setApprovalForAll(operator, true);
        assertTrue(tokenContract.isApprovedForAll(collector, operator));
        vm.stopPrank();
    }

    function testBlockListAirdrop(address collector, address operator) public {
        vm.assume(collector != address(0));
        vm.assume(collector != operator);
        vm.assume(operator != address(0));
        address[] memory addresses = new address[](2);
        addresses[0] = collector;
        addresses[1] = collector;
        address[] memory blocked = new address[](1);
        blocked[0] = operator;
        BlockListRegistry registry = new BlockListRegistry(false);
        registry.initialize(address(this), blocked);
        tokenContract.updateBlockListRegistry(address(registry));

        // mint and verify blocked operator
        tokenContract.airdrop(addresses, "uri");
        vm.startPrank(collector, collector);
        vm.expectRevert();
        tokenContract.approve(operator, 1);
        vm.expectRevert();
        tokenContract.approve(operator, 2);
        vm.expectRevert();
        tokenContract.setApprovalForAll(operator, true);
        vm.stopPrank();

        // unblock operator and verify approvals
        registry.clearBlockList();
        vm.startPrank(collector, collector);
        tokenContract.approve(operator, 1);
        assertEq(tokenContract.getApproved(1), operator);
        tokenContract.approve(operator, 2);
        assertEq(tokenContract.getApproved(2), operator);
        tokenContract.setApprovalForAll(operator, true);
        assertTrue(tokenContract.isApprovedForAll(collector, operator));
        vm.stopPrank();
    }

    function testBlockListExternalMint(address collector, address operator) public {
        vm.assume(collector != address(0));
        vm.assume(collector != address(1));
        vm.assume(collector != operator);
        vm.assume(operator != address(0));
        address[] memory users = new address[](1);
        users[0] = address(1);
        tokenContract.setRole(tokenContract.APPROVED_MINT_CONTRACT(), users, true);

        address[] memory blocked = new address[](1);
        blocked[0] = operator;
        BlockListRegistry registry = new BlockListRegistry(false);
        registry.initialize(address(this), blocked);
        tokenContract.updateBlockListRegistry(address(registry));

        // mint and verify blocked operator
        vm.startPrank(address(1), address(1));
        tokenContract.externalMint(collector, "uri");
        vm.stopPrank();
        vm.startPrank(collector, collector);
        vm.expectRevert();
        tokenContract.approve(operator, 1);
        vm.expectRevert();
        tokenContract.setApprovalForAll(operator, true);
        vm.stopPrank();

        // unblock operator and verify approvals
        registry.clearBlockList();
        vm.startPrank(collector, collector);
        tokenContract.approve(operator, 1);
        assertEq(tokenContract.getApproved(1), operator);
        tokenContract.setApprovalForAll(operator, true);
        assertTrue(tokenContract.isApprovedForAll(collector, operator));
        vm.stopPrank();
    }

    /// @notice test ERC-165 support
    // - EIP-721 ✅
    // - EIP-721 Metadata ✅
    // - EIP-4906 ✅
    // - EIP-2981 ✅
    // - Story ✅
    // - EIP-165 ✅
    function testSupportsInterface() public {
        assertTrue(tokenContract.supportsInterface(0x80ac58cd)); // 721
        assertTrue(tokenContract.supportsInterface(0x5b5e139f)); // 721 metadata
        assertTrue(tokenContract.supportsInterface(0x49064906)); // 4906
        assertTrue(tokenContract.supportsInterface(0x2a55205a)); // 2981
        assertTrue(tokenContract.supportsInterface(0x0d23ecb9)); // Story
        assertTrue(tokenContract.supportsInterface(0x01ffc9a7)); // 165
        assertTrue(tokenContract.supportsInterface(0x06e1bc5b)); // 7160
    }
}

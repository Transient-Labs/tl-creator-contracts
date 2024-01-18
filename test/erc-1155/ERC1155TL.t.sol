// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import "forge-std/Test.sol";
import {Strings} from "openzeppelin/utils/Strings.sol";
import {ERC1155TL} from "src/erc-1155/ERC1155TL.sol";
import {IERC721Errors} from "openzeppelin/interfaces/draft-IERC6093.sol";
import {Initializable} from "openzeppelin/proxy/utils/Initializable.sol";
import {OwnableAccessControlUpgradeable} from "tl-sol-tools/upgradeable/access/OwnableAccessControlUpgradeable.sol";
import {IBlockListRegistry} from "src/interfaces/IBlockListRegistry.sol";
import {ITLNftDelegationRegistry} from "src/interfaces/ITLNftDelegationRegistry.sol";

contract ERC1155TLTest is Test {
    using Strings for uint256;
    using Strings for address;

    ERC1155TL public tokenContract;
    address public royaltyRecipient = makeAddr("royaltyRecipient");
    address public blocklistRegistry = makeAddr("blocklistRegistry");

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event RoleChange(address indexed from, address indexed user, bool indexed approved, bytes32 role);
    event StoryStatusUpdate(address indexed sender, bool indexed status);
    event BlockListRegistryUpdate(
        address indexed sender, address indexed prevBlockListRegistry, address indexed newBlockListRegistry
    );
    event URI(string value, uint256 indexed id);
    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);
    event TransferBatch(
        address indexed operator, address indexed from, address indexed to, uint256[] ids, uint256[] values
    );
    event CollectionStory(address indexed creatorAddress, string creatorName, string story);
    event CreatorStory(uint256 indexed tokenId, address indexed creatorAddress, string creatorName, string story);
    event Story(uint256 indexed tokenId, address indexed collectorAddress, string collectorName, string story);

    function setUp() public {
        address[] memory admins = new address[](0);
        tokenContract = new ERC1155TL(false);
        tokenContract.initialize(
            "Test1155", "TEST", "", royaltyRecipient, 1000, address(this), admins, true, address(0)
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
        address blockListRegistry
    ) public {
        // limit fuzz
        vm.assume(defaultRoyaltyRecipient != address(0));
        if (defaultRoyaltyPercentage >= 10_000) {
            defaultRoyaltyPercentage = defaultRoyaltyPercentage % 10_000;
        }
        vm.assume(initOwner != address(0));

        vm.startPrank(address(this), address(this));

        // create contract
        tokenContract = new ERC1155TL(false);
        // initialize and verify events thrown (order matters)
        vm.expectEmit(true, true, true, true);
        emit OwnershipTransferred(address(0), initOwner);
        for (uint256 i = 0; i < admins.length; i++) {
            vm.expectEmit(true, true, true, true);
            emit RoleChange(address(this), admins[i], true, tokenContract.ADMIN_ROLE());
        }
        vm.expectEmit(true, true, true, true);
        emit StoryStatusUpdate(address(this), enableStory);
        vm.expectEmit(true, true, true, true);
        emit BlockListRegistryUpdate(address(this), address(0), blockListRegistry);
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
        assertEq(address(tokenContract.blocklistRegistry()), blockListRegistry);

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
            blockListRegistry
        );

        // can't get by initializers disabled
        tokenContract = new ERC1155TL(true);

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
            blockListRegistry
        );

        vm.stopPrank();
    }

    /// @notice test ERC-165 support
    function test_supportsInterface() public {
        assertTrue(tokenContract.supportsInterface(0x1c8e024d)); // ICreatorBase
        assertTrue(tokenContract.supportsInterface(0x452d5a4a)); // IERC1155TL
        assertTrue(tokenContract.supportsInterface(0x2464f17b)); // IStory
        assertTrue(tokenContract.supportsInterface(0x0d23ecb9)); // IStory (old)
        assertTrue(tokenContract.supportsInterface(0x01ffc9a7)); // ERC-165
        assertTrue(tokenContract.supportsInterface(0xd9b67a26)); // ERC-1155
        assertTrue(tokenContract.supportsInterface(0x2a55205a)); // ERC-2981
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
        vm.expectRevert(
            abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE())
        );
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

    /// @notice test createToken
    // - access control ✅
    // - proper recipients ✅
    // - transfer event ✅
    // - proper token id ✅
    // - ownership ✅
    // - balance ✅
    // - transfer to another address ✅
    // - token uri ✅
    function test_createToken_errors() public {
        address[] memory collectors = new address[](1);
        collectors[0] = address(1);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;
        address[] memory emptyCollectors = new address[](0);
        uint256[] memory emptyAmounts = new uint256[](0);

        vm.expectRevert(ERC1155TL.EmptyTokenURI.selector);
        tokenContract.createToken("", collectors, amounts);

        vm.expectRevert(ERC1155TL.MintToZeroAddresses.selector);
        tokenContract.createToken("uri", emptyCollectors, amounts);

        vm.expectRevert(ERC1155TL.ArrayLengthMismatch.selector);
        tokenContract.createToken("uri", collectors, emptyAmounts);
    }

    function test_createToken_accessControl(address user) public {
        vm.assume(user != address(this));
        vm.assume(user != address(0));
        address[] memory collectors = new address[](1);
        collectors[0] = address(1);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;
        address[] memory users = new address[](1);
        users[0] = user;

        // verify user can't access
        vm.startPrank(user, user);
        vm.expectRevert(
            abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE())
        );
        tokenContract.createToken("uri", collectors, amounts);
        vm.expectRevert(
            abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE())
        );
        tokenContract.createToken("uri", collectors, amounts, address(1), 10);
        vm.stopPrank();

        // verify minter can't access
        tokenContract.setRole(tokenContract.APPROVED_MINT_CONTRACT(), users, true);
        vm.startPrank(user, user);
        vm.expectRevert(
            abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE())
        );
        tokenContract.createToken("uri", collectors, amounts);
        vm.expectRevert(
            abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE())
        );
        tokenContract.createToken("uri", collectors, amounts, address(1), 10);
        vm.stopPrank();
        tokenContract.setRole(tokenContract.APPROVED_MINT_CONTRACT(), users, false);

        // verify admin can access
        tokenContract.setRole(tokenContract.ADMIN_ROLE(), users, true);
        vm.startPrank(user, user);
        vm.expectEmit(true, true, true, true);
        emit TransferSingle(user, address(0), collectors[0], 1, amounts[0]);
        tokenContract.createToken("uri1", collectors, amounts);
        vm.expectEmit(true, true, true, true);
        emit TransferSingle(user, address(0), collectors[0], 2, amounts[0]);
        tokenContract.createToken("uri2", collectors, amounts, address(1), 10);
        assertTrue(tokenContract.getTokenDetails(1).created);
        assertEq(tokenContract.getTokenDetails(1).uri, "uri1");
        assertTrue(tokenContract.getTokenDetails(2).created);
        assertEq(tokenContract.getTokenDetails(2).uri, "uri2");
        vm.stopPrank();
        tokenContract.setRole(tokenContract.ADMIN_ROLE(), users, false);

        // verify owner can access
        vm.expectEmit(true, true, true, true);
        emit TransferSingle(address(this), address(0), collectors[0], 3, amounts[0]);
        tokenContract.createToken("uri3", collectors, amounts);
        vm.expectEmit(true, true, true, true);
        emit TransferSingle(address(this), address(0), collectors[0], 4, amounts[0]);
        tokenContract.createToken("uri4", collectors, amounts, address(1), 10);
        assertTrue(tokenContract.getTokenDetails(3).created);
        assertEq(tokenContract.getTokenDetails(3).uri, "uri3");
        assertTrue(tokenContract.getTokenDetails(4).created);
        assertEq(tokenContract.getTokenDetails(4).uri, "uri4");
    }

    function test_createToken(uint16 numAddresses, uint16 amount) public {
        vm.assume(numAddresses > 0);
        // limit num addresses to 300
        if (numAddresses > 300) {
            numAddresses = numAddresses % 300 + 1;
        }
        // if (amount > 1000) {
        //     amount = amount % 1000 + 1;
        // }
        vm.assume(amount != 0);
        address recipient = makeAddr(uint256(numAddresses).toString());
        address[] memory recipients = new address[](numAddresses);
        uint256[] memory amounts = new uint256[](numAddresses);
        for (uint256 i = 0; i < numAddresses; i++) {
            recipients[i] = makeAddr(i.toString());
            amounts[i] = amount;
        }
        // create token
        for (uint256 i = 0; i < numAddresses; i++) {
            vm.expectEmit(true, true, true, true);
            emit TransferSingle(address(this), address(0), recipients[i], 1, amounts[i]);
        }
        tokenContract.createToken("uri", recipients, amounts);
        assertEq(tokenContract.uri(1), "uri");
        for (uint256 i = 0; i < numAddresses; i++) {
            assertEq(tokenContract.balanceOf(recipients[i], 1), amounts[i]);
        }
        // transfer
        uint256 bal = 0;
        for (uint256 i = 0; i < numAddresses; i++) {
            bal += amount;
            vm.startPrank(recipients[i], recipients[i]);
            vm.expectEmit(true, true, true, true);
            emit TransferSingle(recipients[i], recipients[i], recipient, 1, amounts[i]);
            tokenContract.safeTransferFrom(recipients[i], recipient, 1, amounts[i], "");
            vm.stopPrank();
            assertEq(tokenContract.balanceOf(recipient, 1), bal);
        }
    }

    function test_createToken_withRoyalty(
        uint16 numAddresses,
        uint16 amount,
        address royaltyAddress,
        uint16 royaltyPercent
    ) public {
        vm.assume(numAddresses > 0);
        // limit num addresses to 300
        if (numAddresses > 300) {
            numAddresses = numAddresses % 300 + 1;
        }
        vm.assume(royaltyAddress != royaltyRecipient);
        vm.assume(royaltyAddress != address(0));
        if (royaltyPercent >= 10_000) royaltyPercent = royaltyPercent % 10_000;
        // if (amount > 1000) {
        //     amount = amount % 1000 + 1;
        // }
        vm.assume(amount != 0);
        address recipient = makeAddr(uint256(numAddresses).toString());
        address[] memory recipients = new address[](numAddresses);
        uint256[] memory amounts = new uint256[](numAddresses);
        for (uint256 i = 0; i < numAddresses; i++) {
            recipients[i] = makeAddr(i.toString());
            amounts[i] = amount;
        }
        // create token
        for (uint256 i = 0; i < numAddresses; i++) {
            vm.expectEmit(true, true, true, true);
            emit TransferSingle(address(this), address(0), recipients[i], 1, amounts[i]);
        }
        tokenContract.createToken("uri", recipients, amounts, royaltyAddress, royaltyPercent);
        assertEq(tokenContract.uri(1), "uri");
        (address recp, uint256 amt) = tokenContract.royaltyInfo(1, 10_000);
        assertEq(recp, royaltyAddress);
        assertEq(amt, royaltyPercent);
        for (uint256 i = 0; i < numAddresses; i++) {
            assertEq(tokenContract.balanceOf(recipients[i], 1), amounts[i]);
        }
        // transfer
        uint256 bal = 0;
        for (uint256 i = 0; i < numAddresses; i++) {
            bal += amount;
            vm.startPrank(recipients[i], recipients[i]);
            vm.expectEmit(true, true, true, true);
            emit TransferSingle(recipients[i], recipients[i], recipient, 1, amounts[i]);
            tokenContract.safeTransferFrom(recipients[i], recipient, 1, amounts[i], "");
            vm.stopPrank();
            assertEq(tokenContract.balanceOf(recipient, 1), bal);
        }
    }

    /// @notice test batchCreateToken
    // - access control ✅
    // - proper recipients ✅
    // - transfer event ✅
    // - proper token id ✅
    // - ownership ✅
    // - balance ✅
    // - transfer to another address ✅
    // - token uri ✅
    function test_batchCreateToken_errors() public {
        string[] memory strings = new string[](1);
        strings[0] = "uri";
        string[] memory blankStrings = new string[](1);
        blankStrings[0] = "";
        address[][] memory collectors = new address[][](1);
        collectors[0] = new address[](1);
        collectors[0][0] = address(1);
        uint256[][] memory amounts = new uint256[][](1);
        amounts[0] = new uint256[](1);
        amounts[0][0] = 1;
        string[] memory emptyStrings = new string[](0);
        address[][] memory emptyCollectors = new address[][](1);
        emptyCollectors[0] = new address[](0);
        uint256[][] memory emptyAmounts = new uint256[][](1);
        emptyAmounts[0] = new uint256[](0);

        // empty token uri
        vm.expectRevert(ERC1155TL.EmptyTokenURI.selector);
        tokenContract.batchCreateToken(new string[](0), collectors, amounts);
        vm.expectRevert(ERC1155TL.EmptyTokenURI.selector);
        tokenContract.batchCreateToken(blankStrings, collectors, amounts);
        vm.expectRevert(ERC1155TL.EmptyTokenURI.selector);
        tokenContract.batchCreateToken(emptyStrings, collectors, amounts);

        // mint to zero addresses
        vm.expectRevert(ERC1155TL.MintToZeroAddresses.selector);
        tokenContract.batchCreateToken(strings, emptyCollectors, amounts);

        // array length mismatch
        vm.expectRevert(ERC1155TL.ArrayLengthMismatch.selector);
        tokenContract.batchCreateToken(strings, new address[][](0), amounts);
        vm.expectRevert(ERC1155TL.ArrayLengthMismatch.selector);
        tokenContract.batchCreateToken(strings, collectors, new uint256[][](0));
        vm.expectRevert(ERC1155TL.ArrayLengthMismatch.selector);
        tokenContract.batchCreateToken(strings, collectors, emptyAmounts);
    }

    function test_batchCreateToken_withRoyalty_errors() public {
        string[] memory strings = new string[](1);
        strings[0] = "uri";
        string[] memory blankStrings = new string[](1);
        blankStrings[0] = "";
        address[][] memory collectors = new address[][](1);
        collectors[0] = new address[](1);
        collectors[0][0] = address(1);
        uint256[][] memory amounts = new uint256[][](1);
        amounts[0] = new uint256[](1);
        amounts[0][0] = 1;
        address[] memory royaltyRecipients = new address[](1);
        royaltyRecipients[0] = royaltyRecipient;
        uint256[] memory royaltyAmounts = new uint256[](1);
        royaltyAmounts[0] = 100;
        string[] memory emptyStrings = new string[](0);
        address[][] memory emptyCollectors = new address[][](1);
        emptyCollectors[0] = new address[](0);
        uint256[][] memory emptyAmounts = new uint256[][](1);
        emptyAmounts[0] = new uint256[](0);

        // empty token uri
        vm.expectRevert(ERC1155TL.EmptyTokenURI.selector);
        tokenContract.batchCreateToken(new string[](0), collectors, amounts, royaltyRecipients, royaltyAmounts);
        vm.expectRevert(ERC1155TL.EmptyTokenURI.selector);
        tokenContract.batchCreateToken(blankStrings, collectors, amounts, royaltyRecipients, royaltyAmounts);
        vm.expectRevert(ERC1155TL.EmptyTokenURI.selector);
        tokenContract.batchCreateToken(emptyStrings, collectors, amounts, royaltyRecipients, royaltyAmounts);

        // mint to zero addresses
        vm.expectRevert(ERC1155TL.MintToZeroAddresses.selector);
        tokenContract.batchCreateToken(strings, emptyCollectors, amounts, royaltyRecipients, royaltyAmounts);

        // array length mismatch
        vm.expectRevert(ERC1155TL.ArrayLengthMismatch.selector);
        tokenContract.batchCreateToken(strings, new address[][](0), amounts, royaltyRecipients, royaltyAmounts);
        vm.expectRevert(ERC1155TL.ArrayLengthMismatch.selector);
        tokenContract.batchCreateToken(strings, collectors, new uint256[][](0), royaltyRecipients, royaltyAmounts);
        vm.expectRevert(ERC1155TL.ArrayLengthMismatch.selector);
        tokenContract.batchCreateToken(strings, collectors, amounts, new address[](0), royaltyAmounts);
        vm.expectRevert(ERC1155TL.ArrayLengthMismatch.selector);
        tokenContract.batchCreateToken(strings, collectors, amounts, royaltyRecipients, new uint256[](0));
        vm.expectRevert(ERC1155TL.ArrayLengthMismatch.selector);
        tokenContract.batchCreateToken(strings, collectors, emptyAmounts, royaltyRecipients, royaltyAmounts);
    }

    function test_batchCreateToken_accessControl(address user) public {
        vm.assume(user != address(this));
        vm.assume(user != address(0));
        string[] memory strings = new string[](1);
        strings[0] = "uri";
        address[][] memory collectors = new address[][](1);
        collectors[0] = new address[](1);
        collectors[0][0] = address(1);
        uint256[][] memory amounts = new uint256[][](1);
        amounts[0] = new uint256[](1);
        amounts[0][0] = 1;
        address[] memory royaltyRecipients = new address[](1);
        royaltyRecipients[0] = royaltyRecipient;
        uint256[] memory royaltyAmounts = new uint256[](1);
        royaltyAmounts[0] = 100;
        address[] memory users = new address[](1);
        users[0] = user;
        // verify user can't access
        vm.startPrank(user, user);
        vm.expectRevert(
            abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE())
        );
        tokenContract.batchCreateToken(strings, collectors, amounts);
        vm.expectRevert(
            abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE())
        );
        tokenContract.batchCreateToken(strings, collectors, amounts, royaltyRecipients, royaltyAmounts);
        vm.stopPrank();
        // verify minter can't access
        tokenContract.setRole(tokenContract.APPROVED_MINT_CONTRACT(), users, true);
        vm.startPrank(user, user);
        vm.expectRevert(
            abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE())
        );
        tokenContract.batchCreateToken(strings, collectors, amounts);
        vm.expectRevert(
            abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE())
        );
        tokenContract.batchCreateToken(strings, collectors, amounts, royaltyRecipients, royaltyAmounts);
        vm.stopPrank();
        tokenContract.setRole(tokenContract.APPROVED_MINT_CONTRACT(), users, false);
        // verify admin can access
        tokenContract.setRole(tokenContract.ADMIN_ROLE(), users, true);
        vm.startPrank(user, user);
        vm.expectEmit(true, true, true, true);
        emit TransferSingle(user, address(0), collectors[0][0], 1, amounts[0][0]);
        tokenContract.batchCreateToken(strings, collectors, amounts);
        vm.expectEmit(true, true, true, true);
        emit TransferSingle(user, address(0), collectors[0][0], 2, amounts[0][0]);
        tokenContract.batchCreateToken(strings, collectors, amounts, royaltyRecipients, royaltyAmounts);
        vm.stopPrank();
        tokenContract.setRole(tokenContract.ADMIN_ROLE(), users, false);
        // verify owner can access
        vm.expectEmit(true, true, true, true);
        emit TransferSingle(address(this), address(0), collectors[0][0], 3, amounts[0][0]);
        tokenContract.batchCreateToken(strings, collectors, amounts);
        vm.expectEmit(true, true, true, true);
        emit TransferSingle(address(this), address(0), collectors[0][0], 4, amounts[0][0]);
        tokenContract.batchCreateToken(strings, collectors, amounts, royaltyRecipients, royaltyAmounts);
    }

    function test_batchCreateToken(uint16 numTokens, uint16 numAddresses, uint16 amount) public {
        vm.assume(numAddresses > 0);
        // limit num addresses to 300
        if (numAddresses > 300) {
            numAddresses = numAddresses % 300 + 1;
        }
        vm.assume(numTokens > 0);
        // limit number of tokens to 10
        if (numTokens > 10) {
            numTokens = numTokens % 10 + 1;
        }
        vm.assume(amount != 0);
        address recipient = makeAddr(uint256(numAddresses).toString());
        string[] memory strings = new string[](numTokens);
        address[][] memory recipients = new address[][](numTokens);
        uint256[][] memory amounts = new uint256[][](numTokens);
        for (uint256 i = 0; i < numTokens; i++) {
            strings[i] = i.toString();
            recipients[i] = new address[](numAddresses);
            amounts[i] = new uint256[](numAddresses);
            for (uint256 j = 0; j < numAddresses; j++) {
                recipients[i][j] = makeAddr(j.toString());
                amounts[i][j] = amount;
            }
        }
        // create token
        for (uint256 i = 0; i < numTokens; i++) {
            for (uint256 j = 0; j < numAddresses; j++) {
                vm.expectEmit(true, true, true, true);
                emit TransferSingle(address(this), address(0), recipients[i][j], i + 1, amounts[i][j]);
            }
        }
        tokenContract.batchCreateToken(strings, recipients, amounts);
        for (uint256 i = 0; i < numTokens; i++) {
            assertEq(tokenContract.uri(i + 1), i.toString());
            for (uint256 j = 0; j < numAddresses; j++) {
                assertEq(tokenContract.balanceOf(recipients[i][j], i + 1), amounts[i][j]);
            }
        }
        // transfer
        for (uint256 i = 0; i < numTokens; i++) {
            uint256 bal = 0;
            for (uint256 j = 0; j < numAddresses; j++) {
                bal += amount;
                vm.startPrank(recipients[i][j], recipients[i][j]);
                vm.expectEmit(true, true, true, true);
                emit TransferSingle(recipients[i][j], recipients[i][j], recipient, i + 1, amounts[i][j]);
                tokenContract.safeTransferFrom(recipients[i][j], recipient, i + 1, amounts[i][j], "");
                vm.stopPrank();
                assertEq(tokenContract.balanceOf(recipient, i + 1), bal);
            }
        }
    }

    function test_batchCreateToken_withRoyalty(
        uint16 numTokens,
        uint16 numAddresses,
        uint16 amount,
        address royaltyAddress,
        uint16 royaltyPercent
    ) public {
        vm.assume(numAddresses > 0);
        // limit num addresses to 300
        if (numAddresses > 300) {
            numAddresses = numAddresses % 300 + 1;
        }
        vm.assume(royaltyAddress != royaltyRecipient);
        vm.assume(royaltyAddress != address(0));
        if (royaltyPercent >= 10_000) royaltyPercent = royaltyPercent % 10_000;
        vm.assume(numTokens > 0);
        // limit number of tokens to 10
        if (numTokens > 10) {
            numTokens = numTokens % 10 + 1;
        }
        vm.assume(amount != 0);
        address recipient = makeAddr(uint256(numAddresses).toString());
        string[] memory strings = new string[](numTokens);
        address[][] memory recipients = new address[][](numTokens);
        uint256[][] memory amounts = new uint256[][](numTokens);
        address[] memory royaltyAddresses = new address[](numTokens);
        uint256[] memory royaltyPercents = new uint256[](numTokens);
        for (uint256 i = 0; i < numTokens; i++) {
            strings[i] = i.toString();
            royaltyAddresses[i] = royaltyAddress;
            royaltyPercents[i] = royaltyPercent;
            recipients[i] = new address[](numAddresses);
            amounts[i] = new uint256[](numAddresses);
            for (uint256 j = 0; j < numAddresses; j++) {
                recipients[i][j] = makeAddr(j.toString());
                amounts[i][j] = amount;
            }
        }
        // create token
        for (uint256 i = 0; i < numTokens; i++) {
            for (uint256 j = 0; j < numAddresses; j++) {
                vm.expectEmit(true, true, true, true);
                emit TransferSingle(address(this), address(0), recipients[i][j], i + 1, amounts[i][j]);
            }
        }
        tokenContract.batchCreateToken(strings, recipients, amounts, royaltyAddresses, royaltyPercents);
        for (uint256 i = 0; i < numTokens; i++) {
            assertEq(tokenContract.uri(i + 1), i.toString());
            (address recp, uint256 amt) = tokenContract.royaltyInfo(i + 1, 10_000);
            assertEq(recp, royaltyAddress);
            assertEq(amt, royaltyPercent);
            for (uint256 j = 0; j < numAddresses; j++) {
                assertEq(tokenContract.balanceOf(recipients[i][j], i + 1), amounts[i][j]);
            }
        }
        // transfer
        for (uint256 i = 0; i < numTokens; i++) {
            uint256 bal = 0;
            for (uint256 j = 0; j < numAddresses; j++) {
                bal += amount;
                vm.startPrank(recipients[i][j], recipients[i][j]);
                vm.expectEmit(true, true, true, true);
                emit TransferSingle(recipients[i][j], recipients[i][j], recipient, i + 1, amounts[i][j]);
                tokenContract.safeTransferFrom(recipients[i][j], recipient, i + 1, amounts[i][j], "");
                vm.stopPrank();
                assertEq(tokenContract.balanceOf(recipient, i + 1), bal);
            }
        }
    }

    /// @notice test mint
    // - access control ✅
    // - proper recipients ✅
    // - transfer event ✅
    // - proper token id ✅
    // - ownership ✅
    // - balance ✅
    // - transfer to another address ✅
    function test_mintToken_errors() public {
        address[] memory collectors = new address[](1);
        collectors[0] = address(1);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;
        address[] memory emptyCollectors = new address[](0);
        uint256[] memory emptyAmounts = new uint256[](0);

        vm.expectRevert(ERC1155TL.TokenDoesntExist.selector);
        tokenContract.mintToken(1, collectors, amounts);

        tokenContract.createToken("uri", collectors, amounts);
        vm.expectRevert(ERC1155TL.MintToZeroAddresses.selector);
        tokenContract.mintToken(1, emptyCollectors, amounts);

        vm.expectRevert(ERC1155TL.ArrayLengthMismatch.selector);
        tokenContract.mintToken(1, collectors, emptyAmounts);
    }

    function test_mintToken_accessControl(address user) public {
        vm.assume(user != address(this));
        vm.assume(user != address(0));
        address[] memory collectors = new address[](1);
        collectors[0] = address(1);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;
        address[] memory users = new address[](1);
        users[0] = user;
        tokenContract.createToken("uri", collectors, amounts);
        // verify user can't access
        vm.startPrank(user, user);
        vm.expectRevert(
            abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE())
        );
        tokenContract.mintToken(1, collectors, amounts);
        vm.stopPrank();
        // verify minter can't access
        tokenContract.setRole(tokenContract.APPROVED_MINT_CONTRACT(), users, true);
        vm.startPrank(user, user);
        vm.expectRevert(
            abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE())
        );
        tokenContract.mintToken(1, collectors, amounts);
        vm.stopPrank();
        tokenContract.setRole(tokenContract.APPROVED_MINT_CONTRACT(), users, false);
        // verify admin can access
        tokenContract.setRole(tokenContract.ADMIN_ROLE(), users, true);
        vm.startPrank(user, user);
        vm.expectEmit(true, true, true, true);
        emit TransferSingle(user, address(0), collectors[0], 1, amounts[0]);
        tokenContract.mintToken(1, collectors, amounts);
        vm.stopPrank();
        tokenContract.setRole(tokenContract.ADMIN_ROLE(), users, false);
        // verify owner can access
        vm.expectEmit(true, true, true, true);
        emit TransferSingle(address(this), address(0), collectors[0], 1, amounts[0]);
        tokenContract.mintToken(1, collectors, amounts);
    }

    function test_mintToken(uint16 numAddresses, uint16 amount) public {
        vm.assume(numAddresses > 0);
        // limit num addresses to 300
        if (numAddresses > 300) {
            numAddresses = numAddresses % 300 + 1;
        }
        vm.assume(amount != 0);
        address[] memory collector = new address[](1);
        collector[0] = address(1);
        uint256[] memory amount_ = new uint256[](1);
        amount_[0] = 1;
        tokenContract.createToken("uri", collector, amount_);
        address recipient = makeAddr(uint256(numAddresses).toString());
        address[] memory recipients = new address[](numAddresses);
        uint256[] memory amounts = new uint256[](numAddresses);
        for (uint256 i = 0; i < numAddresses; i++) {
            recipients[i] = makeAddr(i.toString());
            amounts[i] = amount;
        }
        // mint token
        for (uint256 i = 0; i < numAddresses; i++) {
            vm.expectEmit(true, true, true, true);
            emit TransferSingle(address(this), address(0), recipients[i], 1, amounts[i]);
        }
        tokenContract.mintToken(1, recipients, amounts);
        assertEq(tokenContract.uri(1), "uri");
        for (uint256 i = 0; i < numAddresses; i++) {
            assertEq(tokenContract.balanceOf(recipients[i], 1), amounts[i]);
        }
        // transfer
        uint256 bal = 0;
        for (uint256 i = 0; i < numAddresses; i++) {
            bal += amount;
            vm.startPrank(recipients[i], recipients[i]);
            vm.expectEmit(true, true, true, true);
            emit TransferSingle(recipients[i], recipients[i], recipient, 1, amounts[i]);
            tokenContract.safeTransferFrom(recipients[i], recipient, 1, amounts[i], "");
            vm.stopPrank();
            assertEq(tokenContract.balanceOf(recipient, 1), bal);
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
    function test_externalMint_errors() public {
        address[] memory minters = new address[](1);
        minters[0] = address(this);
        tokenContract.setRole(tokenContract.APPROVED_MINT_CONTRACT(), minters, true);
        address[] memory collectors = new address[](1);
        collectors[0] = address(1);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;
        address[] memory emptyCollectors = new address[](0);
        uint256[] memory emptyAmounts = new uint256[](0);

        vm.expectRevert(ERC1155TL.TokenDoesntExist.selector);
        tokenContract.externalMint(1, collectors, amounts);

        tokenContract.createToken("uri", collectors, amounts);
        vm.expectRevert(ERC1155TL.MintToZeroAddresses.selector);
        tokenContract.externalMint(1, emptyCollectors, amounts);

        vm.expectRevert(ERC1155TL.ArrayLengthMismatch.selector);
        tokenContract.externalMint(1, collectors, emptyAmounts);
    }

    function test_externalMint_accessControl(address user) public {
        vm.assume(user != address(this));
        vm.assume(user != address(0));
        address[] memory collectors = new address[](1);
        collectors[0] = address(1);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;
        address[] memory users = new address[](1);
        users[0] = user;
        tokenContract.createToken("uri", collectors, amounts);
        // verify user can't access
        vm.startPrank(user, user);
        vm.expectRevert(
            abi.encodeWithSelector(
                OwnableAccessControlUpgradeable.NotSpecifiedRole.selector, tokenContract.APPROVED_MINT_CONTRACT()
            )
        );
        tokenContract.externalMint(1, collectors, amounts);
        vm.stopPrank();
        // verify admin can't access
        tokenContract.setRole(tokenContract.ADMIN_ROLE(), users, true);
        vm.startPrank(user, user);
        vm.expectRevert(
            abi.encodeWithSelector(
                OwnableAccessControlUpgradeable.NotSpecifiedRole.selector, tokenContract.APPROVED_MINT_CONTRACT()
            )
        );
        tokenContract.externalMint(1, collectors, amounts);
        vm.stopPrank();
        tokenContract.setRole(tokenContract.ADMIN_ROLE(), users, false);
        // verify minter can access
        tokenContract.setRole(tokenContract.APPROVED_MINT_CONTRACT(), users, true);
        vm.startPrank(user, user);
        vm.expectEmit(true, true, true, true);
        emit TransferSingle(user, address(0), collectors[0], 1, amounts[0]);
        tokenContract.externalMint(1, collectors, amounts);
        vm.stopPrank();
        tokenContract.setRole(tokenContract.APPROVED_MINT_CONTRACT(), users, false);
        // verify owner can't access
        vm.expectRevert(
            abi.encodeWithSelector(
                OwnableAccessControlUpgradeable.NotSpecifiedRole.selector, tokenContract.APPROVED_MINT_CONTRACT()
            )
        );
        tokenContract.externalMint(1, collectors, amounts);
    }

    function test_externalMint(uint16 numAddresses, uint16 amount) public {
        vm.assume(numAddresses > 0);
        // limit num addresses to 300
        if (numAddresses > 300) {
            numAddresses = numAddresses % 300 + 1;
        }
        vm.assume(amount != 0);
        address[] memory minters = new address[](1);
        minters[0] = address(this);
        tokenContract.setRole(tokenContract.APPROVED_MINT_CONTRACT(), minters, true);
        address[] memory collector = new address[](1);
        collector[0] = address(1);
        uint256[] memory amount_ = new uint256[](1);
        amount_[0] = 1;
        tokenContract.createToken("uri", collector, amount_);
        address recipient = makeAddr(uint256(numAddresses).toString());
        address[] memory recipients = new address[](numAddresses);
        uint256[] memory amounts = new uint256[](numAddresses);
        for (uint256 i = 0; i < numAddresses; i++) {
            recipients[i] = makeAddr(i.toString());
            amounts[i] = amount;
        }
        // mint token
        for (uint256 i = 0; i < numAddresses; i++) {
            vm.expectEmit(true, true, true, true);
            emit TransferSingle(address(this), address(0), recipients[i], 1, amounts[i]);
        }
        tokenContract.externalMint(1, recipients, amounts);
        assertEq(tokenContract.uri(1), "uri");
        for (uint256 i = 0; i < numAddresses; i++) {
            assertEq(tokenContract.balanceOf(recipients[i], 1), amounts[i]);
        }
        // transfer
        uint256 bal = 0;
        for (uint256 i = 0; i < numAddresses; i++) {
            bal += amount;
            vm.startPrank(recipients[i], recipients[i]);
            vm.expectEmit(true, true, true, true);
            emit TransferSingle(recipients[i], recipients[i], recipient, 1, amounts[i]);
            tokenContract.safeTransferFrom(recipients[i], recipient, 1, amounts[i], "");
            vm.stopPrank();
            assertEq(tokenContract.balanceOf(recipient, 1), bal);
        }
    }

    /// @notice test burn
    // - access control
    // - transfer events
    // - ownership
    // - balance
    // - transfer to another address
    // - safe transfer to another address
    function test_burn_errors() public {
        uint256[] memory tokens = new uint256[](0);
        vm.expectRevert(ERC1155TL.BurnZeroTokens.selector);
        tokenContract.burn(address(this), tokens, tokens);
    }

    function test_burn_accessControl(address user) public {
        vm.assume(user != address(0));
        vm.assume(user != address(1));
        address[] memory collectors = new address[](1);
        collectors[0] = address(1);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 2;
        uint256[] memory tokens = new uint256[](1);
        tokens[0] = 1;
        uint256[] memory amts = new uint256[](1);
        amts[0] = 1;
        address[] memory users = new address[](1);
        users[0] = user;
        tokenContract.createToken("uri", collectors, amounts);

        // verify user can't burn
        vm.startPrank(user, user);
        vm.expectRevert(ERC1155TL.CallerNotApprovedOrOwner.selector);
        tokenContract.burn(address(1), tokens, amts);
        vm.stopPrank();

        // verify admin can't burn
        tokenContract.setRole(tokenContract.ADMIN_ROLE(), users, true);
        vm.startPrank(user, user);
        vm.expectRevert(ERC1155TL.CallerNotApprovedOrOwner.selector);
        tokenContract.burn(address(1), tokens, amts);
        vm.stopPrank();
        tokenContract.setRole(tokenContract.ADMIN_ROLE(), users, false);

        // verify minter cant' burn
        tokenContract.setRole(tokenContract.APPROVED_MINT_CONTRACT(), users, true);
        vm.startPrank(user, user);
        vm.expectRevert(ERC1155TL.CallerNotApprovedOrOwner.selector);
        tokenContract.burn(address(1), tokens, amts);
        vm.stopPrank();
        tokenContract.setRole(tokenContract.APPROVED_MINT_CONTRACT(), users, false);

        // verify owner can't burn
        vm.expectRevert(ERC1155TL.CallerNotApprovedOrOwner.selector);
        tokenContract.burn(address(1), tokens, amts);

        // verify collector can burn
        vm.startPrank(address(1), address(1));
        vm.expectEmit(true, true, true, true);
        emit TransferSingle(address(1), address(1), address(0), tokens[0], amts[0]);
        tokenContract.burn(address(1), tokens, amts);
        vm.stopPrank();

        // verify approved operator can burn
        vm.startPrank(address(1), address(1));
        tokenContract.setApprovalForAll(user, true);
        vm.stopPrank();
        vm.startPrank(user, user);
        vm.expectEmit(true, true, true, true);
        emit TransferSingle(user, address(1), address(0), tokens[0], amts[0]);
        tokenContract.burn(address(1), tokens, amts);
        vm.stopPrank();
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

        // verify that minters can't set royalty
        tokenContract.setRole(tokenContract.APPROVED_MINT_CONTRACT(), users, true);
        vm.startPrank(user, user);
        vm.expectRevert(
            abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE())
        );
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

        // verify that minters can't set royalty
        tokenContract.setRole(tokenContract.APPROVED_MINT_CONTRACT(), users, true);
        vm.startPrank(user, user);
        vm.expectRevert(
            abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE())
        );
        tokenContract.setTokenRoyalty(tokenId, newRecipient, newPercentage);
        vm.stopPrank();
        tokenContract.setRole(tokenContract.APPROVED_MINT_CONTRACT(), users, false);

        // verify owner of the contract can set royalty
        tokenContract.setTokenRoyalty(tokenId, royaltyRecipient, 0);
        (recp, amt) = tokenContract.royaltyInfo(tokenId, 10_000);
        assertEq(recp, royaltyRecipient);
        assertEq(amt, 0);
    }

    /// @notice test token uri update
    // - access control ✅
    // - proper events ✅
    function test_setTokenUri_errors() public {
        vm.expectRevert(ERC1155TL.TokenDoesntExist.selector);
        tokenContract.setTokenUri(1, "newURI");

        address[] memory collectors = new address[](1);
        collectors[0] = address(1);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;
        tokenContract.createToken("uri", collectors, amounts);

        vm.expectRevert(ERC1155TL.EmptyTokenURI.selector);
        tokenContract.setTokenUri(1, "");

        vm.expectRevert(ERC1155TL.TokenDoesntExist.selector);
        tokenContract.uri(2);
    }

    function test_setTokenUri(address user) public {
        vm.assume(user != address(0));
        vm.assume(user != address(this));
        address[] memory users = new address[](1);
        users[0] = user;

        address[] memory collectors = new address[](1);
        collectors[0] = address(1);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;
        tokenContract.createToken("uri", collectors, amounts);

        // verify user can't access
        vm.startPrank(user, user);
        vm.expectRevert(
            abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE())
        );
        tokenContract.setTokenUri(1, "newUri");
        vm.stopPrank();

        // verify minter can't access
        tokenContract.setRole(tokenContract.APPROVED_MINT_CONTRACT(), users, true);
        vm.startPrank(user, user);
        vm.expectRevert(
            abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE())
        );
        tokenContract.setTokenUri(1, "newUri");
        vm.stopPrank();
        tokenContract.setRole(tokenContract.APPROVED_MINT_CONTRACT(), users, false);

        // verify admin can access
        tokenContract.setRole(tokenContract.ADMIN_ROLE(), users, true);
        vm.startPrank(user, user);
        vm.expectEmit(true, false, false, true);
        emit URI("newUri", 1);
        tokenContract.setTokenUri(1, "newUri");
        assertEq(tokenContract.uri(1), "newUri");
        vm.stopPrank();
        tokenContract.setRole(tokenContract.ADMIN_ROLE(), users, false);

        // verify owner can access
        vm.expectEmit(true, false, false, true);
        emit URI("newUris", 1);
        tokenContract.setTokenUri(1, "newUris");
        assertEq(tokenContract.uri(1), "newUris");
    }

    /// @notice test story functions
    // - enable/disable story access control ✅
    // - write collection story w/ proper acccess ✅
    // - write creator story to existing token w/ proper acccess ✅
    // - write collector story to existing token w/ proper access ✅
    // - write creator story to non-existent token (reverts) ✅
    // - write collector story to non-existent token (reverts) ✅
    function test_story_accessControl(address user) public {
        vm.assume(user != address(10));
        address[] memory users = new address[](1);
        users[0] = user;

        address[] memory collectors = new address[](1);
        collectors[0] = address(10);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;
        tokenContract.createToken("uri", collectors, amounts);

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
        emit CreatorStory(1, user, user.toHexString(), "my story!");
        tokenContract.addCreatorStory(1, "", "my story!");
        vm.stopPrank();
        tokenContract.setRole(tokenContract.ADMIN_ROLE(), users, false);

        // verify minter can't enable/disable and can't add collection and creator stories
        tokenContract.setRole(tokenContract.APPROVED_MINT_CONTRACT(), users, true);
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

    function testStoryNonExistentTokens() public {
        vm.expectRevert(ERC1155TL.TokenDoesntExist.selector);
        tokenContract.addCreatorStory(1, "XCOPY", "I AM XCOPY");
        vm.expectRevert(ERC1155TL.CallerNotTokenOwner.selector);
        tokenContract.addStory(1, "NOT XCOPY", "I AM NOT XCOPY");
    }

    function test_addStory(uint16 numAddresses, uint16 amount) public {
        vm.assume(numAddresses > 0);
        // limit num addresses to 300
        if (numAddresses > 300) {
            numAddresses = numAddresses % 300 + 1;
        }
        vm.assume(amount != 0);
        address[] memory recipients = new address[](numAddresses);
        uint256[] memory amounts = new uint256[](numAddresses);
        for (uint256 i = 0; i < numAddresses; i++) {
            recipients[i] = makeAddr(i.toString());
            amounts[i] = amount;
        }
        // create token
        tokenContract.createToken("uri", recipients, amounts);

        // test creator can add story
        vm.expectEmit(true, true, true, true);
        emit CreatorStory(1, address(this), address(this).toHexString(), "I AM XCOPY");
        tokenContract.addCreatorStory(1, "XCOPY", "I AM XCOPY");

        // test collectors can't add creator story
        for (uint256 i = 0; i < numAddresses; i++) {
            vm.startPrank(recipients[i], recipients[i]);
            vm.expectRevert(
                abi.encodeWithSelector(
                    OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE()
                )
            );
            tokenContract.addCreatorStory(1, "XCOPY", "I AM XCOPY");
            vm.stopPrank();
        }

        // test collectors story
        for (uint256 i = 0; i < numAddresses; i++) {
            vm.startPrank(recipients[i], recipients[i]);
            vm.expectEmit(true, true, true, true);
            emit Story(1, recipients[i], recipients[i].toHexString(), "I AM NOT XCOPY");
            tokenContract.addStory(1, "NOT XCOPY", "I AM NOT XCOPY");
            vm.stopPrank();
        }

        // test that owner can't add collector story
        vm.expectRevert(ERC1155TL.CallerNotTokenOwner.selector);
        tokenContract.addStory(1, "NOT XCOPY", "I AM NOT XCOPY");
    }

    function test_story_disabled(address collector) public {
        vm.assume(collector != address(0));
        vm.assume(collector != address(this));
        vm.assume(collector.code.length == 0);
        address[] memory collectors = new address[](1);
        collectors[0] = collector;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;
        tokenContract.createToken("uri", collectors, amounts);

        // disable story
        tokenContract.setStoryStatus(false);

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
        vm.expectRevert(ERC1155TL.StoryNotEnabled.selector);
        tokenContract.addStory(1, "NOT XCOPY", "I AM NOT XCOPY");
        vm.stopPrank();

        // test that owner can't add collector story
        vm.expectRevert(ERC1155TL.StoryNotEnabled.selector);
        tokenContract.addStory(1, "NOT XCOPY", "I AM NOT XCOPY");
    }

    /// @notice test blocklist functions
    // - test blocked ✅
    // - test not blocked ✅
    // - test access control for changing the registry ✅
    function test_setBlockListRegistry_accessControl(address user) public {
        vm.assume(user != address(this));
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

        // verify minter can't access
        tokenContract.setRole(tokenContract.APPROVED_MINT_CONTRACT(), users, true);
        vm.startPrank(user, user);
        vm.expectRevert(
            abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, tokenContract.ADMIN_ROLE())
        );
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
        address[] memory collectors = new address[](1);
        collectors[0] = address(10);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;
        tokenContract.createToken("uri", collectors, amounts);

        // expect revert
        vm.expectRevert();
        tokenContract.setApprovalForAll(address(10), true);

        // expect can set approval for all to false regardless
        tokenContract.setApprovalForAll(address(10), false);
    }

    function test_blocklist_singleToken(uint16 numAddresses, uint16 amount) public {
        vm.assume(numAddresses > 0);
        // limit num addresses to 300
        if (numAddresses > 300) {
            numAddresses = numAddresses % 300 + 1;
        }
        vm.assume(amount != 0);
        address operator = makeAddr(uint256(numAddresses).toString());
        address[] memory recipients = new address[](numAddresses);
        uint256[] memory amounts = new uint256[](numAddresses);
        for (uint256 i = 0; i < numAddresses; i++) {
            recipients[i] = makeAddr(i.toString());
            amounts[i] = amount;
        }

        // mock call
        vm.mockCall(
            blocklistRegistry, abi.encodeWithSelector(IBlockListRegistry.getBlockListStatus.selector), abi.encode(true)
        );

        // update blocklist registry
        tokenContract.setBlockListRegistry(blocklistRegistry);

        // create token
        tokenContract.createToken("uri", recipients, amounts);

        // verify blocked operator
        for (uint256 i = 0; i < numAddresses; i++) {
            vm.startPrank(recipients[i], recipients[i]);
            vm.expectRevert();
            tokenContract.setApprovalForAll(operator, true);
            vm.stopPrank();
        }

        // unblock operator and test approvals
        vm.mockCall(
            blocklistRegistry, abi.encodeWithSelector(IBlockListRegistry.getBlockListStatus.selector), abi.encode(false)
        );
        for (uint256 i = 0; i < numAddresses; i++) {
            vm.startPrank(recipients[i], recipients[i]);
            tokenContract.setApprovalForAll(operator, true);
            assertTrue(tokenContract.isApprovedForAll(recipients[i], operator));
            vm.stopPrank();
        }

        // clear mocked call
        vm.clearMockedCalls();
    }

    function test_blocklist_batchTokens(uint16 numTokens, uint16 numAddresses, uint16 amount) public {
        vm.assume(numTokens > 0);
        if (numTokens > 10) {
            numTokens = numTokens % 10 + 1;
        }
        vm.assume(numAddresses > 0);
        // limit num addresses to 300
        if (numAddresses > 300) {
            numAddresses = numAddresses % 300 + 1;
        }
        vm.assume(amount != 0);
        address operator = makeAddr(uint256(numAddresses).toString());
        string[] memory uris = new string[](numTokens);
        address[][] memory recipients = new address[][](numTokens);
        uint256[][] memory amounts = new uint256[][](numTokens);
        for (uint256 i = 0; i < numTokens; i++) {
            uris[i] = "uri";
            recipients[i] = new address[](numAddresses);
            amounts[i] = new uint256[](numAddresses);
            for (uint256 j = 0; j < numAddresses; j++) {
                recipients[i][j] = makeAddr(j.toString());
                amounts[i][j] = amount;
            }
        }

        // mock call
        vm.mockCall(
            blocklistRegistry, abi.encodeWithSelector(IBlockListRegistry.getBlockListStatus.selector), abi.encode(true)
        );

        // update blocklist registry
        tokenContract.setBlockListRegistry(blocklistRegistry);

        // create tokens
        tokenContract.batchCreateToken(uris, recipients, amounts);

        // verify blocked operator
        for (uint256 i = 0; i < numTokens; i++) {
            for (uint256 j = 0; j < numAddresses; j++) {
                vm.startPrank(recipients[i][j], recipients[i][j]);
                vm.expectRevert();
                tokenContract.setApprovalForAll(operator, true);
                vm.stopPrank();
            }
        }

        // unblock operator and test approvals
        vm.mockCall(
            blocklistRegistry, abi.encodeWithSelector(IBlockListRegistry.getBlockListStatus.selector), abi.encode(false)
        );
        for (uint256 i = 0; i < numTokens; i++) {
            for (uint256 j = 0; j < numAddresses; j++) {
                vm.startPrank(recipients[i][j], recipients[i][j]);
                tokenContract.setApprovalForAll(operator, true);
                assertTrue(tokenContract.isApprovedForAll(recipients[i][j], operator));
                vm.stopPrank();
            }
        }

        // clear mocked calls
        vm.clearMockedCalls();
    }

    /// @notice tl nft delegation registry test
    function test_tlNftDelegationRegistry(address user, address registry) public {
        vm.expectRevert();
        vm.prank(user);
        tokenContract.setNftDelegationRegistry(registry);

        assertEq(address(tokenContract.tlNftDelegationRegistry()), address(0));
    }
}

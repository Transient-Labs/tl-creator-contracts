// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import {ERC721TL, OwnableAccessControlUpgradeable} from "../src/ERC721TL.sol";

contract ERC721TLUnitTest is Test {
    ERC721TL public tokenContract;
    address public royaltyRecipient = makeAddr("royaltyRecipient");

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event RoleChange(address indexed from, address indexed user, bool indexed approved, bytes32 role);
    event BlockListRegistryUpdated(address indexed caller, address indexed oldRegistry, address indexed newRegistry);

    function setUp() public {
        address[] memory admins = new address[](0);
        tokenContract = new ERC721TL();
        tokenContract.initialize("Test721", "T721", royaltyRecipient, 1000, address(this), admins, true, address(0));
    }

    // Initialization Tests
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
        tokenContract = new ERC721TL();
        // initialize and verify events thrown
        vm.expectEmit(true, true, false, false);
        emit OwnershipTransferred(address(0), address(this));
        vm.expectEmit(true, true, false, false);
        emit OwnershipTransferred(address(this), initOwner);
        for (uint256 i = 0; i < admins.length; i++) {
            vm.expectEmit(true, true, true, true);
            emit RoleChange(address(this), admins[i], true, tokenContract.ADMIN_ROLE());
        }
        vm.expectEmit(true, true, true, false);
        emit BlockListRegistryUpdated(address(this), address(0), blockListRegistry);
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
    }


}

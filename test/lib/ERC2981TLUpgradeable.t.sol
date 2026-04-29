// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std-1.14.0/Test.sol";
import {MockERC2981TLUpgradeable} from "test/utils/MockERC2981TLUpgradeable.sol";
import {ERC2981TLUpgradeable} from "src/lib/ERC2981TLUpgradeable.sol";

contract TestERC2981TLUpgradeable is Test {
    MockERC2981TLUpgradeable public mockContract;

    /// @dev Event to emit when the default roylaty is updated
    event DefaultRoyaltyUpdate(address indexed sender, address newRecipient, uint256 newPercentage);

    /// @dev Event to emit when a token royalty is overriden
    event TokenRoyaltyOverride(
        address indexed sender, uint256 indexed tokenId, address newRecipient, uint256 newPercentage
    );

    function test_DefaultRoyaltyInfo(uint256 tokenId, address recipient, uint16 percentage, uint256 saleAmount) public {
        mockContract = new MockERC2981TLUpgradeable();
        uint256 maxRoyalty = mockContract.MAX_ROYALTY();
        if (recipient == address(0)) {
            vm.expectRevert(ERC2981TLUpgradeable.ZeroAddressError.selector);
        } else if (percentage > maxRoyalty) {
            vm.expectRevert(ERC2981TLUpgradeable.MaxRoyaltyError.selector);
        } else {
            vm.expectEmit(true, true, true, true);
            emit DefaultRoyaltyUpdate(address(this), recipient, percentage);
        }
        mockContract.initialize(recipient, uint256(percentage));
        if (recipient != address(0) && percentage <= maxRoyalty) {
            if (saleAmount > 3_000_000 ether) {
                saleAmount = saleAmount % 3_000_000 ether;
            }
            uint256 expectedAmount = saleAmount * percentage / 10_000;
            (address returnedRecipient, uint256 amount) = mockContract.royaltyInfo(tokenId, saleAmount);
            assertEq(recipient, returnedRecipient);
            assertEq(amount, expectedAmount);

            (address returnedDefaultRecipient, uint256 returnedDefaultPercentage) =
                mockContract.getDefaultRoyaltyRecipientAndPercentage();
            assertEq(returnedDefaultRecipient, recipient);
            assertEq(returnedDefaultPercentage, percentage);
        }
    }

    function test_ERC165Support(address recipient, uint16 percentage) public {
        if (recipient != address(0)) {
            mockContract = new MockERC2981TLUpgradeable();
            uint256 maxRoyalty = mockContract.MAX_ROYALTY();
            vm.assume(percentage <= maxRoyalty);
            mockContract.initialize(recipient, uint256(percentage));
            assertTrue(mockContract.supportsInterface(0x01ffc9a7)); // ERC165 interface id
            assertTrue(mockContract.supportsInterface(0x2a55205a)); // EIP2981 interface id
        }
    }

    function test_OverrideDefaultRoyalty(uint256 tokenId, address recipient, uint16 percentage, uint256 saleAmount)
        public
    {
        address defaultRecipient = makeAddr("account");
        mockContract = new MockERC2981TLUpgradeable();
        mockContract.initialize(defaultRecipient, 1_000);
        uint256 maxRoyalty = mockContract.MAX_ROYALTY();
        if (recipient == address(0)) {
            vm.expectRevert(ERC2981TLUpgradeable.ZeroAddressError.selector);
        } else if (percentage > maxRoyalty) {
            vm.expectRevert(ERC2981TLUpgradeable.MaxRoyaltyError.selector);
        } else {
            vm.expectEmit(true, true, true, true);
            emit DefaultRoyaltyUpdate(address(this), recipient, percentage);
        }
        mockContract.setDefaultRoyalty(recipient, uint256(percentage));
        if (recipient != address(0) && percentage <= maxRoyalty) {
            if (saleAmount > 3_000_000 ether) {
                saleAmount = saleAmount % 3_000_000 ether;
            }
            uint256 expectedAmount = saleAmount * percentage / 10_000;
            (address returnedRecipient, uint256 amount) = mockContract.royaltyInfo(tokenId, saleAmount);
            assertEq(recipient, returnedRecipient);
            assertEq(amount, expectedAmount);
        }
    }

    function test_OverrideTokenRoyaltyInfo(uint256 tokenId, address recipient, uint16 percentage, uint256 saleAmount)
        public
    {
        address defaultRecipient = makeAddr("account");
        mockContract = new MockERC2981TLUpgradeable();
        mockContract.initialize(defaultRecipient, 1_000);
        uint256 maxRoyalty = mockContract.MAX_ROYALTY();
        if (recipient == address(0)) {
            vm.expectRevert(ERC2981TLUpgradeable.ZeroAddressError.selector);
        } else if (percentage > maxRoyalty) {
            vm.expectRevert(ERC2981TLUpgradeable.MaxRoyaltyError.selector);
        } else {
            vm.expectEmit(true, true, true, true);
            emit TokenRoyaltyOverride(address(this), tokenId, recipient, percentage);
        }
        mockContract.setTokenRoyalty(tokenId, recipient, uint256(percentage));
        if (recipient != address(0) && percentage <= maxRoyalty) {
            if (saleAmount > 3_000_000 ether) {
                saleAmount = saleAmount % 3_000_000 ether;
            }
            uint256 expectedAmount = saleAmount * percentage / 10_000;
            (address returnedRecipient, uint256 amount) = mockContract.royaltyInfo(tokenId, saleAmount);
            assertEq(recipient, returnedRecipient);
            assertEq(amount, expectedAmount);
        }
    }

    function test_setDefaultRoyalty_zeroAddress_reverts() public {
        address defaultRecipient = makeAddr("account");
        mockContract = new MockERC2981TLUpgradeable();
        mockContract.initialize(defaultRecipient, 1_000);

        vm.expectRevert(ERC2981TLUpgradeable.ZeroAddressError.selector);
        mockContract.setDefaultRoyalty(address(0), 1_000);
    }

    function test_setTokenRoyalty_zeroAddress_reverts(uint256 tokenId) public {
        address defaultRecipient = makeAddr("account");
        mockContract = new MockERC2981TLUpgradeable();
        mockContract.initialize(defaultRecipient, 1_000);

        vm.expectRevert(ERC2981TLUpgradeable.ZeroAddressError.selector);
        mockContract.setTokenRoyalty(tokenId, address(0), 1_000);
    }

    function test_MAX_ROYALTY_boundary_initialize() public {
        address recipient = makeAddr("recipient");
        mockContract = new MockERC2981TLUpgradeable();

        uint256 maxRoyalty = mockContract.MAX_ROYALTY();
        mockContract.initialize(recipient, maxRoyalty);

        (address returnedRecipient, uint256 returnedPercentage) = mockContract.getDefaultRoyaltyRecipientAndPercentage();
        assertEq(returnedRecipient, recipient);
        assertEq(returnedPercentage, maxRoyalty);
    }

    function test_MAX_ROYALTY_plus_one_initialize_reverts() public {
        mockContract = new MockERC2981TLUpgradeable();
        address recipient = makeAddr("recipient");
        uint256 invalidRoyalty = mockContract.MAX_ROYALTY() + 1;

        vm.expectRevert(ERC2981TLUpgradeable.MaxRoyaltyError.selector);
        mockContract.initialize(recipient, invalidRoyalty);
    }

    function test_MAX_ROYALTY_boundary_setDefaultRoyalty() public {
        address recipient = makeAddr("recipient");
        mockContract = new MockERC2981TLUpgradeable();
        mockContract.initialize(makeAddr("defaultRecipient"), 0);

        uint256 maxRoyalty = mockContract.MAX_ROYALTY();
        mockContract.setDefaultRoyalty(recipient, maxRoyalty);

        (address returnedRecipient, uint256 returnedPercentage) = mockContract.getDefaultRoyaltyRecipientAndPercentage();
        assertEq(returnedRecipient, recipient);
        assertEq(returnedPercentage, maxRoyalty);
    }

    function test_MAX_ROYALTY_plus_one_setDefaultRoyalty_reverts() public {
        mockContract = new MockERC2981TLUpgradeable();
        mockContract.initialize(makeAddr("defaultRecipient"), 0);
        address recipient = makeAddr("recipient");
        uint256 invalidRoyalty = mockContract.MAX_ROYALTY() + 1;

        vm.expectRevert(ERC2981TLUpgradeable.MaxRoyaltyError.selector);
        mockContract.setDefaultRoyalty(recipient, invalidRoyalty);
    }

    function test_MAX_ROYALTY_boundary_setTokenRoyalty(uint256 tokenId, uint256 saleAmount) public {
        address defaultRecipient = makeAddr("defaultRecipient");
        address tokenRecipient = makeAddr("tokenRecipient");
        mockContract = new MockERC2981TLUpgradeable();
        mockContract.initialize(defaultRecipient, 0);

        if (saleAmount > 3_000_000 ether) {
            saleAmount = saleAmount % 3_000_000 ether;
        }

        uint256 maxRoyalty = mockContract.MAX_ROYALTY();
        mockContract.setTokenRoyalty(tokenId, tokenRecipient, maxRoyalty);

        (address returnedRecipient, uint256 amount) = mockContract.royaltyInfo(tokenId, saleAmount);
        assertEq(returnedRecipient, tokenRecipient);
        assertEq(amount, saleAmount * maxRoyalty / mockContract.BASIS());
    }

    function test_MAX_ROYALTY_plus_one_setTokenRoyalty_reverts(uint256 tokenId) public {
        mockContract = new MockERC2981TLUpgradeable();
        mockContract.initialize(makeAddr("defaultRecipient"), 0);
        address tokenRecipient = makeAddr("tokenRecipient");
        uint256 invalidRoyalty = mockContract.MAX_ROYALTY() + 1;

        vm.expectRevert(ERC2981TLUpgradeable.MaxRoyaltyError.selector);
        mockContract.setTokenRoyalty(tokenId, tokenRecipient, invalidRoyalty);
    }
}

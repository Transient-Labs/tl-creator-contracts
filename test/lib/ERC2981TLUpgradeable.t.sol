// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std-1.9.4/Test.sol";
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

    function test_DefaultRoyaltyInfo(uint256 tokenId, address recipient, uint16 percentage, uint256 saleAmount)
        public
    {
        mockContract = new MockERC2981TLUpgradeable();
        if (recipient == address(0)) {
            vm.expectRevert(ERC2981TLUpgradeable.ZeroAddressError.selector);
        } else if (percentage > 10_000) {
            vm.expectRevert(ERC2981TLUpgradeable.MaxRoyaltyError.selector);
        } else {
            vm.expectEmit(true, true, true, true);
            emit DefaultRoyaltyUpdate(address(this), recipient, percentage);
        }
        mockContract.initialize(recipient, uint256(percentage));
        if (recipient != address(0) && percentage <= 10_000) {
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
        if (recipient != address(0) && percentage <= 10_000) {
            mockContract = new MockERC2981TLUpgradeable();
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
        mockContract.initialize(defaultRecipient, 10_000);
        if (recipient == address(0)) {
            vm.expectRevert(ERC2981TLUpgradeable.ZeroAddressError.selector);
        } else if (percentage > 10_000) {
            vm.expectRevert(ERC2981TLUpgradeable.MaxRoyaltyError.selector);
        } else {
            vm.expectEmit(true, true, true, true);
            emit DefaultRoyaltyUpdate(address(this), recipient, percentage);
        }
        mockContract.setDefaultRoyalty(recipient, uint256(percentage));
        if (recipient != address(0) && percentage <= 10_000) {
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
        mockContract.initialize(defaultRecipient, 10_000);
        if (recipient == address(0)) {
            vm.expectRevert(ERC2981TLUpgradeable.ZeroAddressError.selector);
        } else if (percentage > 10_000) {
            vm.expectRevert(ERC2981TLUpgradeable.MaxRoyaltyError.selector);
        } else {
            vm.expectEmit(true, true, true, true);
            emit TokenRoyaltyOverride(address(this), tokenId, recipient, percentage);
        }
        mockContract.setTokenRoyalty(tokenId, recipient, uint256(percentage));
        if (recipient != address(0) && percentage <= 10_000) {
            if (saleAmount > 3_000_000 ether) {
                saleAmount = saleAmount % 3_000_000 ether;
            }
            uint256 expectedAmount = saleAmount * percentage / 10_000;
            (address returnedRecipient, uint256 amount) = mockContract.royaltyInfo(tokenId, saleAmount);
            assertEq(recipient, returnedRecipient);
            assertEq(amount, expectedAmount);
        }
    }
}

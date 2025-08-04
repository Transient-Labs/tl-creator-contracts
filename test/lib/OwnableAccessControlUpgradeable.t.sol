// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std-1.9.4/Test.sol";
import {MockOwnableAccessControlUpgradeable} from "test/utils/MockOwnableAccessControlUpgradeable.sol";
import {OwnableAccessControlUpgradeable, OwnableUpgradeable} from "src/lib/OwnableAccessControlUpgradeable.sol";

contract OwnableAccessControlTest is Test {
    MockOwnableAccessControlUpgradeable public mockContract;

    event RoleChange(address indexed from, address indexed user, bool indexed approved, bytes32 role);
    event AllRolesRevoked(address indexed from);

    function test_Initialization(address owner) public {
        vm.assume(owner != address(0));

        mockContract = new MockOwnableAccessControlUpgradeable();
        mockContract.initialize(address(this));
        mockContract = new MockOwnableAccessControlUpgradeable();
        mockContract.initialize(owner);
        assertEq(mockContract.owner(), owner);
    }

    function test_InitialValues() public {
        mockContract = new MockOwnableAccessControlUpgradeable();
        mockContract.initialize(address(this));
        // expect default owner and number
        assertEq(mockContract.owner(), address(this));
        assertEq(mockContract.number(), 0);
    }

    function test_OwnerRole() public {
        mockContract = new MockOwnableAccessControlUpgradeable();
        mockContract.initialize(address(this));
        // expect owner can change the number
        mockContract.onlyOwnerFunction(1);
        assertEq(mockContract.number(), 1);
        mockContract.onlyAdminOrOwnerFunction(2);
        assertEq(mockContract.number(), 2);

        address[] memory admins = new address[](2);
        admins[0] = address(1);
        admins[1] = address(2);

        address[] memory minters = new address[](2);
        minters[0] = address(3);
        minters[1] = address(4);

        // expect owner can set admin and minter roles
        vm.expectEmit(true, true, true, true);
        emit RoleChange(address(this), address(1), true, mockContract.ADMIN_ROLE());
        emit RoleChange(address(this), address(2), true, mockContract.ADMIN_ROLE());
        mockContract.setRole(mockContract.ADMIN_ROLE(), admins, true);
        assertEq(mockContract.getRoleMembers(mockContract.ADMIN_ROLE()), admins);

        vm.expectEmit(true, true, true, true);
        emit RoleChange(address(this), address(3), true, mockContract.MINTER_ROLE());
        emit RoleChange(address(this), address(4), true, mockContract.MINTER_ROLE());
        mockContract.setRole(mockContract.MINTER_ROLE(), minters, true);
        assertEq(mockContract.getRoleMembers(mockContract.MINTER_ROLE()), minters);

        vm.expectEmit(true, true, true, true);
        emit RoleChange(address(this), address(5), true, mockContract.MINTER_ROLE());
        mockContract.setMinterRole(address(5));

        // expect owner can revoke all roles
        vm.expectEmit(true, false, false, false);
        emit AllRolesRevoked(address(this));
        mockContract.revokeAllRoles();

        // expect reverts on other access controlled functions
        vm.expectRevert(
            abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotSpecifiedRole.selector, mockContract.ADMIN_ROLE())
        );
        mockContract.onlyAdminFunction(3);

        vm.expectRevert(
            abi.encodeWithSelector(
                OwnableAccessControlUpgradeable.NotSpecifiedRole.selector, mockContract.MINTER_ROLE()
            )
        );
        mockContract.onlyMinterFunction(3);
    }

    function test_AdminRole(address admin, address minter, uint256 newNumberOne, uint256 newNumberTwo) public {
        vm.assume(admin != address(this));

        mockContract = new MockOwnableAccessControlUpgradeable();
        mockContract.initialize(address(this));
        address[] memory admins = new address[](1);
        admins[0] = admin;

        // set admin
        vm.expectEmit(true, true, true, true);
        emit RoleChange(address(this), admin, true, mockContract.ADMIN_ROLE());
        mockContract.setRole(mockContract.ADMIN_ROLE(), admins, true);
        assertTrue(mockContract.hasRole(mockContract.ADMIN_ROLE(), admin));

        vm.startPrank(admin, admin);
        // set minter role
        vm.expectEmit(true, true, true, true);
        emit RoleChange(admin, minter, true, mockContract.MINTER_ROLE());
        mockContract.setMinterRole(minter);

        // set numbers
        mockContract.onlyAdminFunction(newNumberOne);
        assertEq(mockContract.number(), newNumberOne);
        mockContract.onlyAdminOrOwnerFunction(newNumberTwo);
        assertEq(mockContract.number(), newNumberTwo);

        // expect reverts on other role locked functions
        if (admin != address(this)) {
            vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, admin));
            mockContract.onlyOwnerFunction(newNumberOne);
        }

        if (admin != minter) {
            vm.expectRevert(
                abi.encodeWithSelector(
                    OwnableAccessControlUpgradeable.NotSpecifiedRole.selector, mockContract.MINTER_ROLE()
                )
            );
            mockContract.onlyMinterFunction(newNumberOne);
        }

        // expect can't revoke all roles
        if (admin != address(this)) {
            vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, admin));
            mockContract.revokeAllRoles();
        }

        vm.stopPrank();

        // revoke admin functionality
        vm.expectEmit(true, true, true, true);
        emit RoleChange(address(this), admin, false, mockContract.ADMIN_ROLE());
        mockContract.setRole(mockContract.ADMIN_ROLE(), admins, false);

        // check reverts happen for all functions
        vm.startPrank(admin, admin);
        vm.expectRevert(
            abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, mockContract.ADMIN_ROLE())
        );
        mockContract.setMinterRole(minter);

        vm.expectRevert(
            abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotSpecifiedRole.selector, mockContract.ADMIN_ROLE())
        );
        mockContract.onlyAdminFunction(newNumberOne);

        vm.expectRevert(
            abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, mockContract.ADMIN_ROLE())
        );
        mockContract.onlyAdminOrOwnerFunction(newNumberTwo);

        if (admin != address(this)) {
            vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, admin));
            mockContract.onlyOwnerFunction(newNumberOne);
        }

        if (admin != minter) {
            vm.expectRevert(
                abi.encodeWithSelector(
                    OwnableAccessControlUpgradeable.NotSpecifiedRole.selector, mockContract.MINTER_ROLE()
                )
            );
            mockContract.onlyMinterFunction(newNumberOne);
        }

        // expect can't revoke all roles
        if (admin != address(this)) {
            vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, admin));
            mockContract.revokeAllRoles();
        }

        vm.stopPrank();

        // expect admin to renounce role
        mockContract.setRole(mockContract.ADMIN_ROLE(), admins, true);
        vm.startPrank(admin, admin);
        vm.expectEmit(true, true, true, true);
        emit RoleChange(admin, admin, false, mockContract.ADMIN_ROLE());
        mockContract.renounceRole(mockContract.ADMIN_ROLE());
        assertFalse(mockContract.hasRole(mockContract.ADMIN_ROLE(), admin));
        vm.stopPrank();
    }

    function test_MinterRole(address minter, uint256 newNumber) public {
        vm.assume(minter != address(this));

        mockContract = new MockOwnableAccessControlUpgradeable();
        mockContract.initialize(address(this));
        // grant minter role and expect proper event log
        address[] memory minters = new address[](1);
        minters[0] = minter;

        vm.expectEmit(true, true, true, true);
        emit RoleChange(address(this), minter, true, mockContract.MINTER_ROLE());
        mockContract.setRole(mockContract.MINTER_ROLE(), minters, true);
        assertEq(mockContract.getRoleMembers(mockContract.MINTER_ROLE()), minters);

        vm.startPrank(minter, minter);
        // expect able to set new number with `onlyMinterFunction`
        mockContract.onlyMinterFunction(newNumber);
        assertEq(mockContract.number(), newNumber);

        // expect reverts on all other functions
        vm.expectRevert(
            abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, mockContract.ADMIN_ROLE())
        );
        mockContract.setMinterRole(minter);

        vm.expectRevert(
            abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotSpecifiedRole.selector, mockContract.ADMIN_ROLE())
        );
        mockContract.onlyAdminFunction(newNumber);

        vm.expectRevert(
            abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, mockContract.ADMIN_ROLE())
        );
        mockContract.onlyAdminOrOwnerFunction(newNumber);

        if (minter != address(this)) {
            vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, minter));
            mockContract.onlyOwnerFunction(newNumber);
        }

        // expect can't revoke all roles
        if (minter != address(this)) {
            vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, minter));
            mockContract.revokeAllRoles();
        }

        vm.stopPrank();

        // revoke minter role and expect proper event log
        vm.expectEmit(true, true, true, true);
        emit RoleChange(address(this), minter, false, mockContract.MINTER_ROLE());
        mockContract.setRole(mockContract.MINTER_ROLE(), minters, false);
        assertFalse(mockContract.hasRole(mockContract.MINTER_ROLE(), minter));

        // expect reverts on all functions
        vm.startPrank(minter, minter);

        vm.expectRevert(
            abi.encodeWithSelector(
                OwnableAccessControlUpgradeable.NotSpecifiedRole.selector, mockContract.MINTER_ROLE()
            )
        );
        mockContract.onlyMinterFunction(newNumber);

        vm.expectRevert(
            abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, mockContract.ADMIN_ROLE())
        );
        mockContract.setMinterRole(minter);

        vm.expectRevert(
            abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotSpecifiedRole.selector, mockContract.ADMIN_ROLE())
        );
        mockContract.onlyAdminFunction(newNumber);

        vm.expectRevert(
            abi.encodeWithSelector(OwnableAccessControlUpgradeable.NotRoleOrOwner.selector, mockContract.ADMIN_ROLE())
        );
        mockContract.onlyAdminOrOwnerFunction(newNumber);

        if (minter != address(this)) {
            vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, minter));
            mockContract.onlyOwnerFunction(newNumber);
        }

        // expect can't revoke all roles
        if (minter != address(this)) {
            vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, minter));
            mockContract.revokeAllRoles();
        }

        vm.stopPrank();

        // expect minter able to renounce role
        mockContract.setRole(mockContract.MINTER_ROLE(), minters, true);
        vm.startPrank(minter, minter);
        vm.expectEmit(true, true, true, true);
        emit RoleChange(minter, minter, false, mockContract.MINTER_ROLE());
        mockContract.renounceRole(mockContract.MINTER_ROLE());
        assertFalse(mockContract.hasRole(mockContract.MINTER_ROLE(), minter));
        vm.stopPrank();
    }
}

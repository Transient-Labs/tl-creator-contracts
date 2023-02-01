// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import {Strings} from "openzeppelin/utils/Strings.sol";
import {ERC721TL} from "../src/ERC721TL.sol";
import {ERC1155TL} from "../src/ERC1155TL.sol";
import {TLCoreContractsFactory} from "../src/TLCoreContractsFactory.sol";

contract TLCoreContractsFactoryUnitTest is Test {
    using Strings for uint256;

    TLCoreContractsFactory public factory;
    ERC721TL public erc721;
    ERC1155TL public erc1155;

    event ERC721TLCreated(address indexed creator, address indexed implementation, address indexed contractAddress);
    event ERC1155TLCreated(address indexed creator, address indexed implementation, address indexed contractAddress);

    function setUp() public {
        erc721 = new ERC721TL();
        erc1155 = new ERC1155TL();
        factory = new TLCoreContractsFactory(address(erc721), address(erc1155));
    }

    /// @notice initialization tests
    function testInitialization() public {
        assertEq(factory.ERC721TLImplementation(), address(erc721));
        assertEq(factory.ERC1155TLImplementation(), address(erc1155));
        assertEq(factory.owner(), address(this));
    }

    /// @notice test access control
    function testAccessControl(address user, address implementation) public {
        vm.assume(user != address(this));
        vm.assume(user != address(0));

        // user can't access setters
        vm.startPrank(user, user);
        vm.expectRevert(abi.encodePacked("Ownable: caller is not the owner"));
        factory.setERC721TLImplementation(implementation);
        vm.expectRevert(abi.encodePacked("Ownable: caller is not the owner"));
        factory.setERC1155TLImplementation(implementation);
        vm.stopPrank();

        // owner can access
        factory.setERC721TLImplementation(implementation);
        assertEq(factory.ERC721TLImplementation(), implementation);
        factory.setERC1155TLImplementation(implementation);
        assertEq(factory.ERC1155TLImplementation(), implementation);
    }

    /// @notice test creating erc721 contracts
    function testCreateERC721(address user, string memory name, string memory symbol, address royaltyRecipient, uint16 royaltyPercentage, uint16 numAdmins, bool enableStory, address blocklistRegistry) public {
        vm.assume(user != address(0));
        vm.assume(bytes(name).length > 0);
        vm.assume(bytes(symbol).length > 0);
        vm.assume(royaltyRecipient != address(0));
        if (royaltyPercentage >= 10000) {
            royaltyPercentage = royaltyPercentage % 10000;
        }
        if (numAdmins > 10) {
            numAdmins = numAdmins % 10;
        }
        address[] memory admins = new address[](numAdmins);
        for (uint256 i = 0; i < numAdmins; i++) {
            admins[i] = makeAddr(i.toString());
        }

        vm.startPrank(user, user);
        ERC721TL c = ERC721TL(factory.createERC721TL(name, symbol, royaltyRecipient, royaltyPercentage, admins, enableStory, blocklistRegistry));
        vm.stopPrank();
        assertEq(c.name(), name);
        assertEq(c.symbol(), symbol);
        assertEq(c.getRoleMembers(c.ADMIN_ROLE()), admins);
        assertEq(c.storyEnabled(), enableStory);
        assertEq(address(c.blockListRegistry()), blocklistRegistry);
        (address recp, uint256 amt) = c.royaltyInfo(1, 10_000);
        assertEq(recp, royaltyRecipient);
        assertEq(amt, royaltyPercentage);
    }

    /// @notice test creating erc1155 contracts
    function testCreateERC1155(address user, string memory name, address royaltyRecipient, uint16 royaltyPercentage, uint16 numAdmins, bool enableStory, address blocklistRegistry) public {
        vm.assume(user != address(0));
        vm.assume(bytes(name).length > 0);
        vm.assume(royaltyRecipient != address(0));
        if (royaltyPercentage >= 10000) {
            royaltyPercentage = royaltyPercentage % 10000;
        }
        if (numAdmins > 10) {
            numAdmins = numAdmins % 10;
        }
        address[] memory admins = new address[](numAdmins);
        for (uint256 i = 0; i < numAdmins; i++) {
            admins[i] = makeAddr(i.toString());
        }

        vm.startPrank(user, user);
        ERC1155TL c = ERC1155TL(factory.createERC1155TL(name, royaltyRecipient, royaltyPercentage, admins, enableStory, blocklistRegistry));
        vm.stopPrank();
        assertEq(c.name(), name);
        assertEq(c.getRoleMembers(c.ADMIN_ROLE()), admins);
        assertEq(c.storyEnabled(), enableStory);
        assertEq(address(c.blockListRegistry()), blocklistRegistry);
        (address recp, uint256 amt) = c.royaltyInfo(1, 10_000);
        assertEq(recp, royaltyRecipient);
        assertEq(amt, royaltyPercentage);
    }
}
// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {TLCreatorContractFactory} from "../src/TLCreatorContractFactory.sol";
import {ERC721TL} from "../src/core/ERC721TL.sol";
import {ERC1155TL} from "../src/core/ERC1155TL.sol";

contract TLCreatorContractFactoryTest is Test {

    event ContractTypeAdded(uint256 indexed contractId, address indexed firstImplementation, string name);
    event ImplementationAdded(uint256 indexed contractId, address indexed implementation);
    event ContractDeployed(address indexed contractAddress, address indexed implementationAddress, address indexed sender);

    address ERC721TLImplementation;
    address ERC1155TLImplementation;

    TLCreatorContractFactory factory;

    function setUp() public {
        ERC721TLImplementation = address(new ERC721TL(true));
        ERC1155TLImplementation = address(new ERC1155TL(true));
        factory = new TLCreatorContractFactory();
    }

    function testSetUp() public view {
        assert(factory.owner() == address(this));
    }

    function testAccessControl(address hacker) public {
        vm.assume(hacker != address(this));

        vm.startPrank(hacker);
        vm.expectRevert("Ownable: caller is not the owner");
        factory.transferOwnership(hacker);
        vm.expectRevert("Ownable: caller is not the owner");
        factory.addContractType("ERC721TL", ERC721TLImplementation);
        vm.expectRevert("Ownable: caller is not the owner");
        factory.addContractImplementation(0, ERC721TLImplementation);
        vm.stopPrank();
    }

    function testEmptyContractTypes() public {
        TLCreatorContractFactory.ContractType[] memory contractTypes = factory.getContractTypes();
        assert(contractTypes.length == 0);

        vm.expectRevert();
        factory.getContractType(0);
    }

    function testRevertInvalidContractId() public {
        vm.expectRevert();
        factory.deployLatestImplementation(0, "test", "test", address(1), 100, address(this), new address[](0), false, address(0));

        vm.expectRevert();
        factory.deployImplementation(0, 0, "test", "test", address(1), 100, address(this), new address[](0), false, address(0));
    }

    function testAddContractTypesAndImplementations() public {

        vm.expectEmit(true, true, false, true);
        emit ContractTypeAdded(0, ERC721TLImplementation, "ERC721TL");
        factory.addContractType("ERC721TL", ERC721TLImplementation);

        TLCreatorContractFactory.ContractType[] memory contractTypes = factory.getContractTypes();
        assert(contractTypes.length == 1);

        TLCreatorContractFactory.ContractType memory contractType = factory.getContractType(0);
        assert(keccak256(bytes(contractType.name)) == keccak256("ERC721TL"));
        assert(contractType.implementations.length == 1);
        assert(contractType.implementations[0] == ERC721TLImplementation);

        vm.expectEmit(true, true, false, true);
        emit ContractTypeAdded(1, ERC1155TLImplementation, "ERC1155TL");
        factory.addContractType("ERC1155TL", ERC1155TLImplementation);

        contractTypes = factory.getContractTypes();
        assert(contractTypes.length == 2);

        contractType = factory.getContractType(1);
        assert(keccak256(bytes(contractType.name)) == keccak256("ERC1155TL"));
        assert(contractType.implementations.length == 1);
        assert(contractType.implementations[0] == ERC1155TLImplementation);
        
        address implementation = address(new ERC721TL(true));
        vm.expectEmit(true, true, false, false);
        emit ImplementationAdded(0, implementation);
        factory.addContractImplementation(0, implementation);

        contractTypes = factory.getContractTypes();
        assert(contractTypes.length == 2);

        contractType = factory.getContractType(0);
        assert(keccak256(bytes(contractType.name)) == keccak256("ERC721TL"));
        assert(contractType.implementations.length == 2);
        assert(contractType.implementations[1] == implementation);

        implementation = address(new ERC1155TL(true));
        vm.expectEmit(true, true, false, false);
        emit ImplementationAdded(1, implementation);
        factory.addContractImplementation(1, implementation);

        contractTypes = factory.getContractTypes();
        assert(contractTypes.length == 2);

        contractType = factory.getContractType(1);
        assert(keccak256(bytes(contractType.name)) == keccak256("ERC1155TL"));
        assert(contractType.implementations.length == 2);
        assert(contractType.implementations[1] == implementation);
    }

    function testDeployLatestImplementation(
        address sender,
        uint256 contractId,
        string memory contractName,
        string memory contractSymbol,
        address defaultRoyaltyRecipient,
        uint256 defaultRoyaltyPercentage,
        address initOwner,
        bool enableStory,
        address blockListRegistry
    ) public {
        vm.assume(defaultRoyaltyRecipient != address(0));
        vm.assume(initOwner != address(0));
        if (contractId > 1) contractId = contractId % 2;
        if (defaultRoyaltyPercentage > 10_000) defaultRoyaltyPercentage = defaultRoyaltyPercentage % 10_000;

        factory.addContractType("ERC721TL", ERC721TLImplementation);
        factory.addContractType("ERC1155TL", ERC1155TLImplementation);

        vm.startPrank(sender);

        vm.expectEmit(false, true, true, false);
        if (contractId == 0) {
            emit ContractDeployed(address(0), ERC721TLImplementation, sender);
        } else {
            emit ContractDeployed(address(0), ERC1155TLImplementation, sender);
        }
        address deployedAddress = factory.deployLatestImplementation(
            contractId,
            contractName,
            contractSymbol,
            defaultRoyaltyRecipient,
            defaultRoyaltyPercentage, 
            initOwner,
            new address[](0),
            enableStory,
            blockListRegistry
        );

        ERC721TL nft = ERC721TL(deployedAddress);

        assert(keccak256(bytes(nft.name())) == keccak256(bytes(contractName)));
        assert(keccak256(bytes(nft.symbol())) == keccak256(bytes(contractSymbol)));
        address recipient;
        uint256 percentage;
        (recipient, percentage) = nft.royaltyInfo(1, 10_000);
        assert(recipient == defaultRoyaltyRecipient);
        assert(percentage == defaultRoyaltyPercentage);
        assert(nft.owner() == initOwner);
        assert(nft.storyEnabled() == enableStory);
        assert(address(nft.blockListRegistry()) == blockListRegistry);

        vm.stopPrank();
    }

    function testDeployImplementation(
        address sender,
        uint256 contractId,
        uint256 implementationId,
        string memory contractName,
        string memory contractSymbol,
        address defaultRoyaltyRecipient,
        uint256 defaultRoyaltyPercentage,
        address initOwner,
        bool enableStory,
        address blockListRegistry
    ) public {
        vm.assume(defaultRoyaltyRecipient != address(0));
        vm.assume(initOwner != address(0));
        if (contractId > 1) contractId = contractId % 2;
        if (implementationId > 1) implementationId = implementationId % 2;
        if (defaultRoyaltyPercentage > 10_000) defaultRoyaltyPercentage = defaultRoyaltyPercentage % 10_000;

        factory.addContractType("ERC721TL", ERC721TLImplementation);
        factory.addContractType("ERC1155TL", ERC1155TLImplementation);
        address implementation1 = address(new ERC721TL(true));
        factory.addContractImplementation(0, implementation1);
        address implementation2 = address(new ERC1155TL(true));
        factory.addContractImplementation(1, implementation2);

        vm.startPrank(sender);

        vm.expectEmit(false, true, true, false);
        if (contractId == 0) {
            if (implementationId == 0) {
                emit ContractDeployed(address(0), ERC721TLImplementation, sender);
            } else {
                emit ContractDeployed(address(0), implementation1, sender);
            }
        } else {
            if (implementationId == 0) {
                emit ContractDeployed(address(0), ERC1155TLImplementation, sender);
            } else {
                emit ContractDeployed(address(0), implementation2, sender);
            }
        }
        address deployedAddress = factory.deployImplementation(
            contractId,
            implementationId,
            contractName,
            contractSymbol,
            defaultRoyaltyRecipient,
            defaultRoyaltyPercentage, 
            initOwner,
            new address[](0),
            enableStory,
            blockListRegistry
        );

        ERC721TL nft = ERC721TL(deployedAddress);

        assert(keccak256(bytes(nft.name())) == keccak256(bytes(contractName)));
        assert(keccak256(bytes(nft.symbol())) == keccak256(bytes(contractSymbol)));
        address recipient;
        uint256 percentage;
        (recipient, percentage) = nft.royaltyInfo(1, 10_000);
        assert(recipient == defaultRoyaltyRecipient);
        assert(percentage == defaultRoyaltyPercentage);
        assert(nft.owner() == initOwner);
        assert(nft.storyEnabled() == enableStory);
        assert(address(nft.blockListRegistry()) == blockListRegistry);

        vm.stopPrank();
    }

}
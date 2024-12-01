// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import "forge-std-1.9.4/Script.sol";
import {Strings} from "@openzeppelin-contracts-5.0.2/utils/Strings.sol";

interface ICreate2Deployer {
    function deploy(uint256 value, bytes32 salt, bytes memory code) external;
    function computeAddress(bytes32 salt, bytes32 codeHash) external view returns (address);
}

contract DeployERC721TL is Script {
    using Strings for address;

    function run() public {
        // get environment variables
        ICreate2Deployer create2Deployer = ICreate2Deployer(vm.envAddress("CREATE2_DEPLOYER"));
        bytes memory constructorArgs = vm.envBytes("CONSTRUCTOR_ARGS");
        bytes32 salt = vm.envBytes32("SALT");

        // get bytecode
        bytes memory bytecode = abi.encodePacked(vm.getCode("ERC721TL.sol:ERC721TL"), constructorArgs);

        // deploy
        address deployedContract = create2Deployer.computeAddress(salt, keccak256(bytecode));
        console.logAddress(deployedContract);
        vm.broadcast();
        create2Deployer.deploy(0, salt, bytecode);

        // save deployed contract address
        vm.writeLine("out.txt", deployedContract.toHexString());
    }
}

contract DeployERC721TLMutable is Script {
    using Strings for address;

    function run() public {
        // get environment variables
        ICreate2Deployer create2Deployer = ICreate2Deployer(vm.envAddress("CREATE2_DEPLOYER"));
        bytes memory constructorArgs = vm.envBytes("CONSTRUCTOR_ARGS");
        bytes32 salt = vm.envBytes32("SALT");

        // get bytecode
        bytes memory bytecode = abi.encodePacked(vm.getCode("ERC721TLMutable.sol:ERC721TLMutable"), constructorArgs);

        // deploy
        address deployedContract = create2Deployer.computeAddress(salt, keccak256(bytecode));
        console.logAddress(deployedContract);
        vm.broadcast();
        create2Deployer.deploy(0, salt, bytecode);

        // save deployed contract address
        vm.writeLine("out.txt", deployedContract.toHexString());
    }
}

contract DeployERC1155TL is Script {
    using Strings for address;

    function run() public {
        // get environment variables
        ICreate2Deployer create2Deployer = ICreate2Deployer(vm.envAddress("CREATE2_DEPLOYER"));
        bytes memory constructorArgs = vm.envBytes("CONSTRUCTOR_ARGS");
        bytes32 salt = vm.envBytes32("SALT");

        // get bytecode
        bytes memory bytecode = abi.encodePacked(vm.getCode("ERC1155TL.sol:ERC1155TL"), constructorArgs);

        // deploy
        address deployedContract = create2Deployer.computeAddress(salt, keccak256(bytecode));
        vm.broadcast();
        create2Deployer.deploy(0, salt, bytecode);

        // save deployed contract address
        vm.writeLine("out.txt", deployedContract.toHexString());
    }
}

contract DeployShatter is Script {
    using Strings for address;

    function run() public {
        // get environment variables
        ICreate2Deployer create2Deployer = ICreate2Deployer(vm.envAddress("CREATE2_DEPLOYER"));
        bytes memory constructorArgs = vm.envBytes("CONSTRUCTOR_ARGS");
        bytes32 salt = vm.envBytes32("SALT");

        // get bytecode
        bytes memory bytecode = abi.encodePacked(vm.getCode("Shatter.sol:Shatter"), constructorArgs);

        // deploy
        address deployedContract = create2Deployer.computeAddress(salt, keccak256(bytecode));
        vm.broadcast();
        create2Deployer.deploy(0, salt, bytecode);

        // save deployed contract address
        vm.writeLine("out.txt", deployedContract.toHexString());
    }
}

contract DeployERC7160TL is Script {
    using Strings for address;

    function run() public {
        // get environment variables
        ICreate2Deployer create2Deployer = ICreate2Deployer(vm.envAddress("CREATE2_DEPLOYER"));
        bytes memory constructorArgs = vm.envBytes("CONSTRUCTOR_ARGS");
        bytes32 salt = vm.envBytes32("SALT");

        // get bytecode
        bytes memory bytecode = abi.encodePacked(vm.getCode("ERC7160TL.sol:ERC7160TL"), constructorArgs);

        // deploy
        address deployedContract = create2Deployer.computeAddress(salt, keccak256(bytecode));
        vm.broadcast();
        create2Deployer.deploy(0, salt, bytecode);

        // save deployed contract address
        vm.writeLine("out.txt", deployedContract.toHexString());
    }
}

contract DeployERC7160TLEditions is Script {
    using Strings for address;

    function run() public {
        // get environment variables
        ICreate2Deployer create2Deployer = ICreate2Deployer(vm.envAddress("CREATE2_DEPLOYER"));
        bytes memory constructorArgs = vm.envBytes("CONSTRUCTOR_ARGS");
        bytes32 salt = vm.envBytes32("SALT");

        // get bytecode
        bytes memory bytecode = abi.encodePacked(vm.getCode("ERC7160TLEditions.sol:ERC7160TLEditions"), constructorArgs);

        // deploy
        address deployedContract = create2Deployer.computeAddress(salt, keccak256(bytecode));
        vm.broadcast();
        create2Deployer.deploy(0, salt, bytecode);

        // save deployed contract address
        vm.writeLine("out.txt", deployedContract.toHexString());
    }
}

contract DeployCollectorsChoice is Script {
    using Strings for address;

    function run() public {
        // get environment variables
        ICreate2Deployer create2Deployer = ICreate2Deployer(vm.envAddress("CREATE2_DEPLOYER"));
        bytes memory constructorArgs = vm.envBytes("CONSTRUCTOR_ARGS");
        bytes32 salt = vm.envBytes32("SALT");

        // get bytecode
        bytes memory bytecode = abi.encodePacked(vm.getCode("CollectorsChoice.sol:CollectorsChoice"), constructorArgs);

        // deploy
        address deployedContract = create2Deployer.computeAddress(salt, keccak256(bytecode));
        vm.broadcast();
        create2Deployer.deploy(0, salt, bytecode);

        // save deployed contract address
        vm.writeLine("out.txt", deployedContract.toHexString());
    }
}

contract DeployTRACE is Script {
    using Strings for address;

    function run() public {
        // get environment variables
        ICreate2Deployer create2Deployer = ICreate2Deployer(vm.envAddress("CREATE2_DEPLOYER"));
        bytes memory constructorArgs = vm.envBytes("CONSTRUCTOR_ARGS");
        bytes32 salt = vm.envBytes32("SALT");

        // get bytecode
        bytes memory bytecode = abi.encodePacked(vm.getCode("TRACE.sol:TRACE"), constructorArgs);

        // deploy
        address deployedContract = create2Deployer.computeAddress(salt, keccak256(bytecode));
        vm.broadcast();
        create2Deployer.deploy(0, salt, bytecode);

        // save deployed contract address
        vm.writeLine("out.txt", deployedContract.toHexString());
    }
}

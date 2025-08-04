// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std-1.9.4/Script.sol";
import {Strings} from "@openzeppelin-contracts-5.0.2/utils/Strings.sol";

interface ICreate2Deployer {
    function deploy(uint256 value, bytes32 salt, bytes memory code) external;
    function computeAddress(bytes32 salt, bytes32 codeHash) external view returns (address);
}

contract Deploy is Script {
    using Strings for address;

    function run(string memory bytecodePath, bool isTestnet) public {
        // get environment variables
        ICreate2Deployer create2Deployer = ICreate2Deployer(vm.envAddress("CREATE2_DEPLOYER"));
        bytes memory constructorArgs = vm.envBytes("CONSTRUCTOR_ARGS");
        bytes32 salt = vm.envBytes32("SALT");

        // get bytecode
        bytes memory bytecode = abi.encodePacked(vm.getCode(bytecodePath), constructorArgs);

        // create address
        vm.createSelectFork("mainnet"); // use mainnet for computing address
        address deployedContract = create2Deployer.computeAddress(salt, keccak256(bytecode));
        console.logAddress(deployedContract);

        if (isTestnet) {
            // deploy to sepolia
            vm.createSelectFork("sepolia");
            vm.broadcast();
            create2Deployer.deploy(0, salt, bytecode);

            // deploy to arbitrum sepolia
            vm.createSelectFork("arbitrum_sepolia");
            vm.broadcast();
            create2Deployer.deploy(0, salt, bytecode);

            // deploy to base sepolia
            vm.createSelectFork("base_sepolia");
            vm.broadcast();
            create2Deployer.deploy(0, salt, bytecode);

            // deploy to shape sepolia
            vm.createSelectFork("shape_sepolia");
            vm.broadcast();
            create2Deployer.deploy(0, salt, bytecode);
        } else {
            // deploy to eth
            vm.createSelectFork("mainnet");
            vm.broadcast();
            create2Deployer.deploy(0, salt, bytecode);

            // deploy to arbitrum
            vm.createSelectFork("arbitrum");
            vm.broadcast();
            create2Deployer.deploy(0, salt, bytecode);

            // deploy to base
            vm.createSelectFork("base");
            vm.broadcast();
            create2Deployer.deploy(0, salt, bytecode);

            // deploy to shape
            vm.createSelectFork("shape");
            vm.broadcast();
            create2Deployer.deploy(0, salt, bytecode);
        }

        // save deployed contract address
        vm.writeLine("out.txt", deployedContract.toHexString());
    }
}

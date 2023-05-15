// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Script.sol";

contract OnChainArtScript is Script {
	string metadataPath = "test/utils/metadata.txt";
	string metadata;

	function setUp() public {
		metadata = vm.readFile(metadataPath);
	}

	function run() public {
		
	}
}

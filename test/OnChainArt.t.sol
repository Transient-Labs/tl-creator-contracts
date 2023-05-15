// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {ERC721TL} from "tl-creator/ERC721TL.sol";
import {OnChainArtString} from "tl-creator/custom/OnChainArtString.sol";
import {OnChainArtBytes} from "tl-creator/custom/OnChainArtBytes.sol";
import {OnChainArtDeployed} from "tl-creator/custom/OnChainArtDeployed.sol";

contract OnChainArtTest is Test {
	OnChainArtString str;
	OnChainArtBytes byt;
	OnChainArtDeployed dep;
	ERC721TL public erc721;

	function setUp() public {
		erc721 = new ERC721TL(true);

		str = new OnChainArtString(
			address(erc721),
			"Test721", 
			"T721", 
			address(1), 
			1000, 
			address(this), 
			new address[](0), 
			true, 
			address(0)
		);

		byt = new OnChainArtBytes(
			address(erc721),
			"Test721", 
			"T721", 
			address(1), 
			1000, 
			address(this), 
			new address[](0), 
			true, 
			address(0)
		);

		dep = new OnChainArtDeployed(
			address(erc721),
			"Test721", 
			"T721", 
			address(1), 
			1000, 
			address(this), 
			new address[](0), 
			true, 
			address(0)
		);
	}

	function test_str_mint() public {
		string memory path = "test/utils/metadata.txt";
		string memory metadata = vm.readFile(path);

		ERC721TL(address(str)).mint(address(this), " ");
		str.create(metadata);
	}

	function test_dep_mint() public {
		string memory path = "test/utils/metadata.txt";
		string memory metadata = vm.readFile(path);

		ERC721TL(address(dep)).mint(address(this), " ");
		dep.create(1, bytes(metadata));
		emit log_named_string("uri", dep.tokenURI(1));
	}

	function test_byt_mint() public {
		string memory path = "test/utils/metadata.txt";
		string memory metadata = vm.readFile(path);

		ERC721TL(address(byt)).mint(address(this), " ");
		byt.create(1, bytes(metadata));
	}
}

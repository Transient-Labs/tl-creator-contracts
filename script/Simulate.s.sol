// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import "forge-std/Script.sol";
import {ERC7160TL} from "../src/erc-721/multi-metadata/ERC7160TL.sol";
import {ERC721TL} from "../src/erc-721/ERC721TL.sol";

contract Simulate7160AddTokenUris is Script {

    function run() public {
        // variables
        address[] memory admins = new address[](0);
        uint256 numTokens = 1_000_000;
        uint256 batchSize = 200;

        // deploy ERC7160TL contract
        ERC7160TL c = new ERC7160TL(false);
        c.initialize("Test", "TEST", "", address(1), 0, address(1), admins, true, address(0), address(0));

        // mint tokens
        for (uint256 i = 1; i <= numTokens; ++i) {
            vm.prank(address(1));
            c.mint(address(uint160(i)), "https://arweave.net/HzUUWz2uB4IxUPuLxbppi7SNbhFJrZFLVnZaVvFIGd0/0");
        }

        for (uint256 i = 0; i < numTokens / batchSize; ++i) {
            // create token id array
            uint256[] memory tokenIds = new uint256[](batchSize);
            for (uint256 j = 0; j < batchSize; ++j) {
                tokenIds[j] = j + 1 + i*batchSize;
            }

            // add token uris
            uint256 gasPrior = gasleft();
            vm.prank(address(1));
            c.addTokenUris(tokenIds, "https://arweave.net/HzUUWz2uB4IxUPuLxbppi7SNbhFJrZFLVnZaVvFIGd0");
            console.log(gasPrior - gasleft());
        }
    }
}

contract SimulateERC721TLAirdrop is Script {

    function run() public {
        // variables
        address[] memory admins = new address[](0);
        uint256 numTokens = 10_000;
        uint256 batchSize = 250;

        // deploy ERC721TL contract
        ERC721TL c = new ERC721TL(false);
        c.initialize("Test", "TEST", "", address(1), 0, address(1), admins, true, address(0), address(0));

        for (uint256 i = 0; i < numTokens / batchSize; ++i) {
            // create address array
            address[] memory addresses = new address[](batchSize);
            for (uint256 j = 0; j < batchSize; ++j) {
                addresses[j] = address(uint160(j + 1 + i*batchSize));
            }

            // add token uris
            uint256 gasPrior = gasleft();
            vm.prank(address(1));
            c.airdrop(addresses, "https://arweave.net/HzUUWz2uB4IxUPuLxbppi7SNbhFJrZFLVnZaVvFIGd0");
            console.log(gasPrior - gasleft());
        }
    }
}
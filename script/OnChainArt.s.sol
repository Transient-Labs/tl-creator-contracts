// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import {OnChainArt} from "tl-creator-contracts/onchain/OnChainArt.sol";
import {ERC721TL} from "tl-creator-contracts/core/ERC721TL.sol";

contract OnChainArtScript is Script {
    string chunkedMetadataPath = "chunks.json";
    string[] metadata;
    address payable onChainArt;

    function setUp() public {
        string memory rawMetadata = vm.readFile(chunkedMetadataPath);
        metadata = vm.parseJsonStringArray(rawMetadata, "");

        onChainArt = payable(0x08B73A944eBbAa3f9F98A7b32661D93cb669b6ba);
    }

    function run() public {
        vm.startBroadcast();

        uint256 tokenId = ERC721TL(onChainArt).totalSupply() + 1;
        ERC721TL(onChainArt).mint(msg.sender, " ");

        for (uint256 i = 0; i < metadata.length; i++) {
            OnChainArt(onChainArt).addToURI(tokenId, metadata[i]);
        }
        vm.stopBroadcast();
    }
}

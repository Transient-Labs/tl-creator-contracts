// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {ERC721TL} from "tl-creator-contracts/core/ERC721TL.sol";
import {OnChainArt} from "tl-creator-contracts/onchain/OnChainArt.sol";

contract OnChainArtTest is Test {
    OnChainArt oca;
    ERC721TL public erc721;

    function setUp() public {
        erc721 = new ERC721TL(true);

        oca = new OnChainArt(
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

    function testMint() public {
        string memory path = "test/utils/metadata.txt";
        string memory metadata = vm.readFile(path);

        ERC721TL(address(oca)).mint(address(this), " ");
        oca.addToURI(1, metadata);
    }
}

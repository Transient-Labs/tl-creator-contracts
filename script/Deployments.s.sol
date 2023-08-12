// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import {ERC721TL} from "tl-creator-contracts/core/ERC721TL.sol";
import {ERC1155TL} from "tl-creator-contracts/core/ERC1155TL.sol";
import {Shatter} from "tl-creator-contracts/shatter/Shatter.sol";
import {TLCreatorContractFactory} from "tl-creator-contracts/TLCreatorContractFactory.sol";

contract DeployERC721TL is Script {
    function run() public {
        vm.broadcast();
        new ERC721TL(true);
    }
}

contract DeployERC1155TL is Script {
    function run() public {
        vm.broadcast();
        new ERC1155TL(true);
    }
}

contract DeployShatter is Script {
    function run() public {
        vm.broadcast();
        new Shatter(true);
    }
}

contract DeployTLCreatorContractFactory is Script {
    function run() public {
        vm.broadcast();
        new TLCreatorContractFactory();
    }
}
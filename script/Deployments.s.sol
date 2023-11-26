// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import {ERC721TL} from "tl-creator-contracts/core/ERC721TL.sol";
import {ERC1155TL} from "tl-creator-contracts/core/ERC1155TL.sol";
import {Shatter} from "tl-creator-contracts/shatter/Shatter.sol";
import {ERC721TLM} from "tl-creator-contracts/multi-metadata/ERC721TLM.sol";
import {TRACE} from "tl-creator-contracts/TRACE/TRACE.sol";

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

contract DeployERC721TLM is Script {
    function run() public {
        vm.broadcast();
        new ERC721TLM(true);
    }
}

contract DeployTRACE is Script {
    function run() public {
        vm.broadcast();
        new TRACE(true);
    }
}
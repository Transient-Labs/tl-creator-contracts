// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC721} from "@openzeppelin-contracts-5.0.2/token/ERC721/ERC721.sol";

contract MockERC721 is ERC721 {
    constructor(address recipient) ERC721("Mock", "MOCK") {
        _mint(recipient, 1);
    }
}

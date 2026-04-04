// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ERC721} from "@openzeppelin-contracts-5.6.1/token/ERC721/ERC721.sol";

contract MockERC721 is ERC721 {
    constructor(address recipient) ERC721("Mock", "MOCK") {
        _mint(recipient, 1);
    }
}

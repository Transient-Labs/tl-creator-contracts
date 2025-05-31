// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {ERC20} from "@openzeppelin-contracts-5.0.2/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor(address recipient, uint256 amount) ERC20("Mock", "MOCK") {
        _mint(recipient, amount);
    }
}

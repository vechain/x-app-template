// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol';

contract Token is ERC20, Ownable, ERC20Permit {
    constructor(address initialOwner) ERC20('Token', 'TKN') Ownable(initialOwner) ERC20Permit('Token') {}

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}

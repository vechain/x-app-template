// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title B3TR_Mock
 * @dev Mock contract for the B3TR token.
 */
contract B3TR_Mock is ERC20 {
    // Mint 10,000,000 B3TR tokens to the deployer
    constructor() ERC20("B3TR", "B3TR") {
        _mint(msg.sender, 10000000 * 10 ** decimals());
    }

    // Public function to mint tokens
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

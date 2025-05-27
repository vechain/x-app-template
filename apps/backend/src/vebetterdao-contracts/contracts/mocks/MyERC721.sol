// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MyERC721 is ERC721, Ownable {
  constructor(address initialOwner) ERC721("MyToken", "MTK") Ownable(initialOwner) {}

  function safeMint(address to, uint256 tokenId) external onlyOwner {
    _safeMint(to, tokenId);
  }
}

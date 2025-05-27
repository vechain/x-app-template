// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.1) (token/ERC1155/IERC1155.sol)

pragma solidity 0.8.20;

interface IERC1155 {
  function balanceOf(address account, uint256 id) external view returns (uint256);

  function safeTransferFrom(address from, address to, uint256 id, uint256 value, bytes calldata data) external;
}

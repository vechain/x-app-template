// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IX2EarnCreator {
  // ---------------- Role Management ----------------

  /// @notice Grants a role to an account
  /// @param role The role to assign
  /// @param account The account to grant the role to
  function grantRole(bytes32 role, address account) external;

  /// @notice Revokes a role from an account
  /// @param role The role to revoke
  /// @param account The account to revoke the role from
  function revokeRole(bytes32 role, address account) external;

  /// @notice Checks if an account has a specific role
  /// @param role The role identifier
  /// @param account The account to check
  /// @return Boolean indicating if the account has the role
  function hasRole(bytes32 role, address account) external view returns (bool);

  // ---------------- Token Management ----------------

  /// @notice Mints a new token to the specified address
  /// @param to The address to receive the token
  function safeMint(address to) external;

  /// @notice Burns a specified token, removing it from circulation
  /// @param tokenId The ID of the token to burn
  function burn(uint256 tokenId) external;

  /// @notice Retrieves the token URI for a given token ID
  /// @param tokenId The ID of the token
  /// @return The URI pointing to the token's metadata
  function tokenURI(uint256 tokenId) external view returns (string memory);

  // ---------------- Pausing Management ----------------

  /// @notice Pauses all minting and burning functions
  function pause() external;

  /// @notice Unpauses minting and burning functions
  function unpause() external;

  /// @notice Returns whether the contract is paused
  /// @return Boolean indicating whether the contract is paused
  function paused() external view returns (bool);

  // ---------------- Enumeration Functions ----------------

  /// @notice Gets the total number of tokens in existence
  /// @return Total supply of tokens
  function totalSupply() external view returns (uint256);

  /// @notice Gets the token ID owned by `owner` at a specific `index`
  /// @param owner Address owning the tokens
  /// @param index Index of the token in the owner's list of tokens
  /// @return Token ID owned by `owner` at the specified `index`
  function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256);

  /// @notice Gets the token ID at a specific global `index`
  /// @param index Index of the token in the total supply
  /// @return Token ID at the specified `index`
  function tokenByIndex(uint256 index) external view returns (uint256);

  // ---------------- View Functions ----------------

  /// @notice Checks if the contract supports a specific interface
  /// @param interfaceId The interface identifier
  /// @return Boolean indicating if the interface is supported
  function supportsInterface(bytes4 interfaceId) external view returns (bool);

  /// @notice Returns the balance of tokens held by `owner`
  /// @param owner Address to query the balance of
  /// @return Balance of tokens held by `owner`
  function balanceOf(address owner) external view returns (uint256);
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

interface IB3TR {
  error AccessControlBadConfirmation();

  error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);

  error ERC20ExceededCap(uint256 increasedSupply, uint256 cap);

  error ERC20InsufficientAllowance(address spender, uint256 allowance, uint256 needed);

  error ERC20InsufficientBalance(address sender, uint256 balance, uint256 needed);

  error ERC20InvalidApprover(address approver);

  error ERC20InvalidCap(uint256 cap);

  error ERC20InvalidReceiver(address receiver);

  error ERC20InvalidSender(address sender);

  error ERC20InvalidSpender(address spender);

  error EnforcedPause();

  error ExpectedPause();

  event Approval(address indexed owner, address indexed spender, uint256 value);

  event Paused(address account);

  event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);

  event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);

  event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

  event Transfer(address indexed from, address indexed to, uint256 value);

  event Unpaused(address account);

  function DEFAULT_ADMIN_ROLE() external view returns (bytes32);

  function MINTER_ROLE() external view returns (bytes32);

  function allowance(address owner, address spender) external view returns (uint256);

  function approve(address spender, uint256 value) external returns (bool);

  function balanceOf(address account) external view returns (uint256);

  function cap() external view returns (uint256);

  function decimals() external view returns (uint8);

  function getRoleAdmin(bytes32 role) external view returns (bytes32);

  function grantRole(bytes32 role, address account) external;

  function hasRole(bytes32 role, address account) external view returns (bool);

  function mint(address to, uint256 amount) external;

  function name() external view returns (string memory);

  function pause() external;

  function paused() external view returns (bool);

  function renounceRole(bytes32 role, address callerConfirmation) external;

  function revokeRole(bytes32 role, address account) external;

  function supportsInterface(bytes4 interfaceId) external view returns (bool);

  function symbol() external view returns (string memory);

  function tokenDetails() external view returns (string memory, string memory, uint8, uint256, uint256);

  function totalSupply() external view returns (uint256);

  function transfer(address to, uint256 value) external returns (bool);

  function transferFrom(address from, address to, uint256 value) external returns (bool);

  function unpause() external;
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import "@openzeppelin/contracts/utils/structs/Checkpoints.sol";

interface IVOT3 {
  error AccessControlBadConfirmation();

  error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);

  error CheckpointUnorderedInsertion();

  error ECDSAInvalidSignature();

  error ECDSAInvalidSignatureLength(uint256 length);

  error ECDSAInvalidSignatureS(bytes32 s);

  error ERC20ExceededSafeSupply(uint256 increasedSupply, uint256 cap);

  error ERC20InsufficientAllowance(address spender, uint256 allowance, uint256 needed);

  error ERC20InsufficientBalance(address sender, uint256 balance, uint256 needed);

  error ERC20InvalidApprover(address approver);

  error ERC20InvalidReceiver(address receiver);

  error ERC20InvalidSender(address sender);

  error ERC20InvalidSpender(address spender);

  error ERC2612ExpiredSignature(uint256 deadline);

  error ERC2612InvalidSigner(address signer, address owner);

  error ERC5805FutureLookup(uint256 timepoint, uint48 clock);

  error ERC6372InconsistentClock();

  error EnforcedPause();

  error ExpectedPause();

  error InvalidAccountNonce(address account, uint256 currentNonce);

  error InvalidShortString();

  error SafeCastOverflowedUintDowncast(uint8 bits, uint256 value);

  error StringTooLong(string str);

  error VotesExpiredSignature(uint256 expiry);

  event Approval(address indexed owner, address indexed spender, uint256 value);

  event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);

  event DelegateVotesChanged(address indexed delegate, uint256 previousVotes, uint256 newVotes);

  event EIP712DomainChanged();

  event Paused(address account);

  event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);

  event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);

  event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

  event Transfer(address indexed from, address indexed to, uint256 value);

  event Unpaused(address account);

  function CLOCK_MODE() external view returns (string memory);

  function DEFAULT_ADMIN_ROLE() external view returns (bytes32);

  function DOMAIN_SEPARATOR() external view returns (bytes32);

  function allowance(address owner, address spender) external view returns (uint256);

  function approve(address spender, uint256 value) external returns (bool);

  function b3tr() external view returns (address);

  function balanceOf(address account) external view returns (uint256);

  function checkpoints(address account, uint32 pos) external view returns (Checkpoints.Checkpoint208 memory);

  function clock() external view returns (uint48);

  function decimals() external view returns (uint8);

  function delegate(address delegatee) external;

  function delegateBySig(address delegatee, uint256 nonce, uint256 expiry, uint8 v, bytes32 r, bytes32 s) external;

  function delegates(address account) external view returns (address);

  function eip712Domain()
    external
    view
    returns (
      bytes1 fields,
      string memory name,
      string memory version,
      uint256 chainId,
      address verifyingContract,
      bytes32 salt,
      uint256[] memory extensions
    );

  function getPastTotalSupply(uint256 timepoint) external view returns (uint256);

  function getPastVotes(address account, uint256 timepoint) external view returns (uint256);

  function getRoleAdmin(bytes32 role) external view returns (bytes32);

  function getVotes(address account) external view returns (uint256);

  function grantRole(bytes32 role, address account) external;

  function hasRole(bytes32 role, address account) external view returns (bool);

  function name() external view returns (string memory);

  function nonces(address owner) external view returns (uint256);

  function numCheckpoints(address account) external view returns (uint32);

  function pause() external;

  function paused() external view returns (bool);

  function permit(
    address owner,
    address spender,
    uint256 value,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external;

  function renounceRole(bytes32 role, address callerConfirmation) external;

  function revokeRole(bytes32 role, address account) external;

  function convertToVOT3(uint256 amount) external;

  function convertedB3trOf(address account) external view returns (uint256);

  function supportsInterface(bytes4 interfaceId) external view returns (bool);

  function symbol() external view returns (string memory);

  function totalSupply() external view returns (uint256);

  function transfer(address to, uint256 value) external returns (bool);

  function transferFrom(address from, address to, uint256 value) external returns (bool);

  function unpause() external;

  function convertToB3TR(uint256 amount) external;

  function getQuadraticVotingPower(address account) external view returns (uint256);

  function getPastQuadraticVotingPower(address account, uint256 timepoint) external view returns (uint256);

  function version() external view returns (string memory);
}


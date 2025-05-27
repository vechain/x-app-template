// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

/**
 * @title IVoterRewards Interface
 * @notice Interface for managing voter rewards, roles, emissions, and galaxy membership
 * @dev Handles reward distribution, vote registration, and role management for the voting system
 */
interface IVoterRewards {
  /// @notice Thrown when access control confirmation is invalid
  error AccessControlBadConfirmation();

  /// @notice Thrown when account doesn't have required role
  /// @param account The address that lacks permissions
  /// @param neededRole The required role
  error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);

  /// @notice Thrown when target address contains no code
  /// @param target The address checked for code
  error AddressEmptyCode(address target);

  /// @notice Thrown when implementation is invalid for ERC1967
  /// @param implementation The invalid implementation address
  error ERC1967InvalidImplementation(address implementation);

  /// @notice Thrown when non-payable function receives Ether
  error ERC1967NonPayable();

  /// @notice Thrown when internal call fails
  error FailedInnerCall();

  /// @notice Thrown when contract is initialized again
  error InvalidInitialization();

  /// @notice Thrown when function called outside initialization
  error NotInitializing();

  /// @notice Thrown on reentrant call
  error ReentrancyGuardReentrantCall();

  /// @notice Thrown when upgrade called from unauthorized context
  error UUPSUnauthorizedCallContext();

  /// @notice Thrown when UUID doesn't match UUPS
  /// @param slot The invalid UUID slot
  error UUPSUnsupportedProxiableUUID(bytes32 slot);

  /// @notice Emitted when contract is initialized
  /// @param version The version number
  event Initialized(uint64 version);

  /// @notice Emitted when reward is claimed
  /// @param cycle The reward cycle
  /// @param voter The voter's address
  /// @param reward The reward amount
  event RewardClaimed(uint256 indexed cycle, address indexed voter, uint256 reward);

  /// @notice Emitted when role admin is changed
  /// @param role The role being modified
  /// @param previousAdminRole The previous admin role
  /// @param newAdminRole The new admin role
  event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);

  /// @notice Emitted when role is granted
  /// @param role The role being granted
  /// @param account The account receiving the role
  /// @param sender The account granting the role
  event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);

  /// @notice Emitted when role is revoked
  /// @param role The role being revoked
  /// @param account The account losing the role
  /// @param sender The account revoking the role
  event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

  /// @notice Emitted when contract is upgraded
  /// @param implementation The new implementation address
  event Upgraded(address indexed implementation);

  /// @notice Emitted when vote is registered
  /// @param cycle The voting cycle
  /// @param voter The voter's address
  /// @param votes Number of votes cast
  /// @param rewardWeightedVote The weighted vote amount
  event VoteRegistered(uint256 indexed cycle, address indexed voter, uint256 votes, uint256 rewardWeightedVote);

  /// @notice Emitted when galaxy member address is updated
  /// @param newAddress The new galaxy member address
  /// @param oldAddress The previous galaxy member address
  event GalaxyMemberAddressUpdated(address indexed newAddress, address indexed oldAddress);

  /// @notice Emitted when emissions address is updated
  /// @param newAddress The new emissions address
  /// @param oldAddress The previous emissions address
  event EmissionsAddressUpdated(address indexed newAddress, address indexed oldAddress);

  /// @notice Emitted when level multiplier is set
  /// @param level The level being modified
  /// @param multiplier The new multiplier value
  event LevelToMultiplierSet(uint256 indexed level, uint256 multiplier);

  /// @notice Emitted when quadratic rewarding is toggled
  /// @param disabled The new disabled state
  event QuadraticRewardingDisabled(bool indexed disabled);

  /// @notice Gets the default admin role
  /// @return bytes32 The admin role identifier
  function DEFAULT_ADMIN_ROLE() external view returns (bytes32);

  /// @notice Gets the upgrader role
  /// @return bytes32 The upgrader role identifier
  function UPGRADER_ROLE() external view returns (bytes32);

  /// @notice Gets the interface version
  /// @return string The interface version
  function UPGRADE_INTERFACE_VERSION() external view returns (string memory);

  /// @notice Gets the vote registrar role
  /// @return bytes32 The vote registrar role identifier
  function VOTE_REGISTRAR_ROLE() external view returns (bytes32);

  /// @notice Gets the B3TR token address
  /// @return address The B3TR contract address
  function b3tr() external view returns (address);

  /// @notice Gets the galaxy member contract address
  /// @return address The galaxy member contract address
  function galaxyMember() external view returns (address);

  /// @notice Claims reward for a voter in a cycle
  /// @param cycle The reward cycle
  /// @param voter The voter's address
  function claimReward(uint256 cycle, address voter) external;

  /// @notice Gets total rewards for a cycle
  /// @param cycle The cycle to query
  /// @return uint256 The total rewards
  function cycleToTotal(uint256 cycle) external view returns (uint256);

  /// @notice Gets voter's total for a cycle
  /// @param cycle The cycle to query
  /// @param voter The voter's address
  /// @return uint256 The voter's total
  function cycleToVoterToTotal(uint256 cycle, address voter) external view returns (uint256);

  /// @notice Gets the emissions contract address
  /// @return address The emissions contract address
  function emissions() external view returns (address);

  /// @notice Gets reward amount for voter in cycle
  /// @param cycle The reward cycle
  /// @param voter The voter's address
  /// @return uint256 The reward amount
  function getReward(uint256 cycle, address voter) external view returns (uint256);

  /// @notice Gets admin role for a role
  /// @param role The role to query
  /// @return bytes32 The admin role
  function getRoleAdmin(bytes32 role) external view returns (bytes32);

  /// @notice Grants role to account
  /// @param role The role to grant
  /// @param account The receiving account
  function grantRole(bytes32 role, address account) external;

  /// @notice Checks if account has role
  /// @param role The role to check
  /// @param account The account to check
  /// @return bool True if account has role
  function hasRole(bytes32 role, address account) external view returns (bool);

  /// @notice Gets multiplier for level
  /// @param level The level to query
  /// @return uint256 The multiplier value
  function levelToMultiplier(uint256 level) external view returns (uint256);

  /// @notice Gets the proxiable UUID
  /// @return bytes32 The UUID
  function proxiableUUID() external view returns (bytes32);

  /// @notice Registers a vote
  /// @param proposalStart The proposal start time
  /// @param voter The voter's address
  /// @param votes Number of votes
  /// @param votePower The vote power
  function registerVote(uint256 proposalStart, address voter, uint256 votes, uint256 votePower) external;

  /// @notice Renounces role for caller
  /// @param role The role to renounce
  /// @param callerConfirmation The caller's address for confirmation
  function renounceRole(bytes32 role, address callerConfirmation) external;

  /// @notice Revokes role from account
  /// @param role The role to revoke
  /// @param account The account to revoke from
  function revokeRole(bytes32 role, address account) external;

  /// @notice Gets the scaling factor
  /// @return uint256 The scaling factor
  function scalingFactor() external view returns (uint256);

  /// @notice Sets the galaxy member address
  /// @param _galaxyMember The new galaxy member address
  function setGalaxyMember(address _galaxyMember) external;

  /// @notice Sets the emissions address
  /// @param _emissions The new emissions address
  function setEmissions(address _emissions) external;

  /// @notice Sets multiplier for level
  /// @param level The level to set
  /// @param multiplier The new multiplier value
  function setLevelToMultiplier(uint256 level, uint256 multiplier) external;

  /// @notice Sets the scaling factor
  /// @param newScalingFactor The new scaling factor
  function setScalingFactor(uint256 newScalingFactor) external;

  /// @notice Sets the vote registrar role
  /// @param _voteRegistrar The new vote registrar address
  function setXallocationVoteRegistrarRole(address _voteRegistrar) external;

  /// @notice Checks if interface is supported
  /// @param interfaceId The interface identifier
  /// @return bool True if supported
  function supportsInterface(bytes4 interfaceId) external view returns (bool);

  /// @notice Gets the contract version
  /// @return string The version string
  function version() external view returns (string memory);

  /// @notice Upgrades contract and calls function
  /// @param newImplementation The new implementation address
  /// @param data The function call data
  function upgradeToAndCall(address newImplementation, bytes memory data) external payable;

  /// @notice Checks if node has voted on proposal
  /// @param nodeId The node identifier
  /// @param proposalId The proposal identifier
  /// @return bool True if voted
  function hasNodeVoted(uint256 nodeId, uint256 proposalId) external view returns (bool);

  /// @notice Checks if token has voted on proposal
  /// @param tokenId The token identifier
  /// @param proposalId The proposal identifier
  /// @return bool True if voted
  function hasTokenVoted(uint256 tokenId, uint256 proposalId) external view returns (bool);

  /// @notice Gets multiplier for token and proposal
  /// @param tokenId The token identifier
  /// @param proposalId The proposal identifier
  /// @return uint256 The multiplier value
  function getMultiplier(uint256 tokenId, uint256 proposalId) external view returns (uint256);

  /// @notice Initializes V2 of contract
  /// @param _quadraticRewardingFlag The quadratic rewarding flag
  function initializeV2(bool _quadraticRewardingFlag) external;

  /// @notice Checks if quadratic rewarding disabled at block
  /// @param blockNumber The block number to check
  /// @return bool True if disabled
  function isQuadraticRewardingDisabledAtBlock(uint48 blockNumber) external view returns (bool);

  /// @notice Checks if quadratic rewarding disabled for current cycle
  /// @return bool True if disabled
  function isQuadraticRewardingDisabledForCurrentCycle() external view returns (bool);

  /// @notice Disables quadratic rewarding
  /// @param _disableQuadraticRewarding The disable flag
  function disableQuadraticRewarding(bool _disableQuadraticRewarding) external;
}

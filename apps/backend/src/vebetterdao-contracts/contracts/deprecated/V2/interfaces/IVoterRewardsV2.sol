// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IVoterRewardsV2 {
  error AccessControlBadConfirmation();

  error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);

  error AddressEmptyCode(address target);

  error ERC1967InvalidImplementation(address implementation);

  error ERC1967NonPayable();

  error FailedInnerCall();

  error InvalidInitialization();

  error NotInitializing();

  error ReentrancyGuardReentrantCall();

  error UUPSUnauthorizedCallContext();

  error UUPSUnsupportedProxiableUUID(bytes32 slot);

  event Initialized(uint64 version);

  event RewardClaimed(uint256 indexed cycle, address indexed voter, uint256 reward);

  event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);

  event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);

  event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

  event Upgraded(address indexed implementation);

  event VoteRegistered(uint256 indexed cycle, address indexed voter, uint256 votes, uint256 rewardWeightedVote);

  event GalaxyMemberAddressUpdated(address indexed newAddress, address indexed oldAddress);

  event EmissionsAddressUpdated(address indexed newAddress, address indexed oldAddress);

  event LevelToMultiplierSet(uint256 indexed level, uint256 multiplier);

  event QuadraticRewardingDisabled(bool indexed disabled);

  function DEFAULT_ADMIN_ROLE() external view returns (bytes32);

  function UPGRADER_ROLE() external view returns (bytes32);

  function UPGRADE_INTERFACE_VERSION() external view returns (string memory);

  function VOTE_REGISTRAR_ROLE() external view returns (bytes32);

  function b3tr() external view returns (address);

  function galaxyMember() external view returns (address);

  function claimReward(uint256 cycle, address voter) external;

  function cycleToTotal(uint256 cycle) external view returns (uint256);

  function cycleToVoterToTotal(uint256 cycle, address voter) external view returns (uint256);

  function emissions() external view returns (address);

  function getReward(uint256 cycle, address voter) external view returns (uint256);

  function getRoleAdmin(bytes32 role) external view returns (bytes32);

  function grantRole(bytes32 role, address account) external;

  function hasRole(bytes32 role, address account) external view returns (bool);

  function levelToMultiplier(uint256 level) external view returns (uint256);

  function proxiableUUID() external view returns (bytes32);

  function registerVote(uint256 proposalStart, address voter, uint256 votes, uint256 votePower) external;

  function renounceRole(bytes32 role, address callerConfirmation) external;

  function revokeRole(bytes32 role, address account) external;

  function scalingFactor() external view returns (uint256);

  function setGalaxyMember(address _galaxyMember) external;

  function setEmissions(address _emissions) external;

  function setLevelToMultiplier(uint256 level, uint256 multiplier) external;

  function setScalingFactor(uint256 newScalingFactor) external;

  function setXallocationVoteRegistrarRole(address _voteRegistrar) external;

  function supportsInterface(bytes4 interfaceId) external view returns (bool);

  function version() external view returns (string memory);

  function upgradeToAndCall(address newImplementation, bytes memory data) external payable;

  function initializeV2(bool _quadraticRewardingFlag) external;

  function isQuadraticRewardingDisabledAtBlock(uint48 blockNumber) external view returns (bool);

  function isQuadraticRewardingDisabledForCurrentCycle() external view returns (bool);

  function disableQuadraticRewarding(bool _disableQuadraticRewarding) external;
}

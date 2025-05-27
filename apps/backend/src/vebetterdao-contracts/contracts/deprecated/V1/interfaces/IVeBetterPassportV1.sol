// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { PassportTypesV1 } from "../ve-better-passport/libraries/PassportTypesV1.sol";
import { IX2EarnApps } from "../../../interfaces/IX2EarnApps.sol";
import { IXAllocationVotingGovernor } from "../../../interfaces/IXAllocationVotingGovernor.sol";

interface IVeBetterPassportV1 {
  // ---------- Events ---------- //

  /// @notice Emitted when a specific check is toggled.
  /// @param checkName The name of the check being toggled.
  /// @param enabled True if the check is enabled, false if disabled.
  event CheckToggled(string indexed checkName, bool enabled);

  /// @notice Emitted when the minimum galaxy member level is set.
  /// @param minimumGalaxyMemberLevel The new minimum galaxy member level.
  event MinimumGalaxyMemberLevelSet(uint256 minimumGalaxyMemberLevel);

  /// @notice Emitted when a user delegates personhood to another user.
  event LinkCreated(address indexed entity, address indexed passport);

  /// @notice Emitted when a user revokes the delegation of personhood to another user.
  event LinkRemoved(address indexed entity, address indexed passport);

  /// @notice Emitted when a user delegates personhood to another user pending acceptance.
  event LinkPending(address indexed entity, address indexed passport);

  /// @notice Emitted when a user registers an action
  /// @param user - the user that registered the action
  /// @param passport - the passport address of the user
  /// @param appId - the app id of the action
  /// @param round - the round of the action
  /// @param actionScore - the score of the action
  event RegisteredAction(
    address indexed user,
    address passport,
    bytes32 indexed appId,
    uint256 indexed round,
    uint256 actionScore
  );

  /// @notice Emitted when a user is signaled.
  /// @param user  The address of the user that was signaled.
  /// @param signaler  The address of the user that signaled the user.
  /// @param app  The app that the user was signaled for.
  /// @param reason  The reason for signaling the user.
  event UserSignaled(address indexed user, address indexed signaler, bytes32 indexed app, string reason);

  /// @notice Emited when an address is associated with an app.
  /// @param signaler  The address of the signaler.
  /// @param app  The app that the signaler was associated with.
  event SignalerAssignedToApp(address indexed signaler, bytes32 indexed app);

  /// @notice Emitted when an address is removed from an app.
  /// @param signaler  The address of the signaler.
  /// @param app  The app that the signaler was removed from.
  event SignalerRemovedFromApp(address indexed signaler, bytes32 indexed app);

  /// @notice Emitted when a user's signals are reset.
  /// @param user  The address of the user that had their signals reset.
  /// @param reason  The reason for resetting the signals.
  event UserSignalsReset(address indexed user, string reason);

  /// @notice Emitted when a user is whitelisted
  /// @param user - the user that is whitelisted
  /// @param whitelistedBy - the user that whitelisted the user
  event UserWhitelisted(address indexed user, address indexed whitelistedBy);

  /// @notice Emitted when a user is removed from the whitelist
  /// @param user - the user that is removed from the whitelist
  /// @param removedBy - the user that removed the user from the whitelist
  event RemovedUserFromWhitelist(address indexed user, address indexed passport, address indexed removedBy);

  /// @notice Emitted when a user is blacklisted
  /// @param user - the user that is blacklisted
  /// @param blacklistedBy - the user that blacklisted the user
  event UserBlacklisted(address indexed user, address indexed blacklistedBy);

  /// @notice Emitted when a user is removed from the blacklist
  /// @param user - the user that is removed from the blacklist
  /// @param removedBy - the user that removed the user from the blacklist
  event RemovedUserFromBlacklist(address indexed user, address indexed removedBy);

  /// @notice Emitted when a user's signals are reset for an app.
  /// @param user  The address of the user that had their signals reset.
  /// @param app  The app that the user had their signals reset for.
  /// @param reason - The reason for resetting the signals.
  event UserSignalsResetForApp(address indexed user, bytes32 indexed app, string reason);

  /// @notice Emitted when a user delegates passport to another user.
  event DelegationCreated(address indexed delegator, address indexed delegatee);

  /// @notice Emitted when a user delegates passport to another user pending acceptance.
  event DelegationPending(address indexed delegator, address indexed delegatee);

  /// @notice Emitted when a user revokes the delegation of passport to another user.
  event DelegationRevoked(address indexed delegator, address indexed delegatee);

  /// @notice Emitted when an an entity is linked to a passport
  error AlreadyLinked(address entity);

  // ---------- Errors ---------- //
  /// @notice Emitted when a user does not have permission to delegate personhood.
  error UnauthorizedUser(address user);

  /// @notice Emitted when a user tries to delegate personhood to a user that has already been delegated to.
  error AlreadyDelegated(address entity);

  /// @notice Emitted when a user tries to delegate personhood to themselves.
  error CannotLinkToSelf(address user);

  /// @notice Emitted when a user tries to delegate personhood to more than one user.
  error OnlyOneLinkAllowed();

  /// @notice Emitted when a user tries to call a function that they are not authorized to call.
  error VeBetterPassportUnauthorizedUser(address user);

  /// @notice Emitted when a user does not have permission to delegate passport.
  error PassportDelegationUnauthorizedUser(address user);

  /// @notice Emitted when a user tries to delegate passport to themselves.
  error CannotDelegateToSelf(address user);

  /// @notice Emitted when a user tries to revoke a delegation that does not exist.
  error NotDelegated(address user);

  /// @notice Emitted when a user tries to delegate passport to more than one user.
  error OnlyOneUserAllowed();

  /// @notice Emiited when a user tries to delegate a passport to another passport or entity.
  error PassportDelegationFromEntity();

  /// @notice Emitted when a user tries to delegate a passport to another entity.
  error PassportDelegationToEntity();

  /// @notice Emitted when a user tries to sign a message with an expired signature
  error SignatureExpired();

  /// @notice Emitted when a user tries to sign a message with an invalid signature
  error InvalidSignature();

  ///  @notice Thrown when a user tries to link a entity to a passport that has reached the maximum number of entities.
  error MaxEntitiesPerPassportReached();

  /// @notice Thrown when a user tries to link a entity to a passport that is already linked to another entity.
  error NotLinked(address user);

  /// @notice Thrown when a user tries to link a entity to a passport that is already delegated.
  error DelegatedEntity(address entity);

  // ---------- Functions ---------- //
  /// @notice Initializes the contract with the required data and roles
  /// @param data The initialization data for the contract
  /// @param roles The roles data for initialization
  function initialize(
    PassportTypesV1.InitializationData calldata data,
    PassportTypesV1.InitializationRoleData calldata roles
  ) external;

  /// @notice Checks if a user is a person based on the participation score and other criteria
  /// @param user The address of the user to check
  /// @return person True if the user is a valid person
  /// @return reason Reason why the user is not a person
  function isPerson(address user) external view returns (bool person, string memory reason);

  /// @notice Checks if a user is a person
  /// @dev Checks if a wallet is a person or not at a specific timepoint based on the participation score, blacklisting, and GM holdings
  /// @param user - the user address
  /// @param timepoint - the timepoint to query
  /// @return person - true if the user is a person
  /// @return reason - the reason why the user is not a person
  function isPersonAtTimepoint(
    address user,
    uint48 timepoint
  ) external view returns (bool person, string memory reason);

  /// @notice Checks if a user is whitelisted
  /// @param _user The user to check
  /// @return True if the user is whitelisted
  function isWhitelisted(address _user) external view returns (bool);

  /// @notice Checks if a user is blacklisted
  /// @param _user The user to check
  /// @return True if the user is blacklisted
  function isBlacklisted(address _user) external view returns (bool);

  /// @notice Toggles the specified check
  function toggleCheck(PassportTypesV1.CheckType check) external;

  /// @notice Returns the passport address for a entity
  /// @param entity The entity's address
  /// @return The address of the passport
  function getPassportForEntity(address entity) external view returns (address);

  /// @notice Returns the pending links for a user (both incoming and outgoing)
  /// @param user The address of the user
  /// @return incoming The addresss of users that want to link to the user.
  /// @return outgoing The address that the user wants to link to.
  function getPendingLinkings(address user) external view returns (address[] memory incoming, address outgoing);

  /// @notice Returns the passport address for a entity at a specific timepoint
  /// @param entity The entity's address
  /// @param timepoint The timepoint to query
  function getPassportForEntityAtTimepoint(address entity, uint256 timepoint) external view returns (address);

  /// @notice Returns the entity address for a passport
  /// @param passport The passport's address
  /// @return The address of the entity
  function getEntitiesLinkedToPassport(address passport) external view returns (address[] memory);

  /// @notice Returns if a user is a entity
  /// @param user The user address
  function isEntity(address user) external view returns (bool);

  /// @notice Returns if a user is a entity at a specific timepoint
  /// @param user The user address
  /// @param timepoint The timepoint to query
  function isEntityInTimepoint(address user, uint256 timepoint) external view returns (bool);

  /// @notice Returns if a user is a passport
  /// @param user The user address
  function isPassport(address user) external view returns (bool);

  /// @notice Returns if a user is a passport at a specific timepoint
  /// @param user The user address
  /// @param timepoint The timepoint to query
  function isPassportInTimepoint(address user, uint256 timepoint) external view returns (bool);

  /// @notice Gets the cumulative score of a user based on exponential decay for a number of last rounds
  /// @param user The user address
  /// @param lastRound The round to consider as a starting point for the cumulative score
  /// @return The cumulative score of the user
  function getCumulativeScoreWithDecay(address user, uint256 lastRound) external view returns (uint256);

  /// @notice Gets the round score of a user
  /// @param user The user address
  /// @param round The round to check
  /// @return The round score of the user
  function userRoundScore(address user, uint256 round) external view returns (uint256);

  /// @notice Gets the total score of a user
  /// @param user The user address
  /// @return The total score of the user
  function userTotalScore(address user) external view returns (uint256);

  /// @notice Gets the score of a user for an app in a specific round
  /// @param user The user address
  /// @param round The round to check
  /// @param appId The app ID
  /// @return The score of the user for the app in the round
  function userRoundScoreApp(address user, uint256 round, bytes32 appId) external view returns (uint256);

  /// @notice Gets the total score of a user for an app
  /// @param user The user address
  /// @param appId The app ID
  /// @return The total score of the user for the app
  function userAppTotalScore(address user, bytes32 appId) external view returns (uint256);

  /// @notice Gets the threshold score for a user to be considered a person
  /// @return The threshold participation score
  function thresholdPoPScore() external view returns (uint256);

  /// @notice Gets the threshold score for a user to be considered a person at a specific timepoint
  function thresholdPoPScoreAtTimepoint(uint48 timepoint) external view returns (uint256);

  /// @notice Gets the number of rounds to be considered for the cumulative score
  /// @return The number of rounds
  function roundsForCumulativeScore() external view returns (uint256);

  /// @notice Gets the security multiplier for an app security
  /// @param security The app security level (LOW, MEDIUM, HIGH)
  /// @return The security multiplier for the app
  function securityMultiplier(PassportTypesV1.APP_SECURITY security) external view returns (uint256);

  /// @notice Gets the security level of an app
  /// @param appId The app ID
  /// @return The security level of the app
  function appSecurity(bytes32 appId) external view returns (PassportTypesV1.APP_SECURITY);

  /// @notice Gets the minimum galaxy member level required
  /// @return The minimum galaxy member level
  function getMinimumGalaxyMemberLevel() external view returns (uint256);

  /// @notice Returns if the specific check is enabled
  function isCheckEnabled(PassportTypesV1.CheckType check) external view returns (bool);

  /// @notice Returns the signaling threshold
  /// @return The signaling threshold
  function signalingThreshold() external view returns (uint256);

  /// @notice Gets the total number of signals for an app
  /// @param app The app ID
  /// @return The total number of signals for the app
  function appTotalSignalsCounter(bytes32 app) external view returns (uint256);

  /// @notice Returns the domain for EIP-712 signature
  function eip712Domain()
    external
    view
    returns (
      bytes1 fields,
      string memory name,
      string memory signatureVersion,
      uint256 chainId,
      address verifyingContract,
      bytes32 salt,
      uint256[] memory extensions
    );

  /// @notice Grants a role to a specific account
  /// @param role The role to grant
  /// @param account The account to grant the role to
  function grantRole(bytes32 role, address account) external;

  /// @notice Revokes a role from a specific account
  /// @param role The role to revoke
  /// @param account The account to revoke the role from
  function revokeRole(bytes32 role, address account) external;

  /// @notice Signals a user
  /// @param _user The user to signal
  function signalUser(address _user) external;

  /// @notice Signals a user with a reason
  /// @param _user The user to signal
  /// @param reason The reason for the signal
  function signalUserWithReason(address _user, string memory reason) external;

  /// @notice Assigns a signaler to an app
  /// @param app The app ID
  /// @param user The signaler address
  function assignSignalerToApp(bytes32 app, address user) external;

  /// @notice Removes a signaler from an app
  /// @param user The signaler address
  function removeSignalerFromApp(address user) external;

  /// @notice Resets the signals of a user with a given reason
  /// @param user The user address
  /// @param reason The reason for resetting the signals
  function resetUserSignalsWithReason(address user, string memory reason) external;

  /// @notice Gets the version of the contract
  /// @return The version of the contract as a string
  function version() external pure returns (string memory);

  /// @notice Returns the current block number
  /// @return The current block number
  function clock() external view returns (uint48);

  /// @notice Returns the clock mode for the contract
  /// @return The clock mode as a string
  function CLOCK_MODE() external pure returns (string memory);

  /// @notice Sets the signaling threshold
  /// @param threshold The new signaling threshold
  function setSignalingThreshold(uint256 threshold) external;

  /// @notice Sets the security multiplier for an app security level
  /// @param security The app security level
  /// @param multiplier The security multiplier
  function setSecurityMultiplier(PassportTypesV1.APP_SECURITY security, uint256 multiplier) external;

  /// @notice Sets the app security level for a specific app
  /// @param appId The app ID
  /// @param security The security level
  function setAppSecurity(bytes32 appId, PassportTypesV1.APP_SECURITY security) external;

  /// @notice Sets the threshold score for a user to be considered a person
  /// @param threshold The threshold score
  function setThresholdPoPScore(uint208 threshold) external;

  /// @notice Sets the number of rounds to consider for cumulative score calculation
  /// @param rounds The number of rounds
  function setRoundsForCumulativeScore(uint256 rounds) external;

  /// @notice Sets the decay rate for exponential decay scoring
  /// @param decayRate The decay rate
  function setDecayRate(uint256 decayRate) external;

  /// @notice Sets the X2EarnApps contract address
  /// @param _x2EarnApps The X2EarnApps contract address
  function setX2EarnApps(IX2EarnApps _x2EarnApps) external;

  /// @notice Sets the xAllocationVoting contract address
  /// @param xAllocationVoting The xAllocationVoting contract address
  function setXAllocationVoting(IXAllocationVotingGovernor xAllocationVoting) external;

  /// @notice Delegate personhood to another address
  /// @param entity The entity's address
  /// @param deadline The deadline for the signature
  /// @param signature The signature of the delegation
  function linkEntityToPassportWithSignature(address entity, uint256 deadline, bytes memory signature) external;

  /// @notice Delegate the personhood to another address
  /// @dev The passport must accept the delegation
  /// Eg: Alice has a personhood where she is not considered a person, she delegates her personhood to Bob, which
  /// is considered a person. Bob now cannot vote because he is not considered a person anymore.
  function linkEntityToPassport(address passport) external;

  /// @notice Allow the passport to accept the delegation
  /// @param entity - the entity address
  function acceptEntityLink(address entity) external;

  /// @notice Deny an incoming pending entity link to the sender's passport.
  /// @param entity - the entity address
  function denyIncomingPendingEntityLink(address entity) external;

  /// @notice Cancel an outgoing pending entity link from the sender.
  function cancelOutgoingPendingEntityLink() external;

  /// @notice Remove the linked enitity from the passport
  /// @param entity - the entity address
  function removeEntityLink(address entity) external;

  /// @notice Registers an action for a user
  /// @param user - the user that performed the action
  /// @param appId - the app id of the action
  function registerAction(address user, bytes32 appId) external;

  /// @notice Registers an action for a user in a round
  /// @param user - the user that performed the action
  /// @param appId - the app id of the action
  /// @param round - the round id of the action
  function registerActionForRound(address user, bytes32 appId, uint256 round) external;

  /// @notice Function used to seed the passport with old actions by aggregating them
  /// based on (user, appId, round) and summing up the total score offchain
  /// @param user - the user that performed the actions
  /// @param appId - the app id of the actions
  /// @param round - the round id of the actions
  /// @param totalScore - the total score of the actions
  function registerAggregatedActionsForRound(address user, bytes32 appId, uint256 round, uint256 totalScore) external;

  /// @notice Gets the threshold percentage of blacklisted entities for a passport to be considered blacklisted
  function blacklistThreshold() external view returns (uint256);

  // @notice Gets the threshold percentage of whitelisted entities for a passport to be considered whitelisted
  function whitelistThreshold() external view returns (uint256);

  /// @notice Returns the maximum number of entities per passport
  function maxEntitiesPerPassport() external view returns (uint256);

  /// @notice Gets the decay rate for the cumulative score
  function decayRate() external view returns (uint256);

  /// @notice Gets the minimum galaxy member level to be considered a person
  function minimumGalaxyMemberLevel() external view returns (uint256);

  /// @notice Sets the threshold percentage of blacklisted entities for a passport to be considered blacklisted
  function setBlacklistThreshold(uint256 _threshold) external;

  /// @notice Sets the threshold percentage of whitelisted entities for a passport to be considered whitelisted
  function setWhitelistThreshold(uint256 _threshold) external;

  /// @notice Sets the maximum number of entities that can be linked to a passport
  /// @param maxEntities - the maximum number of entities
  function setMaxEntitiesPerPassport(uint256 maxEntities) external;

  /// @notice Delegate the personhood to another address
  /// @param delegatee - the delegatee address
  function delegatePassport(address delegatee) external;

  /// @notice Allow the delegatee to accept the delegation
  /// @param delegator - the delegator address
  function acceptDelegation(address delegator) external;

  /// @notice Revoke the delegation (can be done by the delegator or the delegatee)
  function revokeDelegation() external;

  /// @notice Allows a delegator to deny (and remove) an incoming pending delegation.
  /// @param delegator - the user who is delegating to me (aka the delegator)
  function denyIncomingPendingDelegation(address delegator) external;

  /// @notice Allows a delegator to cancel (and remove) the outgoing pending delegation.
  function cancelOutgoingPendingDelegation() external;

  /// @notice Returns the delegatee address for a delegator
  /// @param delegator The delegator's address
  /// @return The address of the delegatee
  function getDelegatee(address delegator) external view returns (address);

  /// @notice Returns the incoming and outgoing pending delegations for a user
  /// @param user - the user address
  /// @return incoming The address[] memory of users that are delegating to the user.
  /// @return outgoing The address that the user is delegating to.
  function getPendingDelegations(address user) external view returns (address[] memory incoming, address outgoing);

  /// @notice Returns the delegatee address for a delegator at a specific timepoint
  /// @param delegator The delegator's address
  /// @param timepoint The timepoint to query
  function getDelegateeInTimepoint(address delegator, uint256 timepoint) external view returns (address);

  /// @notice Returns the delegator address for a delegatee
  /// @param delegatee The delegatee's address
  /// @return The address of the delegator
  function getDelegator(address delegatee) external view returns (address);

  /// @notice Returns the delegator address for a delegatee at a specific timepoint
  /// @param delegatee The delegatee's address
  /// @param timepoint The timepoint to query
  function getDelegatorInTimepoint(address delegatee, uint256 timepoint) external view returns (address);

  /// @notice Returns if a user is a delegator
  /// @param user The user address
  function isDelegator(address user) external view returns (bool);

  /// @notice Returns if a user is a delegator at a specific timepoint
  /// @param user The user address
  /// @param timepoint The timepoint to query
  function isDelegatorInTimepoint(address user, uint256 timepoint) external view returns (bool);

  /// @notice Returns if a user is a delegatee
  /// @param user The user address
  function isDelegatee(address user) external view returns (bool);

  /// @notice Returns if a user is a delegatee at a specific timepoint
  /// @param user The user address
  /// @param timepoint The timepoint to query
  function isDelegateeInTimepoint(address user, uint256 timepoint) external view returns (bool);
}

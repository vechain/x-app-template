// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { PassportTypesV1 } from "./libraries/PassportTypesV1.sol";
import { PassportStorageTypesV1 } from "./libraries/PassportStorageTypesV1.sol";
import { PassportChecksLogicV1 } from "./libraries/PassportChecksLogicV1.sol";
import { PassportWhitelistAndBlacklistLogicV1 } from "./libraries/PassportWhitelistAndBlacklistLogicV1.sol";
import { PassportPoPScoreLogicV1 } from "./libraries/PassportPoPScoreLogicV1.sol";
import { PassportEntityLogicV1 } from "./libraries/PassportEntityLogicV1.sol";
import { PassportClockLogicV1 } from "./libraries/PassportClockLogicV1.sol";
import { PassportDelegationLogicV1 } from "./libraries/PassportDelegationLogicV1.sol";
import { PassportSignalingLogicV1 } from "./libraries/PassportSignalingLogicV1.sol";
import { PassportPersonhoodLogicV1 } from "./libraries/PassportPersonhoodLogicV1.sol";
import { PassportEIP712SigningLogicV1 } from "./libraries/PassportEIP712SigningLogicV1.sol";
import { PassportConfiguratorV1 } from "./libraries/PassportConfiguratorV1.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { IVeBetterPassportV1 } from "../interfaces/IVeBetterPassportV1.sol";
import { IXAllocationVotingGovernor } from "../../../interfaces/IXAllocationVotingGovernor.sol";
import { IGalaxyMember } from "../../../interfaces/IGalaxyMember.sol";
import { IX2EarnApps } from "../../../interfaces/IX2EarnApps.sol";

/// @title VeBetterPassport
/// @notice Contract to manage the VeBetterPassport, a system to determine if a wallet is a person or not
/// based on the participation score, blacklisting, GM holdings and much more that can be added in the future.
contract VeBetterPassportV1 is AccessControlUpgradeable, UUPSUpgradeable, IVeBetterPassportV1 {
  bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
  bytes32 public constant ROLE_GRANTER = keccak256("ROLE_GRANTER");
  bytes32 public constant SETTINGS_MANAGER_ROLE = keccak256("SETTINGS_MANAGER_ROLE");
  bytes32 public constant WHITELISTER_ROLE = keccak256("WHITELISTER_ROLE");
  bytes32 public constant ACTION_REGISTRAR_ROLE = keccak256("ACTION_REGISTRAR_ROLE");
  bytes32 public constant ACTION_SCORE_MANAGER_ROLE = keccak256("ACTION_SCORE_MANAGER_ROLE");
  bytes32 public constant SIGNALER_ROLE = keccak256("SIGNALER_ROLE");

  // keccak256(abi.encode(uint256(keccak256("PassportStorageLocation")) - 1)) & ~bytes32(uint256(0xff))
  bytes32 private constant PassportStorageLocation = 0x273c9387b78d9b22e6f3371bb3aa3a918f53507e8cacc54e4831933cbb844100;

  /// @dev Internal function to access the passport storage slot.
  function getPassportStorage() internal pure returns (PassportStorageTypesV1.PassportStorage storage $) {
    assembly {
      $.slot := PassportStorageLocation
    }
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  /// @notice Initializes the contract
  function initialize(
    PassportTypesV1.InitializationData memory data,
    PassportTypesV1.InitializationRoleData memory roles
  ) external initializer {
    __UUPSUpgradeable_init();
    __AccessControl_init();

    PassportConfiguratorV1.initializePassportStorage(getPassportStorage(), data);

    // Grant roles
    _grantRole(DEFAULT_ADMIN_ROLE, roles.admin);
    _grantRole(UPGRADER_ROLE, roles.upgrader);
    _grantRole(SIGNALER_ROLE, roles.botSignaler);
    _grantRole(ROLE_GRANTER, roles.roleGranter);
    _grantRole(SETTINGS_MANAGER_ROLE, roles.settingsManager);
    _grantRole(WHITELISTER_ROLE, roles.whitelister);
    _grantRole(ACTION_REGISTRAR_ROLE, roles.actionRegistrar);
    _grantRole(ACTION_SCORE_MANAGER_ROLE, roles.actionScoreManager);
  }

  // ---------- Modifiers ------------ //

  /// @notice Modifier to check if the user has the required role or is the DEFAULT_ADMIN_ROLE
  /// @param role - the role to check
  modifier onlyRoleOrAdmin(bytes32 role) {
    if (!hasRole(role, msg.sender) && !hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
      revert VeBetterPassportUnauthorizedUser(msg.sender);
    }
    _;
  }

  // ---------- Authorizers ---------- //

  /// @notice Authorizes the upgrade of the contract
  /// @param newImplementation - the new implementation address
  function _authorizeUpgrade(address newImplementation) internal virtual override onlyRole(UPGRADER_ROLE) {}

  // ---------- Getters ---------- //

  /// @notice Checks if a user is a person
  /// @dev Checks if a wallet is a person or not based on the participation score, blacklisting, and GM holdings
  /// @param user - the user address
  /// @return person - true if the user is a person
  /// @return reason - the reason why the user is not a person
  function isPerson(address user) external view returns (bool person, string memory reason) {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    return PassportPersonhoodLogicV1.isPerson($, user);
  }

  /// @notice Checks if a user is a person
  /// @dev Checks if a wallet is a person or not at a specific timepoint based on the participation score, blacklisting, and GM holdings
  /// @param user - the user address
  /// @param timepoint - the timepoint to query
  /// @return person - true if the user is a person
  /// @return reason - the reason why the user is not a person
  function isPersonAtTimepoint(
    address user,
    uint48 timepoint
  ) external view returns (bool person, string memory reason) {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    return PassportPersonhoodLogicV1.isPersonAtTimepoint($, user, timepoint);
  }

  /// @notice Returns if the specific check is enabled
  function isCheckEnabled(PassportTypesV1.CheckType check) external view returns (bool) {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    return PassportChecksLogicV1.isCheckEnabled($, check);
  }

  /// @notice Returns the minimum galaxy member level
  function getMinimumGalaxyMemberLevel() external view returns (uint256) {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    return PassportChecksLogicV1.getMinimumGalaxyMemberLevel($);
  }

  /// @notice Returns if a user is whitelisted
  function isWhitelisted(address _user) external view returns (bool) {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    return PassportWhitelistAndBlacklistLogicV1.isWhitelisted($, _user);
  }

  /// @notice Returns if a user is blacklisted
  function isBlacklisted(address _user) external view returns (bool) {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    return PassportWhitelistAndBlacklistLogicV1.isBlacklisted($, _user);
  }

  /// @notice Checks if a passport is whitelisted.
  /// @dev If passport is an entity, it will check the passport of the entity.
  /// @param passport The address of the passport to check.
  /// @return True if the passport is whitelisted, false otherwise.
  function isPassportWhitelisted(address passport) external view returns (bool) {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    return PassportWhitelistAndBlacklistLogicV1.isPassportWhitelisted($, passport);
  }

  /// @notice Checks if a passport is blacklisted.
  /// @dev If passport is an entity, it will check the passport of the entity.
  /// @param passport The address of the passport to check.
  /// @return True if the passport is blacklisted, false otherwise.
  function isPassportBlacklisted(address passport) external view returns (bool) {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    return PassportWhitelistAndBlacklistLogicV1.isPassportBlacklisted($, passport);
  }

  /// @notice Gets the threshold percentage of blacklisted entities for a passport to be considered blacklisted
  function blacklistThreshold() external view returns (uint256) {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    return PassportWhitelistAndBlacklistLogicV1.blacklistThreshold($);
  }

  /// @notice Gets the threshold percentage of whitelisted entities for a passport to be considered whitelisted
  function whitelistThreshold() external view returns (uint256) {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    return PassportWhitelistAndBlacklistLogicV1.whitelistThreshold($);
  }

  /// @notice Gets the cumulative score of a user based on exponential decay for a number of last rounds
  /// @dev This function calculates the decayed score f(t) = a * (1 - r)^t
  /// @param user - the user address
  /// @param lastRound - the round to consider as a starting point for the cumulative score
  function getCumulativeScoreWithDecay(address user, uint256 lastRound) external view returns (uint256) {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    return PassportPoPScoreLogicV1.getCumulativeScoreWithDecay($, user, lastRound);
  }

  /// @notice Gets the round score of a user
  /// @param user - the user address
  /// @param round - the round
  function userRoundScore(address user, uint256 round) external view returns (uint256) {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    return PassportPoPScoreLogicV1.userRoundScore($, user, round);
  }

  /// @notice Gets the total score of a user
  /// @param user - the user address
  function userTotalScore(address user) external view returns (uint256) {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    return PassportPoPScoreLogicV1.userTotalScore($, user);
  }

  /// @notice Gets the score of a user for an app in a round
  /// @param user - the user address
  /// @param round - the round
  /// @param appId - the app id
  function userRoundScoreApp(address user, uint256 round, bytes32 appId) external view returns (uint256) {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    return PassportPoPScoreLogicV1.userRoundScoreApp($, user, round, appId);
  }

  /// @notice Gets the total score of a user for an app
  /// @param user - the user address
  /// @param appId - the app id
  function userAppTotalScore(address user, bytes32 appId) external view returns (uint256) {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    return PassportPoPScoreLogicV1.userAppTotalScore($, user, appId);
  }

  /// @notice Gets the threshold for a user to be considered a person
  function thresholdPoPScore() external view returns (uint256) {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    return PassportPoPScoreLogicV1.thresholdPoPScore($);
  }

  /// @notice Gets the threshold for a user to be considered a person at a specific timepoint (block number)
  function thresholdPoPScoreAtTimepoint(uint48 timepoint) external view returns (uint256) {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    return PassportPoPScoreLogicV1.thresholdPoPScoreAtTimepoint($, timepoint);
  }

  /// @notice Gets the security multiplier for an app security
  /// @param security - the app security between LOW, MEDIUM, HIGH
  function securityMultiplier(PassportTypesV1.APP_SECURITY security) external view returns (uint256) {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    return PassportPoPScoreLogicV1.securityMultiplier($, security);
  }

  /// @notice Gets the security level of an app
  /// @param appId - the app id
  function appSecurity(bytes32 appId) external view returns (PassportTypesV1.APP_SECURITY) {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    return PassportPoPScoreLogicV1.appSecurity($, appId);
  }

  /// @notice Gets the round threshold for a user to be considered a person
  function roundsForCumulativeScore() external view returns (uint256) {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    return PassportPoPScoreLogicV1.roundsForCumulativeScore($);
  }

  /// @notice Gets the decay rate for the cumulative score
  function decayRate() external view returns (uint256) {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    return PassportPoPScoreLogicV1.decayRate($);
  }

  /// @notice Gets the minimum galaxy member level to be considered a person
  function minimumGalaxyMemberLevel() external view returns (uint256) {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    return $.minimumGalaxyMemberLevel;
  }

  /// @notice Returns the maximum number of entities per passport
  function maxEntitiesPerPassport() external view returns (uint256) {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    return PassportEntityLogicV1.getMaxEntitiesPerPassport($);
  }

  /// @notice Returns the passport address for a entity
  /// @param entity - the entity address
  function getPassportForEntity(address entity) external view returns (address) {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    return PassportEntityLogicV1.getPassportForEntity($, entity);
  }

  /// @notice Returns the passport address for a entity at a specific timepoint
  /// @param entity - the entity address
  /// @param timepoint - the timepoint to query
  function getPassportForEntityAtTimepoint(address entity, uint256 timepoint) external view returns (address) {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    return PassportEntityLogicV1.getPassportForEntityAtTimepoint($, entity, timepoint);
  }

  /// @notice Returns the entity address for a passport
  /// @param passport - the passport address
  function getEntitiesLinkedToPassport(address passport) external view returns (address[] memory) {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    return PassportEntityLogicV1.getEntitiesLinkedToPassport($, passport);
  }

  /// @notice Returns if a user is a entity
  /// @param user - the user address
  function isEntity(address user) external view returns (bool) {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    return PassportEntityLogicV1.isEntity($, user);
  }

  /// @notice Returns if a user is a entity at a specific timepoint
  /// @param user - the user address
  /// @param timepoint - the timepoint to query
  function isEntityInTimepoint(address user, uint256 timepoint) external view returns (bool) {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    return PassportEntityLogicV1.isEntityInTimepoint($, user, timepoint);
  }

  /// @notice Returns if a user is a passport
  /// @param user - the user address
  function isPassport(address user) external view returns (bool) {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    return PassportEntityLogicV1.isPassport($, user);
  }

  /// @notice Returns if a user is a passport at a specific timepoint
  /// @param user - the user address
  /// @param timepoint - the timepoint to query
  function isPassportInTimepoint(address user, uint256 timepoint) external view returns (bool) {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    return PassportEntityLogicV1.isPassportInTimepoint($, user, timepoint);
  }

  /// @notice Returns the pending links for a user (both incoming and outgoing)
  /// @param user The address of the user
  /// @return incoming The addresss of users that want to link to the user.
  /// @return outgoing The address that the user wants to link to.
  function getPendingLinkings(address user) external view returns (address[] memory incoming, address outgoing) {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    return PassportEntityLogicV1.getPendingLinkings($, user);
  }

  /// @notice Returns the delegatee address for a delegator
  /// @param delegator - the delegator address
  function getDelegatee(address delegator) external view returns (address) {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    return PassportDelegationLogicV1.getDelegatee($, delegator);
  }

  /// @notice Returns the delegatee address for a delegator at a specific timepoint
  /// @param delegator - the delegator address
  /// @param timepoint - the timepoint to query
  function getDelegateeInTimepoint(address delegator, uint256 timepoint) external view returns (address) {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    return PassportDelegationLogicV1.getDelegateeInTimepoint($, delegator, timepoint);
  }

  /// @notice Returns the delegator address for a delegatee
  /// @param delegatee - the delegatee address
  function getDelegator(address delegatee) external view returns (address) {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    return PassportDelegationLogicV1.getDelegator($, delegatee);
  }

  /// @notice Returns the delegator address for a delegatee at a specific timepoint
  /// @param delegatee - the delegatee address
  /// @param timepoint - the timepoint to query
  function getDelegatorInTimepoint(address delegatee, uint256 timepoint) external view returns (address) {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    return PassportDelegationLogicV1.getDelegatorInTimepoint($, delegatee, timepoint);
  }

  /// @notice Returns if a user is a delegator
  /// @param user - the user address
  function isDelegator(address user) external view returns (bool) {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    return PassportDelegationLogicV1.isDelegator($, user);
  }

  /// @notice Returns if a user is a delegator at a specific timepoint
  /// @param user - the user address
  /// @param timepoint - the timepoint to query
  function isDelegatorInTimepoint(address user, uint256 timepoint) external view returns (bool) {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    return PassportDelegationLogicV1.isDelegatorInTimepoint($, user, timepoint);
  }

  /// @notice Returns if a user is a delegatee
  /// @param user - the user address
  function isDelegatee(address user) external view returns (bool) {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    return PassportDelegationLogicV1.isDelegatee($, user);
  }

  /// @notice Returns if a user is a delegatee at a specific timepoint
  /// @param user - the user address
  /// @param timepoint - the timepoint to query
  function isDelegateeInTimepoint(address user, uint256 timepoint) external view returns (bool) {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    return PassportDelegationLogicV1.isDelegateeInTimepoint($, user, timepoint);
  }

  /// @notice Returns the pending incoming and outgoing delegations for a user
  /// @param user - the user address
  /// @return incoming The address[] memory of users that are delegating to the user.
  /// @return outgoing The address that the user is delegating to.
  function getPendingDelegations(address user) external view returns (address[] memory incoming, address outgoing) {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    return PassportDelegationLogicV1.getPendingDelegations($, user);
  }

  /// @notice Returns the number of times a user has been signaled
  function signaledCounter(address _user) external view returns (uint256) {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    return PassportSignalingLogicV1.signaledCounter($, _user);
  }

  /// @notice Returns the belonging app of a signaler
  function appOfSignaler(address _signaler) external view returns (bytes32) {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    return PassportSignalingLogicV1.appOfSignaler($, _signaler);
  }

  /// @notice Returns the number of times a user has been signaled by an app
  function appSignalsCounter(bytes32 _app, address _user) external view returns (uint256) {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    return PassportSignalingLogicV1.appSignalsCounter($, _app, _user);
  }

  /// @notice Returns the total number of signals for an app
  function appTotalSignalsCounter(bytes32 _app) external view returns (uint256) {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    return PassportSignalingLogicV1.appTotalSignalsCounter($, _app);
  }

  /// @notice Returns the signaling threshold
  function signalingThreshold() external view returns (uint256) {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    return PassportSignalingLogicV1.signalingThreshold($);
  }

  /// @notice Gets the x2EarnApps contract address
  function getX2EarnApps() external view returns (IX2EarnApps) {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    return PassportConfiguratorV1.getX2EarnApps($);
  }

  /// @notice Gets the xAllocationVoting contract address
  function getXAllocationVoting() external view returns (IXAllocationVotingGovernor) {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    return PassportConfiguratorV1.getXAllocationVoting($);
  }

  /// @notice Gets the galaxy member contract address
  function getGalaxyMember() external view returns (IGalaxyMember) {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    return PassportConfiguratorV1.getGalaxyMember($);
  }

  /// @notice Get the current block number
  function clock() external view returns (uint48) {
    return PassportClockLogicV1.clock();
  }

  /// @notice Get the clock mode
  function CLOCK_MODE() external pure returns (string memory) {
    return PassportClockLogicV1.CLOCK_MODE();
  }

  ///@dev returns the fields and values that describe the domain separator used by this contract for EIP-712 signature.
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
    )
  {
    return PassportEIP712SigningLogicV1.eip712Domain();
  }

  /// @notice Returns the version of the contract
  function version() external pure returns (string memory) {
    return "1";
  }

  // ---------- Setters ---------- //
  /// @notice Toggles the specified check
  function toggleCheck(PassportTypesV1.CheckType check) external onlyRole(SETTINGS_MANAGER_ROLE) {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    PassportChecksLogicV1.toggleCheck($, check);
  }

  /// @notice user can be whitelisted but the counter will not be reset
  function whitelist(address _user) external onlyRoleOrAdmin(WHITELISTER_ROLE) {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    PassportWhitelistAndBlacklistLogicV1.whitelist($, _user);
  }

  /// @notice Removes a user from the whitelist
  function removeFromWhitelist(address _user) external onlyRoleOrAdmin(WHITELISTER_ROLE) {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    PassportWhitelistAndBlacklistLogicV1.removeFromWhitelist($, _user);
  }

  /// @notice user can be blacklisted but the counter will not be reset
  function blacklist(address _user) external onlyRoleOrAdmin(WHITELISTER_ROLE) {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    PassportWhitelistAndBlacklistLogicV1.blacklist($, _user);
  }

  /// @notice Removes a user from the blacklist
  function removeFromBlacklist(address _user) external onlyRoleOrAdmin(WHITELISTER_ROLE) {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    PassportWhitelistAndBlacklistLogicV1.removeFromBlacklist($, _user);
  }

  /// @notice Sets the threshold percentage of blacklisted entities for a passport to be considered blacklisted
  function setBlacklistThreshold(uint256 _threshold) external onlyRoleOrAdmin(SETTINGS_MANAGER_ROLE) {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    PassportWhitelistAndBlacklistLogicV1.setBlacklistThreshold($, _threshold);
  }

  /// @notice Sets the threshold percentage of whitelisted entities for a passport to be considered whitelisted
  function setWhitelistThreshold(uint256 _threshold) external onlyRoleOrAdmin(SETTINGS_MANAGER_ROLE) {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    PassportWhitelistAndBlacklistLogicV1.setWhitelistThreshold($, _threshold);
  }

  /// @notice Registers an action for a user
  /// @param user - the user that performed the action
  /// @param appId - the app id of the action
  function registerAction(address user, bytes32 appId) external onlyRole(ACTION_REGISTRAR_ROLE) {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    PassportPoPScoreLogicV1.registerAction($, user, appId);
  }

  /// @notice Registers an action for a user in a round
  /// @param user - the user that performed the action
  /// @param appId - the app id of the action
  /// @param round - the round id of the action
  function registerActionForRound(address user, bytes32 appId, uint256 round) external onlyRole(ACTION_REGISTRAR_ROLE) {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    PassportPoPScoreLogicV1.registerActionForRound($, user, appId, round);
  }

  /// @notice Function used to seed the passport with old actions by aggregating them
  /// based on (user, appId, round) and summing up the total score offchain
  /// @param user - the user that performed the actions
  /// @param appId - the app id of the actions
  /// @param round - the round id of the actions
  /// @param totalScore - the total score of the actions
  function registerAggregatedActionsForRound(
    address user,
    bytes32 appId,
    uint256 round,
    uint256 totalScore
  ) external onlyRole(ACTION_REGISTRAR_ROLE) {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    PassportPoPScoreLogicV1.registerAggregatedActionsForRound($, user, appId, round, totalScore);
  }

  /// @notice Sets the threshold for a user to be considered a person
  /// @param threshold - the proof of participation score threshold
  function setThresholdPoPScore(uint208 threshold) external onlyRoleOrAdmin(ACTION_SCORE_MANAGER_ROLE) {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    PassportPoPScoreLogicV1.setThresholdPoPScore($, threshold);
  }

  /// @notice Sets the number of rounds to consider for the cumulative score
  /// @param rounds - the number of rounds
  function setRoundsForCumulativeScore(uint256 rounds) external onlyRoleOrAdmin(ACTION_SCORE_MANAGER_ROLE) {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    PassportPoPScoreLogicV1.setRoundsForCumulativeScore($, rounds);
  }

  /// @notice Sets the  security multiplier
  /// @param security - the app security between LOW, MEDIUM, HIGH
  /// @param multiplier - the multiplier
  function setSecurityMultiplier(
    PassportTypesV1.APP_SECURITY security,
    uint256 multiplier
  ) external onlyRoleOrAdmin(ACTION_SCORE_MANAGER_ROLE) {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    PassportPoPScoreLogicV1.setSecurityMultiplier($, security, multiplier);
  }

  /// @dev Sets the security level of an app
  /// @param appId - the app id
  /// @param security  - the security level
  function setAppSecurity(
    bytes32 appId,
    PassportTypesV1.APP_SECURITY security
  ) external onlyRoleOrAdmin(ACTION_SCORE_MANAGER_ROLE) {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    PassportPoPScoreLogicV1.setAppSecurity($, appId, security);
  }

  /// @notice Sets the decay rate for the exponential decay
  /// @param _decayRate - the decay rate
  function setDecayRate(uint256 _decayRate) external onlyRoleOrAdmin(DEFAULT_ADMIN_ROLE) {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    PassportPoPScoreLogicV1.setDecayRate($, _decayRate);
  }

  /// @notice Delegate the personhood to another address
  /// The entity must sign a message where he authorizes the passport to request the delegation:
  /// this is done to avoid that a malicious user delegates the personhood to another user without his consent.
  /// Eg: Alice has a personhood where she is not considered a person, she delegates her personhood to Bob, which
  /// is considered a person. Bob now cannot vote because he is not considered a person anymore.
  /// @param entity - the entity address
  /// @param deadline - the deadline for the signature
  /// @param signature - the signature of the delegation
  function linkEntityToPassportWithSignature(address entity, uint256 deadline, bytes memory signature) external {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    PassportEntityLogicV1.linkEntityToPassportWithSignature($, entity, deadline, signature);
  }

  /// @notice Delegate the personhood to another address
  /// @dev The passport must accept the delegation
  /// Eg: Alice has a personhood where she is not considered a person, she delegates her personhood to Bob, which
  /// is considered a person. Bob now cannot vote because he is not considered a person anymore.
  function linkEntityToPassport(address passport) external {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    PassportEntityLogicV1.linkEntityToPassport($, passport);
  }

  /// @notice Allow the passport to accept the delegation
  /// @param entity - the entity address
  function acceptEntityLink(address entity) external {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    PassportEntityLogicV1.acceptEntityLink($, entity);
  }

  /// @notice Revoke the delegation (can be done by the entity or the passport)
  /// @param entity - the entity address
  function removeEntityLink(address entity) external {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    PassportEntityLogicV1.removeEntityLink($, entity);
  }

  /// @notice Deny an incoming pending entity link to the sender's passport.
  /// @param entity - the entity address
  function denyIncomingPendingEntityLink(address entity) external {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    PassportEntityLogicV1.denyIncomingPendingEntityLink($, entity);
  }

  /// @notice Cancel an outgoing pending entity link from the sender.
  function cancelOutgoingPendingEntityLink() external {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    PassportEntityLogicV1.cancelOutgoingPendingEntityLink($);
  }

  /// @notice Sets the maximum number of entities that can be linked to a passport
  /// @param maxEntities - the maximum number of entities
  function setMaxEntitiesPerPassport(uint256 maxEntities) external onlyRoleOrAdmin(SETTINGS_MANAGER_ROLE) {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    PassportEntityLogicV1.setMaxEntitiesPerPassport($, maxEntities);
  }

  /// @notice Delegate the passport to another address
  /// The delegator must sign a message where he authorizes the delegatee to request the delegation:
  /// this is done to avoid that a malicious user delegates the personhood to another user without his consent.
  /// Eg: Alice has a personhood where she is not considered a person, she delegates her personhood to Bob, which
  /// is considered a person. Bob now cannot vote because he is not considered a person anymore.
  /// @param delegator - the delegator address
  /// @param deadline - the deadline for the signature
  /// @param signature - the signature of the delegation
  function delegateWithSignature(address delegator, uint256 deadline, bytes memory signature) external {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    PassportDelegationLogicV1.delegateWithSignature($, delegator, deadline, signature);
  }

  /// @notice Delegate the personhood to another address
  /// @dev The delegatee must accept the delegation
  /// Eg: Alice has a personhood where she is not considered a person, she delegates her personhood to Bob, which
  /// is considered a person. Bob now cannot vote because he is not considered a person anymore.
  function delegatePassport(address delegatee) external {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    PassportDelegationLogicV1.delegatePassport($, delegatee);
  }

  /// @notice Allow the delegatee to accept the delegation
  /// @param delegator - the delegator address
  function acceptDelegation(address delegator) external {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    PassportDelegationLogicV1.acceptDelegation($, delegator);
  }

  /// @notice Revoke the delegation (can be done by the delegator or the delegatee)
  function revokeDelegation() external {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    PassportDelegationLogicV1.revokeDelegation($);
  }

  /// @notice Allows a user to deny (and remove) an incoming pending delegation.
  /// @param delegator - the user who is delegating to me (aka the delegator)
  function denyIncomingPendingDelegation(address delegator) external {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    PassportDelegationLogicV1.denyIncomingPendingDelegation($, delegator);
  }

  /// @notice Allows a delegator to cancel (and remove) the outgoing pending delegation.
  function cancelOutgoingPendingDelegation() external {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    PassportDelegationLogicV1.cancelOutgoingPendingDelegation($);
  }

  /// @notice Signals a user
  function signalUser(address _user) external onlyRoleOrAdmin(SIGNALER_ROLE) {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    PassportSignalingLogicV1.signalUser($, _user);
  }

  /// @notice Signals a user with a reason
  function signalUserWithReason(address _user, string memory reason) external onlyRoleOrAdmin(SIGNALER_ROLE) {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    PassportSignalingLogicV1.signalUserWithReason($, _user, reason);
  }

  /// @notice this method allows an app admin to assign a signaler to an app
  /// @param app - the app to assign the signaler to
  /// @param user - the signaler to assign to the app
  function assignSignalerToAppByAppAdmin(bytes32 app, address user) external {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    PassportSignalingLogicV1.assignSignalerToAppByAppAdmin($, app, user);
    _grantRole(SIGNALER_ROLE, user);
  }

  /// @notice this method allows an app admin to remove a signaler from an app
  /// @param user - the signaler to remove from the app
  function removeSignalerFromAppByAppAdmin(address user) external {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    PassportSignalingLogicV1.removeSignalerFromAppByAppAdmin($, user);
    _revokeRole(SIGNALER_ROLE, user);
  }

  /// @notice Sets the signaling threshold
  /// @param threshold - the signaling threshold
  function setSignalingThreshold(uint256 threshold) external onlyRoleOrAdmin(DEFAULT_ADMIN_ROLE) {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    PassportSignalingLogicV1.setSignalingThreshold($, threshold);
  }

  /// @dev Assigns a signaler to an app, allowing us to track the amount of signals from a specific app
  /// @notice to be used together with grantRole
  /// @param app - the app ID
  /// @param user - the signaler address
  function assignSignalerToApp(bytes32 app, address user) external onlyRoleOrAdmin(ROLE_GRANTER) {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    PassportSignalingLogicV1.assignSignalerToApp($, app, user);
    _grantRole(SIGNALER_ROLE, user);
  }

  /// @dev Removes a signaler from an app
  /// @notice to be used together with revokeRole
  /// @param user - the signaler address
  function removeSignalerFromApp(address user) external onlyRoleOrAdmin(ROLE_GRANTER) {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    PassportSignalingLogicV1.removeSignalerFromApp($, user);
    _revokeRole(SIGNALER_ROLE, user);
  }

  /// @notice Resets the signals of a user with a given reason
  /// @dev assigns the signals of a user to zero
  /// @param user - the address of the user
  /// @param reason - the reason for resetting the signals
  function resetUserSignalsWithReason(address user, string memory reason) external onlyRole(DEFAULT_ADMIN_ROLE) {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    PassportSignalingLogicV1.resetUserSignals($, user, reason);
  }

  /// @notice Resets the signals of a user by app admin
  /// @param user - the user to reset the signals of
  /// @param reason - the reason for resetting the signals
  function resetUserSignalsByAppAdminWithReason(address user, string memory reason) external {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    PassportSignalingLogicV1.resetUserSignalsByAppAdminWithReason($, user, reason);
  }

  /// @notice Sets the minimum galaxy member level
  /// @param _minimumGalaxyMemberLevel The new minimum galaxy member level
  function setMinimumGalaxyMemberLevel(uint256 _minimumGalaxyMemberLevel) external onlyRole(SETTINGS_MANAGER_ROLE) {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    PassportChecksLogicV1.setMinimumGalaxyMemberLevel($, _minimumGalaxyMemberLevel);
  }

  /// @dev Sets the xAllocationVoting contract
  /// @param xAllocationVoting - the xAllocationVoting contract address
  function setXAllocationVoting(
    IXAllocationVotingGovernor xAllocationVoting
  ) external onlyRoleOrAdmin(DEFAULT_ADMIN_ROLE) {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    PassportConfiguratorV1.setXAllocationVoting($, xAllocationVoting);
  }

  /// @dev Sets the galaxy member contract
  /// @param galaxyMember - the galaxy member contract address
  function setGalaxyMember(IGalaxyMember galaxyMember) external onlyRoleOrAdmin(DEFAULT_ADMIN_ROLE) {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    PassportConfiguratorV1.setGalaxyMember($, galaxyMember);
  }

  /// @notice Sets the x2EarnApps contract address
  /// @param _x2EarnApps - the X2EarnApps contract address
  function setX2EarnApps(IX2EarnApps _x2EarnApps) external override onlyRole(DEFAULT_ADMIN_ROLE) {
    PassportStorageTypesV1.PassportStorage storage $ = getPassportStorage();
    PassportConfiguratorV1.setX2EarnApps($, _x2EarnApps);
  }

  // ---------- Overrides ---------- //

  /// @dev Grants a role to an account
  /// @notice Overrides the grantRole function to add a modifier to check if the user has the required role or is the DEFAULT_ADMIN_ROLE
  /// @param role - the role to grant
  /// @param account - the account to grant the role to
  function grantRole(
    bytes32 role,
    address account
  ) public override(AccessControlUpgradeable, IVeBetterPassportV1) onlyRoleOrAdmin(ROLE_GRANTER) {
    _grantRole(role, account);
  }

  /// @dev Revokes a role from an account
  /// @notice Overrides the revokeRole function to add a modifier to check if the user has the required role or is the DEFAULT_ADMIN_ROLE
  /// @param role - the role to revoke
  /// @param account - the account to revoke the role from
  function revokeRole(
    bytes32 role,
    address account
  ) public override(AccessControlUpgradeable, IVeBetterPassportV1) onlyRoleOrAdmin(ROLE_GRANTER) {
    _revokeRole(role, account);
  }
}

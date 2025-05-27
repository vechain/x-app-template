// SPDX-License-Identifier: MIT

//                                      #######
//                                 ################
//                               ####################
//                             ###########   #########
//                            #########      #########
//          #######          #########       #########
//          #########       #########      ##########
//           ##########     ########     ####################
//            ##########   #########  #########################
//              ################### ############################
//               #################  ##########          ########
//                 ##############      ###              ########
//                  ############                       #########
//                    ##########                     ##########
//                     ########                    ###########
//                       ###                    ############
//                                          ##############
//                                    #################
//                                   ##############
//                                   #########

pragma solidity 0.8.20;

import { PassportStorageTypes } from "./PassportStorageTypes.sol";
import { PassportTypes } from "./PassportTypes.sol";
import { PassportEntityLogic } from "./PassportEntityLogic.sol";
import { Checkpoints } from "@openzeppelin/contracts/utils/structs/Checkpoints.sol";
import { PassportClockLogic } from "./PassportClockLogic.sol";

/**
 * @title PassportPoPScoreLogic
 * @dev This library manages the Proof of Participation (PoP) score system for the Passport system.
 * Users gain PoP scores by performing actions in XApps. The scores are influenced by the security level of the app,
 * exponential decay, and various other factors. The PoP score can determine if a user qualifies as a person in the Passport system.
 */
library PassportPoPScoreLogic {
  using Checkpoints for Checkpoints.Trace208;

  // ---------- Events ---------- //
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
  // ---------- Constants ---------- //

  /// @dev Scaling factor for the exponential decay
  uint256 private constant scalingFactor = 1e18;

  // ---------- Getters ---------- //
  /// @notice Gets the cumulative score of a user based on exponential decay for a number of last roundst
  /// @param user - the user address
  /// @param lastRound - the round to consider as a starting point for the cumulative score
  function getCumulativeScoreWithDecay(
    PassportStorageTypes.PassportStorage storage self,
    address user,
    uint256 lastRound
  ) external view returns (uint256) {
    return _cumulativeScoreWithDecay(self, user, lastRound);
  }

  /// @notice Gets the round score of a user
  /// @param user - the user address
  /// @param round - the round
  function userRoundScore(
    PassportStorageTypes.PassportStorage storage self,
    address user,
    uint256 round
  ) internal view returns (uint256) {
    return self.userRoundScore[user][round];
  }

  /// @notice Gets the total score of a user
  /// @param user - the user address
  function userTotalScore(
    PassportStorageTypes.PassportStorage storage self,
    address user
  ) internal view returns (uint256) {
    return self.userTotalScore[user];
  }

  /// @notice Gets the score of a user for an app in a round
  /// @param user - the user address
  /// @param round - the round
  /// @param appId - the app id
  function userRoundScoreApp(
    PassportStorageTypes.PassportStorage storage self,
    address user,
    uint256 round,
    bytes32 appId
  ) internal view returns (uint256) {
    return self.userAppRoundScore[user][round][appId];
  }

  /// @notice Gets the total score of a user for an app
  /// @param user - the user address
  /// @param appId - the app id
  function userAppTotalScore(
    PassportStorageTypes.PassportStorage storage self,
    address user,
    bytes32 appId
  ) internal view returns (uint256) {
    return self.userAppTotalScore[user][appId];
  }

  /// @notice Gets the threshold for a user to be considered a person
  function thresholdPoPScore(PassportStorageTypes.PassportStorage storage self) internal view returns (uint256) {
    return self.popScoreThreshold.latest();
  }

  /// @notice Gets the threshold for a user to be considered a person at a specific timepoint
  function thresholdPoPScoreAtTimepoint(
    PassportStorageTypes.PassportStorage storage self,
    uint48 timepoint
  ) external view returns (uint256) {
    return _thresholdPoPScoreAtTimepoint(self, timepoint);
  }

  /// @notice Gets the security multiplier for an app security
  /// @param security - the app security between LOW, MEDIUM, HIGH
  function securityMultiplier(
    PassportStorageTypes.PassportStorage storage self,
    PassportTypes.APP_SECURITY security
  ) internal view returns (uint256) {
    return self.securityMultiplier[security];
  }

  /// @notice Gets the security level of an app
  /// @param appId - the app id
  function appSecurity(
    PassportStorageTypes.PassportStorage storage self,
    bytes32 appId
  ) internal view returns (PassportTypes.APP_SECURITY) {
    return self.appSecurity[appId];
  }

  /// @notice Gets the round threshold for a user to be considered a person
  function roundsForCumulativeScore(PassportStorageTypes.PassportStorage storage self) internal view returns (uint256) {
    return self.roundsForCumulativeScore;
  }

  /// @notice Gets the decay rate for the cumulative score
  function decayRate(PassportStorageTypes.PassportStorage storage self) internal view returns (uint256) {
    return self.decayRate;
  }

  // ---------- Setters ---------- //

  /// @notice Registers an action for a user
  /// @param user - the user that performed the action
  /// @param appId - the app id of the action
  function registerAction(PassportStorageTypes.PassportStorage storage self, address user, bytes32 appId) external {
    _registerAction(self, user, appId, self.xAllocationVoting.currentRoundId());
  }

  /// @notice Registers an action for a user in a round
  /// @param user - the user that performed the action
  /// @param appId - the app id of the action
  /// @param round - the round id of the action
  function registerActionForRound(
    PassportStorageTypes.PassportStorage storage self,
    address user,
    bytes32 appId,
    uint256 round
  ) external {
    _registerAction(self, user, appId, round);
  }

  /// @notice Function used to seed the passport with old actions by aggregating them
  /// based on (user, appId, round) and summing up the total score offchain
  /// @param user - the user that performed the actions
  /// @param appId - the app id of the actions
  /// @param round - the round id of the actions
  /// @param totalScore - the total score of the actions
  function registerAggregatedActionsForRound(
    PassportStorageTypes.PassportStorage storage self,
    address user,
    bytes32 appId,
    uint256 round,
    uint256 totalScore
  ) external {
    require(user != address(0), "ProofOfParticipation: user is the zero address");
    require(self.x2EarnApps.appExists(appId), "ProofOfParticipation: app does not exist");

    // Check if the user has attached their entity to a passport, if so, use the passport address, else use the users address (passport)
    address passport = PassportEntityLogic._getPassportForEntity(self, user);

    // Track unique apps core user has interacted with
    if (!self.userUniqueAppInteraction[passport][appId]) {
      updateUniqueAppInteractions(self, passport, appId);
    }

    // If the entity is linked to a passport and the entity has not interacted with the app track interaction
    if (passport != user && !self.userUniqueAppInteraction[user][appId]) {
      updateUniqueAppInteractions(self, user, appId);
    }

    // Update the user's score for the round
    self.userRoundScore[passport][round] += totalScore;
    // Update the user's total score
    self.userTotalScore[passport] += totalScore;
    // Update the user's score for the app in the round
    self.userAppRoundScore[passport][round][appId] += totalScore;
    // Update the user's total score for the app
    self.userAppTotalScore[passport][appId] += totalScore;

    emit RegisteredAction(user, passport, appId, round, totalScore);
  }

  /// @notice Sets the threshold for a user to be considered a person
  /// @param threshold - the round threshold
  function setThresholdPoPScore(PassportStorageTypes.PassportStorage storage self, uint208 threshold) external {
    self.popScoreThreshold.push(PassportClockLogic.clock(), threshold);
  }

  /// @notice Sets the number of rounds to consider for the cumulative score
  /// @param rounds - the number of rounds
  function setRoundsForCumulativeScore(PassportStorageTypes.PassportStorage storage self, uint256 rounds) external {
    require(rounds > 0, "ProofOfParticipation: rounds is zero");

    self.roundsForCumulativeScore = rounds;
  }

  /// @notice Sets the  security multiplier
  /// @param security - the app security between LOW, MEDIUM, HIGH
  /// @param multiplier - the multiplier
  function setSecurityMultiplier(
    PassportStorageTypes.PassportStorage storage self,
    PassportTypes.APP_SECURITY security,
    uint256 multiplier
  ) external {
    require(multiplier > 0, "ProofOfParticipation: multiplier is zero");

    self.securityMultiplier[security] = multiplier;
  }

  /// @dev Sets the security level of an app
  /// @param appId - the app id
  /// @param security  - the security level
  function setAppSecurity(
    PassportStorageTypes.PassportStorage storage self,
    bytes32 appId,
    PassportTypes.APP_SECURITY security
  ) external {
    self.appSecurity[appId] = security;
  }

  /// @notice Sets the decay rate for the exponential decay
  /// @param newDecayRate - the decay rate
  function setDecayRate(PassportStorageTypes.PassportStorage storage self, uint256 newDecayRate) external {
    self.decayRate = newDecayRate;
  }

  // ---------- Internal & Private ---------- //

  /// @dev Gets the cumulative score of a user based on exponential decay for a number of last rounds
  /// @dev This function calculates the decayed score f(t) = a * (1 - r)^t
  /// @param user - the user address
  /// @param lastRound - the round to consider as a starting point for the cumulative score
  function _cumulativeScoreWithDecay(
    PassportStorageTypes.PassportStorage storage self,
    address user,
    uint256 lastRound
  ) internal view returns (uint256) {
    // Calculate the starting round for the cumulative score. If the last round is less than the rounds for cumulative score, start from the first round
    uint256 startingRound = lastRound <= self.roundsForCumulativeScore
      ? 1
      : lastRound - self.roundsForCumulativeScore + 1;

    uint256 decayFactor = ((100 - self.decayRate) * scalingFactor) / 100;

    // Calculate the cumulative score with exponential decay
    uint256 cumulativeScore = 0;
    for (uint256 round = startingRound; round <= lastRound; round++) {
      cumulativeScore = self.userRoundScore[user][round] + (cumulativeScore * decayFactor) / scalingFactor;
    }

    return cumulativeScore;
  }

  /**
   * @dev Internal funciton to get the threshold for a user to be considered a person at a specific timepoint
   */
  function _thresholdPoPScoreAtTimepoint(
    PassportStorageTypes.PassportStorage storage self,
    uint48 timepoint
  ) internal view returns (uint256) {
    return self.popScoreThreshold.upperLookupRecent(timepoint);
  }

  /**
   * @dev Registers an action for a user in a specific round. If the user is an entity attached to a passport,
   * the passport will receive the score instead of the entity. The score is calculated based on the security level of the app.
   * @param self The storage object for the Passport contract.
   * @param user The address of the user (or entity) that performed the action.
   * @param appId The ID of the app where the action took place.
   * @param round The round or timepoint in which the action occurred.
   */
  function _registerAction(
    PassportStorageTypes.PassportStorage storage self,
    address user,
    bytes32 appId,
    uint256 round
  ) private {
    require(user != address(0), "ProofOfParticipation: user is the zero address");

    require(self.x2EarnApps.appExists(appId), "ProofOfParticipation: app does not exist");

    // If app was just added and the security level is not set, set it to LOW by default
    if (self.appSecurity[appId] == PassportTypes.APP_SECURITY.NONE) {
      return;
    }

    // If user is blacklisted, do not register the action
    if (self.blacklisted[user]) {
      return;
    }

    // Check if the user has attached their entity to a passport, if so, use the passport address, else use the users address (passport)
    address passport = PassportEntityLogic._getPassportForEntity(self, user);

    // Track unique apps core user has interacted with
    if (!self.userUniqueAppInteraction[passport][appId]) {
      updateUniqueAppInteractions(self, passport, appId);
    }

    // If the entity is linked to a passport and the entity has not interacted with the app track interaction
    if (passport != user && !self.userUniqueAppInteraction[user][appId]) {
      updateUniqueAppInteractions(self, user, appId);
    }

    // Calculate the action score, can be min 0, max 6
    uint256 actionScore = self.securityMultiplier[self.appSecurity[appId]];

    // Update the user's score for the round
    self.userRoundScore[passport][round] += actionScore;
    // Update the user's total score
    self.userTotalScore[passport] += actionScore;
    // Update the user's score for the app in the round
    self.userAppRoundScore[passport][round][appId] += actionScore;
    // Update the user's total score for the app
    self.userAppTotalScore[passport][appId] += actionScore;

    emit RegisteredAction(user, passport, appId, round, actionScore);
  }

  /**
   * @dev Updates the record of unique app interactions for a user. If this is the user's first interaction
   * with the specified app, the function marks the interaction as unique and stores the app ID in the user's
   * list of interacted apps.
   * @param self The storage object for the Passport contract.
   * @param user The address of the user whose app interactions are being tracked.
   * @param appId The ID of the app that the user has interacted with.
   */
  function updateUniqueAppInteractions(
    PassportStorageTypes.PassportStorage storage self,
    address user,
    bytes32 appId
  ) internal {
    // This is the first time the user interacts with this app
    self.userUniqueAppInteraction[user][appId] = true;

    // Add the appId to the user's interacted apps array
    self.userInteractedApps[user].push(appId);
  }
}

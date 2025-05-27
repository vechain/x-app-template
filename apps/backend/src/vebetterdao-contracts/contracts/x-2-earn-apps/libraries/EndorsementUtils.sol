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

import { VechainNodesDataTypes } from "../../libraries/VechainNodesDataTypes.sol";
import { PassportTypes } from "../../ve-better-passport/libraries/PassportTypes.sol";
import { INodeManagement } from "../../interfaces/INodeManagement.sol";
import { IVeBetterPassport } from "../../interfaces/IVeBetterPassport.sol";

/**
 * @title EndorsementUtils
 * @dev Utility library for handling endorsements of applications in a voting context.
 * It manages endorsements, endorsement scores, endorsement status, and app eligibility
 * for voting by interacting with node levels and managing endorsement checkpoints.
 */
library EndorsementUtils {
  /**
   * @dev Emitted when an app is endorsed or unendorsed.
   * @param appId The unique identifier of the app.
   * @param endorser The node ID of the endorser.
   * @param endorsed Boolean indicating endorsement (true) or unendorsement (false).
   */
  event AppEndorsed(bytes32 indexed appId, uint256 endorser, bool endorsed);

  /**
   * @dev Emitted when node strength scores are updated.
   * @param nodeStrengthScores Updated scores for different node levels.
   */
  event NodeStrengthScoresUpdated(VechainNodesDataTypes.NodeStrengthScores nodeStrengthScores);

  /**
   * @dev Emitted when the endorsement status of an app changes.
   * @param appId The unique identifier of the app.
   * @param endorsed Boolean indicating endorsement (true) or unendorsement (false).
   */
  event AppEndorsementStatusUpdated(bytes32 indexed appId, bool endorsed);

  /**
   * @dev Emitted when the grace period starts for an app that has been unendorsed.
   * @param appId The unique identifier of the app.
   * @param startBlock The block number when the grace period started.
   * @param endBlock The block number when the grace period ends.
   */
  event AppUnendorsedGracePeriodStarted(bytes32 indexed appId, uint48 startBlock, uint48 endBlock);

  // ------------------------------- Getter Functions -------------------------------
  /**
   * @notice Retrieves the endorsers of a given app.
   * @param _appEndorsers Mapping of app IDs to arrays of endorsing node IDs.
   * @param _nodeManagementContract The node management contract to retrieve node information.
   * @param appId The unique identifier of the app.
   * @return address[] Array of addresses of the endorsers.
   */
  function getEndorsers(
    mapping(bytes32 => uint256[]) storage _appEndorsers,
    INodeManagement _nodeManagementContract,
    bytes32 appId
  ) external view returns (address[] memory) {
    uint256 length = _appEndorsers[appId].length;
    address[] memory endorsers = new address[](length);
    uint256 count = 0;

    for (uint256 i = 0; i < length; i++) {
      address endorser = _nodeManagementContract.getNodeManager(_appEndorsers[appId][i]);
      if (endorser != address(0)) {
        endorsers[count] = endorser;
        count++;
      }
    }

    assembly {
      mstore(endorsers, count)
    }

    return endorsers;
  }

  /**
   * @notice Calculates the total endorsement score for a user's nodes.
   * @param _nodeEnodorsmentScore Mapping of endorsement scores for each node level.
   * @param _nodeManagementContract The node management contract to retrieve node information.
   * @param user The address of the user whose endorsement score to calculate.
   * @return uint256 The total endorsement score for the user's nodes.
   */
  function getUsersEndorsementScore(
    mapping(VechainNodesDataTypes.NodeStrengthLevel => uint256) storage _nodeEnodorsmentScore,
    INodeManagement _nodeManagementContract,
    address user
  ) external view returns (uint256) {
    VechainNodesDataTypes.NodeStrengthLevel[] memory nodeLevels = _nodeManagementContract.getUsersNodeLevels(user);
    uint256 totalScore;

    for (uint256 i; i < nodeLevels.length; i++) {
      totalScore += _nodeEnodorsmentScore[nodeLevels[i]];
    }

    return totalScore;
  }

  // ------------------------------- Setter Functions -------------------------------
  /**
   * @notice Calculates the score of an app based on its endorsers, and removes a specified endorser if needed.
   * @param _nodeEnodorsmentScore Mapping of endorsement scores for each node level.
   * @param _nodeToEndorsedApp Mapping of node IDs to the app ID they are currently endorsing.
   * @param _appEndorsers Mapping of app IDs to arrays of node IDs that have endorsed them.
   * @param _appScores Mapping of app IDs to their calculated endorsement scores.
   * @param _nodeManagementContract The node management contract to retrieve node levels.
   * @param appId The unique identifier of the app.
   * @param endorserToRemove The node ID of the endorser to remove.
   * @return uint256 The updated score of the app.
   */
  function getScoreAndRemoveEndorsement(
    mapping(VechainNodesDataTypes.NodeStrengthLevel => uint256) storage _nodeEnodorsmentScore,
    mapping(uint256 => bytes32) storage _nodeToEndorsedApp,
    mapping(bytes32 => uint256[]) storage _appEndorsers,
    mapping(bytes32 => uint256) storage _appScores,
    INodeManagement _nodeManagementContract,
    bytes32 appId,
    uint256 endorserToRemove
  ) external returns (uint256) {
    uint256 score;

    // Iterate over the list of endorsers for the given app
    for (uint256 i; i < _appEndorsers[appId].length; ) {
      // Get the current endorser's node id
      uint256 endorser = _appEndorsers[appId][i];
      // Get the node level of the endorser
      VechainNodesDataTypes.NodeStrengthLevel nodeLevel = _nodeManagementContract.getNodeLevel(endorser);

      // Check if the endorser's node level is 0 or if the endorser is the one to be removed
      if (nodeLevel == VechainNodesDataTypes.NodeStrengthLevel.None || endorser == endorserToRemove) {
        // Remove endorser by swapping with the last element and then reducing the length
        _appEndorsers[appId][i] = _appEndorsers[appId][_appEndorsers[appId].length - 1];
        _appEndorsers[appId].pop();

        // Emit an event indicating the app has been unendorsed by the node ID
        emit AppEndorsed(appId, endorser, false);

        // Delete the endorser from the endorsers mapping
        delete _nodeToEndorsedApp[endorser];
      } else {
        // Add the endorser's score to the total score
        score += _nodeEnodorsmentScore[nodeLevel];
        i++; // Only increment i if we didn't remove an endorser
      }
    }

    // Store the latest score of the app
    _appScores[appId] = score;

    // Return the total score of the app
    return score;
  }

  /**
   * @notice Updates the list of apps pending endorsement by adding or removing the specified app.
   * @param unendorsedApps The list of currently unendorsed apps.
   * @param unendorsedAppsIndex Mapping of app IDs to their index in the unendorsedApps array.
   * @param appId The unique identifier of the app to update.
   * @param remove Boolean indicating if the app should be removed from pending endorsement (true).
   */
  function updateAppsPendingEndorsement(
    bytes32[] storage unendorsedApps,
    mapping(bytes32 => uint256) storage unendorsedAppsIndex,
    bytes32 appId,
    bool remove
  ) public {
    if (remove) {
      /**
       *  If the app is no longer pending endorsement we need to remove it from the _unendorsedApps array
       *
       * In order to remove an app from the _unendorsedApps array correctly we need to:
       * 1) Move the element in the last position of the array to the index we want to remove
       * 2) Update the `_unendorsedAppsIndex` mapping accordingly.
       * 3) Pop the last element of the _unendorsedApps array and delete the index mapping of the app we removed
       *
       * Example:
       *
       * _unendorsedApps = [A, B, C, D, E]
       * _unendorsedAppsIndex = {A: 1, B: 2, C: 3, D: 4, E: 5}
       *
       * If we want to remove C:
       *
       * 1) Move E to the index of C
       * _unendorsedApps = [A, B, E, D, E]
       *
       * 2) Update the index of E in the mapping
       * _unendorsedAppsIndex = {A: 1, B: 2, C: 3, D: 4, E: 3}
       *
       * 3) Pop the last element of the array and delete the index mapping of the app we removed
       * _unendorsedApps = [A, B, E, D]
       * _unendorsedAppsIndex = {A: 1, B: 2, D: 4, E: 3}
       *
       */
      uint256 index = unendorsedAppsIndex[appId] - 1;
      uint256 lastIndex = unendorsedApps.length - 1;
      bytes32 lastAppId = unendorsedApps[lastIndex];

      unendorsedApps[index] = lastAppId;
      unendorsedAppsIndex[lastAppId] = index + 1;

      unendorsedApps.pop();
      delete unendorsedAppsIndex[appId];
    } else {
      // If the app is pending endorsement we need to add it to the _unendorsedApps array
      unendorsedApps.push(appId);
      // Store index + 1 to avoid zero index
      unendorsedAppsIndex[appId] = unendorsedApps.length;
    }
  }

  /**
   * @notice Updates the endorsement scores for each node strength level.
   * @param nodeEnodorsmentScores Mapping of endorsement scores for each node level.
   * @param nodeStrengthScores New scores for each node strength level.
   *
   * Emits a {NodeStrengthScoresUpdated} event.
   */
  function updateNodeEndorsementScores(
    mapping(VechainNodesDataTypes.NodeStrengthLevel => uint256) storage nodeEnodorsmentScores,
    VechainNodesDataTypes.NodeStrengthScores calldata nodeStrengthScores
  ) external {
    // Set the endorsement score for each node level
    nodeEnodorsmentScores[VechainNodesDataTypes.NodeStrengthLevel.Strength] = nodeStrengthScores.strength; // Strength Node score
    nodeEnodorsmentScores[VechainNodesDataTypes.NodeStrengthLevel.Thunder] = nodeStrengthScores.thunder; // Thunder Node score
    nodeEnodorsmentScores[VechainNodesDataTypes.NodeStrengthLevel.Mjolnir] = nodeStrengthScores.mjolnir; // Mjolnir Node score

    nodeEnodorsmentScores[VechainNodesDataTypes.NodeStrengthLevel.VeThorX] = nodeStrengthScores.veThorX; // VeThor X Node score
    nodeEnodorsmentScores[VechainNodesDataTypes.NodeStrengthLevel.StrengthX] = nodeStrengthScores.strengthX; // Strength X Node score
    nodeEnodorsmentScores[VechainNodesDataTypes.NodeStrengthLevel.ThunderX] = nodeStrengthScores.thunderX; // Thunder X Node score
    nodeEnodorsmentScores[VechainNodesDataTypes.NodeStrengthLevel.MjolnirX] = nodeStrengthScores.mjolnirX; // Mjolnir X Node score

    emit NodeStrengthScoresUpdated(nodeStrengthScores);
  }

  /**
   * @notice Updates an app's status if its endorsement score threshold is not met.
   * @param appGracePeriodStart Mapping of app IDs to their grace period start time.
   * @param appSecurity Mapping of app IDs to their security status.
   * @param unendorsedApps The list of currently unendorsed apps.
   * @param unendorsedAppsIndex Mapping of app IDs to their index in unendorsedApps.
   * @param veBetterPassport The VeBetterPassport contract to update app security.
   * @param gracePeriodDuration The grace period duration for an unendorsed app.
   * @param isAppUnendorsed Boolean indicating if the app is currently unendorsed.
   * @param clock The current block number.
   * @param appId The unique identifier of the app.
   * @param isEligibleNow Boolean indicating if the app is currently eligible for voting.
   * @return stillEligible Boolean indicating if the app remains eligible for voting.
   *
   * Emits an {AppEndorsementStatusUpdated} or {AppUnendorsedGracePeriodStarted} event.
   */
  function updateStatusIfThresholdNotMet(
    mapping(bytes32 => uint48) storage appGracePeriodStart,
    mapping(bytes32 => PassportTypes.APP_SECURITY) storage appSecurity,
    bytes32[] storage unendorsedApps,
    mapping(bytes32 => uint256) storage unendorsedAppsIndex,
    IVeBetterPassport veBetterPassport,
    uint48 gracePeriodDuration,
    bool isAppUnendorsed,
    uint48 clock,
    bytes32 appId,
    bool isEligibleNow
  ) external returns (bool stillEligible) {
    // If the app is not pending endorsement
    if (!isAppUnendorsed) {
      // Mark the app as not endorsed so that it is added to the list of apps pending endorsement
      updateAppsPendingEndorsement(unendorsedApps, unendorsedAppsIndex, appId, false);
      emit AppEndorsementStatusUpdated(appId, false);
    }

    // If the app has a grace period of 0, set the grace period
    if (appGracePeriodStart[appId] == 0 && isEligibleNow) {
      // Set the grace period start (current block number)
      appGracePeriodStart[appId] = clock;

      // Emit an event indicating the grace period has started for the app
      emit AppUnendorsedGracePeriodStarted(appId, clock, clock + gracePeriodDuration);

      // Return true indicating the app is eligible for voting
      return true;

      // If the X2Earn app is no longer in the grace period and is eligible for voting
    } else if ((clock > appGracePeriodStart[appId] + gracePeriodDuration) && isEligibleNow) {
      // Store the security score of the app
      appSecurity[appId] = veBetterPassport.appSecurity(appId);

      // Set the XAPP security score to 0 in VeBetterPassport
      veBetterPassport.setAppSecurity(appId, PassportTypes.APP_SECURITY.NONE);

      // Return false indicating the app is not eligible for voting
      return false;
    }

    // Return true indicating the app is still eligible for voting
    return true;
  }
}
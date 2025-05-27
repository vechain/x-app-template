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
import { Checkpoints } from "@openzeppelin/contracts/utils/structs/Checkpoints.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";

/**
 * @title VoteEligibilityUtils
 * @dev Utility library for managing voting eligibility status for applications within the system.
 * This library manages eligibility checkpoints, allowing for efficient tracking of voting eligibility
 * changes over time. Eligibility is tracked via Checkpoints to enable time-based queries.
 */
library VoteEligibilityUtils {
  using Checkpoints for Checkpoints.Trace208; // Checkpoints used to track eligibility changes over time

  /**
   * @dev Emitted when an app's eligibility for allocation voting changes.
   * @param appId The unique identifier of the app whose eligibility status was updated.
   * @param isAvailable The new eligibility status for the app.
   */
  event VotingEligibilityUpdated(bytes32 indexed appId, bool isAvailable);

  /**
   * @notice Error for when a future timepoint lookup is requested.
   * @param timepoint The requested timepoint for eligibility lookup.
   * @param clock The current timepoint.
   */
  error ERC5805FutureLookup(uint256 timepoint, uint48 clock);

  // ------------------------------- Setter Functions -------------------------------
  /**
   * @notice Updates an app's voting eligibility checkpoint.
   * @param eligibleApps The list of apps currently eligible for voting.
   * @param isAppEligibleCheckpoints Mapping of app IDs to their eligibility checkpoints.
   * @param eligibleAppIndex Mapping of app IDs to their index in the `eligibleApps` array.
   * @param appId The ID of the app to update eligibility for.
   * @param canBeVoted Boolean indicating whether the app is now eligible for voting.
   * @param isEligibleNow The current eligibility status of the app.
   * @param clock The current timepoint for the checkpoint.
   *
   * Emits a {VotingEligibilityUpdated} event.
   */
  function updateVotingEligibility(
    bytes32[] storage eligibleApps,
    mapping(bytes32 appId => Checkpoints.Trace208) storage isAppEligibleCheckpoints,
    mapping(bytes32 appId => uint256 index) storage eligibleAppIndex,
    bytes32 appId,
    bool canBeVoted,
    bool isEligibleNow,
    uint48 clock
  ) external {
    // Exit if no state change is required
    if (isEligibleNow == canBeVoted) {
      return;
    }

    // Update eligibility checkpoint with the new status
    _pushCheckpoint(isAppEligibleCheckpoints[appId], clock, canBeVoted ? SafeCast.toUint208(1) : SafeCast.toUint208(0));

    if (!canBeVoted) {
      // Remove app from eligibility if it is no longer eligible
      uint256 index = eligibleAppIndex[appId];
      uint256 lastIndex = eligibleApps.length - 1;
      bytes32 lastAppId = eligibleApps[lastIndex];

      eligibleApps[index] = lastAppId;
      eligibleAppIndex[lastAppId] = index;

      eligibleApps.pop();
      delete eligibleAppIndex[appId];
    } else {
      // Add app to eligibility if it is now eligible
      eligibleApps.push(appId);
      eligibleAppIndex[appId] = eligibleApps.length - 1;
    }

    emit VotingEligibilityUpdated(appId, canBeVoted);
  }

  // ------------------------------- Getter Functions -------------------------------
  /**
   * @notice Checks if an app is eligible for voting at a specific timepoint.
   * @param isAppEligibleCheckpoints Mapping of app IDs to their eligibility checkpoints.
   * @param appId The ID of the app being queried.
   * @param timepoint The timepoint to check for eligibility.
   * @param appExists Boolean indicating if the app exists.
   * @param currentTimepoint The current timepoint.
   * @return Boolean indicating if the app is eligible for voting at the specified timepoint.
   *
   * Reverts with {ERC5805FutureLookup} if `timepoint` is in the future.
   */
  function isEligible(
    mapping(bytes32 => Checkpoints.Trace208) storage isAppEligibleCheckpoints,
    bytes32 appId,
    uint256 timepoint,
    bool appExists,
    uint48 currentTimepoint
  ) external view returns (bool) {
    if (!appExists) {
      return false;
    }

    if (timepoint > currentTimepoint) {
      revert ERC5805FutureLookup(timepoint, currentTimepoint);
    }

    return isAppEligibleCheckpoints[appId].upperLookupRecent(SafeCast.toUint48(timepoint)) == 1;
  }

  // ------------------------------- Private Functions -------------------------------
  /**
   * @dev Stores a new eligibility checkpoint for an app.
   * @param store The checkpoint storage to update.
   * @param clock The current timepoint for the checkpoint.
   * @param delta The eligibility value to store in the checkpoint.
   * @return previousValue The value before the update.
   * @return newValue The updated value.
   */
  function _pushCheckpoint(
    Checkpoints.Trace208 storage store,
    uint48 clock,
    uint208 delta
  ) private returns (uint208 previousValue, uint208 newValue) {
    return store.push(clock, delta);
  }
}

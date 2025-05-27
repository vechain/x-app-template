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

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { X2EarnAppsUpgradeableV1 } from "../X2EarnAppsUpgradeableV1.sol";
import { Checkpoints } from "@openzeppelin/contracts/utils/structs/Checkpoints.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";

/**
 * @title VoteEligibilityUpgradeable
 * @dev Contract module that provides the vote eligibility functionalities of the x2earn apps.
 * By deafult every new added app becomes eligible for voting. The eligibility can be changed.
 * All eligible apps are stored in an array and can be retrieved at any tiem. Since eligibility of an app can change over time
 * we also have a checkpoint to track the changes for each single app (not for the array which is always up to date).
 * This is needed beacuse other contracts (like XAllocationPool) may want to know if a specific app was eligible for voting at a specific timepoint.
 */
abstract contract VoteEligibilityUpgradeable is Initializable, X2EarnAppsUpgradeableV1 {
  using Checkpoints for Checkpoints.Trace208; // Checkpoints used to track eligibility changes over time

  /// @custom:storage-location erc7201:b3tr.storage.X2EarnApps.VoteEligibility
  struct VoteEligibilityStorage {
    bytes32[] _eligibleApps; // Array containing an up to date list of apps that are eligible for voting
    mapping(bytes32 appId => uint256 index) _eligibleAppIndex; // Mapping from app ID to index in the _eligibleApps array, so we can remove an app in O(1)
    mapping(bytes32 appId => Checkpoints.Trace208) _isAppEligibleCheckpoints; // Checkpoints to track the eligibility changes of an app over time
  }

  // keccak256(abi.encode(uint256(keccak256("b3tr.storage.X2EarnApps.VoteEligibility")) - 1)) & ~bytes32(uint256(0xff))
  bytes32 private constant VoteEligibilityStorageLocation =
    0xb5b8d618af1ffb8d5bcc4bd23f445ba34ed08d7a16d1e1b5411cfbe7913e5900;

  function _getVoteEligibilityStorage() internal pure returns (VoteEligibilityStorage storage $) {
    assembly {
      $.slot := VoteEligibilityStorageLocation
    }
  }

  /**
   * @dev Initializes the contract
   */
  function __VoteEligibility_init() internal onlyInitializing {
    __VoteEligibility_init_unchained();
  }

  function __VoteEligibility_init_unchained() internal onlyInitializing {}

  // ---------- Internal ---------- //

  /**
   * @dev Update the app availability for voting checkpoint.
   */
  function _setVotingEligibility(bytes32 appId, bool canBeVoted) internal override {
    if (!appExists(appId)) {
      revert X2EarnNonexistentApp(appId);
    }

    VoteEligibilityStorage storage $ = _getVoteEligibilityStorage();

    // We update the checkpoint with the new Eligibility status
    _pushCheckpoint($._isAppEligibleCheckpoints[appId], canBeVoted ? SafeCast.toUint208(1) : SafeCast.toUint208(0));

    if (!canBeVoted) {
      // If the app is not eligible for voting we need to remove it from the _eligibleApps array
      /**
       * In order to remove an app from the _eligibleApps array correctly we need to:
       * 1) move the element in the last position of the array to the index we want to remove
       * 2) Update the `_eligibleAppIndex` mapping accordingly.
       * 3) pop() the last element of the _eligibleApps array and delete the index mapping of the app we removed
       *
       * Example:
       *
       * _eligibleApps = [A, B, C, D, E]
       * _eligibleAppIndex = {A: 0, B: 1, C: 2, D: 3, E: 4}
       *
       * If we want to remove C:
       *
       * 1) Move E to the index of C
       * _eligibleApps = [A, B, E, D, E]
       *
       * 2) Update the index of E in the mapping
       * _eligibleAppIndex = {A: 0, B: 1, C: 2, D: 3, E: 2}
       *
       * 3) pop() the last element of the array and delete the index mapping of the app we removed
       * _eligibleApps = [A, B, E, D]
       * _eligibleAppIndex = {A: 0, B: 1, D: 3, E: 2}
       *
       */
      uint256 index = $._eligibleAppIndex[appId];
      uint256 lastIndex = $._eligibleApps.length - 1;
      bytes32 lastAppId = $._eligibleApps[lastIndex];

      $._eligibleApps[index] = lastAppId;
      $._eligibleAppIndex[lastAppId] = index;

      $._eligibleApps.pop();
      delete $._eligibleAppIndex[appId];
    } else {
      // If the app is eligible for voting we need to add it to the _eligibleApps array
      $._eligibleApps.push(appId);
      $._eligibleAppIndex[appId] = $._eligibleApps.length - 1;
    }

    emit VotingEligibilityUpdated(appId, canBeVoted);
  }

  /**
   * @dev Store a new checkpoint for the app's Eligibility.
   */
  function _pushCheckpoint(Checkpoints.Trace208 storage store, uint208 delta) private returns (uint208, uint208) {
    return store.push(clock(), delta);
  }

  // ---------- Getters ---------- //

  /**
   * @dev All apps that are currently eligible for voting in x-allocation rounds
   */
  function allEligibleApps() public view returns (bytes32[] memory) {
    VoteEligibilityStorage storage $ = _getVoteEligibilityStorage();

    return $._eligibleApps;
  }

  /**
   * @dev Returns true if an app is eligible for voting in a specific timepoint.
   *
   * @param appId the hashed name of the app
   * @param timepoint the timepoint when the app should be checked for Eligibility
   */
  function isEligible(bytes32 appId, uint256 timepoint) public view override returns (bool) {
    if (!appExists(appId)) {
      return false;
    }

    VoteEligibilityStorage storage $ = _getVoteEligibilityStorage();

    uint48 currentTimepoint = clock();
    if (timepoint > currentTimepoint) {
      revert ERC5805FutureLookup(timepoint, currentTimepoint);
    }

    return $._isAppEligibleCheckpoints[appId].upperLookupRecent(SafeCast.toUint48(timepoint)) == 1;
  }

  /**
   * @dev Returns true if an app is eligible for voting in the current block.
   *
   * @param appId the hashed name of the app
   */
  function isEligibleNow(bytes32 appId) public view override returns (bool) {
    if (!appExists(appId)) {
      return false;
    }

    VoteEligibilityStorage storage $ = _getVoteEligibilityStorage();

    return $._isAppEligibleCheckpoints[appId].latest() == 1;
  }
}

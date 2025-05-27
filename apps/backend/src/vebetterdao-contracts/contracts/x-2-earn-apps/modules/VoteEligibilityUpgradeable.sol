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
import { X2EarnAppsUpgradeable } from "../X2EarnAppsUpgradeable.sol";
import { Checkpoints } from "@openzeppelin/contracts/utils/structs/Checkpoints.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { VoteEligibilityUtils } from "../libraries/VoteEligibilityUtils.sol";

/**
 * @title VoteEligibilityUpgradeable
 * @dev Contract module that provides the vote eligibility functionalities of the x2earn apps.
 * By deafult every new added app becomes eligible for voting. The eligibility can be changed.
 * All eligible apps are stored in an array and can be retrieved at any tiem. Since eligibility of an app can change over time
 * we also have a checkpoint to track the changes for each single app (not for the array which is always up to date).
 * This is needed beacuse other contracts (like XAllocationPool) may want to know if a specific app was eligible for voting at a specific timepoint.
 */
abstract contract VoteEligibilityUpgradeable is Initializable, X2EarnAppsUpgradeable {
  using Checkpoints for Checkpoints.Trace208; // Checkpoints used to track eligibility changes over time

  /// @custom:storage-location erc7201:b3tr.storage.X2EarnApps.VoteEligibility
  struct VoteEligibilityStorage {
    bytes32[] _eligibleApps; // Array containing an up to date list of apps that are eligible for voting
    mapping(bytes32 appId => uint256 index) _eligibleAppIndex; // Mapping from app ID to index in the _eligibleApps array, so we can remove an app in O(1)
    mapping(bytes32 appId => Checkpoints.Trace208) _isAppEligibleCheckpoints; // Checkpoints to track the eligibility changes of an app over time
    mapping(bytes32 => bool) _blackList; // Mapping to store the blacklisted apps
  }

  // keccak256(abi.encode(uint256(keccak256("b3tr.storage.X2EarnApps.VoteEligibility")) - 1)) & ~bytes32(uint256(0xff))
  bytes32 private constant VoteEligibilityStorageLocation =
    0xb5b8d618af1ffb8d5bcc4bd23f445ba34ed08d7a16d1e1b5411cfbe7913e5900;

  function _getVoteEligibilityStorage() internal pure returns (VoteEligibilityStorage storage $) {
    assembly {
      $.slot := VoteEligibilityStorageLocation
    }
  }

  // ---------- Internal ---------- //

  /**
   * @dev Update the app availability for voting checkpoint.
   */
  function _setVotingEligibility(bytes32 appId, bool canBeVoted) internal override {
    VoteEligibilityStorage storage $ = _getVoteEligibilityStorage();

    // Use VoteEligibilityUtils to update the eligibility checkpoint
    VoteEligibilityUtils.updateVotingEligibility(
      $._eligibleApps,
      $._isAppEligibleCheckpoints,
      $._eligibleAppIndex,
      appId,
      canBeVoted,
      isEligibleNow(appId),
      clock()
    );
  }

  function _setBlacklist(bytes32 _appId, bool _isBlacklisted) internal virtual {
    VoteEligibilityStorage storage $ = _getVoteEligibilityStorage();

    $._blackList[_appId] = _isBlacklisted;
    emit BlacklistUpdated(_appId, _isBlacklisted);
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
   * @dev Returns true if an app is blacklisted.
   */
  function isBlacklisted(bytes32 appId) public view virtual override returns (bool) {
    VoteEligibilityStorage storage $ = _getVoteEligibilityStorage();

    return $._blackList[appId];
  }

  /**
   * @dev Returns true if an app is eligible for voting in a specific timepoint.
   *
   * @param appId the hashed name of the app
   * @param timepoint the timepoint when the app should be checked for Eligibility
   */
  function isEligible(bytes32 appId, uint256 timepoint) public view override returns (bool) {
    VoteEligibilityStorage storage $ = _getVoteEligibilityStorage();

    // Use VoteEligibilityUtils to check if the app is eligible at the given timepoint
    return VoteEligibilityUtils.isEligible(
      $._isAppEligibleCheckpoints,
      appId,
      timepoint,
      appExists(appId),
      clock()
    );
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

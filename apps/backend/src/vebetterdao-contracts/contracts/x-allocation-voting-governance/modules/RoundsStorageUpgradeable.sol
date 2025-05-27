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

import { XAllocationVotingGovernor } from "../XAllocationVotingGovernor.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { X2EarnAppsDataTypes } from "../../libraries/X2EarnAppsDataTypes.sol";

/**
 * @title RoundsStorageUpgradeable
 * @dev Extension of {XAllocationVotingGovernor} for storing rounds data and managing the rounds lifecycle.
 */
abstract contract RoundsStorageUpgradeable is Initializable, XAllocationVotingGovernor {
  struct RoundCore {
    address proposer;
    uint48 voteStart;
    uint32 voteDuration;
  }

  /// @custom:storage-location erc7201:b3tr.storage.XAllocationVotingGovernor.RoundsStorage
  struct RoundsStorageStorage {
    uint256 _roundCount; // counter to count the number of proposals and also used to create the id
    mapping(uint256 roundId => RoundCore) _rounds; // mapping to store the round data
    mapping(uint256 roundId => bytes32[]) _appsEligibleForVoting; // mapping to store the apps eligible for voting in each round
  }

  // keccak256(abi.encode(uint256(keccak256("b3tr.storage.XAllocationVotingGovernor.RoundsStorage")) - 1)) & ~bytes32(uint256(0xff))
  bytes32 private constant RoundsStorageStorageLocation =
    0x0f5210c47c3bb73c471770a1cbb5b7ddc03c0ec886694cc17ae21d1f595f1900;

  function _getRoundsStorageStorage() internal pure returns (RoundsStorageStorage storage $) {
    assembly {
      $.slot := RoundsStorageStorageLocation
    }
  }

  /**
   * @dev Initializes the contract
   */
  function __RoundsStorage_init() internal onlyInitializing {
    __RoundsStorage_init_unchained();
  }

  function __RoundsStorage_init_unchained() internal onlyInitializing {}

  // ------- Setters ------- //

  /**
   * @dev Internal function to start a new round
   * @param proposer The address of the proposer
   * @return roundId The id of the new round
   *
   * Emits a {RoundCreated} event
   */
  function _startNewRound(address proposer) internal virtual override returns (uint256 roundId) {
    RoundsStorageStorage storage $ = _getRoundsStorageStorage();

    ++$._roundCount;
    roundId = $._roundCount;
    if ($._rounds[roundId].voteStart != 0) {
      revert GovernorUnexpectedRoundState(roundId, state(roundId), bytes32(0));
    }

    // Do not run for the first round
    if (roundId > 1) {
      // finalize the previous round
      finalizeRound(roundId - 1);
    }

    // save x-apps that users can vote for
    bytes32[] memory apps = x2EarnApps().allEligibleApps();
    $._appsEligibleForVoting[roundId] = apps;

    _snapshotRoundEarningsCap(roundId);

    uint256 snapshot = clock();
    uint256 duration = votingPeriod();

    RoundCore storage round = $._rounds[roundId];
    round.proposer = proposer;
    round.voteStart = SafeCast.toUint48(snapshot);
    round.voteDuration = SafeCast.toUint32(duration);

    emit RoundCreated(roundId, proposer, snapshot, snapshot + duration, apps);

    // Using a named return variable to avoid stack too deep errors
  }

  // ------- Getters ------- //

  /**
   * @dev Get the data of a round
   */
  function getRound(uint256 roundId) external view returns (RoundCore memory) {
    RoundsStorageStorage storage $ = _getRoundsStorageStorage();
    return $._rounds[roundId];
  }

  /**
   * @dev Get the current round id
   */
  function currentRoundId() public view virtual override returns (uint256) {
    RoundsStorageStorage storage $ = _getRoundsStorageStorage();
    return $._roundCount;
  }

  /**
   * @dev Get the current round start block
   */
  function currentRoundSnapshot() public view virtual override returns (uint256) {
    return roundSnapshot(currentRoundId());
  }

  /**
   * @dev Get the current round deadline block
   */
  function currentRoundDeadline() public view virtual returns (uint256) {
    return roundDeadline(currentRoundId());
  }

  /**
   * @dev Get the start block of a round
   */
  function roundSnapshot(uint256 roundId) public view virtual override returns (uint256) {
    RoundsStorageStorage storage $ = _getRoundsStorageStorage();
    return $._rounds[roundId].voteStart;
  }

  /**
   * @dev Get the deadline block of a round
   */
  function roundDeadline(uint256 roundId) public view virtual override returns (uint256) {
    RoundsStorageStorage storage $ = _getRoundsStorageStorage();
    return $._rounds[roundId].voteStart + $._rounds[roundId].voteDuration;
  }

  /**
   * @dev Get the proposer of a round
   */
  function roundProposer(uint256 roundId) public view virtual returns (address) {
    RoundsStorageStorage storage $ = _getRoundsStorageStorage();
    return $._rounds[roundId].proposer;
  }

  /**
   * @dev Get the ids of the apps eligible for voting in a round
   */
  function getAppIdsOfRound(uint256 roundId) public view override returns (bytes32[] memory) {
    RoundsStorageStorage storage $ = _getRoundsStorageStorage();
    return $._appsEligibleForVoting[roundId];
  }

  /**
   * @dev Get all the apps in the form of {App} eligible for voting in a round
   *
   * @notice This function could not be efficient with a large number of apps, in that case, use {getAppIdsOfRound}
   * and then call {IX2EarnApps-app} for each app id
   */
  function getAppsOfRound(
    uint256 roundId
  ) external view returns (X2EarnAppsDataTypes.AppWithDetailsReturnType[] memory) {
    RoundsStorageStorage storage $ = _getRoundsStorageStorage();

    bytes32[] memory appsInRound = $._appsEligibleForVoting[roundId];
    uint256 length = appsInRound.length;
    X2EarnAppsDataTypes.AppWithDetailsReturnType[] memory allApps = new X2EarnAppsDataTypes.AppWithDetailsReturnType[](
      length
    );

    for (uint i; i < length; i++) {
      allApps[i] = x2EarnApps().app(appsInRound[i]);
    }
    return allApps;
  }
}

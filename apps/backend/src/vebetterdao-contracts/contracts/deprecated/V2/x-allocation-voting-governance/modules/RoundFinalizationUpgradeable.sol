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

/**
 * @title RoundFinalizationUpgradeable
 * @notice Extension of {XAllocationVotingGovernor} that handles the finalization of rounds
 * @dev If a round does not meet the quorum (RoundState.Failed) we need to know the last round that succeeded,
 * so we can calculate the earnings for the x-2-earn-apps upon that round. By always pointing each round at the last succeeded one, if a round fails,
 * it will be enough to look at what round the previous one points to.
 */
abstract contract RoundFinalizationUpgradeable is Initializable, XAllocationVotingGovernor {
  /// @custom:storage-location erc7201:b3tr.storage.XAllocationVotingGovernor.RoundFinalization
  struct RoundFinalizationStorage {
    mapping(uint256 roundId => uint256) _latestSucceededRoundId;
    mapping(uint256 roundId => bool) _roundFinalized;
  }

  // keccak256(abi.encode(uint256(keccak256("b3tr.storage.XAllocationVotingGovernor.RoundFinalization")) - 1)) & ~bytes32(uint256(0xff))
  bytes32 private constant RoundFinalizationStorageLocation =
    0x7dd3251b9882a8b07dc283a0b43197aa2be3a6af1a7f0284070fe5d86e502500;

  function _getRoundFinalizationStorage() internal pure returns (RoundFinalizationStorage storage $) {
    assembly {
      $.slot := RoundFinalizationStorageLocation
    }
  }

  /**
   * @dev Initializes the contract
   */
  function __RoundFinalization_init() internal onlyInitializing {
    __RoundFinalization_init_unchained();
  }

  function __RoundFinalization_init_unchained() internal onlyInitializing {}

  // ------- Setters ------- //

  /**
   * @dev Store the last succeeded round for the given round
   * @param roundId The round to finalize
   */
  function finalizeRound(uint256 roundId) public virtual override {
    require(!isActive(roundId), "XAllocationVotingGovernor: round is not ended yet");

    RoundFinalizationStorage storage $ = _getRoundFinalizationStorage();
    // First round is always considered succeeded
    if (roundId == 1) {
      $._latestSucceededRoundId[roundId] = 1;
      $._roundFinalized[roundId] = true;
      return;
    }

    if (state(roundId) == RoundState.Succeeded) {
      // if round is succeeded, it is the last succeeded round
      $._latestSucceededRoundId[roundId] = roundId;
      $._roundFinalized[roundId] = true;
    } else if (state(roundId) == RoundState.Failed) {
      // if round is failed, it points to the last succeeded round
      $._latestSucceededRoundId[roundId] = $._latestSucceededRoundId[roundId - 1];
      $._roundFinalized[roundId] = true;
    }
  }

  // ------- Getters ------- //

  /**
   * @dev Get the last succeeded round for the given round
   */
  function latestSucceededRoundId(uint256 roundId) external view returns (uint256) {
    RoundFinalizationStorage storage $ = _getRoundFinalizationStorage();
    return $._latestSucceededRoundId[roundId];
  }

  /**
   * @dev Check if the round is finalized
   */
  function isFinalized(uint256 roundId) external view returns (bool) {
    RoundFinalizationStorage storage $ = _getRoundFinalizationStorage();
    return $._roundFinalized[roundId];
  }
}

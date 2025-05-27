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

import { GovernorStorageTypes } from "./GovernorStorageTypes.sol";
import { GovernorClockLogic } from "./GovernorClockLogic.sol";
import { GovernorVotesLogic } from "./GovernorVotesLogic.sol";
import { GovernorProposalLogic } from "./GovernorProposalLogic.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { Checkpoints } from "@openzeppelin/contracts/utils/structs/Checkpoints.sol";

/// @title GovernorQuorumLogic
/// @notice Library for managing quorum numerators using checkpointed data structures.
library GovernorQuorumLogic {
  using Checkpoints for Checkpoints.Trace208;

  /// @notice Error that is thrown when the new quorum numerator exceeds the denominator.
  /// @param quorumNumerator The attempted new numerator that failed the update.
  /// @param quorumDenominator The denominator against which the numerator was compared.
  error GovernorInvalidQuorumFraction(uint256 quorumNumerator, uint256 quorumDenominator);

  /// @notice Emitted when the quorum numerator is updated.
  /// @param oldNumerator The numerator before the update.
  /// @param newNumerator The numerator after the update.
  event QuorumNumeratorUpdated(uint256 oldNumerator, uint256 newNumerator);

  /** ------------------ GETTERS ------------------ **/

  /// @notice Retrieves the quorum denominator, which is a constant in this implementation.
  /// @return The quorum denominator (constant value of 100).
  function quorumDenominator() internal pure returns (uint256) {
    return 100;
  }

  /// @notice Retrieves the quorum numerator at a specific timepoint using checkpoint data.
  /// @param self The storage structure containing the quorum numerator history.
  /// @param timepoint The specific timepoint for which to fetch the numerator.
  /// @return The quorum numerator at the given timepoint.
  function quorumNumerator(
    GovernorStorageTypes.GovernorStorage storage self,
    uint256 timepoint
  ) public view returns (uint256) {
    uint256 length = self.quorumNumeratorHistory._checkpoints.length;

    // Optimistic search, check the latest checkpoint
    Checkpoints.Checkpoint208 storage latest = self.quorumNumeratorHistory._checkpoints[length - 1];
    uint48 latestKey = latest._key;
    uint208 latestValue = latest._value;
    if (latestKey <= timepoint) {
      return latestValue;
    }

    // Otherwise, do the binary search
    return self.quorumNumeratorHistory.upperLookupRecent(SafeCast.toUint48(timepoint));
  }

  /// @notice Retrieves the latest quorum numerator using the GovernorClockLogic library.
  /// @param self The storage structure containing the quorum numerator history.
  /// @return The latest quorum numerator.
  function quorumNumerator(GovernorStorageTypes.GovernorStorage storage self) public view returns (uint256) {
    return self.quorumNumeratorHistory.latest();
  }

  /**
   * @notice Checks if the quorum has been reached for a proposal.
   * @param self The storage reference for the GovernorStorage.
   * @param proposalId The ID of the proposal.
   * @return True if the quorum has been reached, false otherwise.
   */
  function isQuorumReached(
    GovernorStorageTypes.GovernorStorage storage self,
    uint256 proposalId
  ) external view returns (bool) {
    return quorumReached(self, proposalId);
  }

  /**
   * @notice Returns the quorum for a specific timepoint.
   * @param self The storage reference for the GovernorStorage.
   * @param timepoint The specific timepoint.
   * @return The quorum at the given timepoint.
   */
  function quorum(GovernorStorageTypes.GovernorStorage storage self, uint256 timepoint) public view returns (uint256) {
    return (self.vot3.getPastTotalSupply(timepoint) * quorumNumerator(self, timepoint)) / quorumDenominator();
  }

  /** ------------------ SETTERS ------------------ **/

  /**
   * @notice Updates the quorum numerator to a new value at a specified time, emitting an event upon success.
   * @dev This function should only be called from governance actions where numerators need updating.
   * @dev New numerator must be smaller or equal to the denominator.
   * @param self The storage structure containing the quorum numerator history.
   * @param newQuorumNumerator The new value for the quorum numerator.
   */
  function updateQuorumNumerator(
    GovernorStorageTypes.GovernorStorage storage self,
    uint256 newQuorumNumerator
  ) external {
    uint256 denominator = quorumDenominator();
    uint256 oldQuorumNumerator = quorumNumerator(self);

    if (newQuorumNumerator > denominator) {
      revert GovernorInvalidQuorumFraction(newQuorumNumerator, denominator);
    }

    self.quorumNumeratorHistory.push(GovernorClockLogic.clock(self), SafeCast.toUint208(newQuorumNumerator));

    emit QuorumNumeratorUpdated(oldQuorumNumerator, newQuorumNumerator);
  }

  /** ------------------ INTERNAL FUNCTIONS ------------------ **/

  /**
   * @dev Internal function to check if the quorum has been reached for a proposal.
   * @param self The storage reference for the GovernorStorage.
   * @param proposalId The ID of the proposal.
   * @return True if the quorum has been reached, false otherwise.
   */
  function quorumReached(
    GovernorStorageTypes.GovernorStorage storage self,
    uint256 proposalId
  ) internal view returns (bool) {
    return
      quorum(self, GovernorProposalLogic._proposalSnapshot(self, proposalId)) <= self.proposalTotalVotes[proposalId];
  }
}

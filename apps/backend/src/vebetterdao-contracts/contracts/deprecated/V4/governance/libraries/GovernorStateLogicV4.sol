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

import { GovernorTypesV4 } from "./GovernorTypesV4.sol";
import { GovernorStorageTypesV4 } from "./GovernorStorageTypesV4.sol";
import { GovernorProposalLogicV4 } from "./GovernorProposalLogicV4.sol";
import { GovernorVotesLogicV4 } from "./GovernorVotesLogicV4.sol";
import { GovernorQuorumLogicV4 } from "./GovernorQuorumLogicV4.sol";
import { GovernorClockLogicV4 } from "./GovernorClockLogicV4.sol";
import { GovernorDepositLogicV4 } from "./GovernorDepositLogicV4.sol";

/// @title GovernorStateLogicV4
/// @notice Library for Governor state logic, managing the state transitions and validations of governance proposals.
library GovernorStateLogicV4 {
  /// @notice Bitmap representing all possible proposal states.
  bytes32 internal constant ALL_PROPOSAL_STATES_BITMAP =
    bytes32((2 ** (uint8(type(GovernorTypesV4.ProposalState).max) + 1)) - 1);

  /// @dev Thrown when the `proposalId` does not exist.
  /// @param proposalId The ID of the proposal that does not exist.
  error GovernorNonexistentProposal(uint256 proposalId);

  /// @dev Thrown when the current state of a proposal does not match the expected states.
  /// @param proposalId The ID of the proposal.
  /// @param current The current state of the proposal.
  /// @param expectedStates The expected states of the proposal as a bitmap.
  error GovernorUnexpectedProposalState(
    uint256 proposalId,
    GovernorTypesV4.ProposalState current,
    bytes32 expectedStates
  );

  /** ------------------ GETTERS ------------------ **/

  /**
   * @notice Retrieves the current state of a proposal.
   * @param self The storage reference for the GovernorStorage.
   * @param proposalId The ID of the proposal.
   * @return The current state of the proposal.
   */
  function state(
    GovernorStorageTypesV4.GovernorStorage storage self,
    uint256 proposalId
  ) external view returns (GovernorTypesV4.ProposalState) {
    return _state(self, proposalId);
  }

  /** ------------------ INTERNAL FUNCTIONS ------------------ **/

  /**
   * @dev Internal function to validate the current state of a proposal against expected states.
   * @param self The storage reference for the GovernorStorage.
   * @param proposalId The ID of the proposal.
   * @param allowedStates The bitmap of allowed states.
   * @return The current state of the proposal.
   */
  function validateStateBitmap(
    GovernorStorageTypesV4.GovernorStorage storage self,
    uint256 proposalId,
    bytes32 allowedStates
  ) internal view returns (GovernorTypesV4.ProposalState) {
    GovernorTypesV4.ProposalState currentState = _state(self, proposalId);
    if (encodeStateBitmap(currentState) & allowedStates == bytes32(0)) {
      revert GovernorUnexpectedProposalState(proposalId, currentState, allowedStates);
    }
    return currentState;
  }

  /**
   * @dev Encodes a `ProposalState` into a `bytes32` representation where each bit enabled corresponds to the underlying position in the `ProposalState` enum.
   * @param proposalState The state to encode.
   * @return The encoded state bitmap.
   */
  function encodeStateBitmap(GovernorTypesV4.ProposalState proposalState) internal pure returns (bytes32) {
    return bytes32(1 << uint8(proposalState));
  }

  /**
   * @notice Retrieves the current state of a proposal.
   * @dev See {IB3TRGovernor-state}.
   * @param self The storage reference for the GovernorStorage.
   * @param proposalId The ID of the proposal.
   * @return The current state of the proposal.
   */
  function _state(
    GovernorStorageTypesV4.GovernorStorage storage self,
    uint256 proposalId
  ) internal view returns (GovernorTypesV4.ProposalState) {
    // Load the proposal into memory
    GovernorTypesV4.ProposalCore storage proposal = self.proposals[proposalId];
    bool proposalExecuted = proposal.executed;
    bool proposalCanceled = proposal.canceled;

    if (proposalExecuted) {
      return GovernorTypesV4.ProposalState.Executed;
    }

    if (proposalCanceled) {
      return GovernorTypesV4.ProposalState.Canceled;
    }

    if (proposal.roundIdVoteStart == 0) {
      revert GovernorNonexistentProposal(proposalId);
    }

    // Check if the proposal is pending
    if (self.xAllocationVoting.currentRoundId() < proposal.roundIdVoteStart) {
      return GovernorTypesV4.ProposalState.Pending;
    }

    uint256 currentTimepoint = GovernorClockLogicV4.clock(self);
    uint256 deadline = GovernorProposalLogicV4._proposalDeadline(self, proposalId);

    if (!GovernorDepositLogicV4.proposalDepositReached(self, proposalId)) {
      return GovernorTypesV4.ProposalState.DepositNotMet;
    }

    if (deadline >= currentTimepoint) {
      return GovernorTypesV4.ProposalState.Active;
    } else if (
      !GovernorQuorumLogicV4.quorumReached(self, proposalId) || !GovernorVotesLogicV4.voteSucceeded(self, proposalId)
    ) {
      return GovernorTypesV4.ProposalState.Defeated;
    } else if (GovernorProposalLogicV4.proposalEta(self, proposalId) == 0) {
      return GovernorTypesV4.ProposalState.Succeeded;
    } else {
      bytes32 queueid = self.timelockIds[proposalId];
      if (self.timelock.isOperationPending(queueid)) {
        return GovernorTypesV4.ProposalState.Queued;
      } else if (self.timelock.isOperationDone(queueid)) {
        return GovernorTypesV4.ProposalState.Executed;
      } else {
        return GovernorTypesV4.ProposalState.Canceled;
      }
    }
  }
}

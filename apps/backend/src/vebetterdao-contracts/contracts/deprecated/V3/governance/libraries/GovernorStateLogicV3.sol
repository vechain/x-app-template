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

import { GovernorTypesV3 } from "./GovernorTypesV3.sol";
import { GovernorStorageTypesV3 } from "./GovernorStorageTypesV3.sol";
import { GovernorProposalLogicV3 } from "./GovernorProposalLogicV3.sol";
import { GovernorVotesLogicV3 } from "./GovernorVotesLogicV3.sol";
import { GovernorQuorumLogicV3 } from "./GovernorQuorumLogicV3.sol";
import { GovernorClockLogicV3 } from "./GovernorClockLogicV3.sol";
import { GovernorDepositLogicV3 } from "./GovernorDepositLogicV3.sol";

/// @title GovernorStateLogicV3
/// @notice Library for Governor state logic, managing the state transitions and validations of governance proposals.
library GovernorStateLogicV3 {
  /// @notice Bitmap representing all possible proposal states.
  bytes32 internal constant ALL_PROPOSAL_STATES_BITMAP =
    bytes32((2 ** (uint8(type(GovernorTypesV3.ProposalState).max) + 1)) - 1);

  /// @dev Thrown when the `proposalId` does not exist.
  /// @param proposalId The ID of the proposal that does not exist.
  error GovernorNonexistentProposal(uint256 proposalId);

  /// @dev Thrown when the current state of a proposal does not match the expected states.
  /// @param proposalId The ID of the proposal.
  /// @param current The current state of the proposal.
  /// @param expectedStates The expected states of the proposal as a bitmap.
  error GovernorUnexpectedProposalState(
    uint256 proposalId,
    GovernorTypesV3.ProposalState current,
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
    GovernorStorageTypesV3.GovernorStorage storage self,
    uint256 proposalId
  ) external view returns (GovernorTypesV3.ProposalState) {
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
    GovernorStorageTypesV3.GovernorStorage storage self,
    uint256 proposalId,
    bytes32 allowedStates
  ) internal view returns (GovernorTypesV3.ProposalState) {
    GovernorTypesV3.ProposalState currentState = _state(self, proposalId);
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
  function encodeStateBitmap(GovernorTypesV3.ProposalState proposalState) internal pure returns (bytes32) {
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
    GovernorStorageTypesV3.GovernorStorage storage self,
    uint256 proposalId
  ) internal view returns (GovernorTypesV3.ProposalState) {
    // Load the proposal into memory
    GovernorTypesV3.ProposalCore storage proposal = self.proposals[proposalId];
    bool proposalExecuted = proposal.executed;
    bool proposalCanceled = proposal.canceled;

    if (proposalExecuted) {
      return GovernorTypesV3.ProposalState.Executed;
    }

    if (proposalCanceled) {
      return GovernorTypesV3.ProposalState.Canceled;
    }

    if (proposal.roundIdVoteStart == 0) {
      revert GovernorNonexistentProposal(proposalId);
    }

    // Check if the proposal is pending
    if (self.xAllocationVoting.currentRoundId() < proposal.roundIdVoteStart) {
      return GovernorTypesV3.ProposalState.Pending;
    }

    uint256 currentTimepoint = GovernorClockLogicV3.clock(self);
    uint256 deadline = GovernorProposalLogicV3._proposalDeadline(self, proposalId);

    if (!GovernorDepositLogicV3.proposalDepositReached(self, proposalId)) {
      return GovernorTypesV3.ProposalState.DepositNotMet;
    }

    if (deadline >= currentTimepoint) {
      return GovernorTypesV3.ProposalState.Active;
    } else if (
      !GovernorQuorumLogicV3.quorumReached(self, proposalId) || !GovernorVotesLogicV3.voteSucceeded(self, proposalId)
    ) {
      return GovernorTypesV3.ProposalState.Defeated;
    } else if (GovernorProposalLogicV3.proposalEta(self, proposalId) == 0) {
      return GovernorTypesV3.ProposalState.Succeeded;
    } else {
      bytes32 queueid = self.timelockIds[proposalId];
      if (self.timelock.isOperationPending(queueid)) {
        return GovernorTypesV3.ProposalState.Queued;
      } else if (self.timelock.isOperationDone(queueid)) {
        return GovernorTypesV3.ProposalState.Executed;
      } else {
        return GovernorTypesV3.ProposalState.Canceled;
      }
    }
  }
}

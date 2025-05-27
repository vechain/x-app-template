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

import { GovernorStorageTypesV1 } from "./GovernorStorageTypesV1.sol";
import { GovernorStateLogicV1 } from "./GovernorStateLogicV1.sol";
import { GovernorTypesV1 } from "./GovernorTypesV1.sol";

/// @title GovernorDepositLogic Library
/// @notice Library for managing deposits related to proposals in the Governor contract.
/// @dev This library provides functions to deposit and withdraw tokens for proposals, and to get deposit-related information.
library GovernorDepositLogicV1 {
  /// @dev Emitted when a deposit is made to a proposal.
  event ProposalDeposit(address indexed depositor, uint256 indexed proposalId, uint256 amount);

  /// @dev Thrown when there is no deposit to withdraw.
  error GovernorNoDepositToWithdraw(uint256 proposalId, address depositer);

  /// @dev Thrown when the deposit amount is invalid (must be greater than 0).
  error GovernorInvalidDepositAmount();

  /// @dev Thrown when the proposal ID does not exist.
  error GovernorNonexistentProposal(uint256 proposalId);

  // --------------- SETTERS ---------------
  /**
   * @notice Deposits tokens for a proposal.
   * @dev Proposer and proposal sponsors can contribute towards a proposal's deposit using this function. The proposal must be in the Pending state to make a deposit. The amount deposited from an address is tracked and can be withdrawn by the same address when the voting round is over.
   * @param self The storage reference for the GovernorStorage.
   * @param amount The amount of tokens to deposit.
   * @param proposalId The ID of the proposal.
   */
  function deposit(GovernorStorageTypesV1.GovernorStorage storage self, uint256 amount, uint256 proposalId) external {
    if (amount == 0) {
      revert GovernorInvalidDepositAmount();
    }

    GovernorTypesV1.ProposalCore storage proposal = self.proposals[proposalId];

    if (proposal.roundIdVoteStart == 0) {
      revert GovernorNonexistentProposal(proposalId);
    }

    GovernorStateLogicV1.validateStateBitmap(
      self,
      proposalId,
      GovernorStateLogicV1.encodeStateBitmap(GovernorTypesV1.ProposalState.Pending)
    );

    proposal.depositAmount += amount;

    depositFunds(self, amount, msg.sender, proposalId);
  }

  /**
   * @notice Withdraws tokens previously deposited to a proposal.
   * @dev A depositor can only withdraw their tokens once the proposal is no longer Pending or Active. Each address can only withdraw once per proposal. Reverts if no deposits are available to withdraw or if the deposits have already been withdrawn by the message sender. Reverts if the token transfer fails.
   * @param self The storage reference for the GovernorStorage.
   * @param proposalId The ID of the proposal to withdraw deposits from.
   * @param depositer The address of the depositor.
   */
  function withdraw(GovernorStorageTypesV1.GovernorStorage storage self, uint256 proposalId, address depositer) external {
    uint256 amount = self.deposits[proposalId][depositer];

    GovernorStateLogicV1.validateStateBitmap(
      self,
      proposalId,
      GovernorStateLogicV1.ALL_PROPOSAL_STATES_BITMAP ^
        GovernorStateLogicV1.encodeStateBitmap(GovernorTypesV1.ProposalState.Pending)
    );

    if (amount == 0) {
      revert GovernorNoDepositToWithdraw(proposalId, depositer);
    }

    self.deposits[proposalId][depositer] = 0;

    require(self.vot3.transfer(depositer, amount), "B3TRGovernor: transfer failed");
  }

  /**
   * @notice Internal function to deposit tokens to a proposal.
   * @dev Emits a {ProposalDeposit} event.
   * @param self The storage reference for the GovernorStorage.
   * @param amount The amount of tokens to deposit.
   * @param depositor The address of the depositor.
   * @param proposalId The ID of the proposal.
   */
  function depositFunds(
    GovernorStorageTypesV1.GovernorStorage storage self,
    uint256 amount,
    address depositor,
    uint256 proposalId
  ) internal {
    require(self.vot3.transferFrom(depositor, address(this), amount), "B3TRGovernor: transfer failed");

    self.deposits[proposalId][depositor] += amount;

    emit ProposalDeposit(depositor, proposalId, amount);
  }

  // --------------- GETTERS ---------------
  /**
   * @notice Returns the amount of tokens deposited by a user for a proposal.
   * @param self The storage reference for the GovernorStorage.
   * @param proposalId The ID of the proposal.
   * @param user The address of the user.
   * @return uint256 The amount of tokens deposited by the user.
   */
  function getUserDeposit(
    GovernorStorageTypesV1.GovernorStorage storage self,
    uint256 proposalId,
    address user
  ) internal view returns (uint256) {
    return self.deposits[proposalId][user];
  }

  /**
   * @notice Returns the deposit threshold for a proposal.
   * @param self The storage reference for the GovernorStorage.
   * @param proposalId The ID of the proposal.
   * @return uint256 The deposit threshold for the proposal.
   */
  function proposalDepositThreshold(
    GovernorStorageTypesV1.GovernorStorage storage self,
    uint256 proposalId
  ) internal view returns (uint256) {
    return self.proposals[proposalId].depositThreshold;
  }

  /**
   * @notice Returns the total amount of deposits made to a proposal.
   * @param self The storage reference for the GovernorStorage.
   * @param proposalId The ID of the proposal.
   * @return uint256 The total amount of deposits made to the proposal.
   */
  function getProposalDeposits(
    GovernorStorageTypesV1.GovernorStorage storage self,
    uint256 proposalId
  ) internal view returns (uint256) {
    return self.proposals[proposalId].depositAmount;
  }

  /**
   * @notice Returns true if the threshold of deposits required to reach a proposal has been reached.
   * @param self The storage reference for the GovernorStorage.
   * @param proposalId The ID of the proposal.
   * @return True if the deposit threshold has been reached, false otherwise.
   */
  function proposalDepositReached(
    GovernorStorageTypesV1.GovernorStorage storage self,
    uint256 proposalId
  ) internal view returns (bool) {
    GovernorTypesV1.ProposalCore storage proposal = self.proposals[proposalId];
    return proposal.depositAmount >= proposal.depositThreshold;
  }

  /**
   * @notice Returns the deposit threshold.
   * @param self The storage reference for the GovernorStorage.
   * @return uint256 The deposit threshold.
   */
  function depositThreshold(GovernorStorageTypesV1.GovernorStorage storage self) external view returns (uint256) {
    return _depositThreshold(self);
  }

  /**
   * @notice Internal function to calculate the deposit threshold as a percentage of the total supply of B3TR tokens.
   * @param self The storage reference for the GovernorStorage.
   * @return uint256 The deposit threshold.
   */
  function _depositThreshold(GovernorStorageTypesV1.GovernorStorage storage self) internal view returns (uint256) {
    // deposit threshold is a percentage of the total supply of B3TR tokens
    return (self.depositThresholdPercentage * self.b3tr.totalSupply()) / 100;
  }
}

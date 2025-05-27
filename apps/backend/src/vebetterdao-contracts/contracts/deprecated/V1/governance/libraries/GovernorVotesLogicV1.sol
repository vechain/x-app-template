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
import { GovernorTypesV1 } from "./GovernorTypesV1.sol";
import { GovernorStateLogicV1} from "./GovernorStateLogicV1.sol";
import { GovernorConfiguratorV1 } from "./GovernorConfiguratorV1.sol";
import { GovernorProposalLogicV1 } from "./GovernorProposalLogicV1.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

/// @title GovernorVotesLogic
/// @notice Library for handling voting logic in the Governor contract.
library GovernorVotesLogicV1 {
  /// @dev Thrown when a vote has already been cast by the voter.
  /// @param voter The address of the voter who already cast a vote.
  error GovernorAlreadyCastVote(address voter);

  /// @dev Thrown when an invalid vote type is used.
  error GovernorInvalidVoteType();

  /// @dev Thrown when the voting threshold is not met.
  /// @param threshold The required voting threshold.
  /// @param votes The actual votes received.
  error GovernorVotingThresholdNotMet(uint256 threshold, uint256 votes);

  /// @notice Emitted when a vote is cast without parameters.
  /// @param voter The address of the voter.
  /// @param proposalId The ID of the proposal being voted on.
  /// @param support The support value of the vote.
  /// @param weight The weight of the vote.
  /// @param power The voting power of the voter.
  /// @param reason The reason for the vote.
  event VoteCast(
    address indexed voter,
    uint256 indexed proposalId,
    uint8 support,
    uint256 weight,
    uint256 power,
    string reason
  );

  /** ------------------ INTERNAL FUNCTIONS ------------------ **/

  /**
   * @dev Internal function to count a vote for a proposal.
   * @param self The storage reference for the GovernorStorage.
   * @param proposalId The ID of the proposal.
   * @param account The address of the voter.
   * @param support The support value of the vote.
   * @param weight The weight of the vote.
   * @param power The voting power of the voter.
   */
  function _countVote(
    GovernorStorageTypesV1.GovernorStorage storage self,
    uint256 proposalId,
    address account,
    uint8 support,
    uint256 weight,
    uint256 power
  ) private {
    GovernorTypesV1.ProposalVote storage proposalVote = self.proposalVotes[proposalId];

    if (proposalVote.hasVoted[account]) {
      revert GovernorAlreadyCastVote(account);
    }
    proposalVote.hasVoted[account] = true;

    if (support == uint8(GovernorTypesV1.VoteType.Against)) {
      proposalVote.againstVotes += power;
    } else if (support == uint8(GovernorTypesV1.VoteType.For)) {
      proposalVote.forVotes += power;
    } else if (support == uint8(GovernorTypesV1.VoteType.Abstain)) {
      proposalVote.abstainVotes += power;
    } else {
      revert GovernorInvalidVoteType();
    }

    self.proposalTotalVotes[proposalId] += weight;

    // Save that user cast vote only the first time
    if (!self.hasVotedOnce[account]) {
      self.hasVotedOnce[account] = true;
    }
  }

  /**
   * @dev Internal function to check if the vote succeeded.
   * @param self The storage reference for the GovernorStorage.
   * @param proposalId The ID of the proposal.
   * @return True if the vote succeeded, false otherwise.
   */
  function voteSucceeded(
    GovernorStorageTypesV1.GovernorStorage storage self,
    uint256 proposalId
  ) internal view returns (bool) {
    GovernorTypesV1.ProposalVote storage proposalVote = self.proposalVotes[proposalId];
    return proposalVote.forVotes > proposalVote.againstVotes;
  }

  /** ------------------ GETTERS ------------------ **/

  /**
   * @notice Retrieves the votes for a specific account at a given timepoint.
   * @param self The storage reference for the GovernorStorage.
   * @param account The address of the account.
   * @param timepoint The specific timepoint.
   * @return The votes of the account at the given timepoint.
   */
  function getVotes(
    GovernorStorageTypesV1.GovernorStorage storage self,
    address account,
    uint256 timepoint
  ) internal view returns (uint256) {
    return self.vot3.getPastVotes(account, timepoint);
  }

  /**
   * @notice Retrieves the quadratic voting power of an account at a given timepoint.
   * @param self The storage reference for the GovernorStorage.
   * @param account The address of the account.
   * @param timepoint The specific timepoint.
   * @return The quadratic voting power of the account.
   */
  function getQuadraticVotingPower(
    GovernorStorageTypesV1.GovernorStorage storage self,
    address account,
    uint256 timepoint
  ) external view returns (uint256) {
    // Scale the votes by 1e9 so that the number returned is 1e18
    return Math.sqrt(self.vot3.getPastVotes(account, timepoint)) * 1e9;
  }

  /**
   * @notice Checks if an account has voted on a specific proposal.
   * @param self The storage reference for the GovernorStorage.
   * @param proposalId The ID of the proposal.
   * @param account The address of the account.
   * @return True if the account has voted, false otherwise.
   */
  function hasVoted(
    GovernorStorageTypesV1.GovernorStorage storage self,
    uint256 proposalId,
    address account
  ) internal view returns (bool) {
    return self.proposalVotes[proposalId].hasVoted[account];
  }

  /**
   * @notice Retrieves the votes for a proposal.
   * @param self The storage reference for the GovernorStorage.
   * @param proposalId The ID of the proposal.
   * @return againstVotes The number of votes against the proposal.
   * @return forVotes The number of votes for the proposal.
   * @return abstainVotes The number of abstain votes.
   */
  function getProposalVotes(
    GovernorStorageTypesV1.GovernorStorage storage self,
    uint256 proposalId
  ) internal view returns (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes) {
    GovernorTypesV1.ProposalVote storage proposalVote = self.proposalVotes[proposalId];
    return (proposalVote.againstVotes, proposalVote.forVotes, proposalVote.abstainVotes);
  }

  /**
   * @notice Checks if a user has voted at least once.
   * @param self The storage reference for the GovernorStorage.
   * @param user The address of the user.
   * @return True if the user has voted once, false otherwise.
   */
  function userVotedOnce(GovernorStorageTypesV1.GovernorStorage storage self, address user) internal view returns (bool) {
    return self.hasVotedOnce[user];
  }

  /** ------------------ EXTERNAL FUNCTIONS ------------------ **/

  /**
   * @notice Casts a vote on a proposal.
   * @param self The storage reference for the GovernorStorage.
   * @param proposalId The ID of the proposal.
   * @param voter The address of the voter.
   * @param support The support value of the vote.
   * @param reason The reason for the vote.
   * @return The weight of the vote.
   */
  function castVote(
    GovernorStorageTypesV1.GovernorStorage storage self,
    uint256 proposalId,
    address voter,
    uint8 support,
    string calldata reason
  ) external returns (uint256) {
    GovernorStateLogicV1.validateStateBitmap(self, proposalId, GovernorStateLogicV1.encodeStateBitmap(GovernorTypesV1.ProposalState.Active));

    uint256 weight = self.vot3.getPastVotes(voter, GovernorProposalLogicV1._proposalSnapshot(self, proposalId));
    uint256 power = Math.sqrt(weight) * 1e9;

    if (weight < GovernorConfiguratorV1.getVotingThreshold(self)) {
      revert GovernorVotingThresholdNotMet(weight, GovernorConfiguratorV1.getVotingThreshold(self));
    }

    _countVote(self, proposalId, voter, support, weight, power);

    self.voterRewards.registerVote(GovernorProposalLogicV1._proposalSnapshot(self, proposalId), voter, weight, Math.sqrt(weight));

    emit VoteCast(voter, proposalId, support, weight, power, reason);

    return weight;
  }
}

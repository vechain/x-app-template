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

import { XAllocationVotingGovernorV1 } from "../XAllocationVotingGovernorV1.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title RoundVotesCountingUpgradeable
 *
 * @dev Extension of {XAllocationVotingGovernorV1} for counting votes for allocation rounds.
 *
 * In every round users can vote a fraction of their balance for the eligible apps in that round.
 */
abstract contract RoundVotesCountingUpgradeableV1 is Initializable, XAllocationVotingGovernorV1 {
  struct RoundVote {
    // Total votes received for each app
    mapping(bytes32 appId => uint256) votesReceived;
    // Total votes received for each app in quadratic funding
    mapping(bytes32 appId => uint256) votesReceivedQF; // ∑(sqrt(votes)) -> sqrt(votes1) + sqrt(votes2) + ...
    // Total votes cast in the round
    uint256 totalVotes;
    // Total votes cast in the round in quadratic funding
    uint256 totalVotesQF; // ∑(∑sqrt(votes))^2 -> (sqrt(votesAppX1) + sqrt(votesAppX2) + ...)^2 + (sqrt(votesAppY1) + sqrt(votesAppY2) + ...)^2 + ...
    // Mapping to store if a user has voted
    mapping(address user => bool) hasVoted;
    // Total number of voters in the round
    uint256 totalVoters;
  }

  /// @custom:storage-location erc7201:b3tr.storage.XAllocationVotingGovernorV1.RoundVotesCounting
  struct RoundVotesCountingStorage {
    mapping(address user => bool) _hasVotedOnce; // mapping to store that a user has voted at least one time
    mapping(uint256 roundId => RoundVote) _roundVotes; // mapping to store the votes for each round
    uint256 votingThreshold; // minimum number of tokens needed to cast a vote
  }

  // keccak256(abi.encode(uint256(keccak256("b3tr.storage.XAllocationVotingGovernorV1.RoundVotesCounting")) - 1)) & ~bytes32(uint256(0xff))
  bytes32 private constant RoundVotesCountingStorageLocation =
    0xa760c041d4a9fa3a2c67d0d325f3592ba2c7e4330f7ba2283ebf9fe63913d500;

  function _getRoundVotesCountingStorage() private pure returns (RoundVotesCountingStorage storage $) {
    assembly {
      $.slot := RoundVotesCountingStorageLocation
    }
  }

  //@notice emitted when a the minimum number of tokens needed to cast a vote is updated
  event VotingThresholdSet(uint256 oldVotingThreshold, uint256 newVotingThreshold);

  /**
   * @dev Initializes the contract
   */
  function __RoundVotesCounting_init(uint256 _votingThreshold) internal onlyInitializing {
    __RoundVotesCounting_init_unchained(_votingThreshold);
  }

  function __RoundVotesCounting_init_unchained(uint256 _votingThreshold) internal onlyInitializing {
    RoundVotesCountingStorage storage $ = _getRoundVotesCountingStorage();

    $.votingThreshold = _votingThreshold;
  }

  /**
   * @dev See {IXAllocationVotingGovernor-COUNTING_MODE}.
   */
  // solhint-disable-next-line func-name-mixedcase
  function COUNTING_MODE() public pure virtual override returns (string memory) {
    return "support=x-allocations&quorum=auto";
  }

  /**
   * @dev Update the voting threshold. This operation can only be performed through a governance proposal.
   *
   * Emits a {VotingThresholdSet} event.
   */
  function setVotingThreshold(uint256 newVotingThreshold) public virtual {
    _setVotingThreshold(newVotingThreshold);
  }

  /**
   * @dev Internal setter for the voting threshold.
   *
   * Emits a {VotingThresholdSet} event.
   */
  function _setVotingThreshold(uint256 newVotingThreshold) internal virtual {
    RoundVotesCountingStorage storage $ = _getRoundVotesCountingStorage();

    emit VotingThresholdSet($.votingThreshold, newVotingThreshold);
    $.votingThreshold = newVotingThreshold;
  }

  /**
   * @dev Counts votes for a given round of voting, applying quadratic funding principles.
   * Allows a voter to allocate weights to various applications (apps) for a specific voting round,
   * ensuring each voter votes only once per round to prevent double voting.
   *
   * Quadratic funding is used to calculate the impact of each vote. For each app, the square root of the 
   * individual vote's weight is computed and added to the total sum of square roots for that app.
   * After updating with each vote, this sum of square roots is squared to determine the total quadratic funding votes for the app. 
   * This method aims to democratize the voting process by amplifying the influence of a larger number of smaller votes.

   * Requirements:
   * - The voter must not have voted in this round already.
   * - The total voting weight allocated by the voter must not exceed the voter's available voting power.
   * - Each app voted on must be eligible for votes in the current round.
   *
   * @param roundId The identifier of the current voting round.
   * @param voter The address of the voter casting the votes.
   * @param apps An array of app identifiers that the voter is allocating votes to.
   * @param weights An array of vote weights corresponding to each app.
   */

  function _countVote(
    uint256 roundId,
    address voter,
    bytes32[] memory apps,
    uint256[] memory weights
  ) internal virtual override {
    if (hasVoted(roundId, voter)) {
      revert GovernorAlreadyCastVote(voter);
    }

    RoundVotesCountingStorage storage $ = _getRoundVotesCountingStorage();

    // Get the start of the round
    uint256 roundStart = roundSnapshot(roundId);

    // To hold the total weight of votes cast by the voter
    uint256 totalWeight;
    // To hold the total adjustment to the quadratic funding value for the given app
    uint256 totalQFVotesAdjustment;

    // Get the total voting power of the voter to use in the for loop to check
    // if the total weight of votes cast by the voter is greater than the voter's available voting power
    uint256 voterAvailableVotes = getVotes(voter, roundStart);

    // Iterate through the apps and weights to calculate the total weight of votes cast by the voter
    for (uint256 i; i < apps.length; i++) {
      // Update the total weight of votes cast by the voter
      totalWeight += weights[i];

      if (totalWeight > voterAvailableVotes) {
        revert GovernorInsufficientVotingPower();
      }

      // Check if the app is eligible for votes in the current round
      if (!isEligibleForVote(apps[i], roundId)) {
        revert GovernorAppNotAvailableForVoting(apps[i]);
      }

      // Get the current sum of the square roots of individual votes for the given project
      uint256 qfAppVotesPreVote = $._roundVotes[roundId].votesReceivedQF[apps[i]]; // ∑(sqrt(votes)) -> sqrt(votes1) + sqrt(votes2) + ... + sqrt(votesN)

      // Calculate the new sum of the square roots of individual votes for the given project
      uint256 newQFVotes = Math.sqrt(weights[i]); // sqrt(votes)
      uint256 qfAppVotesPostVote = qfAppVotesPreVote + newQFVotes; // ∑(sqrt(votes)) -> sqrt(votes1) + sqrt(votes2) + ... + sqrt(votesN) + sqrt(votesN+1)

      // Calculate the adjustment to the quadratic funding value for the given app
      totalQFVotesAdjustment += (qfAppVotesPostVote * qfAppVotesPostVote) - (qfAppVotesPreVote * qfAppVotesPreVote); // (sqrt(votes1) + ... + sqrt(votesN+1))^2 - (sqrt(votes1) + ... + sqrt(votesN))^2

      // Update the quadratic funding votes received for the given app - sum of the square roots of individual votes
      $._roundVotes[roundId].votesReceivedQF[apps[i]] = qfAppVotesPostVote; // ∑(sqrt(votes)) -> sqrt(votes1) + sqrt(votes2) + ... + sqrt(votesN+1)
      $._roundVotes[roundId].votesReceived[apps[i]] += weights[i]; // ∑votes + votesN+1
    }

    // Check if the total weight of votes cast by the voter is greater than the voting threshold
    if (totalWeight < votingThreshold()) {
      revert GovernorVotingThresholdNotMet(votingThreshold(), totalWeight);
    }

    // Apply the total adjustment to storage
    $._roundVotes[roundId].totalVotesQF += totalQFVotesAdjustment; // update the total quadratic funding value for the round - ∑(∑sqrt(votes))^2 -> (sqrt(votesAppX1) + sqrt(votesAppX2) + ...)^2 + (sqrt(votesAppY1) + sqrt(votesAppY2) + ...)^2 + ...
    $._roundVotes[roundId].totalVotes += totalWeight; // update total votes -> ∑votes + votesN+1
    $._roundVotes[roundId].hasVoted[voter] = true; // mark the voter as having voted
    $._roundVotes[roundId].totalVoters++; // increment the total number of voters

    // save that user cast vote only the first time
    if (!$._hasVotedOnce[voter]) {
      $._hasVotedOnce[voter] = true;
    }

    // Register the vote for rewards calculation where the vote power is the square root of the total votes cast by the voter
    voterRewards().registerVote(roundStart, voter, totalWeight, Math.sqrt(totalWeight));

    // Emit the AllocationVoteCast event
    emit AllocationVoteCast(voter, roundId, apps, weights);
  }

  /**
   * @dev Get the votes received by a specific application in a given round
   */
  function getAppVotes(uint256 roundId, bytes32 app) public view override returns (uint256) {
    RoundVotesCountingStorage storage $ = _getRoundVotesCountingStorage();
    return $._roundVotes[roundId].votesReceived[app];
  }

  /**
   * @dev Get the quadratic funding votes received by a specific application in a given round
   */
  function getAppVotesQF(uint256 roundId, bytes32 app) public view override returns (uint256) {
    RoundVotesCountingStorage storage $ = _getRoundVotesCountingStorage();
    return $._roundVotes[roundId].votesReceivedQF[app];
  }

  /**
   * @dev Get the total quadratic funding votes cast in a given round
   */
  function totalVotesQF(uint256 roundId) public view override returns (uint256) {
    RoundVotesCountingStorage storage $ = _getRoundVotesCountingStorage();
    return $._roundVotes[roundId].totalVotesQF;
  }

  /**
   * @dev Get the total votes cast in a given round
   */
  function totalVotes(uint256 roundId) public view override returns (uint256) {
    RoundVotesCountingStorage storage $ = _getRoundVotesCountingStorage();
    return $._roundVotes[roundId].totalVotes;
  }

  /**
   * @dev Get the total number of voters in a given round
   */
  function totalVoters(uint256 roundId) public view override returns (uint256) {
    RoundVotesCountingStorage storage $ = _getRoundVotesCountingStorage();
    return $._roundVotes[roundId].totalVoters;
  }

  /**
   * @notice The voting threshold.
   * @dev The minimum number of tokens needed to cast a vote.
   */
  function votingThreshold() public view virtual returns (uint256) {
    RoundVotesCountingStorage storage $ = _getRoundVotesCountingStorage();
    return $.votingThreshold;
  }

  /**
   * @dev Check if a user has voted in a given round
   */
  function hasVoted(uint256 roundId, address user) public view returns (bool) {
    RoundVotesCountingStorage storage $ = _getRoundVotesCountingStorage();
    return $._roundVotes[roundId].hasVoted[user];
  }

  /**
   * @dev Internal function to check if the quorum is reached for a given round
   */
  function _quorumReached(uint256 roundId) internal view virtual override returns (bool) {
    return quorum(roundSnapshot(roundId)) <= totalVotes(roundId);
  }

  /**
   * @dev Internal function to check if the vote succeeded for a given round
   */
  function _voteSucceeded(uint256 roundId) internal view virtual override returns (bool) {
    // vote is successful if quorum is reached
    return _quorumReached(roundId);
  }

  /**
   * @dev Check if a user has voted at least once from the deployment of the contract
   */
  function hasVotedOnce(address user) public view returns (bool) {
    RoundVotesCountingStorage storage $ = _getRoundVotesCountingStorage();
    return $._hasVotedOnce[user];
  }
}

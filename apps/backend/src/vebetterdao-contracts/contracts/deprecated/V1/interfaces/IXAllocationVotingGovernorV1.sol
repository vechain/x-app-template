// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { IERC165 } from "@openzeppelin/contracts/interfaces/IERC165.sol";
import { IERC6372 } from "@openzeppelin/contracts/interfaces/IERC6372.sol";

/**
 * @dev Interface of the distribution allocation voting for the x-allocation pool reward distributions.
 * This interface was forked from OpenZeppelin's IGovernor.sol and modified to fit the needs of a voting mechanism
 * where a user can vote on multpile x-apps belonging to the ecosystem and fractionalize their votes accross the x-apps.
 *
 * There can be only one round per time.
 * After the round is created  it becomes immediately active.
 * There can be only two possible outcomes of a round: it succeeds or it fails.
 * To succeed the only requirement is that the quorum is reached.
 *
 * New allocation rounds can be started only by the Emissions contract, this way we can align the duration
 * of emission cycles and allocation rounds.
 *
 * If the round fails, we will need to “finalize” it, which means we will create a pointer to the last succeeded round
 * where shares should be calculated. Anyone can finalize the failed round,
 * but it will be automatically done when a new round starts.
 */
interface IXAllocationVotingGovernorV1 is IERC165, IERC6372 {
  enum RoundState {
    Active,
    Failed,
    Succeeded
  }

  /**
   * @dev The vote was already cast.
   */
  error GovernorAlreadyCastVote(address voter);

  /**
   * @dev The `account` is not the governance executor.
   */
  error B3TRGovernorOnlyExecutor(address account);

  /**
   * @dev The `roundId` doesn't exist.
   */
  error GovernorNonexistentRound(uint256 roundId);

  /**
   * @dev The current state of a round is not the required for performing an operation.
   * The `expectedStates` is a bitmap with the bits enabled for each RoundState enum position
   * counting from right to left.
   *
   * NOTE: If `expectedState` is `bytes32(0)`, the round is expected to not be in any state (i.e. not exist).
   * This is the case when a round that is expected to be unset is already initiated (the round is duplicated).
   *
   * See {Governor-_encodeStateBitmap}.
   */
  error GovernorUnexpectedRoundState(uint256 roundId, RoundState current, bytes32 expectedStates);

  /**
   * @dev The voting period set is not a valid period.
   */
  error GovernorInvalidVotingPeriod(uint256 votingPeriod);

  /**
   * @dev The `appId` is not present in the list with the available x-apps for voting in this round.
   */
  error GovernorAppNotAvailableForVoting(bytes32 appId);

  /**
   * @dev The `votingThreshold` is not met.
   */
  error GovernorVotingThresholdNotMet(uint256 threshold, uint256 votes);

  /**
   * @dev The `voter` has insufficient voting power for this round to cast the votes.
   */
  error GovernorInsufficientVotingPower();

  /**
   * @dev Emitted when a round is created.
   */
  event RoundCreated(uint256 roundId, address proposer, uint256 voteStart, uint256 voteEnd, bytes32[] appsIds);

  /**
   * @dev Emitted when votes are cast.
   *
   */
  event AllocationVoteCast(address indexed voter, uint256 indexed roundId, bytes32[] appsIds, uint256[] voteWeights);

  /**
   * @notice module:core
   * @dev Name of the governor instance (used in building the ERC712 domain separator).
   */
  function name() external view returns (string memory);

  /**
   * @notice module:core
   * @dev Version of the governor instance (used in building the ERC712 domain separator). Default: "1"
   */
  function version() external view returns (string memory);

  /**
   * @notice module:voting
   * @dev A description of the possible `support` values for {castVote} and the way these votes are counted, meant to
   * be consumed by UIs to show correct vote options and interpret the results. The string is a URL-encoded sequence of
   * key-value pairs that each describe one aspect, for example `support=bravo&quorum=for,abstain`.
   *
   * There are 2 standard keys: `support` and `quorum`.
   *
   * - `support=bravo` refers to the vote options 0 = Against, 1 = For, 2 = Abstain, as in `GovernorBravo`.
   * - `support=x-allocations` refers to the fractionalized vote for each x-application.
   * - `quorum=bravo` means that only For votes are counted towards quorum.
   * - `quorum=for,abstain` means that both For and Abstain votes are counted towards quorum.
   * - `quorum=auto` means that the contract defines the logic for counting the quorum.
   *
   * If a counting module makes use of encoded `params`, it should  include this under a `params` key with a unique
   * name that describes the behavior. For example:
   *
   * - `params=fractional` might refer to a scheme where votes are divided fractionally between for/against/abstain.
   * - `params=erc721` might refer to a scheme where specific NFTs are delegated to vote.
   *
   * NOTE: The string can be decoded by the standard
   * https://developer.mozilla.org/en-US/docs/Web/API/URLSearchParams[`URLSearchParams`]
   * JavaScript class.
   */
  // solhint-disable-next-line func-name-mixedcase
  function COUNTING_MODE() external view returns (string memory);

  /**
   * @notice module:core
   * @dev Current state of a round
   */
  function state(uint256 roundId) external view returns (RoundState);

  /**
   * @notice module:core
   * @dev Timepoint used to retrieve user's votes and quorum. If using block number (as per Compound's Comp), the
   * snapshot is performed at the end of this block. Hence, voting for this round starts at the beginning of the
   * following block.
   */
  function roundSnapshot(uint256 roundId) external view returns (uint256);

  /**
   * @notice module:core
   * @dev Timepoint at which votes close. If using block number, votes close at the end of this block, so it is
   * possible to cast a vote during this block.
   */
  function roundDeadline(uint256 roundId) external view returns (uint256);

  /**
   * @notice module:core
   * @dev The account that created a round.
   */
  function roundProposer(uint256 roundId) external view returns (address);

  /**
   * @notice module:user-config
   * @dev Delay between the vote start and vote end. The unit this duration is expressed in depends on the clock
   * (see EIP-6372) this contract uses.
   *
   *
   * NOTE: This value is stored when the round is submitted so that possible changes to the value do not affect
   * proposals that have already been submitted. The type used to save it is a uint32. Consequently, while this
   * interface returns a uint256, the value it returns should fit in a uint32.
   */
  function votingPeriod() external view returns (uint256);

  /**
   * @notice module:user-config
   * @dev Minimum number of cast voted required for a round to be successful.
   *
   * NOTE: The `timepoint` parameter corresponds to the snapshot used for counting vote. This allows to scale the
   * quorum depending on values such as the totalSupply of a token at this timepoint (see {ERC20Votes}).
   */
  function quorum(uint256 timepoint) external view returns (uint256);

  /**
   * @notice module:user-config
   * @dev Minimum number of cast voted required for a round to be successful.
   *
   * NOTE: The `roundId` parameter corresponds to the round for which the quorum is calculated.
   */
  function roundQuorum(uint256 roundId) external view returns (uint256);

  /**
   * @notice module:reputation
   * @dev Voting power of an `account` at a specific `timepoint`.
   *
   * Note: this can be implemented in a number of ways, for example by reading the delegated balance from one (or
   * multiple), {ERC20Votes} tokens.
   */
  function getVotes(address account, uint256 timepoint) external view returns (uint256);

  /**
   * @notice module:reputation
   * @dev Total number of votes cast in an allocation round.
   */
  function totalVotes(uint256 roundId) external view returns (uint256);

  /**
   * @notice module:reputation
   * @dev Total number of voters in an allocation round.
   */
  function totalVoters(uint256 roundId) external view returns (uint256);

  /**
   * @notice module:reputation
   * @dev Number of votes cast for a specific app in an allocation round.
   */
  function getAppVotes(uint256 roundId, bytes32 appId) external view returns (uint256);

  /**
   * @notice module:reputation
   * @dev Sum of the square roots of the votes cast for a specific app in an allocation round used for Quadatic Funding.
   */
  function getAppVotesQF(uint256 roundId, bytes32 app) external view returns (uint256);

  /**
   * @notice module:reputation
   * @dev Calculates the total sum of the squares of the total Quadratic Funding (QF) votes for all apps in an allocation round.
   */
  function totalVotesQF(uint256 roundId) external view returns (uint256);

  /**
   * @notice module:voting
   * @dev Returns whether `account` has cast a vote on `roundId`.
   */
  function hasVoted(uint256 roundId, address account) external view returns (bool);

  /**
   * @dev Create a new allocation round (round). Vote starts immediatly and lasts for a
   * duration specified by {votingPeriod}.
   *
   * Emits a {RoundCreated} event.
   */
  function startNewRound() external returns (uint256 roundId);

  /**
   * @dev Cast multiple votes at once
   *
   * Emits a {AllocationVoteCast} event.
   */
  function castVote(uint256 roundId, bytes32[] memory appsIds, uint256[] memory voteWeights) external;

  /**
   * @dev Returns the current allocation round round.
   */
  function currentRoundId() external view returns (uint256);

  /**
   * @dev Returns the current allocation round block when it starts.
   */
  function currentRoundSnapshot() external view returns (uint256);

  /**
   * @dev Returns the current allocation round block when it ends.
   */
  function currentRoundDeadline() external view returns (uint256);

  /**
   * @dev Returns if quorum was reached for a specific round.
   */
  function quorumReached(uint256 roundId) external view returns (bool);

  /**
   * @dev Returns the ids of apps that are available for voting in a specific round.
   */
  function getAppIdsOfRound(uint256 roundId) external view returns (bytes32[] memory);

  /**
   * @dev Returns if an app can be voted in a specific round.
   */
  function isEligibleForVote(bytes32 appId, uint256 roundId) external view returns (bool);

  /**
   * @dev Checks if the state of the round is {RoundState.Active}.
   */
  function isActive(uint256 roundId) external view returns (bool);

  /**
   * @dev Returns the id of the last round that succeeded.
   */
  function latestSucceededRoundId(uint256 roundId) external view returns (uint256);

  /**
   * @dev Returns true if an account has voted at least one time in any round.
   */
  function hasVotedOnce(address user) external view returns (bool);

  /**
   * @dev Returns the base allocation percentage for funds distribution in a round.
   */
  function getRoundBaseAllocationPercentage(uint256 roundId) external view returns (uint256);

  /**
   * @dev Returns the max amount of shares an app can get in a round.
   */
  function getRoundAppSharesCap(uint256 roundId) external view returns (uint256);
}

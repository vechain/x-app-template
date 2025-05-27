// SPDX-License-Identifier: MIT
// Forked from OpenZeppelin Contracts (last updated v5.0.0) (governance/IGovernor.sol)

pragma solidity 0.8.20;

import { IERC165 } from "@openzeppelin/contracts/interfaces/IERC165.sol";
import { IERC6372 } from "@openzeppelin/contracts/interfaces/IERC6372.sol";
import { IB3TR } from "../../../interfaces/IB3TR.sol";
import { IVoterRewardsV2 } from "../../V2/interfaces/IVoterRewardsV2.sol";
import { IXAllocationVotingGovernorV2 } from "../../V2/interfaces/IXAllocationVotingGovernorV2.sol";
import { GovernorTypesV4 } from "../governance/libraries/GovernorTypesV4.sol";
import { IVeBetterPassport } from "../../../interfaces/IVeBetterPassport.sol";

/**
 * @dev Interface of the {B3TRGovernor} core.
 *
 * Modifications to original forked contract from OZ:
 * - Removed votingDelay()
 * - Removed the possibility to cast vote with params and with signature
 * - Updated propose() and ProposalCreated event to accept the x allocation round id as param when proposal should become active
 * - Added proposalStartRound() to get the round when the proposal should become active
 * - Added canProposalStartInNextRound() to check if the proposal can start in the next allocation round
 * - Added new state `DepositNotMet` to ProposalState enum
 * - Added depositThreshold() to get the minimum required deposit for a proposal and removed proposalThreshold
 */
interface IB3TRGovernorV4 is IERC165, IERC6372 {
  /**
   * @dev Empty proposal or a mismatch between the parameters length for a proposal call.
   */
  error GovernorInvalidProposalLength(uint256 targets, uint256 calldatas, uint256 values);

  /**
   * @dev The vote was already cast.
   */
  error GovernorAlreadyCastVote(address voter);

  /**
   * @dev Token deposits are disabled in this contract.
   */
  error GovernorDisabledDeposit();

  /**
   * @dev The `account` is not a proposer.
   */
  error GovernorOnlyProposer(address account);

  /**
   * @dev The `account` is not the governance executor.
   */
  error GovernorOnlyExecutor(address account);

  /**
   * @dev The `proposalId` doesn't exist.
   */
  error GovernorNonexistentProposal(uint256 proposalId);

  /**
   * @dev The `votingThreshold` is not met.
   */
  error GovernorVotingThresholdNotMet(uint256 threshold, uint256 votes);

  /**
   * @dev The quorum numerator is greater than the quorum denominator.
   */
  error GovernorInvalidQuorumFraction(uint256 quorumNumerator, uint256 quorumDenominator);

  /**
   * @dev Thrown when the personhood verification fails.
   * @param voter The address of the voter.
   * @param explanation The reason for the failure.
   */
  error GovernorPersonhoodVerificationFailed(address voter, string explanation);

  /**
   * @dev The current state of a proposal is not the required for performing an operation.
   * The `expectedStates` is a bitmap with the bits enabled for each ProposalState enum position
   * counting from right to left.
   *
   * NOTE: If `expectedState` is `bytes32(0)`, the proposal is expected to not be in any state (i.e. not exist).
   * This is the case when a proposal that is expected to be unset is already initiated (the proposal is duplicated).
   *
   * See {Governor-_encodeStateBitmap}.
   */
  error GovernorUnexpectedProposalState(
    uint256 proposalId,
    GovernorTypesV4.ProposalState current,
    bytes32 expectedStates
  );

  /**
   * @dev The voting period set is not a valid period.
   */
  error GovernorInvalidVotingPeriod(uint256 votingPeriod);

  /**
   * @dev The `proposer` does not have the required votes to create a proposal.
   */
  error GovernorInsufficientProposerVotes(address proposer, uint256 votes, uint256 threshold);

  /**
   * @dev The `proposer` is not allowed to create a proposal.
   */
  error GovernorRestrictedProposer(address proposer);

  /**
   * @dev The vote type used is not valid for the corresponding counting module.
   */
  error GovernorInvalidVoteType();

  /**
   * @dev Queue operation is not implemented for this governor. Execute should be called directly.
   */
  error GovernorQueueNotImplemented();

  /**
   * @dev The proposal hasn't been queued yet.
   */
  error GovernorNotQueuedProposal(uint256 proposalId);

  /**
   * @dev The proposal has already been queued.
   */
  error GovernorAlreadyQueuedProposal(uint256 proposalId);

  /**
   * @dev The round when proposal should start is not valid.
   */
  error GovernorInvalidStartRound(uint256 roundId);

  /**
   * @dev There is no deposit to withdraw.
   */
  error GovernorNoDepositToWithdraw(uint256 proposalId, address depositer);

  /**
   * @dev The deposit amount must be greater than 0.
   */
  error GovernorInvalidDepositAmount();

  /**
   * @dev The deposit threshold is not in the valid range for a percentage - 0 to 100.
   */
  error GovernorDepositThresholdNotInRange(uint256 depositThreshold);

  /**
   * @dev User is not authorized to perform the action.
   */
  error UnauthorizedAccess(address user);

  /**
   * @dev Emitted when a proposal is created
   */
  event ProposalCreated(
    uint256 indexed proposalId,
    address indexed proposer,
    address[] targets,
    uint256[] values,
    string[] signatures,
    bytes[] calldatas,
    string description,
    uint256 indexed roundIdVoteStart,
    uint256 depositThreshold
  );

  /**
   * @dev Emitted when a proposal is queued.
   */
  event ProposalQueued(uint256 proposalId, uint256 etaSeconds);

  /**
   * @dev Emitted when a proposal is executed.
   */
  event ProposalExecuted(uint256 proposalId);

  /**
   * @dev Emitted when a proposal is canceled.
   */
  event ProposalCanceled(uint256 proposalId);

  /**
   * @dev Emitted when the quorum numerator is updated.
   */
  event QuorumNumeratorUpdated(uint256 oldNumerator, uint256 newNumerator);

  /**
   * @dev Emitted when the timelock controller used for proposal execution is modified.
   */
  event TimelockChange(address oldTimelock, address newTimelock);

  /**
   * @dev Emitted when a function is whitelisted or restricted by the governor.
   */
  event FunctionWhitelisted(address indexed target, bytes4 indexed functionSelector, bool isWhitelisted);

  /**
   * @dev Emitted when a vote is cast without params.
   *
   * Note: `support` values should be seen as buckets. Their interpretation depends on the voting module used.
   */
  event VoteCast(
    address indexed voter,
    uint256 indexed proposalId,
    uint8 support,
    uint256 weight,
    uint256 power,
    string reason
  );

  /**
   * @notice Emits true if quadratic voting is disabled, false otherwise.
   * @param disabled - The flag to enable or disable quadratic voting.
   */
  event QuadraticVotingToggled(bool indexed disabled);

  /**
   * @dev Emitted when a deposit is made to a proposal.
   */
  event ProposalDeposit(address indexed depositor, uint256 indexed proposalId, uint256 amount);

  /**
   * @dev Emitted when the VeBetterPassport contract is set.
   */
  event VeBetterPassportSet(address indexed oldVeBetterPassport, address indexed newVeBetterPassport);

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
   * - `quorum=bravo` means that only For votes are counted towards quorum.
   * - `quorum=for,abstain` means that both For and Abstain votes are counted towards quorum.
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
   * @dev Hashing function used to (re)build the proposal id from the proposal details..
   */
  function hashProposal(
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    bytes32 descriptionHash
  ) external pure returns (uint256);

  /**
   * @notice module:core
   * @dev Current state of a proposal, following Compound's convention
   */
  function state(uint256 proposalId) external view returns (GovernorTypesV4.ProposalState);

  /**
   * @notice module:core
   * @dev Get the minimum required delay between proposal cretion and start when creating a proposal.
   */
  function minVotingDelay() external view returns (uint256);

  /**
   * @notice module:core
   * @dev The B3TR contract address
   */
  function b3tr() external view returns (IB3TR);

  /**
   * @notice module:core
   * @dev Getter for the VoterRewards contract
   */
  function voterRewards() external view returns (IVoterRewardsV2);

  /**
   * @notice module:core
   * @dev Getter for the XAllocationVoting contract
   */
  function xAllocationVoting() external view returns (IXAllocationVotingGovernorV2);

  /**
   * @notice module:core
   * @dev The number of votes in support of a proposal required in order for a proposal to become active.
   */
  function depositThreshold() external view returns (uint256);

  /**
   * @notice module:core
   * @dev The deposit threshold percentage of the total supply of B3TR tokens that need to be deposited to create a proposal
   */
  function depositThresholdPercentage() external view returns (uint256);

  /**
   * @notice module:core
   * @dev The minimum number of vote tokens needed to cast a vote
   */
  function votingThreshold() external view returns (uint256);

  /**
   * @notice module:core
   * @dev Timepoint used to retrieve user's votes and quorum. If using block number (as per Compound's Comp), the
   * snapshot is performed at the end of this block. Hence, voting for this proposal starts at the beginning of the
   * following block.
   */
  function proposalSnapshot(uint256 proposalId) external view returns (uint256);

  /**
   * @notice module:core
   * @dev Timepoint at which votes close. If using block number, votes close at the end of this block, so it is
   * possible to cast a vote during this block.
   */
  function proposalDeadline(uint256 proposalId) external view returns (uint256);

  /**
   * @notice module:core
   * @dev The account that created a proposal.
   */
  function proposalProposer(uint256 proposalId) external view returns (address);

  /**
   * @notice module:core
   * @dev The time when a queued proposal becomes executable ("ETA"). Unlike {proposalSnapshot} and
   * {proposalDeadline}, this doesn't use the governor clock, and instead relies on the executor's clock which may be
   * different. In most cases this will be a timestamp.
   */
  function proposalEta(uint256 proposalId) external view returns (uint256);

  /**
   * @notice module:core
   * @dev Whether a proposal needs to be queued before execution.
   */
  function proposalNeedsQueuing(uint256 proposalId) external view returns (bool);

  /**
   * @notice module:user-config
   * @dev Delay between the vote start and vote end. The unit this duration is expressed in depends on the clock
   * (see EIP-6372) this contract uses.
   *
   * NOTE: The {votingDelay} can delay the start of the vote. This must be considered when setting the voting
   * duration compared to the voting delay.
   *
   * NOTE: This value is stored when the proposal is submitted so that possible changes to the value do not affect
   * proposals that have already been submitted. The type used to save it is a uint32. Consequently, while this
   * interface returns a uint256, the value it returns should fit in a uint32.
   */
  function votingPeriod() external view returns (uint256);

  /**
   * @notice module:user-config
   * @dev Minimum number of cast voted required for a proposal to be successful.
   *
   * NOTE: The `timepoint` parameter corresponds to the snapshot used for counting vote. This allows to scale the
   * quorum depending on values such as the totalSupply of a token at this timepoint (see {ERC20Votes}).
   */
  function quorum(uint256 timepoint) external view returns (uint256);

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
   * @dev Voting power using quadratic voting of an `account` at a specific `timepoint`.
   *
   */
  function getQuadraticVotingPower(address account, uint256 timepoint) external view returns (uint256);

  /**
   * @notice module:voting
   * @dev Returns whether `account` has cast a vote on `proposalId`.
   */
  function hasVoted(uint256 proposalId, address account) external view returns (bool);

  /**
   * @dev Create a new proposal. Specify the allocation round when vote should become active.
   * The duration is specified by {IGovernor-votingPeriod}.
   *
   * Emits a {ProposalCreated} event.
   */
  function propose(
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    string memory description,
    uint256 startRoundId,
    uint256 depositAmount
  ) external returns (uint256 proposalId);

  /**
   * @dev Queue a proposal. Some governors require this step to be performed before execution can happen. If queuing
   * is not necessary, this function may revert.
   * Queuing a proposal requires the quorum to be reached, the vote to be successful, and the deadline to be reached.
   *
   * Emits a {ProposalQueued} event.
   */
  function queue(
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    bytes32 descriptionHash
  ) external returns (uint256 proposalId);

  /**
   * @dev Execute a successful proposal. This requires the quorum to be reached, the vote to be successful, and the
   * deadline to be reached. Depending on the governor it might also be required that the proposal was queued and
   * that some delay passed.
   *
   * Emits a {ProposalExecuted} event.
   *
   * NOTE: Some modules can modify the requirements for execution, for example by adding an additional timelock.
   */
  function execute(
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    bytes32 descriptionHash
  ) external payable returns (uint256 proposalId);

  /**
   * @dev Cancel a proposal. A proposal is cancellable by the proposer, but only while it is Pending state, i.e.
   * before the vote starts.
   *
   * Emits a {ProposalCanceled} event.
   */
  function cancel(
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    bytes32 descriptionHash
  ) external returns (uint256 proposalId);

  /**
   * @dev Cast a vote
   *
   * Emits a {VoteCast} event.
   */
  function castVote(uint256 proposalId, uint8 support) external returns (uint256 balance);

  /**
   * @dev Cast a vote with a reason
   *
   * Emits a {VoteCast} event.
   */
  function castVoteWithReason(
    uint256 proposalId,
    uint8 support,
    string calldata reason
  ) external returns (uint256 balance);

  /**
   * @dev Check if user has cast vote at least in one proposal.
   */
  function hasVotedOnce(address user) external view returns (bool);

  /**
   * @dev Round when the proposal should become active.
   */
  function proposalStartRound(uint256 proposalId) external view returns (uint256);

  /**
   * @dev Check if proposal can start in the next allocation round.
   */
  function canProposalStartInNextRound() external view returns (bool);

  /**
   * @dev Function to deposit tokens to a proposal
   */
  function deposit(uint256 amount, uint256 proposalId) external;

  /**
   * @dev Function to withdraw tokens from a proposal
   */
  function withdraw(uint256 proposalId, address depositer) external;

  /**
   * @dev Getter to retrieve the total amount of tokens deposited to a proposal
   */
  function getProposalDeposits(uint256 proposalId) external view returns (uint256);

  /**
   * @dev Function to check if the deposit threshold for a proposal has been reached
   */
  function proposalDepositReached(uint256 proposalId) external view returns (bool);

  /**
   * @dev Getter to retrieve the amount of tokens a specific user has deposited to a proposal
   */
  function getUserDeposit(uint256 proposalId, address user) external view returns (uint256);

  /**
   * @notice Returns the VeBetterPassport contract.
   * @return The current VeBetterPassport contract.
   */
  function veBetterPassport() external view returns (IVeBetterPassport);

  /**
   * @notice Set the VeBetterPassport contract
   * @param newVeBetterPassport The new VeBetterPassport contract
   */
  function setVeBetterPassport(IVeBetterPassport newVeBetterPassport) external;
}

//SPDX-License-Identifier: MIT

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

import { GovernorProposalLogicV1 } from "./governance/libraries/GovernorProposalLogicV1.sol";
import { GovernorStateLogicV1 } from "./governance/libraries/GovernorStateLogicV1.sol";
import { GovernorVotesLogicV1 } from "./governance/libraries/GovernorVotesLogicV1.sol";
import { GovernorQuorumLogicV1 } from "./governance/libraries/GovernorQuorumLogicV1.sol";
import { GovernorDepositLogicV1 } from "./governance/libraries/GovernorDepositLogicV1.sol";
import { GovernorStorageTypesV1 } from "./governance/libraries/GovernorStorageTypesV1.sol";
import { GovernorClockLogicV1 } from "./governance/libraries/GovernorClockLogicV1.sol";
import { GovernorFunctionRestrictionsLogicV1 } from "./governance/libraries/GovernorFunctionRestrictionsLogicV1.sol";
import { GovernorGovernanceLogicV1 } from "./governance/libraries/GovernorGovernanceLogicV1.sol";
import { GovernorConfiguratorV1 } from "./governance/libraries/GovernorConfiguratorV1.sol";
import { GovernorTypesV1 } from "./governance/libraries/GovernorTypesV1.sol";
import { GovernorStorageV1 } from "./governance/GovernorStorageV1.sol";
import { IVoterRewards } from "../../interfaces/IVoterRewards.sol";
import { IVOT3 } from "../../interfaces/IVOT3.sol";
import { IB3TR } from "../../interfaces/IB3TR.sol";
import { IB3TRGovernorV1 } from "./interfaces/IB3TRGovernorV1.sol";
import { IXAllocationVotingGovernor } from "../../interfaces/IXAllocationVotingGovernor.sol";
import { TimelockControllerUpgradeable } from "@openzeppelin/contracts-upgradeable/governance/TimelockControllerUpgradeable.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { IERC1155Receiver } from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title B3TRGovernor
 * @notice This contract is the main governance contract for the VeBetterDAO ecosystem.
 * Anyone can create a proposal to both change the state of the contract, to execute a transaction
 * on the timelock or to ask for a vote from the community without performing any onchain action.
 * In order for the proposal to become active, the community needs to deposit a certain amount of VOT3 tokens.
 * This is used as a heat check for the proposal, and funds are returned to the depositors after vote is concluded.
 * Votes for proposals start periodically, based on the allocation rounds (see xAllocationVoting contract), and the round
 * in which the proposal should be active is specified by the proposer during the proposal creation.
 *
 * A minimum amount of voting power is required in order to vote on a proposal.
 * The voting power is calculated through the quadratic vote formula based on the amount of VOT3 tokens held by the
 * voter at the block when the proposal becomes active.
 *
 * Once a proposal succeeds, it can be queued and executed. The execution is done through the timelock contract.
 *
 * The contract is upgradeable and uses the UUPS pattern.
 * @dev The contract is upgradeable and uses the UUPS pattern. All LogicV1 is stored in libraries.
 */
contract B3TRGovernorV1 is
  IB3TRGovernorV1,
  GovernorStorageV1,
  AccessControlUpgradeable,
  UUPSUpgradeable,
  PausableUpgradeable
{
  /// @notice The role that can whitelist allowed functions in the propose function
  bytes32 public constant GOVERNOR_FUNCTIONS_SETTINGS_ROLE = keccak256("GOVERNOR_FUNCTIONS_SETTINGS_ROLE");
  /// @notice The role that can pause the contract
  bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
  /// @notice The role that can set external contracts addresses
  bytes32 public constant CONTRACTS_ADDRESS_MANAGER_ROLE = keccak256("CONTRACTS_ADDRESS_MANAGER_ROLE");
  /// @notice The role that can execute a proposal
  bytes32 public constant PROPOSAL_EXECUTOR_ROLE = keccak256("PROPOSAL_EXECUTOR_ROLE");

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  /**
   * @dev Restricts a function so it can only be executed through governance proposals. For example, governance
   * parameter setters in {GovernorSettings} are protected using this modifier.
   *
   * The governance executing address may be different from the Governor's own address, for example it could be a
   * timelock. This can be customized by modules by overriding {_executor}. The executor is only able to invoke these
   * functions during the execution of the governor's {execute} function, and not under any other circumstances. Thus,
   * for example, additional timelock proposers are not able to change governance parameters without going through the
   * governance protocol (since v4.6).
   */
  modifier onlyGovernance() {
    GovernorStorageTypesV1.GovernorStorage storage $ = getGovernorStorage();
    GovernorGovernanceLogicV1.checkGovernance($, _msgSender(), _msgData(), address(this));
    _;
  }

  /**
   * @notice Modifier to check if the caller has the specified role or if the function is called through a governance proposal
   * @param role The role to check against
   */
  modifier onlyRoleOrGovernance(bytes32 role) {
    GovernorStorageTypesV1.GovernorStorage storage $ = getGovernorStorage();
    if (!hasRole(role, _msgSender()))
      GovernorGovernanceLogicV1.checkGovernance($, _msgSender(), _msgData(), address(this));
    _;
  }

  /**
   * @dev Modifier to make a function callable only by a certain role. In
   * addition to checking the sender's role, `address(0)` 's role is also
   * considered. Granting a role to `address(0)` is equivalent to enabling
   * this role for everyone.
   */
  modifier onlyRoleOrOpenRole(bytes32 role) {
    if (!hasRole(role, address(0))) {
      _checkRole(role, _msgSender());
    }
    _;
  }

  /**
   * @notice Initializes the contract with the initial parameters
   * @param data Initialization data containing the initial settings for the governor
   */
  function initialize(
    GovernorTypesV1.InitializationData memory data,
    GovernorTypesV1.InitializationRolesData memory rolesData
  ) external initializer {
    __GovernorStorage_init(data, "B3TRGovernor");
    __AccessControl_init();
    __UUPSUpgradeable_init();
    __Pausable_init();

    GovernorStorageTypesV1.GovernorStorage storage $ = getGovernorStorage();
    GovernorQuorumLogicV1.updateQuorumNumerator($, data.quorumPercentage);

    // Validate and set the governor external contracts storage
    require(address(rolesData.governorAdmin) != address(0), "B3TRGovernor: governor admin address cannot be zero");
    _grantRole(DEFAULT_ADMIN_ROLE, rolesData.governorAdmin);
    _grantRole(GOVERNOR_FUNCTIONS_SETTINGS_ROLE, rolesData.governorFunctionSettingsRoleAddress);
    _grantRole(PAUSER_ROLE, rolesData.pauser);
    _grantRole(CONTRACTS_ADDRESS_MANAGER_ROLE, rolesData.contractsAddressManager);
    _grantRole(PROPOSAL_EXECUTOR_ROLE, rolesData.proposalExecutor);
  }

  /**
   * @dev Function to receive VET that will be handled by the governor (disabled if executor is a third party contract)
   */
  receive() external payable virtual {
    GovernorStorageTypesV1.GovernorStorage storage $ = getGovernorStorage();
    if (GovernorGovernanceLogicV1.executor($) != address(this)) {
      revert GovernorDisabledDeposit();
    }
  }

  /**
   * @notice Relays a transaction or function call to an arbitrary target. In cases where the governance executor
   * is some contract other than the governor itself, like when using a timelock, this function can be invoked
   * in a governance proposal to recover tokens or Ether that was sent to the governor contract by mistake.
   * Note that if the executor is simply the governor itself, use of `relay` is redundant.
   * @param target The target address
   * @param value The amount of ether to send
   * @param data The data to call the target with
   */
  function relay(address target, uint256 value, bytes calldata data) external payable virtual onlyGovernance {
    (bool success, bytes memory returndata) = target.call{ value: value }(data);
    Address.verifyCallResult(success, returndata);
  }

  // ------------------ GETTERS ------------------ //

  /**
   * @notice Function to know if a proposal is executable or not.
   * If the proposal was created without any targets, values, or calldatas, it is not executable.
   * to check if the proposal is executable.
   * @dev If no calldatas or targets then it's not executable, otherwise it will check if the governance can execute transactions or not.
   * @param proposalId The id of the proposal
   * @return bool True if the proposal needs queuing, false otherwise
   */
  function proposalNeedsQueuing(uint256 proposalId) external view returns (bool) {
    GovernorStorageTypesV1.GovernorStorage storage $ = getGovernorStorage();
    return GovernorProposalLogicV1.proposalNeedsQueuing($, proposalId);
  }

  /**
   * @notice Returns the state of a proposal
   * @param proposalId The id of the proposal
   * @return GovernorTypesV1.ProposalState The state of the proposal
   */
  function state(uint256 proposalId) external view returns (GovernorTypesV1.ProposalState) {
    GovernorStorageTypesV1.GovernorStorage storage $ = getGovernorStorage();
    return GovernorStateLogicV1.state($, proposalId);
  }

  /**
   * @notice Check if the proposal can start in the next round
   * @return bool True if the proposal can start in the next round, false otherwise
   */
  function canProposalStartInNextRound() public view returns (bool) {
    GovernorStorageTypesV1.GovernorStorage storage $ = getGovernorStorage();
    return GovernorProposalLogicV1.canProposalStartInNextRound($);
  }

  /**
   * @notice See {IB3TRGovernor-proposalProposer}.
   * @param proposalId The id of the proposal
   * @return address The address of the proposer
   */
  function proposalProposer(uint256 proposalId) public view virtual returns (address) {
    GovernorStorageTypesV1.GovernorStorage storage $ = getGovernorStorage();
    return GovernorProposalLogicV1.proposalProposer($, proposalId);
  }

  /**
   * @notice See {IB3TRGovernor-proposalEta}.
   * @param proposalId The id of the proposal
   * @return uint256 The ETA of the proposal
   */
  function proposalEta(uint256 proposalId) public view virtual returns (uint256) {
    GovernorStorageTypesV1.GovernorStorage storage $ = getGovernorStorage();
    return GovernorProposalLogicV1.proposalEta($, proposalId);
  }

  /**
   * @notice See {IB3TRGovernor-proposalStartRound}
   * @param proposalId The id of the proposal
   * @return uint256 The start round of the proposal
   */
  function proposalStartRound(uint256 proposalId) public view returns (uint256) {
    GovernorStorageTypesV1.GovernorStorage storage $ = getGovernorStorage();
    return GovernorProposalLogicV1.proposalStartRound($, proposalId);
  }

  /**
   * @notice See {IB3TRGovernor-proposalSnapshot}.
   * We take for granted that the round starts the block after it ends. But it can happen that the round is not started yet for whatever reason.
   * Knowing this, if the proposal starts 4 rounds in the future we need to consider also those extra blocks used to start the rounds.
   * @param proposalId The id of the proposal
   * @return uint256 The snapshot of the proposal
   */
  function proposalSnapshot(uint256 proposalId) external view returns (uint256) {
    GovernorStorageTypesV1.GovernorStorage storage $ = getGovernorStorage();
    return GovernorProposalLogicV1.proposalSnapshot($, proposalId);
  }

  /**
   * @notice See {IB3TRGovernor-proposalDeadline}.
   * @param proposalId The id of the proposal
   * @return uint256 The deadline of the proposal
   */
  function proposalDeadline(uint256 proposalId) external view returns (uint256) {
    GovernorStorageTypesV1.GovernorStorage storage $ = getGovernorStorage();
    return GovernorProposalLogicV1.proposalDeadline($, proposalId);
  }

  /**
   * @notice Returns the deposit threshold
   * @return uint256 The deposit threshold
   */
  function depositThreshold() external view returns (uint256) {
    GovernorStorageTypesV1.GovernorStorage storage $ = getGovernorStorage();
    return GovernorDepositLogicV1.depositThreshold($);
  }

  /**
   * @notice See {Governor-depositThreshold}.
   * @return uint256 The deposit threshold percentage
   */
  function depositThresholdPercentage() external view returns (uint256) {
    GovernorStorageTypesV1.GovernorStorage storage $ = getGovernorStorage();
    return $.depositThresholdPercentage;
  }

  /**
   * @notice See {Governor-votingThreshold}.
   * @return uint256 The voting threshold
   */
  function votingThreshold() external view returns (uint256) {
    GovernorStorageTypesV1.GovernorStorage storage $ = getGovernorStorage();
    return $.votingThreshold;
  }

  /**
   * @notice See {IB3TRGovernor-getVotes}.
   * @param account The address of the account
   * @param timepoint The timepoint to get the votes at
   * @return uint256 The number of votes
   */
  function getVotes(address account, uint256 timepoint) external view returns (uint256) {
    GovernorStorageTypesV1.GovernorStorage storage $ = getGovernorStorage();
    return GovernorVotesLogicV1.getVotes($, account, timepoint);
  }

  /**
   * @notice Returns the quadratic voting power that `account` has.  See {IB3TRGovernor-getQuadraticVotingPower}.
   * @param account The address of the account
   * @param timepoint The timepoint to get the voting power at
   * @return uint256 The quadratic voting power
   */
  function getQuadraticVotingPower(address account, uint256 timepoint) external view returns (uint256) {
    GovernorStorageTypesV1.GovernorStorage storage $ = getGovernorStorage();
    return GovernorVotesLogicV1.getQuadraticVotingPower($, account, timepoint);
  }

  /**
   * @notice Clock (as specified in EIP-6372) is set to match the token's clock. Fallback to block numbers if the token
   * does not implement EIP-6372.
   * @return uint48 The current clock time
   */
  function clock() external view returns (uint48) {
    GovernorStorageTypesV1.GovernorStorage storage $ = getGovernorStorage();
    return GovernorClockLogicV1.clock($);
  }

  /**
   * @notice Machine-readable description of the clock as specified in EIP-6372.
   * @return string The clock mode
   */
  // solhint-disable-next-line func-name-mixedcase
  function CLOCK_MODE() external view returns (string memory) {
    GovernorStorageTypesV1.GovernorStorage storage $ = getGovernorStorage();
    return GovernorClockLogicV1.CLOCK_MODE($);
  }

  /**
   * @notice The token that voting power is sourced from.
   * @return IVOT3 The voting token
   */
  function token() external view returns (IVOT3) {
    GovernorStorageTypesV1.GovernorStorage storage $ = getGovernorStorage();
    return $.vot3;
  }

  /**
   * @notice Returns the quorum for a timepoint, in terms of number of votes: `supply * numerator / denominator`.
   * @param blockNumber The block number to get the quorum for
   * @return uint256 The quorum
   */
  function quorum(uint256 blockNumber) external view returns (uint256) {
    GovernorStorageTypesV1.GovernorStorage storage $ = getGovernorStorage();
    return GovernorQuorumLogicV1.quorum($, blockNumber);
  }

  /**
   * @notice Returns the current quorum numerator. See {quorumDenominator}.
   * @return uint256 The current quorum numerator
   */
  function quorumNumerator() external view returns (uint256) {
    GovernorStorageTypesV1.GovernorStorage storage $ = getGovernorStorage();
    return GovernorQuorumLogicV1.quorumNumerator($);
  }

  /**
   * @notice Returns the quorum numerator at a specific timepoint using the GovernorQuorumFraction library.
   * @param timepoint The timepoint to get the quorum numerator for
   * @return uint256 The quorum numerator at the given timepoint
   */
  function quorumNumerator(uint256 timepoint) external view returns (uint256) {
    GovernorStorageTypesV1.GovernorStorage storage $ = getGovernorStorage();
    return GovernorQuorumLogicV1.quorumNumerator($, timepoint);
  }

  /**
   * @notice Returns the quorum denominator using the GovernorQuorumFraction library. Defaults to 100, but may be overridden.
   * @return uint256 The quorum denominator
   */
  function quorumDenominator() external pure returns (uint256) {
    return GovernorQuorumLogicV1.quorumDenominator();
  }

  /**
   * @notice Check if a function is restricted by the governor
   * @param target The address of the contract
   * @param functionSelector The function selector
   * @return bool True if the function is whitelisted, false otherwise
   */
  function isFunctionWhitelisted(address target, bytes4 functionSelector) external view returns (bool) {
    GovernorStorageTypesV1.GovernorStorage storage $ = getGovernorStorage();
    return GovernorFunctionRestrictionsLogicV1.isFunctionWhitelisted($, target, functionSelector);
  }

  /**
   * @notice See {B3TRGovernor-minVotingDelay}.
   * @return uint256 The minimum voting delay
   */
  function minVotingDelay() external view returns (uint256) {
    GovernorStorageTypesV1.GovernorStorage storage $ = getGovernorStorage();
    return $.minVotingDelay;
  }

  /**
   * @notice See {IB3TRGovernor-votingPeriod}.
   * @return uint256 The voting period
   */
  function votingPeriod() external view returns (uint256) {
    GovernorStorageTypesV1.GovernorStorage storage $ = getGovernorStorage();
    return $.xAllocationVoting.votingPeriod();
  }

  /**
   * @notice Check if a user has voted at least one time.
   * @param user The address of the user to check if has voted at least one time
   * @return bool True if the user has voted once, false otherwise
   */
  function hasVotedOnce(address user) external view returns (bool) {
    GovernorStorageTypesV1.GovernorStorage storage $ = getGovernorStorage();
    return GovernorVotesLogicV1.userVotedOnce($, user);
  }

  /**
   * @notice Returns if quorum was reached or not
   * @param proposalId The id of the proposal
   * @return bool True if quorum was reached, false otherwise
   */
  function quorumReached(uint256 proposalId) external view returns (bool) {
    GovernorStorageTypesV1.GovernorStorage storage $ = getGovernorStorage();
    return GovernorQuorumLogicV1.isQuorumReached($, proposalId);
  }

  /**
   * @notice Returns the total votes for a proposal
   * @param proposalId The id of the proposal
   * @return uint256 The total votes for the proposal
   */
  function proposalTotalVotes(uint256 proposalId) external view returns (uint256) {
    GovernorStorageTypesV1.GovernorStorage storage $ = getGovernorStorage();
    return $.proposalTotalVotes[proposalId];
  }

  /**
   * @notice Accessor to the internal vote counts, in terms of vote power.
   * @param proposalId The id of the proposal
   * @return againstVotes The votes against the proposal
   * @return forVotes The votes for the proposal
   * @return abstainVotes The votes abstaining the proposal
   */
  function proposalVotes(
    uint256 proposalId
  ) external view returns (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes) {
    GovernorStorageTypesV1.GovernorStorage storage $ = getGovernorStorage();
    return GovernorVotesLogicV1.getProposalVotes($, proposalId);
  }

  /**
   * @notice Returns the counting mode
   * @return string The counting mode
   */
  // solhint-disable-next-line func-name-mixedcase
  function COUNTING_MODE() external pure returns (string memory) {
    return "support=bravo&quorum=for,abstain,against";
  }

  /**
   * @notice See {IB3TRGovernor-hasVoted}.
   * @param proposalId The id of the proposal
   * @param account The address of the account
   * @return bool True if the account has voted, false otherwise
   */
  function hasVoted(uint256 proposalId, address account) external view returns (bool) {
    GovernorStorageTypesV1.GovernorStorage storage $ = getGovernorStorage();
    return GovernorVotesLogicV1.hasVoted($, proposalId, account);
  }

  /**
   * @notice Returns the amount of deposits made to a proposal.
   * @param proposalId The id of the proposal.
   * @return uint256 The amount of deposits
   */
  function getProposalDeposits(uint256 proposalId) external view returns (uint256) {
    GovernorStorageTypesV1.GovernorStorage storage $ = getGovernorStorage();
    return GovernorDepositLogicV1.getProposalDeposits($, proposalId);
  }

  /**
   * @notice Returns true if the threshold of deposits required to reach a proposal has been reached.
   * @param proposalId The id of the proposal.
   * @return bool True if the threshold is reached, false otherwise
   */
  function proposalDepositReached(uint256 proposalId) external view returns (bool) {
    GovernorStorageTypesV1.GovernorStorage storage $ = getGovernorStorage();
    return GovernorDepositLogicV1.proposalDepositReached($, proposalId);
  }

  /**
   * @notice Returns the deposit threshold for a proposal.
   * @param proposalId The id of the proposal.
   * @return uint256 The deposit threshold for the proposal.
   */
  function proposalDepositThreshold(uint256 proposalId) external view returns (uint256) {
    GovernorStorageTypesV1.GovernorStorage storage $ = getGovernorStorage();
    return GovernorDepositLogicV1.proposalDepositThreshold($, proposalId);
  }

  /**
   * @notice Public endpoint to retrieve the timelock id of a proposal.
   * @param proposalId The id of the proposal
   * @return bytes32 The timelock id
   */
  function getTimelockId(uint256 proposalId) public view returns (bytes32) {
    GovernorStorageTypesV1.GovernorStorage storage $ = getGovernorStorage();
    return GovernorProposalLogicV1.getTimelockId($, proposalId);
  }

  /**
   * @notice Returns the amount of tokens a specific user has deposited to a proposal.
   * @param proposalId The id of the proposal.
   * @param user The address of the user.
   * @return uint256 The amount of tokens deposited by the user
   */
  function getUserDeposit(uint256 proposalId, address user) external view returns (uint256) {
    GovernorStorageTypesV1.GovernorStorage storage $ = getGovernorStorage();
    return GovernorDepositLogicV1.getUserDeposit($, proposalId, user);
  }

  /**
   * @notice See {IB3TRGovernor-name}.
   * @return string The name of the governor
   */
  function name() external view returns (string memory) {
    GovernorStorageTypesV1.GovernorStorage storage $ = getGovernorStorage();
    return $.name;
  }

  /**
   * @notice See {IB3TRGovernor-version}.
   * @return string The version of the governor
   */
  function version() external pure returns (string memory) {
    return "1";
  }

  /**
   * @notice See {IB3TRGovernor-hashProposal}.
   * The proposal id is produced by hashing the ABI encoded `targets` array, the `values` array, the `calldatas` array
   * and the descriptionHash (bytes32 which itself is the keccak256 hash of the description string). This proposal id
   * can be produced from the proposal data which is part of the {ProposalCreated} event. It can even be computed in
   * advance, before the proposal is submitted.
   * Note that the chainId and the governor address are not part of the proposal id computation. Consequently, the
   * same proposal (with same operation and same description) will have the same id if submitted on multiple governors
   * across multiple networks. This also means that in order to execute the same operation twice (on the same
   * governor) the proposer will have to change the description in order to avoid proposal id conflicts.
   * @param targets The list of target addresses
   * @param values The list of values to send
   * @param calldatas The list of call data
   * @param descriptionHash The hash of the description
   * @return uint256 The proposal id
   */
  function hashProposal(
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    bytes32 descriptionHash
  ) public pure returns (uint256) {
    return GovernorProposalLogicV1.hashProposal(targets, values, calldatas, descriptionHash);
  }

  /**
   * @notice Public endpoint to get the salt used for the timelock operation.
   * @param descriptionHash The hash of the description
   * @return bytes32 The timelock salt
   */
  function timelockSalt(bytes32 descriptionHash) external view returns (bytes32) {
    return GovernorGovernanceLogicV1.timelockSalt(descriptionHash, address(this));
  }

  /**
   * @notice The voter rewards contract.
   * @return IVoterRewards The voter rewards contract
   */
  function voterRewards() external view returns (IVoterRewards) {
    GovernorStorageTypesV1.GovernorStorage storage $ = getGovernorStorage();
    return $.voterRewards;
  }

  /**
   * @notice The XAllocationVotingGovernor contract.
   * @return IXAllocationVotingGovernor The XAllocationVotingGovernor contract
   */
  function xAllocationVoting() external view returns (IXAllocationVotingGovernor) {
    GovernorStorageTypesV1.GovernorStorage storage $ = getGovernorStorage();
    return $.xAllocationVoting;
  }

  /**
   * @notice See {B3TRGovernor-b3tr}.
   * @return IB3TR The B3TR contract
   */
  function b3tr() external view returns (IB3TR) {
    GovernorStorageTypesV1.GovernorStorage storage $ = getGovernorStorage();
    return $.b3tr;
  }

  /**
   * @notice Public accessor to check the address of the timelock
   * @return address The address of the timelock
   */
  function timelock() external view virtual returns (address) {
    GovernorStorageTypesV1.GovernorStorage storage $ = getGovernorStorage();
    return address($.timelock);
  }

  // ------------------ SETTERS ------------------ //

  /**
   * @notice Pause the contract
   */
  function pause() external onlyRole(PAUSER_ROLE) {
    _pause();
  }

  /**
   * @notice Unpause the contract
   */
  function unpause() external onlyRole(PAUSER_ROLE) {
    _unpause();
  }

  /**
   * @notice See {IB3TRGovernor-propose}.
   * Callable only when contract is not paused.
   * @param targets The list of target addresses
   * @param values The list of values to send
   * @param calldatas The list of call data
   * @param description The proposal description
   * @param startRoundId The round in which the proposal should start
   * @param depositAmount The amount of deposit for the proposal
   * @return uint256 The proposal id
   */
  function propose(
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    string memory description,
    uint256 startRoundId,
    uint256 depositAmount
  ) external whenNotPaused returns (uint256) {
    GovernorStorageTypesV1.GovernorStorage storage $ = getGovernorStorage();
    return GovernorProposalLogicV1.propose($, targets, values, calldatas, description, startRoundId, depositAmount);
  }

  /**
   * @notice See {IB3TRGovernor-queue}.
   * Callable only when contract is not paused.
   * @param targets The list of target addresses
   * @param values The list of values to send
   * @param calldatas The list of call data
   * @param descriptionHash The hash of the description
   * @return uint256 The proposal id
   */
  function queue(
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    bytes32 descriptionHash
  ) external whenNotPaused returns (uint256) {
    GovernorStorageTypesV1.GovernorStorage storage $ = getGovernorStorage();
    return GovernorProposalLogicV1.queue($, address(this), targets, values, calldatas, descriptionHash);
  }

  /**
   * @notice See {IB3TRGovernor-execute}.
   * Callable only when contract is not paused.
   * @param targets The list of target addresses
   * @param values The list of values to send
   * @param calldatas The list of call data
   * @param descriptionHash The hash of the description
   * @return uint256 The proposal id
   */
  function execute(
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    bytes32 descriptionHash
  ) external payable whenNotPaused onlyRoleOrOpenRole(PROPOSAL_EXECUTOR_ROLE) returns (uint256) {
    GovernorStorageTypesV1.GovernorStorage storage $ = getGovernorStorage();
    return GovernorProposalLogicV1.execute($, address(this), targets, values, calldatas, descriptionHash);
  }

  /**
   * @notice See {Governor-cancel}.
   * @param targets The list of target addresses
   * @param values The list of values to send
   * @param calldatas The list of call data
   * @param descriptionHash The hash of the description
   * @return uint256 The proposal id
   */
  function cancel(
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    bytes32 descriptionHash
  ) external returns (uint256) {
    GovernorStorageTypesV1.GovernorStorage storage $ = getGovernorStorage();
    return
      GovernorProposalLogicV1.cancel(
        $,
        _msgSender(),
        hasRole(DEFAULT_ADMIN_ROLE, _msgSender()),
        targets,
        values,
        calldatas,
        descriptionHash
      );
  }

  /**
   * @notice See {IB3TRGovernor-castVote}.
   * @param proposalId The id of the proposal
   * @param support The support value (0 = against, 1 = for, 2 = abstain)
   * @return uint256 The voting power
   */
  function castVote(uint256 proposalId, uint8 support) external returns (uint256) {
    GovernorStorageTypesV1.GovernorStorage storage $ = getGovernorStorage();
    return GovernorVotesLogicV1.castVote($, proposalId, _msgSender(), support, "");
  }

  /**
   * @notice See {IB3TRGovernor-castVoteWithReason}.
   * @param proposalId The id of the proposal
   * @param support The support value (0 = against, 1 = for, 2 = abstain)
   * @param reason The reason for the vote
   * @return uint256 The voting power
   */
  function castVoteWithReason(uint256 proposalId, uint8 support, string calldata reason) external returns (uint256) {
    GovernorStorageTypesV1.GovernorStorage storage $ = getGovernorStorage();
    return GovernorVotesLogicV1.castVote($, proposalId, _msgSender(), support, reason);
  }

  /**
   * @notice Withdraws deposits for a specific proposal
   * @param proposalId The id of the proposal
   * @param depositor The address of the depositor
   */
  function withdraw(uint256 proposalId, address depositor) external {
    GovernorStorageTypesV1.GovernorStorage storage $ = getGovernorStorage();
    GovernorDepositLogicV1.withdraw($, proposalId, depositor);
  }

  /**
   * @notice Deposits tokens for a specific proposal
   * @param amount The amount of tokens to deposit
   * @param proposalId The id of the proposal
   */
  function deposit(uint256 amount, uint256 proposalId) external {
    GovernorStorageTypesV1.GovernorStorage storage $ = getGovernorStorage();
    GovernorDepositLogicV1.deposit($, amount, proposalId);
  }

  /**
   * @notice Changes the quorum numerator.
   * This operation can only be performed through a governance proposal.
   * Emits a {QuorumNumeratorUpdated} event.
   * @param newQuorumNumerator The new quorum numerator
   */
  function updateQuorumNumerator(uint256 newQuorumNumerator) external onlyGovernance {
    GovernorStorageTypesV1.GovernorStorage storage $ = getGovernorStorage();
    GovernorQuorumLogicV1.updateQuorumNumerator($, newQuorumNumerator);
  }

  /**
   * @notice Method that allows to restrict functions that can be called by proposals for a single function selector
   * @param target The address of the contract
   * @param functionSelector The function selector
   * @param isWhitelisted Bool indicating if function is whitelisted for proposals
   */
  function setWhitelistFunction(
    address target,
    bytes4 functionSelector,
    bool isWhitelisted
  ) public onlyRoleOrGovernance(GOVERNOR_FUNCTIONS_SETTINGS_ROLE) {
    GovernorStorageTypesV1.GovernorStorage storage $ = getGovernorStorage();
    GovernorFunctionRestrictionsLogicV1.setWhitelistFunction($, target, functionSelector, isWhitelisted);
  }

  /**
   * @notice Method that allows to restrict functions that can be called by proposals for multiple function selectors at once
   * @param target The address of the contract
   * @param functionSelectors Array of function selectors
   * @param isWhitelisted Bool indicating if function is whitelisted for proposals
   */
  function setWhitelistFunctions(
    address target,
    bytes4[] memory functionSelectors,
    bool isWhitelisted
  ) public onlyRoleOrGovernance(GOVERNOR_FUNCTIONS_SETTINGS_ROLE) {
    GovernorStorageTypesV1.GovernorStorage storage $ = getGovernorStorage();
    GovernorFunctionRestrictionsLogicV1.setWhitelistFunctions($, target, functionSelectors, isWhitelisted);
  }

  /**
   * @notice Method that allows to toggle the function restriction on/off
   * @param isEnabled Flag to enable/disable function restriction
   */
  function setIsFunctionRestrictionEnabled(
    bool isEnabled
  ) public onlyRoleOrGovernance(GOVERNOR_FUNCTIONS_SETTINGS_ROLE) {
    GovernorStorageTypesV1.GovernorStorage storage $ = getGovernorStorage();
    GovernorFunctionRestrictionsLogicV1.setIsFunctionRestrictionEnabled($, isEnabled);
  }

  /**
   * @notice Update the deposit threshold. This operation can only be performed through a governance proposal.
   * Emits a {DepositThresholdSet} event.
   * @param newDepositThreshold The new deposit threshold
   */
  function setDepositThresholdPercentage(uint256 newDepositThreshold) public onlyGovernance {
    GovernorStorageTypesV1.GovernorStorage storage $ = getGovernorStorage();
    GovernorConfiguratorV1.setDepositThresholdPercentage($, newDepositThreshold);
  }

  /**
   * @notice Update the voting threshold. This operation can only be performed through a governance proposal.
   * Emits a {VotingThresholdSet} event.
   * @param newVotingThreshold The new voting threshold
   */
  function setVotingThreshold(uint256 newVotingThreshold) public onlyGovernance {
    GovernorStorageTypesV1.GovernorStorage storage $ = getGovernorStorage();
    GovernorConfiguratorV1.setVotingThreshold($, newVotingThreshold);
  }

  /**
   * @notice Update the min voting delay before vote can start.
   * This operation can only be performed through a governance proposal.
   * Emits a {MinVotingDelaySet} event.
   * @param newMinVotingDelay The new minimum voting delay
   */
  function setMinVotingDelay(uint256 newMinVotingDelay) public onlyGovernance {
    GovernorStorageTypesV1.GovernorStorage storage $ = getGovernorStorage();
    GovernorConfiguratorV1.setMinVotingDelay($, newMinVotingDelay);
  }

  /**
   * @notice Set the voter rewards contract
   * This function is only callable through governance proposals or by the CONTRACTS_ADDRESS_MANAGER_ROLE
   * @param newVoterRewards The new voter rewards contract
   */
  function setVoterRewards(IVoterRewards newVoterRewards) public onlyRoleOrGovernance(CONTRACTS_ADDRESS_MANAGER_ROLE) {
    GovernorStorageTypesV1.GovernorStorage storage $ = getGovernorStorage();
    GovernorConfiguratorV1.setVoterRewards($, newVoterRewards);
  }

  /**
   * @notice Set the xAllocationVoting contract
   * This function is only callable through governance proposals or by the CONTRACTS_ADDRESS_MANAGER_ROLE
   * @param newXAllocationVoting The new xAllocationVoting contract
   */
  function setXAllocationVoting(
    IXAllocationVotingGovernor newXAllocationVoting
  ) public onlyRoleOrGovernance(CONTRACTS_ADDRESS_MANAGER_ROLE) {
    GovernorStorageTypesV1.GovernorStorage storage $ = getGovernorStorage();
    GovernorConfiguratorV1.setXAllocationVoting($, newXAllocationVoting);
  }

  /**
   * @notice Public endpoint to update the underlying timelock instance. Restricted to the timelock itself, so updates
   * must be proposed, scheduled, and executed through governance proposals.
   * CAUTION: It is not recommended to change the timelock while there are other queued governance proposals.
   * @param newTimelock The new timelock controller
   */
  function updateTimelock(TimelockControllerUpgradeable newTimelock) external virtual onlyGovernance {
    GovernorStorageTypesV1.GovernorStorage storage $ = getGovernorStorage();
    GovernorConfiguratorV1.updateTimelock($, newTimelock);
  }

  // ------------------ Overrides ------------------ //

  /**
   * @notice Authorizes upgrade to a new implementation
   * @param newImplementation The address of the new implementation
   */
  function _authorizeUpgrade(address newImplementation) internal override onlyRoleOrGovernance(DEFAULT_ADMIN_ROLE) {}

  /**
   * @notice Checks if the contract supports a specific interface
   * @param interfaceId The interface id to check
   * @return bool True if the interface is supported, false otherwise
   */
  function supportsInterface(
    bytes4 interfaceId
  ) public pure override(IERC165, AccessControlUpgradeable) returns (bool) {
    return
      interfaceId == type(IB3TRGovernorV1).interfaceId ||
      interfaceId == type(IERC1155Receiver).interfaceId ||
      interfaceId == type(IERC165).interfaceId;
  }

  /**
   * @notice See {IERC1155Receiver-onERC1155Received}.
   * Receiving tokens is disabled if the governance executor is other than the governor itself (eg. when using with a timelock).
   * @return bytes4 The selector of the function
   */
  function onERC1155Received(address, address, uint256, uint256, bytes memory) public virtual returns (bytes4) {
    GovernorStorageTypesV1.GovernorStorage storage $ = getGovernorStorage();
    if (GovernorGovernanceLogicV1.executor($) != address(this)) {
      revert GovernorDisabledDeposit();
    }
    return this.onERC1155Received.selector;
  }

  /**
   * @notice See {IERC721Receiver-onERC721Received}.
   * Receiving tokens is disabled if the governance executor is other than the governor itself (eg. when using with a timelock).
   * @return bytes4 The selector of the function
   */
  function onERC721Received(address, address, uint256, bytes memory) public virtual returns (bytes4) {
    GovernorStorageTypesV1.GovernorStorage storage $ = getGovernorStorage();
    if (GovernorGovernanceLogicV1.executor($) != address(this)) {
      revert GovernorDisabledDeposit();
    }
    return this.onERC721Received.selector;
  }

  /**
   * @notice See {IERC1155Receiver-onERC1155BatchReceived}.
   * Receiving tokens is disabled if the governance executor is other than the governor itself (eg. when using with a timelock).
   * @return bytes4 The selector of the function
   */
  function onERC1155BatchReceived(
    address,
    address,
    uint256[] memory,
    uint256[] memory,
    bytes memory
  ) public virtual returns (bytes4) {
    GovernorStorageTypesV1.GovernorStorage storage $ = getGovernorStorage();
    if (GovernorGovernanceLogicV1.executor($) != address(this)) {
      revert GovernorDisabledDeposit();
    }
    return this.onERC1155BatchReceived.selector;
  }
}

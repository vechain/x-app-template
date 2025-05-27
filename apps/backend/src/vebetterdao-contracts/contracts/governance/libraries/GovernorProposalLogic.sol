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
import { GovernorTypes } from "./GovernorTypes.sol";
import { GovernorStateLogic } from "./GovernorStateLogic.sol";
import { GovernorClockLogic } from "./GovernorClockLogic.sol";
import { GovernorDepositLogic } from "./GovernorDepositLogic.sol";
import { GovernorGovernanceLogic } from "./GovernorGovernanceLogic.sol";
import { GovernorFunctionRestrictionsLogic } from "./GovernorFunctionRestrictionsLogic.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { DoubleEndedQueue } from "@openzeppelin/contracts/utils/structs/DoubleEndedQueue.sol";

/// @title GovernorProposalLogic
/// @notice Library for managing proposals in the Governor contract.
/// @dev This library provides functions to create, cancel, execute, and validate proposals.
library GovernorProposalLogic {
  using DoubleEndedQueue for DoubleEndedQueue.Bytes32Deque;

  /**
   * @dev Emitted when a proposal is canceled.
   */
  event ProposalCanceled(uint256 proposalId);

  /**
   * @dev Emitted when a proposal is created.
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
   * @dev Emitted when a proposal is executed.
   */
  event ProposalExecuted(uint256 proposalId);

  /**
   * @dev Emitted when a proposal is queued.
   */
  event ProposalQueued(uint256 proposalId, uint256 etaSeconds);

  /**
   * @dev Thrown when the current state of a proposal is not the expected state for an operation.
   */
  error GovernorUnexpectedProposalState(
    uint256 proposalId,
    GovernorTypes.ProposalState current,
    bytes32 expectedStates
  );

  /**
   * @dev Thrown when a user is not authorized to perform an action.
   */
  error UnauthorizedAccess(address user);

  /**
   * @dev Thrown when the round for proposal start is invalid.
   */
  error GovernorInvalidStartRound(uint256 roundId);

  /**
   * @dev Thrown when a queue operation is not implemented.
   */
  error GovernorQueueNotImplemented();

  /**
   * @dev Thrown when there is an empty proposal or a mismatch between parameters length for a proposal call.
   */
  error GovernorInvalidProposalLength(uint256 targets, uint256 calldatas, uint256 values);

  /**
   * @dev Thrown when the proposer is not allowed to create a proposal.
   */
  error GovernorRestrictedProposer(address proposer);

  /** ------------------ GETTERS ------------------ **/

  /**
   * @notice Returns the hash of a proposal.
   * @dev Hashes the proposal parameters to produce a unique proposal id.
   * @param targets The addresses of the contracts to call.
   * @param values The values to send to the contracts.
   * @param calldatas The function signatures and arguments.
   * @param descriptionHash The hash of the proposal description.
   * @return The proposal id.
   */
  function hashProposal(
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    bytes32 descriptionHash
  ) internal pure returns (uint256) {
    return uint256(keccak256(abi.encode(targets, values, calldatas, descriptionHash)));
  }

  /**
   * @notice Returns the proposer of a proposal.
   * @param self The storage reference for the GovernorStorage.
   * @param proposalId The id of the proposal.
   * @return The address of the proposer.
   */
  function proposalProposer(
    GovernorStorageTypes.GovernorStorage storage self,
    uint256 proposalId
  ) internal view returns (address) {
    return self.proposals[proposalId].proposer;
  }

  /**
   * @notice Returns the eta (estimated time of arrival) of a proposal.
   * @param self The storage reference for the GovernorStorage.
   * @param proposalId The id of the proposal.
   * @return The eta in seconds.
   */
  function proposalEta(
    GovernorStorageTypes.GovernorStorage storage self,
    uint256 proposalId
  ) internal view returns (uint256) {
    return self.proposals[proposalId].etaSeconds;
  }

  /**
   * @notice Returns the start round of a proposal.
   * @param self The storage reference for the GovernorStorage.
   * @param proposalId The id of the proposal.
   * @return The start round id.
   */
  function proposalStartRound(
    GovernorStorageTypes.GovernorStorage storage self,
    uint256 proposalId
  ) internal view returns (uint256) {
    return self.proposals[proposalId].roundIdVoteStart;
  }

  /**
   * @notice Returns the snapshot block of a proposal.
   * @dev Determines the block number at which the proposal was snapshot.
   * @param self The storage reference for the GovernorStorage.
   * @param proposalId The id of the proposal.
   * @return The snapshot block number.
   */
  function proposalSnapshot(
    GovernorStorageTypes.GovernorStorage storage self,
    uint256 proposalId
  ) external view returns (uint256) {
    return _proposalSnapshot(self, proposalId);
  }

  /**
   * @notice Returns the deadline block of a proposal.
   * @dev Determines the block number at which the proposal will be considered expired.
   * @param self The storage reference for the GovernorStorage.
   * @param proposalId The id of the proposal.
   * @return The deadline block number.
   */
  function proposalDeadline(
    GovernorStorageTypes.GovernorStorage storage self,
    uint256 proposalId
  ) external view returns (uint256) {
    return _proposalDeadline(self, proposalId);
  }

  /**
   * @notice Returns whether a proposal can start in the next round.
   * @param self The storage reference for the GovernorStorage.
   * @return True if the proposal can start in the next round, false otherwise.
   */
  function canProposalStartInNextRound(GovernorStorageTypes.GovernorStorage storage self) external view returns (bool) {
    return _canProposalStartInNextRound(self);
  }

  /**
   * @notice Returns the total votes for a proposal.
   * @param self The storage reference for the GovernorStorage.
   * @param proposalId The id of the proposal.
   * @return The total votes for the proposal.
   */
  function getProposalTotalVotes(
    GovernorStorageTypes.GovernorStorage storage self,
    uint256 proposalId
  ) internal view returns (uint256) {
    return self.proposalTotalVotes[proposalId];
  }

  /**
   * @notice Returns the timelock id of a proposal.
   * @param self The storage reference for the GovernorStorage.
   * @param proposalId The id of the proposal.
   * @return The timelock id of the proposal.
   */
  function getTimelockId(
    GovernorStorageTypes.GovernorStorage storage self,
    uint256 proposalId
  ) internal view returns (bytes32) {
    return self.timelockIds[proposalId];
  }

  /** ------------------ SETTERS ------------------ **/

  /**
   * @notice Proposes a new governance action.
   * @dev Creates a new proposal and validates the proposal parameters.
   * @param self The storage reference for the GovernorStorage.
   * @param targets The addresses of the contracts to call.
   * @param values The values to send to the contracts.
   * @param calldatas The function signatures and arguments.
   * @param description The description of the proposal.
   * @param startRoundId The round in which the proposal should be active.
   * @param depositAmount The amount of tokens the proposer intends to deposit.
   * @return The proposal id.
   */
  function propose(
    GovernorStorageTypes.GovernorStorage storage self,
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    string memory description,
    uint256 startRoundId,
    uint256 depositAmount
  ) external returns (uint256) {
    address proposer = msg.sender;

    uint256 proposalId = hashProposal(targets, values, calldatas, keccak256(bytes(description)));

    validateProposeParams(self, proposer, startRoundId, description, targets, values, calldatas, proposalId);

    return _propose(self, proposer, proposalId, targets, values, calldatas, description, startRoundId, depositAmount);
  }

  /**
   * @dev Function to know if a proposal is executable or not.
   * If the proposal was creted without any targets, values, or calldatas, it is not executable.
   * to check if the proposal is executable.
   *
   * @param proposalId The id of the proposal
   */
  function proposalNeedsQueuing(
    GovernorStorageTypes.GovernorStorage storage self,
    uint256 proposalId
  ) external view returns (bool) {
    GovernorTypes.ProposalCore storage proposal = self.proposals[proposalId];
    if (proposal.roundIdVoteStart == 0) {
      return false;
    }

    if (proposal.isExecutable) {
      return true;
    } else {
      return false;
    }
  }

  /**
   * @notice Queues a proposal for execution.
   * @dev Queues the proposal in the timelock.
   * @param self The storage reference for the GovernorStorage.
   * @param contractAddress The address of the calling contract.
   * @param targets The addresses of the contracts to call.
   * @param values The values to send to the contracts.
   * @param calldatas The function signatures and arguments.
   * @param descriptionHash The hash of the proposal description.
   * @return The proposal id.
   */
  function queue(
    GovernorStorageTypes.GovernorStorage storage self,
    address contractAddress, // Address of the calling contract
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    bytes32 descriptionHash
  ) external returns (uint256) {
    uint256 proposalId = hashProposal(targets, values, calldatas, descriptionHash);

    GovernorStateLogic.validateStateBitmap(
      self,
      proposalId,
      GovernorStateLogic.encodeStateBitmap(GovernorTypes.ProposalState.Succeeded)
    );

    uint48 etaSeconds = _queueOperations(
      self,
      contractAddress,
      proposalId,
      targets,
      values,
      calldatas,
      descriptionHash
    );

    if (etaSeconds != 0) {
      self.proposals[proposalId].etaSeconds = etaSeconds;
      emit ProposalQueued(proposalId, etaSeconds);
    } else {
      revert GovernorQueueNotImplemented();
    }

    return proposalId;
  }

  /**
   * @notice Executes a queued proposal.
   * @dev Executes the proposal in the timelock.
   * @param self The storage reference for the GovernorStorage.
   * @param contractAddress The address of the calling contract.
   * @param targets The addresses of the contracts to call.
   * @param values The values to send to the contracts.
   * @param calldatas The function signatures and arguments.
   * @param descriptionHash The hash of the proposal description.
   * @return The proposal id.
   */
  function execute(
    GovernorStorageTypes.GovernorStorage storage self,
    address contractAddress, // Address of the calling contract
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    bytes32 descriptionHash
  ) external returns (uint256) {
    uint256 proposalId = hashProposal(targets, values, calldatas, descriptionHash);

    GovernorStateLogic.validateStateBitmap(
      self,
      proposalId,
      GovernorStateLogic.encodeStateBitmap(GovernorTypes.ProposalState.Succeeded) |
        GovernorStateLogic.encodeStateBitmap(GovernorTypes.ProposalState.Queued)
    );

    // mark as executed before calls to avoid reentrancy
    self.proposals[proposalId].executed = true;

    // before execute: register governance call in queue.
    if (GovernorGovernanceLogic.executor(self) != contractAddress) {
      for (uint256 i; i < targets.length; ++i) {
        if (targets[i] == address(this)) {
          self.governanceCall.pushBack(keccak256(calldatas[i]));
        }
      }
    }

    _executeOperations(self, contractAddress, proposalId, targets, values, calldatas, descriptionHash);

    // after execute: cleanup governance call queue.
    if (GovernorGovernanceLogic.executor(self) != contractAddress && !self.governanceCall.empty()) {
      self.governanceCall.clear();
    }

    emit ProposalExecuted(proposalId);

    return proposalId;
  }

  /**
   * @notice Cancels a proposal.
   * @dev Cancels a proposal in any state other than Canceled or Executed.
   * @param self The storage reference for the GovernorStorage.
   * @param targets The addresses of the contracts to call.
   * @param values The values to send to the contracts.
   * @param calldatas The function signatures and arguments.
   * @param descriptionHash The hash of the proposal description.
   * @return The proposal id.
   */
  function cancel(
    GovernorStorageTypes.GovernorStorage storage self,
    address account,
    bool admin,
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    bytes32 descriptionHash
  ) external returns (uint256) {
    uint256 proposalId = hashProposal(targets, values, calldatas, descriptionHash);

    if (account != proposalProposer(self, proposalId) && !admin) {
      revert UnauthorizedAccess(account);
    }

    GovernorStateLogic.validateStateBitmap(
      self,
      proposalId,
      GovernorStateLogic.ALL_PROPOSAL_STATES_BITMAP ^
        GovernorStateLogic.encodeStateBitmap(GovernorTypes.ProposalState.Canceled) ^
        GovernorStateLogic.encodeStateBitmap(GovernorTypes.ProposalState.Executed)
    );

    if (account == proposalProposer(self, proposalId)) {
      require(
        GovernorStateLogic._state(self, proposalId) == GovernorTypes.ProposalState.Pending,
        "Governor: proposal not pending"
      );
    }

    bytes32 timelockId = self.timelockIds[proposalId];
    if (timelockId != 0) {
      // cancel
      self.timelock.cancel(timelockId);
      // cleanup
      delete self.timelockIds[proposalId];
    }

    return _cancel(self, proposalId);
  }

  /** ------------------ INTERNAL FUNCTIONS ------------------ **/

  /**
   * @dev Internal function to propose a new governance action.
   * @param self The storage reference for the GovernorStorage.
   * @param proposer The address of the proposer.
   * @param proposalId The id of the proposal.
   * @param targets The addresses of the contracts to call.
   * @param values The values to send to the contracts.
   * @param calldatas The function signatures and arguments.
   * @param description The description of the proposal.
   * @param startRoundId The round in which the proposal should be active.
   * @param depositAmount The amount of tokens the proposer intends to deposit.
   * @return The proposal id.
   */
  function _propose(
    GovernorStorageTypes.GovernorStorage storage self,
    address proposer,
    uint256 proposalId,
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    string memory description,
    uint256 startRoundId,
    uint256 depositAmount
  ) private returns (uint256) {
    uint256 depositThresholdAmount = GovernorDepositLogic._depositThreshold(self);

    _setProposal(
      self,
      proposalId,
      proposer,
      SafeCast.toUint32(self.xAllocationVoting.votingPeriod()),
      startRoundId,
      targets.length > 0,
      depositAmount,
      depositThresholdAmount
    );

    if (depositAmount > 0) {
      GovernorDepositLogic.depositFunds(self, depositAmount, proposer, proposalId);
    }

    emit ProposalCreated(
      proposalId,
      proposer,
      targets,
      values,
      new string[](targets.length),
      calldatas,
      description,
      startRoundId,
      depositThresholdAmount
    );

    return proposalId;
  }

  /**
   * @dev Internal function to validate the parameters of a proposal.
   * @param self The storage reference for the GovernorStorage.
   * @param proposer The address of the proposer.
   * @param startRoundId The round in which the proposal should be active.
   * @param description The description of the proposal.
   * @param targets The addresses of the contracts to call.
   * @param values The values to send to the contracts.
   * @param calldatas The function signatures and arguments.
   * @param proposalId The id of the proposal.
   */
  function validateProposeParams(
    GovernorStorageTypes.GovernorStorage storage self,
    address proposer,
    uint256 startRoundId,
    string memory description,
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    uint256 proposalId
  ) private view {
    // round must be in the future
    if (startRoundId <= self.xAllocationVoting.currentRoundId()) {
      revert GovernorInvalidStartRound(startRoundId);
    }

    // only do this check if user wants to start proposal in the next round
    if (startRoundId == self.xAllocationVoting.currentRoundId() + 1) {
      if (!_canProposalStartInNextRound(self)) {
        revert GovernorInvalidStartRound(startRoundId);
      }
    }

    // check description restriction
    if (!isValidDescriptionForProposer(proposer, description)) {
      revert GovernorRestrictedProposer(proposer);
    }

    if (targets.length != values.length || targets.length != calldatas.length) {
      revert GovernorInvalidProposalLength(targets.length, calldatas.length, values.length);
    }

    if (self.proposals[proposalId].roundIdVoteStart != 0) {
      // Proposal already exists
      revert GovernorUnexpectedProposalState(proposalId, GovernorStateLogic._state(self, proposalId), bytes32(0));
    }

    GovernorFunctionRestrictionsLogic.checkFunctionsRestriction(self, targets, calldatas);
  }

  /**
   * @dev Internal function to set the data of a proposal in storage.
   * @param self The storage reference for the GovernorStorage.
   * @param proposalId The id of the proposal.
   * @param proposer The address of the proposer.
   * @param voteDuration The duration of the vote.
   * @param roundIdVoteStart The round in which the proposal should be active.
   * @param isExecutable Whether the proposal is executable.
   * @param depositAmount The amount of tokens the proposer intends to deposit.
   * @param proposalDepositThreshold The deposit threshold for the proposal.
   */
  function _setProposal(
    GovernorStorageTypes.GovernorStorage storage self,
    uint256 proposalId,
    address proposer,
    uint32 voteDuration,
    uint256 roundIdVoteStart,
    bool isExecutable,
    uint256 depositAmount,
    uint256 proposalDepositThreshold
  ) private {
    GovernorTypes.ProposalCore storage proposal = self.proposals[proposalId];

    proposal.proposer = proposer;
    proposal.roundIdVoteStart = roundIdVoteStart;
    proposal.voteDuration = voteDuration;
    proposal.isExecutable = isExecutable;
    proposal.depositAmount = depositAmount;
    proposal.depositThreshold = proposalDepositThreshold;
  }

  /**
   * @dev Internal function to execute operations of a proposal.
   * @param self The storage reference for the GovernorStorage.
   * @param contractAddress The address of the calling contract.
   * @param proposalId The id of the proposal.
   * @param targets The addresses of the contracts to call.
   * @param values The values to send to the contracts.
   * @param calldatas The function signatures and arguments.
   * @param descriptionHash The hash of the proposal description.
   */
  function _executeOperations(
    GovernorStorageTypes.GovernorStorage storage self,
    address contractAddress, // Address of the calling contract
    uint256 proposalId,
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    bytes32 descriptionHash
  ) private {
    // execute
    self.timelock.executeBatch{ value: msg.value }(
      targets,
      values,
      calldatas,
      0,
      GovernorGovernanceLogic.timelockSalt(descriptionHash, contractAddress)
    );
    // cleanup for refund
    delete self.timelockIds[proposalId];
  }

  /**
   * @dev Internal function to queue operations of a proposal in the timelock.
   * @param self The storage reference for the GovernorStorage.
   * @param contractAddress The address of the calling contract.
   * @param proposalId The id of the proposal.
   * @param targets The addresses of the contracts to call.
   * @param values The values to send to the contracts.
   * @param calldatas The function signatures and arguments.
   * @param descriptionHash The hash of the proposal description.
   * @return The eta (estimated time of arrival) in seconds.
   */
  function _queueOperations(
    GovernorStorageTypes.GovernorStorage storage self,
    address contractAddress, // Address of the calling contract
    uint256 proposalId,
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    bytes32 descriptionHash
  ) private returns (uint48) {
    uint256 delay = self.timelock.getMinDelay();

    bytes32 salt = GovernorGovernanceLogic.timelockSalt(descriptionHash, contractAddress);
    self.timelockIds[proposalId] = self.timelock.hashOperationBatch(targets, values, calldatas, 0, salt);
    self.timelock.scheduleBatch(targets, values, calldatas, 0, salt, delay);

    return SafeCast.toUint48(block.timestamp + delay);
  }

  /**
   * @dev Internal function to cancel a proposal.
   * @param self The storage reference for the GovernorStorage.
   * @param proposalId The id of the proposal.
   * @return The proposal id.
   */
  function _cancel(GovernorStorageTypes.GovernorStorage storage self, uint256 proposalId) private returns (uint256) {
    self.proposals[proposalId].canceled = true;
    emit ProposalCanceled(proposalId);

    return proposalId;
  }

  /**
   * @dev Internal function to validate if a proposal can start in the next round.
   * @param self The storage reference for the GovernorStorage.
   * @return True if the proposal can start in the next round, false otherwise.
   */
  function _canProposalStartInNextRound(
    GovernorStorageTypes.GovernorStorage storage self
  ) internal view returns (bool) {
    uint256 currentRoundId = self.xAllocationVoting.currentRoundId();
    uint256 currentRoundDeadline = self.xAllocationVoting.roundDeadline(currentRoundId);
    uint48 currentBlock = GovernorClockLogic.clock(self);

    // this could happen if the round ended and the next one not started yet
    if (currentRoundDeadline <= currentBlock) {
      return false;
    }

    // if between now and the start of the new round is less then the min delay, revert
    if (self.minVotingDelay > currentRoundDeadline - currentBlock) {
      return false;
    }

    return true;
  }

  /**
   * @dev Internal function to get the snapshot block of a proposal.
   * @param self The storage reference for the GovernorStorage.
   * @param proposalId The id of the proposal.
   * @return The snapshot block number.
   */
  function _proposalSnapshot(
    GovernorStorageTypes.GovernorStorage storage self,
    uint256 proposalId
  ) internal view returns (uint256) {
    // round when proposal should be active is already started
    if (self.xAllocationVoting.currentRoundId() >= self.proposals[proposalId].roundIdVoteStart) {
      return self.xAllocationVoting.roundSnapshot(self.proposals[proposalId].roundIdVoteStart);
    }

    uint256 amountOfRoundsLeft = self.proposals[proposalId].roundIdVoteStart - self.xAllocationVoting.currentRoundId();
    uint256 roundsDurationLeft = self.xAllocationVoting.votingPeriod() * (amountOfRoundsLeft - 1); // -1 because if only 1 round left we want this to be 0
    uint256 currentRoundDeadline = self.xAllocationVoting.currentRoundDeadline();

    // if current round ended and a new one did not start yet
    if (currentRoundDeadline <= GovernorClockLogic.clock(self)) {
      currentRoundDeadline = GovernorClockLogic.clock(self);
    }

    return currentRoundDeadline + roundsDurationLeft + amountOfRoundsLeft;
  }

  /**
   * @dev Internal function to get the deadline block of a proposal.
   * @param self The storage reference for the GovernorStorage.
   * @param proposalId The id of the proposal.
   * @return The deadline block number.
   */
  function _proposalDeadline(
    GovernorStorageTypes.GovernorStorage storage self,
    uint256 proposalId
  ) internal view returns (uint256) {
    // if round is active or already occured proposal end block is the block when round ends
    if (self.xAllocationVoting.currentRoundId() >= self.proposals[proposalId].roundIdVoteStart) {
      return self.xAllocationVoting.roundDeadline(self.proposals[proposalId].roundIdVoteStart);
    }

    // if we call this function before the round starts, it will return 0, so we need to estimate the end block
    return _proposalSnapshot(self, proposalId) + self.xAllocationVoting.votingPeriod();
  }

  /** ------------------ PRIVATE FUNCTIONS ------------------ **/

  /**
   * @dev Checks if the description string ends with a proposer's address suffix.
   * @param proposer The address of the proposer.
   * @param description The description of the proposal.
   * @return True if the suffix matches the proposer's address or if there is no suffix, false otherwise.
   */
  function isValidDescriptionForProposer(address proposer, string memory description) private pure returns (bool) {
    uint256 len = bytes(description).length;

    // Length is too short to contain a valid proposer suffix
    if (len < 52) {
      return true;
    }

    // Extract what would be the `#proposer=0x` marker beginning the suffix
    bytes12 marker;
    assembly {
      // Start of the string contents in memory = description + 32
      // First character of the marker = len - 52
      // We read the memory word starting at the first character of the marker:
      // (description + 32) + (len - 52) = description + (len - 20)
      marker := mload(add(description, sub(len, 20)))
    }

    // If the marker is not found, there is no proposer suffix to check
    if (marker != bytes12("#proposer=0x")) {
      return true;
    }

    // Parse the 40 characters following the marker as uint160
    uint160 recovered;
    for (uint256 i = len - 40; i < len; ++i) {
      (bool isHex, uint8 value) = tryHexToUint(bytes(description)[i]);
      // If any of the characters is not a hex digit, ignore the suffix entirely
      if (!isHex) {
        return true;
      }
      recovered = (recovered << 4) | value;
    }

    return recovered == uint160(proposer);
  }

  /**
   * @dev Tries to parse a character from a string as a hex value.
   * @param char The character to parse.
   * @return isHex True if the character is a valid hex digit, false otherwise.
   * @return value The parsed hex value.
   */
  function tryHexToUint(bytes1 char) private pure returns (bool, uint8) {
    uint8 c = uint8(char);
    unchecked {
      // Case 0-9
      if (47 < c && c < 58) {
        return (true, c - 48);
      }
      // Case A-F
      else if (64 < c && c < 71) {
        return (true, c - 55);
      }
      // Case a-f
      else if (96 < c && c < 103) {
        return (true, c - 87);
      }
      // Else: not a hex char
      else {
        return (false, 0);
      }
    }
  }
}

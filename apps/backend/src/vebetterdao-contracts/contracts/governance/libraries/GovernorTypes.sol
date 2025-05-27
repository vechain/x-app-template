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

import { IVoterRewards } from "../../interfaces/IVoterRewards.sol";
import { IXAllocationVotingGovernor } from "../../interfaces/IXAllocationVotingGovernor.sol";
import { IB3TR } from "../../interfaces/IB3TR.sol";
import { IVOT3 } from "../../interfaces/IVOT3.sol";
import { TimelockControllerUpgradeable } from "@openzeppelin/contracts-upgradeable/governance/TimelockControllerUpgradeable.sol";

library GovernorTypes {
  /**
   * @dev Struct containing data to initialize the contract
   * @param vot3Token The address of the Vot3 token used for voting
   * @param timelock The address of the Timelock
   * @param xAllocationVoting The address of the xAllocationVoting
   * @param quorumPercentage quorum as a percentage of the total supply of VOT3 tokens
   * @param initialDepositThreshold The Deposit Threshold for a proposal to be active
   * @param initialMinVotingDelay The minimum amount of blocks a proposal needs to wait before it can start
   * @param initialVotingThreshold The minimum amount of voting power needed in order to vote
   * @param voterRewards The address of the voter rewards contract
   * @param isFunctionRestrictionEnabled If the function restriction is enabled
   */
  struct InitializationData {
    IVOT3 vot3Token;
    TimelockControllerUpgradeable timelock;
    IXAllocationVotingGovernor xAllocationVoting;
    IB3TR b3tr;
    uint256 quorumPercentage;
    uint256 initialDepositThreshold;
    uint256 initialMinVotingDelay;
    uint256 initialVotingThreshold;
    IVoterRewards voterRewards;
    bool isFunctionRestrictionEnabled;
  }

  /**
   * @param governorAdmin The address of the governor admin
   * @param pauser The address of the pauser
   * @param contractsAddressManager The address of the contracts address manager
   * @param proposalExecutor The address that should be set as executor and have the PROPOSAL_EXECUTOR_ROLE
   * @param governorFunctionSettingsRoleAddress The address that should have the GOVERNOR_FUNCTIONS_SETTINGS_ROLE
   */
  struct InitializationRolesData {
    address governorAdmin;
    address pauser;
    address contractsAddressManager;
    address proposalExecutor;
    address governorFunctionSettingsRoleAddress;
  }

  // Proposal vote types
  enum VoteType {
    Against,
    For,
    Abstain
  }

  // ProposalVote struct to store the votes for a proposal
  struct ProposalVote {
    uint256 againstVotes;
    uint256 forVotes;
    uint256 abstainVotes;
    mapping(address => bool) hasVoted;
  }

  // ProposalCore struct to store the core data for a proposal
  struct ProposalCore {
    address proposer;
    uint256 roundIdVoteStart;
    uint32 voteDuration;
    bool isExecutable;
    bool executed;
    bool canceled;
    uint48 etaSeconds;
    uint256 depositAmount;
    uint256 depositThreshold;
  }

  // ProposalState enum to store the state of a proposal
  enum ProposalState {
    Pending,
    Active,
    Canceled,
    Defeated,
    Succeeded,
    Queued,
    Executed,
    DepositNotMet
  }
}

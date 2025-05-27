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

import { GovernorTypes } from "./GovernorTypes.sol";
import { IVoterRewards } from "../../interfaces/IVoterRewards.sol";
import { IXAllocationVotingGovernor } from "../../interfaces/IXAllocationVotingGovernor.sol";
import { IB3TR } from "../../interfaces/IB3TR.sol";
import { IVOT3 } from "../../interfaces/IVOT3.sol";
import { DoubleEndedQueue } from "@openzeppelin/contracts/utils/structs/DoubleEndedQueue.sol";
import { TimelockControllerUpgradeable } from "@openzeppelin/contracts-upgradeable/governance/TimelockControllerUpgradeable.sol";
import { Checkpoints } from "@openzeppelin/contracts/utils/structs/Checkpoints.sol";
import { IVeBetterPassport } from "../../interfaces/IVeBetterPassport.sol";

/// @title GovernorStorageTypes
/// @notice Library for defining storage types used in the Governor contract.
library GovernorStorageTypes {
  struct GovernorStorage {
    // ------------------------------- Version 1 -------------------------------

    // ------------------------------- General Storage -------------------------------
    string name; // name of the Governor
    mapping(uint256 proposalId => GovernorTypes.ProposalCore) proposals;
    // This queue keeps track of the governor operating on itself. Calls to functions protected by the {onlyGovernance}
    // modifier needs to be whitelisted in this queue. Whitelisting is set in {execute}, consumed by the
    // {onlyGovernance} modifier and eventually reset after {_executeOperations} completes. This ensures that the
    // execution of {onlyGovernance} protected calls can only be achieved through successful proposals.
    DoubleEndedQueue.Bytes32Deque governanceCall;
    // min delay before voting can start
    uint256 minVotingDelay;
    // ------------------------------- Quorum Storage -------------------------------
    // quorum numerator history
    Checkpoints.Trace208 quorumNumeratorHistory;
    // ------------------------------- Timelock Storage -------------------------------
    // Timelock contract
    TimelockControllerUpgradeable timelock;
    // mapping of proposalId to timelockId
    mapping(uint256 proposalId => bytes32) timelockIds;
    // ------------------------------- Function Restriction Storage -------------------------------
    // mapping of target address to function selector to bool indicating if function is whitelisted for proposals
    mapping(address => mapping(bytes4 => bool)) whitelistedFunctions;
    // flag to enable/disable function restrictions
    bool isFunctionRestrictionEnabled;
    // ------------------------------- External Contracts Storage -------------------------------
    // Voter Rewards contract
    IVoterRewards voterRewards;
    // XAllocationVotingGovernor contract
    IXAllocationVotingGovernor xAllocationVoting;
    // B3TR contract
    IB3TR b3tr;
    // VOT3 contract
    IVOT3 vot3;
    // ------------------------------- Desposits Storage -------------------------------
    // mapping to track deposits made to proposals by address
    mapping(uint256 => mapping(address => uint256)) deposits;
    // percentage of the total supply of B3TR tokens that need to be deposited in VOT3 to create a proposal
    uint256 depositThresholdPercentage;
    // ------------------------------- Voting Storage -------------------------------
    // mapping to store the votes for a proposal
    mapping(uint256 => GovernorTypes.ProposalVote) proposalVotes;
    // mapping to store that a user has voted at least one time
    mapping(address => bool) hasVotedOnce;
    // mapping to store the total votes for a proposal
    mapping(uint256 => uint256) proposalTotalVotes;
    // minimum amount of tokens needed to cast a vote
    uint256 votingThreshold;
    // ------------------------------- Version 3 -------------------------------

    // ------------------------------- Voting Storage -------------------------------
    // checkpoints for the quadratic voting status for each round
    Checkpoints.Trace208 quadraticVotingDisabled;
    // ------------------------------- Version 2 -------------------------------

    // ------------------------------- Passport -------------------------------
    IVeBetterPassport veBetterPassport;
  }
}

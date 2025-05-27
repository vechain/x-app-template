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

import { IXAllocationVotingGovernor } from "../../interfaces/IXAllocationVotingGovernor.sol";
import { IGalaxyMember } from "../../interfaces/IGalaxyMember.sol";
import { IX2EarnApps } from "../../interfaces/IX2EarnApps.sol";
import { PassportTypes } from "./PassportTypes.sol";
import { Checkpoints } from "@openzeppelin/contracts/utils/structs/Checkpoints.sol";

/**
 * @title PassportStorageTypes
 * @notice This library defines the primary storage types used within the Passport contract.
 * It uses the ERC-7201 Storage Namespaces standard to separate storage concerns efficiently.
 *
 * The storage includes configurations for personhood checks, external contract references,
 * whitelisting/blacklisting, proof of participation, passport delegation, bot signaling,
 * and entity linkage to passports.
 *
 * @dev This library manages complex contract state by grouping mappings and settings into
 * distinct storage types. It leverages the ERC-7201 standard for organizing these namespaces.
 */
library PassportStorageTypes {
  struct PassportStorage {
    // ------------------ Passport Settings ------------------ //
    // Bitmask of enabled checks (e.g. whitelist, blacklist, signaling, etc.)
    uint256 personhoodChecks;
    // Minimum galaxy member level required for personhood
    uint256 minimumGalaxyMemberLevel;
    // ---------- External Contracts ---------- //
    // Address of the xAllocationVoting contract
    IXAllocationVotingGovernor xAllocationVoting;
    // Address of the galaxy member contract
    IGalaxyMember galaxyMember;
    // Address of the x2EarnApps contract
    IX2EarnApps x2EarnApps;
    // ---------- Blacklisted and Whitelisted info ---------- //
    // Mapping of whitelisted users
    mapping(address user => bool) whitelisted;
    // Mapping of blacklisted users
    mapping(address user => bool) blacklisted;
    // Track number of whitelisted entities
    mapping(address => uint256) whitelistedEntitiesCounter;
    // Track number of blacklisted entities
    mapping(address => uint256) blacklistedEntitiesCounter;
    // Threshold percentage of whitelisted entities for a passport to be considered whitelisted
    uint256 whitelistThreshold;
    // Threshold percentage of blacklisted entities for a passport to be considered blacklisted
    uint256 blacklistThreshold;
    // ---------- Proof of Participation ---------- //
    // Multiplier of the base action score based on the app security
    mapping(PassportTypes.APP_SECURITY security => uint256 multiplier) securityMultiplier;
    // Security level of an app -> will be UNDEFINED and set to LOW by default
    mapping(bytes32 appId => PassportTypes.APP_SECURITY security) appSecurity;
    // All-time total score of a user
    mapping(address user => uint256 totalScore) userTotalScore;
    // All-time total score of a user for a specific app
    mapping(address user => mapping(bytes32 appId => uint256 totalScore)) userAppTotalScore;
    // Score of a user in a specific round
    mapping(address user => mapping(uint256 round => uint256 score)) userRoundScore;
    // Score of a user for a specific app in a specific round
    mapping(address user => mapping(uint256 round => mapping(bytes32 appId => uint256 score))) userAppRoundScore;
    // Checkpointed threshold for a user to be considered a person in a round
    Checkpoints.Trace208 popScoreThreshold;
    // Number of rounds to consider for the cumulative score
    uint256 roundsForCumulativeScore;
    // Decay rate for the exponential decay
    uint256 decayRate;
    // Track which apps a user has interacted with
    mapping(address => mapping(bytes32 => bool)) userUniqueAppInteraction;
    // Store the list of apps a user has interacted with
    mapping(address => bytes32[]) userInteractedApps;
    // Track when as user attached an entity to their passport
    mapping(address => uint256) entityAttachRound;
    // ---------- Passport Entities ---------- //
    // Mapping of entity to passport
    mapping(address => Checkpoints.Trace160) entityToPassport;
    // Mapping to track index of entities for each passport
    mapping(address => uint256) passportEntitiesIndexes;
    // Mapping of passport to entities
    mapping(address => address[]) passportToEntities;
    // Mapping of passport to pending entities indexes
    mapping(address => uint256) pendingLinksIndexes;
    // Mapping of passport to pending entities
    mapping(address => address[]) pendingLinksPassportToEntities;
    // Mapping of pending entities to passport
    mapping(address => address) pendingLinksEntityToPassport;
    // Limit of entities that can be attached to a passport
    uint256 maxEntitiesPerPassport;
    // ---------- Passport Delegation ---------- //
    // Mapping of delegator to delegatee
    mapping(address => Checkpoints.Trace160) delegatorToDelegatee;
    // Mapping of delegatee to delegator
    mapping(address => Checkpoints.Trace160) delegateeToDelegator;
    // Mapping to track index of pending delegations for each delegator
    mapping(address => uint256) pendingDelegationsIndexes;
    // Mapping to track pending delegations for each delegatee
    mapping(address => address[]) pendingDelegationsDelegateeToDelegators;
    // Mapping to map delagator to delegatee for pending delegations
    mapping(address => address) pendingDelegationsDelegatorToDelegatee;
    // ---------- Bot Signaling ---------- //
    // Counter for the number of signals per user
    mapping(address user => uint256) signaledCounter;
    // Threshold for a user to be considered a bot
    uint256 signalsThreshold;
    // Mapping of signaler to app
    mapping(address signaler => bytes32 app) appOfSignaler;
    // Mapping of apps to signaled users
    mapping(bytes32 app => mapping(address user => uint256)) appSignalsCounter;
    // Mapping of apps to total signals
    mapping(bytes32 app => uint256) appTotalSignalsCounter;
  }
}

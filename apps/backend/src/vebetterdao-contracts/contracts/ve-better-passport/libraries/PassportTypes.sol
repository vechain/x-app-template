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
import { IX2EarnApps } from "../../interfaces/IX2EarnApps.sol";
import { IGalaxyMember } from "../../interfaces/IGalaxyMember.sol";

/**
 * @title PassportTypes
 * @notice This library defines various data types, enumerations, and initialization parameters used within the Passport contract.
 * It includes the `InitializationData` struct, which contains references to external contracts and configurations for personhood checks,
 * proof of participation, signaling, and passport delegation. It also includes role-based configuration settings.
 */
library PassportTypes {
  /**
   * @dev Struct containing data to initialize the contract
   * @param xAllocationVoting The address of the xAllocationVoting
   * @param x2EarnApps The address of the x2EarnApps
   * @param galaxyMember The address of the galaxy member contract
   * @param upgrader The address of the upgrader
   * @param admins The addresses of the admins
   * @param settingsManagers The addresses of the settings managers
   * @param roleGranters The addresses of the role granters
   * @param blacklisters The addresses of the blacklisters
   * @param whitelisters The addresses of the whitelisters
   * @param actionRegistrar The address of the action registrar
   * @param actionScoreManager The address of the action score manager
   * @param popScoreThreshold The threshold proof of participation score for a wallet to be considered a person
   * @param signalingThreshold The threshold for a proposal to be active
   * @param roundsForCumulativeScore The number of rounds for cumulative score
   */
  struct InitializationData {
    IXAllocationVotingGovernor xAllocationVoting;
    IX2EarnApps x2EarnApps;
    IGalaxyMember galaxyMember;
    uint256 signalingThreshold;
    uint256 roundsForCumulativeScore;
    uint256 minimumGalaxyMemberLevel;
    uint256 blacklistThreshold;
    uint256 whitelistThreshold;
    uint256 maxEntitiesPerPassport;
    uint256 decayRate;
  }

  struct InitializationRoleData {
    address admin;
    address botSignaler;
    address upgrader;
    address settingsManager;
    address roleGranter;
    address blacklister;
    address whitelister;
    address actionRegistrar;
    address actionScoreManager;
  }

  enum CheckType {
    UNDEFINED, // Default value for invalid or uninitialized checks
    WHITELIST_CHECK, // Check if the user is whitelisted
    BLACKLIST_CHECK, // Check if the user is blacklisted
    SIGNALING_CHECK, // Check if the user has been signaled too many times
    PARTICIPATION_SCORE_CHECK, // Check the user's participation score
    GM_OWNERSHIP_CHECK // Check if the user owns a GM token
  }

  /// @notice Security level indicates how secure the app is
  /// @dev App security is used to calculate the overall score of a sustainable action
  enum APP_SECURITY {
    NONE,
    LOW,
    MEDIUM,
    HIGH
  }
}

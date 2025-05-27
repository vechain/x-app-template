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

import { PassportStorageTypes } from "./PassportStorageTypes.sol";
import { PassportTypes } from "./PassportTypes.sol";
import { PassportClockLogic } from "./PassportClockLogic.sol";
import { IX2EarnApps } from "../../interfaces/IX2EarnApps.sol";
import { IXAllocationVotingGovernor } from "../../interfaces/IXAllocationVotingGovernor.sol";
import { IGalaxyMember } from "../../interfaces/IGalaxyMember.sol";
import { Checkpoints } from "@openzeppelin/contracts/utils/structs/Checkpoints.sol";

/// @title PassportConfigurator Library
/// @notice Library for managing the configuration of a Passport contract.
/// @dev This library provides functions to set and get various configuration parameters and contracts used by the Passport contract.
library PassportConfigurator {
  using Checkpoints for Checkpoints.Trace208;

  // ---------- Getters ---------- //
  /// @notice Gets the x2EarnApps contract address
  function getX2EarnApps(PassportStorageTypes.PassportStorage storage self) internal view returns (IX2EarnApps) {
    return self.x2EarnApps;
  }

  /// @notice Gets the xAllocationVoting contract address
  function getXAllocationVoting(
    PassportStorageTypes.PassportStorage storage self
  ) internal view returns (IXAllocationVotingGovernor) {
    return self.xAllocationVoting;
  }

  /// @notice Gets the galaxy member contract address
  function getGalaxyMember(PassportStorageTypes.PassportStorage storage self) internal view returns (IGalaxyMember) {
    return self.galaxyMember;
  }

  // ---------- Setters ---------- //

  /// @notice Initializes the PassportStorage struct with the provided initialization data
  function initializePassportStorage(
    PassportStorageTypes.PassportStorage storage self,
    PassportTypes.InitializationData memory initializationData
  ) external {
    // Initialize the external contracts
    setX2EarnApps(self, initializationData.x2EarnApps);
    setXAllocationVoting(self, initializationData.xAllocationVoting);
    setGalaxyMember(self, initializationData.galaxyMember);

    // Initialize the bot signals threshold
    self.signalsThreshold = initializationData.signalingThreshold;

    // Initialize the minimum Galaxy Member level to be considered human by Personhood checks
    self.minimumGalaxyMemberLevel = initializationData.minimumGalaxyMemberLevel;

    // Initialize the participant score threshold to be considered human by Personhood checks
    self.popScoreThreshold.push(PassportClockLogic.clock(), 0);

    // Initialize the number of rounds for cumulative score
    self.roundsForCumulativeScore = initializationData.roundsForCumulativeScore;

    // Initialize the secuirty multiplier
    self.securityMultiplier[PassportTypes.APP_SECURITY.LOW] = 100;
    self.securityMultiplier[PassportTypes.APP_SECURITY.MEDIUM] = 200;
    self.securityMultiplier[PassportTypes.APP_SECURITY.HIGH] = 400;

    // Decay
    self.decayRate = initializationData.decayRate;

    // Set the threshold percentage of blacklisted or whitelisted entities to consider a passport user as blacklisted or whitelisted
    self.blacklistThreshold = initializationData.blacklistThreshold;
    self.whitelistThreshold = initializationData.whitelistThreshold;

    // Set the maximum number of entities per passport
    self.maxEntitiesPerPassport = initializationData.maxEntitiesPerPassport;
  }

  /// @notice Sets the X2EarnApps contract address
  /// @dev The X2EarnApps contract address can be modified by the CONTRACTS_ADDRESS_MANAGER_ROLE
  /// @param _x2EarnApps - the X2EarnApps contract address
  function setX2EarnApps(PassportStorageTypes.PassportStorage storage self, IX2EarnApps _x2EarnApps) public {
    require(address(_x2EarnApps) != address(0), "VeBetterPassport: x2EarnApps is the zero address");

    self.x2EarnApps = _x2EarnApps;
  }

  /// @dev Sets the xAllocationVoting contract
  /// @param self - the PassportStorage struct
  /// @param _xAllocationVoting - the xAllocationVoting contract address
  function setXAllocationVoting(
    PassportStorageTypes.PassportStorage storage self,
    IXAllocationVotingGovernor _xAllocationVoting
  ) public {
    require(address(_xAllocationVoting) != address(0), "VeBetterPassport: xAllocationVoting is the zero address");

    self.xAllocationVoting = _xAllocationVoting;
  }

  /// @notice Sets the galaxy member contract address
  /// @param self - the PassportStorage struct
  /// @param _galaxyMember - the galaxy member contract address
  function setGalaxyMember(PassportStorageTypes.PassportStorage storage self, IGalaxyMember _galaxyMember) public {
    require(address(_galaxyMember) != address(0), "VeBetterPassport: galaxyMember is the zero address");

    self.galaxyMember = _galaxyMember;
  }
}

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

import { GovernorStorageTypesV1 } from "./GovernorStorageTypesV1.sol";
import { IVOT3 } from"../../../../interfaces/IVOT3.sol";
import { IVoterRewards } from"../../../../interfaces/IVoterRewards.sol";
import { IXAllocationVotingGovernor } from"../../../../interfaces/IXAllocationVotingGovernor.sol";
import { TimelockControllerUpgradeable } from "@openzeppelin/contracts-upgradeable/governance/TimelockControllerUpgradeable.sol";
import { IB3TR } from"../../../../interfaces/IB3TR.sol";

/// @title GovernorConfigurator Library
/// @notice Library for managing the configuration of a Governor contract.
/// @dev This library provides functions to set and get various configuration parameters and contracts used by the Governor contract.
library GovernorConfiguratorV1 {
  /// @dev Emitted when the `votingThreshold` is set.
  event VotingThresholdSet(uint256 oldVotingThreshold, uint256 newVotingThreshold);

  /// @dev Emitted when the minimum delay before vote starts is set.
  event MinVotingDelaySet(uint256 oldMinMinVotingDelay, uint256 newMinVotingDelay);

  /// @dev Emitted when the deposit threshold percentage is set.
  event DepositThresholdSet(uint256 oldDepositThreshold, uint256 newDepositThreshold);

  /// @dev Emitted when the voter rewards contract is set.
  event VoterRewardsSet(address oldContractAddress, address newContractAddress);

  /// @dev Emitted when the XAllocationVotingGovernor contract is set.
  event XAllocationVotingSet(address oldContractAddress, address newContractAddress);

  /// @dev Emitted when the timelock controller used for proposal execution is modified.
  event TimelockChange(address oldTimelock, address newTimelock);

  /// @dev The deposit threshold is not in the valid range for a percentage - 0 to 100.
  error GovernorDepositThresholdNotInRange(uint256 depositThreshold);

  /**------------------ SETTERS ------------------**/
  /**
   * @notice Sets the voting threshold.
   * @dev Sets a new voting threshold and emits a {VotingThresholdSet} event.
   * @param self The storage reference for the GovernorStorage.
   * @param newVotingThreshold The new voting threshold.
   */
  function setVotingThreshold(GovernorStorageTypesV1.GovernorStorage storage self, uint256 newVotingThreshold) external {
    emit VotingThresholdSet(self.votingThreshold, newVotingThreshold);
    self.votingThreshold = newVotingThreshold;
  }

  /**
   * @notice Sets the minimum delay before vote starts.
   * @dev Sets a new minimum voting delay and emits a {MinVotingDelaySet} event.
   * @param self The storage reference for the GovernorStorage.
   * @param newMinVotingDelay The new minimum voting delay.
   */
  function setMinVotingDelay(GovernorStorageTypesV1.GovernorStorage storage self, uint256 newMinVotingDelay) external {
    emit MinVotingDelaySet(self.minVotingDelay, newMinVotingDelay);
    self.minVotingDelay = newMinVotingDelay;
  }

  /**
   * @notice Sets the voter rewards contract.
   * @dev Sets a new voter rewards contract and emits a {VoterRewardsSet} event.
   * @param self The storage reference for the GovernorStorage.
   * @param newVoterRewards The new voter rewards contract.
   */
  function setVoterRewards(GovernorStorageTypesV1.GovernorStorage storage self, IVoterRewards newVoterRewards) external {
    require(address(newVoterRewards) != address(0), "GovernorConfigurator: voterRewards address cannot be zero");
    emit VoterRewardsSet(address(self.voterRewards), address(newVoterRewards));
    self.voterRewards = newVoterRewards;
  }

  /**
   * @notice Sets the XAllocationVotingGovernor contract.
   * @dev Sets a new XAllocationVotingGovernor contract and emits a {XAllocationVotingSet} event.
   * @param self The storage reference for the GovernorStorage.
   * @param newXAllocationVoting The new XAllocationVotingGovernor contract.
   */
  function setXAllocationVoting(
    GovernorStorageTypesV1.GovernorStorage storage self,
    IXAllocationVotingGovernor newXAllocationVoting
  ) external {
    require(
      address(newXAllocationVoting) != address(0),
      "GovernorConfigurator: xAllocationVoting address cannot be zero"
    );
    emit XAllocationVotingSet(address(self.xAllocationVoting), address(newXAllocationVoting));
    self.xAllocationVoting = newXAllocationVoting;
  }

  /**
   * @notice Sets the deposit threshold percentage.
   * @dev Sets a new deposit threshold percentage and emits a {DepositThresholdSet} event. Reverts if the threshold is not in range.
   * @param self The storage reference for the GovernorStorage.
   * @param newDepositThreshold The new deposit threshold percentage.
   */
  function setDepositThresholdPercentage(
    GovernorStorageTypesV1.GovernorStorage storage self,
    uint256 newDepositThreshold
  ) external {
    if (newDepositThreshold > 100) {
      revert GovernorDepositThresholdNotInRange(newDepositThreshold);
    }

    emit DepositThresholdSet(self.depositThresholdPercentage, newDepositThreshold);
    self.depositThresholdPercentage = newDepositThreshold;
  }

  /**
   * @notice Updates the timelock controller.
   * @dev Sets a new timelock controller and emits a {TimelockChange} event.
   * @param self The storage reference for the GovernorStorage.
   * @param newTimelock The new timelock controller.
   */
  function updateTimelock(
    GovernorStorageTypesV1.GovernorStorage storage self,
    TimelockControllerUpgradeable newTimelock
  ) external {
    require(address(newTimelock) != address(0), "GovernorConfigurator: timelock address cannot be zero");
    emit TimelockChange(address(self.timelock), address(newTimelock));
    self.timelock = newTimelock;
  }

  /**------------------ GETTERS ------------------**/
  /**
   * @notice Returns the voting threshold.
   * @param self The storage reference for the GovernorStorage.
   * @return The current voting threshold.
   */
  function getVotingThreshold(GovernorStorageTypesV1.GovernorStorage storage self) internal view returns (uint256) {
    return self.votingThreshold;
  }

  /**
   * @notice Returns the minimum delay before vote starts.
   * @param self The storage reference for the GovernorStorage.
   * @return The current minimum voting delay.
   */
  function getMinVotingDelay(GovernorStorageTypesV1.GovernorStorage storage self) internal view returns (uint256) {
    return self.minVotingDelay;
  }

  /**
   * @notice Returns the deposit threshold percentage.
   * @param self The storage reference for the GovernorStorage.
   * @return The current deposit threshold percentage.
   */
  function getDepositThresholdPercentage(
    GovernorStorageTypesV1.GovernorStorage storage self
  ) internal view returns (uint256) {
    return self.depositThresholdPercentage;
  }
}

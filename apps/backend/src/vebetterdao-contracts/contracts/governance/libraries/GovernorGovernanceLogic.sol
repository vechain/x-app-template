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
import { DoubleEndedQueue } from "@openzeppelin/contracts/utils/structs/DoubleEndedQueue.sol";

/// @title GovernorGovernanceLogic
/// @notice Library for validating descriptions in governance proposals based on the proposer's address suffix.
/// @dev This library provides functions to manage the governance execution flow and validate the governance executor.
library GovernorGovernanceLogic {
  using DoubleEndedQueue for DoubleEndedQueue.Bytes32Deque;

  /// @dev Thrown when the `account` is not the governance executor.
  /// @param account The address that attempted the unauthorized action.
  error GovernorOnlyExecutor(address account);

  /**
   * @notice Get the salt used for the timelock operation.
   * @dev Combines the contract address and description hash to generate a unique salt.
   * @param descriptionHash The hash of the proposal description.
   * @param contractAddress The address of the calling governance contract.
   * @return The generated salt as a bytes32 value.
   */
  function timelockSalt(bytes32 descriptionHash, address contractAddress) internal pure returns (bytes32) {
    return bytes20(contractAddress) ^ descriptionHash;
  }

  /**
   * @notice Get the address through which the governor executes actions.
   * @dev Returns the timelock address used by the governor.
   * @param self The storage reference for the GovernorStorage.
   * @return The executor address.
   */
  function executor(GovernorStorageTypes.GovernorStorage storage self) internal view returns (address) {
    return address(self.timelock);
  }

  /**
   * @notice Validates that the `msg.sender` is the executor.
   * @dev Reverts if the `msg.sender` is not the executor. If the executor is not the calling contract itself, it verifies that the `msg.data` is whitelisted.
   * @param self The storage reference for the GovernorStorage.
   * @param sender The address of the sender.
   * @param data The calldata to be validated.
   * @param contractAddress The address of the calling governance contract.
   */
  function checkGovernance(
    GovernorStorageTypes.GovernorStorage storage self,
    address sender,
    bytes calldata data,
    address contractAddress
  ) internal {
    if (executor(self) != sender) {
      revert GovernorOnlyExecutor(sender);
    }
    if (executor(self) != contractAddress) {
      bytes32 msgDataHash = keccak256(data);
      // Loop until popping the expected operation, revert if deque is empty (operation not authorized)
      while (self.governanceCall.popFront() != msgDataHash) {}
    }
  }
}

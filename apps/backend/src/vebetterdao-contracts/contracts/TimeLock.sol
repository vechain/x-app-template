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

import { TimelockControllerUpgradeable } from "@openzeppelin/contracts-upgradeable/governance/TimelockControllerUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title TimeLock
 * @notice This contract is used to perform the actions of the B3TRGovernor contract with a time delay.
 * The proposers and executors roles should be assigned only to the B3TRGovernor contract.
 */
contract TimeLock is TimelockControllerUpgradeable, UUPSUpgradeable {
  bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  function initialize(
    uint256 minDelay,
    address[] memory proposers,
    address[] memory executors,
    address admin,
    address upgrader
  ) external initializer {
    __TimelockController_init(minDelay, proposers, executors, admin);
    __UUPSUpgradeable_init();

    _grantRole(UPGRADER_ROLE, upgrader);
  }

  function _authorizeUpgrade(address newImplementation) internal virtual override onlyRole(UPGRADER_ROLE) {}

  /// @notice Retrieves the current version of the contract
  /// @dev This function is used to identify the version of the contract and should be updated in each new version
  /// @return string The version of the contract
  function version() public pure virtual returns (string memory) {
    return "1";
  }
}

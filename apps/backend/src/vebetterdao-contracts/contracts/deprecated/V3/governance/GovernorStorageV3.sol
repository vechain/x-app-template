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

import { GovernorStorageTypesV3 } from "./libraries/GovernorStorageTypesV3.sol";
import { GovernorTypesV3 } from "./libraries/GovernorTypesV3.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/// @title GovernorStorage
/// @notice Contract used as storage of the B3TRGovernor contract.
/// @dev It defines the storage layout of the B3TRGovernor contract.
contract GovernorStorageV3 is Initializable {
  // keccak256(abi.encode(uint256(keccak256("GovernorStorageLocation")) - 1)) & ~bytes32(uint256(0xff))
  bytes32 private constant GovernorStorageLocation = 0xd09a0aaf4ab3087bae7fa25ef74ddd4e5a4950980903ce417e66228cf7dc7b00;

  /// @dev Internal function to access the governor storage slot.
  function getGovernorStorage() internal pure returns (GovernorStorageTypesV3.GovernorStorage storage $) {
    assembly {
      $.slot := GovernorStorageLocation
    }
  }

  /// @dev Initializes the governor storage
  function __GovernorStorage_init(
    GovernorTypesV3.InitializationData memory initializationData,
    string memory governorName
  ) internal onlyInitializing {
    __GovernorStorage_init_unchained(initializationData, governorName);
  }

  /// @dev Part of the initialization process that configures the gGovernorTypesovernor storage.
  function __GovernorStorage_init_unchained(
    GovernorTypesV3.InitializationData memory initializationData,
    string memory governorName
  ) internal onlyInitializing {
    GovernorStorageTypesV3.GovernorStorage storage governorStorage = getGovernorStorage();

    // Validate and set the governor time lock storage
    require(address(initializationData.timelock) != address(0), "B3TRGovernor: timelock address cannot be zero");
    governorStorage.timelock = initializationData.timelock;

    // Set the governor function restrictions storage
    governorStorage.isFunctionRestrictionEnabled = initializationData.isFunctionRestrictionEnabled;

    // Validate and set the governor external contracts storage
    require(address(initializationData.b3tr) != address(0), "B3TRGovernor: B3TR address cannot be zero");
    require(address(initializationData.vot3Token) != address(0), "B3TRGovernor: Vot3 address cannot be zero");
    require(
      address(initializationData.xAllocationVoting) != address(0),
      "B3TRGovernor: xAllocationVoting address cannot be zero"
    );
    require(
      address(initializationData.voterRewards) != address(0),
      "B3TRGovernor: voterRewards address cannot be zero"
    );
    governorStorage.voterRewards = initializationData.voterRewards;
    governorStorage.xAllocationVoting = initializationData.xAllocationVoting;
    governorStorage.b3tr = initializationData.b3tr;
    governorStorage.vot3 = initializationData.vot3Token;

    // Set the governor general storage
    governorStorage.name = governorName;
    governorStorage.minVotingDelay = initializationData.initialMinVotingDelay;

    // Set the governor deposit storage
    governorStorage.depositThresholdPercentage = initializationData.initialDepositThreshold;

    // Set the governor votes storage
    governorStorage.votingThreshold = initializationData.initialVotingThreshold;
  }
}

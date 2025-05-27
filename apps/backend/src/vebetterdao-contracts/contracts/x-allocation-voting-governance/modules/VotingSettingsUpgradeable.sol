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

import { XAllocationVotingGovernor } from "../XAllocationVotingGovernor.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @title VotingSettingsUpgradeable
 * @dev Extension of {XAllocationVotingGovernor} for voting settings.
 */
abstract contract VotingSettingsUpgradeable is Initializable, XAllocationVotingGovernor {
  /// @custom:storage-location erc7201:b3tr.storage.XAllocationVotingGovernor.VotingSettings
  struct VotingSettingsStorage {
    uint32 _votingPeriod;
  }

  // keccak256(abi.encode(uint256(keccak256("b3tr.storage.XAllocationVotingGovernor.VotingSettings")) - 1)) & ~bytes32(uint256(0xff))
  bytes32 private constant VotingSettingsStorageLocation =
    0xd69d068053671881d25a4d751dcad1e692749d9b24184f608cb1d01af3a99900;

  function _getVotingSettingsStorage() private pure returns (VotingSettingsStorage storage $) {
    assembly {
      $.slot := VotingSettingsStorageLocation
    }
  }

  event VotingPeriodSet(uint256 oldVotingPeriod, uint256 newVotingPeriod);

  /**
   * @dev Initialize the governance parameters.
   */
  function __VotingSettings_init(uint32 initialVotingPeriod) internal onlyInitializing {
    __VotingSettings_init_unchained(initialVotingPeriod);
  }

  function __VotingSettings_init_unchained(uint32 initialVotingPeriod) internal onlyInitializing {
    _setVotingPeriod(initialVotingPeriod);
  }

  /**
   * @dev See {IXAllocationVotingGovernor-votingPeriod}.
   */
  function votingPeriod() public view virtual override returns (uint256) {
    VotingSettingsStorage storage $ = _getVotingSettingsStorage();
    return $._votingPeriod;
  }

  /**
   * @dev Internal setter for the voting period.
   *
   * Emits a {VotingPeriodSet} event.
   */
  function _setVotingPeriod(uint32 newVotingPeriod) internal virtual {
    if (newVotingPeriod == 0) {
      revert GovernorInvalidVotingPeriod(0);
    }

    // Ensure the voting period is less than the emissions cycle duration.
    uint256 emissionsCycleDuration = emissions().cycleDuration();
    if (newVotingPeriod >= emissionsCycleDuration) {
      revert GovernorInvalidVotingPeriod(newVotingPeriod);
    }

    VotingSettingsStorage storage $ = _getVotingSettingsStorage();

    emit VotingPeriodSet($._votingPeriod, newVotingPeriod);
    $._votingPeriod = newVotingPeriod;
  }
}

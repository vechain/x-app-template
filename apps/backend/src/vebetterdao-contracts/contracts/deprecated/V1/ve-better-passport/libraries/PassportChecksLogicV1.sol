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

import { PassportStorageTypesV1 } from "./PassportStorageTypesV1.sol";
import { PassportTypesV1 } from "./PassportTypesV1.sol";

/**
 * @title PassportChecksLogic
 * @dev A library that manages various checks related to personhood in the Passport contract.
 * It provides the ability to enable or disable specific personhood checks (such as whitelist, blacklist, signaling, etc.)
 * and to update certain configurations such as the minimum Galaxy Member level.
 * This library operates using a bitmask for efficient storage and toggling of checks.
 */
library PassportChecksLogicV1 {
  // ---------- Consants ---------- //
  uint256 constant WHITELIST_CHECK = 1 << 0; // Bitwise shift to the left by 0
  uint256 constant BLACKLIST_CHECK = 1 << 1; // Bitwise shift to the left by 1
  uint256 constant SIGNALING_CHECK = 1 << 2; // Bitwise shift to the left by 2
  uint256 constant PARTICIPATION_SCORE_CHECK = 1 << 3; // Bitwise shift to the left by 3
  uint256 constant GM_OWNERSHIP_CHECK = 1 << 4; // Bitwise shift to the left by 4

  string constant WHITELIST_CHECK_NAME = "Whitelist Check";
  string constant BLACKLIST_CHECK_NAME = "Blacklist Check";
  string constant SIGNALING_CHECK_NAME = "Signaling Check";
  string constant PARTICIPATION_SCORE_CHECK_NAME = "Participation Score Check";
  string constant GM_OWNERSHIP_CHECK_NAME = "GM Ownership Check";

  // ---------- Events ---------- //
  /// @notice Emitted when a specific check is toggled.
  /// @param checkName The name of the check being toggled.
  /// @param enabled True if the check is enabled, false if disabled.
  event CheckToggled(string indexed checkName, bool enabled);

  /// @notice Emitted when the minimum galaxy member level is set.
  /// @param minimumGalaxyMemberLevel The new minimum galaxy member level.
  event MinimumGalaxyMemberLevelSet(uint256 minimumGalaxyMemberLevel);

  // ---------- Private Functions ---------- //

  /// @notice Maps the PassportTypesV1.CheckType enum to the corresponding bitmask constant.
  /// @param checkType The type of check from the enum.
  /// @return The bitmask constant and the check name for the specified check.
  function _mapCheckTypeToBitmask(PassportTypesV1.CheckType checkType) private pure returns (uint256, string memory) {
    if (checkType == PassportTypesV1.CheckType.WHITELIST_CHECK) return (WHITELIST_CHECK, WHITELIST_CHECK_NAME);
    if (checkType == PassportTypesV1.CheckType.BLACKLIST_CHECK) return (BLACKLIST_CHECK, BLACKLIST_CHECK_NAME);
    if (checkType == PassportTypesV1.CheckType.SIGNALING_CHECK) return (SIGNALING_CHECK, SIGNALING_CHECK_NAME);
    if (checkType == PassportTypesV1.CheckType.PARTICIPATION_SCORE_CHECK)
      return (PARTICIPATION_SCORE_CHECK, PARTICIPATION_SCORE_CHECK_NAME);
    if (checkType == PassportTypesV1.CheckType.GM_OWNERSHIP_CHECK) return (GM_OWNERSHIP_CHECK, GM_OWNERSHIP_CHECK_NAME);
    revert("Invalid PassportTypesV1");
  }

  /// @notice Checks if a specific check is enabled
  /// @param checkType The type of check to query (from the enum)
  /// @return True if the check is enabled, false otherwise
  function _isCheckEnabled(
    PassportStorageTypesV1.PassportStorage storage self,
    PassportTypesV1.CheckType checkType
  ) internal view returns (bool) {
    require(checkType != PassportTypesV1.CheckType.UNDEFINED, "Invalid check type");

    (uint256 checkBit, ) = _mapCheckTypeToBitmask(checkType);
    return (self.personhoodChecks & checkBit) != 0;
  }

  // ---------- Getters ---------- //

  /// @notice Checks if a specific check is enabled.
  /// @param self The storage object for the Passport contract containing all checks.
  /// @param checkType The type of check to query (from the enum).
  /// @return True if the check is enabled, false otherwise.
  function isCheckEnabled(
    PassportStorageTypesV1.PassportStorage storage self,
    PassportTypesV1.CheckType checkType
  ) external view returns (bool) {
    return _isCheckEnabled(self, checkType);
  }

  /// @notice Returns the minimum galaxy member level
  function getMinimumGalaxyMemberLevel(
    PassportStorageTypesV1.PassportStorage storage self
  ) internal view returns (uint256) {
    return self.minimumGalaxyMemberLevel;
  }

  // ---------- Setters ---------- //
  /// @notice Toggles the specified check between enabled and disabled.
  /// @param self The storage object for the Passport contract containing all checks.
  /// @param checkType The type of check to toggle (from the enum).
  function toggleCheck(PassportStorageTypesV1.PassportStorage storage self, PassportTypesV1.CheckType checkType) external {
    require(checkType != PassportTypesV1.CheckType.UNDEFINED, "Invalid check type");

    (uint256 checkBit, string memory checkName) = _mapCheckTypeToBitmask(checkType);

    // Check if the check is currently enabled
    if ((self.personhoodChecks & checkBit) != 0) {
      // Disable the check by clearing the bit
      self.personhoodChecks &= ~checkBit;
      emit CheckToggled(checkName, false);
    } else {
      // Enable the check by setting the bit
      self.personhoodChecks |= checkBit;
      emit CheckToggled(checkName, true);
    }
  }

  /// @notice Sets the minimum galaxy member level
  /// @param minimumGalaxyMemberLevel The new minimum galaxy member level
  function setMinimumGalaxyMemberLevel(
    PassportStorageTypesV1.PassportStorage storage self,
    uint256 minimumGalaxyMemberLevel
  ) external {
    require(minimumGalaxyMemberLevel > 0, "VeBetterPassport: minimum galaxy member level must be greater than 0");

    self.minimumGalaxyMemberLevel = minimumGalaxyMemberLevel;
    emit MinimumGalaxyMemberLevelSet(minimumGalaxyMemberLevel);
  }
}

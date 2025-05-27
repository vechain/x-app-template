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
import { PassportEntityLogicV1 } from "./PassportEntityLogicV1.sol";

/**
 * @title PassportWhitelistAndBlacklistLogicV1
 * @dev This library manages the whitelisting and blacklisting of users and passports in the Passport system.
 * It provides functionality to add or remove users from the whitelist/blacklist, and to check a passport's status based on linked entities.
 */
library PassportWhitelistAndBlacklistLogicV1 {
  // ---------- Events ---------- //
  /// @notice Emitted when a user is whitelisted
  /// @param user - the user that is whitelisted
  /// @param whitelistedBy - the user that whitelisted the user
  event UserWhitelisted(address indexed user, address indexed whitelistedBy);

  /// @notice Emitted when a user is removed from the whitelist
  /// @param user - the user that is removed from the whitelist
  /// @param removedBy - the user that removed the user from the whitelist
  event RemovedUserFromWhitelist(address indexed user, address indexed removedBy);

  /// @notice Emitted when a user is blacklisted
  /// @param user - the user that is blacklisted
  /// @param blacklistedBy - the user that blacklisted the user
  event UserBlacklisted(address indexed user, address indexed blacklistedBy);

  /// @notice Emitted when a user is removed from the blacklist
  /// @param user - the user that is removed from the blacklist
  /// @param removedBy - the user that removed the user from the blacklist
  event RemovedUserFromBlacklist(address indexed user, address indexed removedBy);

  // ---------- Getters ---------- //

  /// @notice Returns if a user is whitelisted
  function isWhitelisted(PassportStorageTypesV1.PassportStorage storage self, address user) internal view returns (bool) {
    return self.whitelisted[user];
  }

  /// @notice Returns if a user is blacklisted
  function isBlacklisted(PassportStorageTypesV1.PassportStorage storage self, address user) internal view returns (bool) {
    return self.blacklisted[user];
  }

  /// @notice return the blacklist threshold
  function blacklistThreshold(PassportStorageTypesV1.PassportStorage storage self) internal view returns (uint256) {
    return self.blacklistThreshold;
  }

  /// @notice return the whitelist threshold
  function whitelistThreshold(PassportStorageTypesV1.PassportStorage storage self) internal view returns (uint256) {
    return self.whitelistThreshold;
  }

  /**
   * @notice Checks if a passport is whitelisted based on a threshold percentage of linked entities.
   * @dev This function checks if the passport itself is whitelisted or if the number of whitelisted entities
   * linked to the passport exceeds the given threshold percentage of the total entities linked to the passport.
   * It first checks if the passport is directly whitelisted. If not, it calculates the percentage of whitelisted
   * entities linked to the passport and compares it to the threshold.
   * @param self The storage reference for PassportStorage.
   * @param passport The address of the passport being checked.
   * @return True if the passport is whitelisted based on the threshold, otherwise false.
   */
  function isPassportWhitelisted(
    PassportStorageTypesV1.PassportStorage storage self,
    address passport
  ) external view returns (bool) {
    return _isPassportWhitelisted(self, passport);
  }

  /**
   * @notice Checks if a passport is blacklisted based on a threshold percentage of linked entities.
   * @dev This function checks if the passport itself is blacklisted or if the number of blacklisted entities
   * linked to the passport exceeds the given threshold percentage of the total entities linked to the passport.
   * It first checks if the passport is directly blacklisted. If not, it calculates the percentage of blacklisted
   * entities linked to the passport and compares it to the specified threshold.
   * @param self The storage reference for PassportStorage.
   * @param passport The address of the passport being checked.
   * @return True if the passport is blacklisted based on the threshold, otherwise false.
   */
  function isPassportBlacklisted(
    PassportStorageTypesV1.PassportStorage storage self,
    address passport
  ) external view returns (bool) {
    return _isPassportBlacklisted(self, passport);
  }

  // ---------- Setters ---------- //

  /// @notice user can be whitelisted but the counter will not be reset
  function whitelist(PassportStorageTypesV1.PassportStorage storage self, address user) external {
    // Check if the user is blacklisted and remove them from the blacklist
    if (isBlacklisted(self, user)) removeFromBlacklist(self, user);

    // Whitelist the user
    self.whitelisted[user] = true;

    // Check if the user has a passport and update the whitelist counter
    _updatePassportWhitelistCounter(self, user, true);

    emit UserWhitelisted(user, msg.sender);
  }

  /// @notice Removes a user from the whitelist
  function removeFromWhitelist(PassportStorageTypesV1.PassportStorage storage self, address user) public {
    self.whitelisted[user] = false;

    // Check if the user has a passport and update the whitelist counter
    _updatePassportWhitelistCounter(self, user, false);

    emit RemovedUserFromWhitelist(user, msg.sender);
  }

  /// @notice user can be blacklisted but the counter will not be reset
  function blacklist(PassportStorageTypesV1.PassportStorage storage self, address user) external {
    // Check if the user is whitelisted and remove them from the whitelist
    if (isWhitelisted(self, user)) removeFromWhitelist(self, user);

    self.blacklisted[user] = true;

    // Check if the user has a passport and update the blacklist counter
    _updatePassportBlacklistCounter(self, user, true);

    emit UserBlacklisted(user, msg.sender);
  }

  /// @notice Removes a user from the blacklist
  function removeFromBlacklist(PassportStorageTypesV1.PassportStorage storage self, address user) public {
    self.blacklisted[user] = false;

    // Check if the user has a passport and update the blacklist counter
    _updatePassportBlacklistCounter(self, user, false);

    emit RemovedUserFromBlacklist(user, msg.sender);
  }

  /// @notice Sets the threshold percentage of whitelisted entities for a passport to be considered whitelisted
  function setWhitelistThreshold(PassportStorageTypesV1.PassportStorage storage self, uint256 threshold) external {
    self.whitelistThreshold = threshold;
  }

  /// @notice Sets the threshold percentage of blacklisted entities for a passport to be considered blacklisted
  function setBlacklistThreshold(PassportStorageTypesV1.PassportStorage storage self, uint256 threshold) external {
    self.blacklistThreshold = threshold;
  }

  // ---------- Internal & Private ---------- //
  /**
   * @notice Assigns an entity's whitelist and blacklist status to a passport when an entity is added to a passport.
   * @dev This function checks whether the entity is whitelisted or blacklisted and updates the corresponding counters on the passport.
   * If the entity is whitelisted, the passport's whitelist counter is incremented. Similarly, if the entity is blacklisted, the blacklist counter is incremented.
   * @param self The storage reference for PassportStorage.
   * @param entity The address of the entity whose whitelist/blacklist status is being assigned.
   * @param passport The address of the passport to which the entity's whitelist/blacklist status is being assigned.
   */
  function attachEntitiesBlackAndWhiteListsToPassport(
    PassportStorageTypesV1.PassportStorage storage self,
    address entity,
    address passport
  ) internal {
    uint256 _whitelist = isWhitelisted(self, entity) ? 1 : 0;
    uint256 _blacklist = isBlacklisted(self, entity) ? 1 : 0;

    self.whitelistedEntitiesCounter[passport] += _whitelist;
    self.blacklistedEntitiesCounter[passport] += _blacklist;
  }

  /**
   * @notice Removes an entity's whitelist and blacklist status from a passport when an entity is removed from a passport.
   * @dev This function checks whether the entity is whitelisted or blacklisted and decrements the corresponding counters on the passport.
   * If the entity is whitelisted, the passport's whitelist counter is decremented. Similarly, if the entity is blacklisted, the blacklist counter is decremented.
   * @param self The storage reference for PassportStorage.
   * @param entity The address of the entity whose whitelist/blacklist status is being removed.
   * @param passport The address of the passport from which the entity's whitelist/blacklist status is being removed.
   */
  function removeEntitiesBlackAndWhiteListsFromPassport(
    PassportStorageTypesV1.PassportStorage storage self,
    address entity,
    address passport
  ) internal {
    uint256 _whitelist = isWhitelisted(self, entity) ? 1 : 0;
    uint256 _blacklist = isBlacklisted(self, entity) ? 1 : 0;

    self.whitelistedEntitiesCounter[passport] -= _whitelist;
    self.blacklistedEntitiesCounter[passport] -= _blacklist;
  }

  /**
   * @notice Updates the blacklist counter for a passport based on the increment flag.
   * @dev This private function adjusts the blacklist counter of the passport by either incrementing or decrementing it.
   * The function checks whether the user is different from the passport before updating the counter.
   * @param self The storage reference for PassportStorage.
   * @param user The address of the user whose blacklisy status is being checked.
   * @param increment A boolean flag indicating whether to increment (true) or decrement (false) the blacklist counter.
   */
  function _updatePassportBlacklistCounter(
    PassportStorageTypesV1.PassportStorage storage self,
    address user,
    bool increment
  ) private {
    address passport = PassportEntityLogicV1._getPassportForEntity(self, user);

    // If the user is the passport, no need to update the counter
    if (passport == user) {
      return;
    } else if (increment) {
      self.blacklistedEntitiesCounter[passport] += 1;
    } else {
      self.blacklistedEntitiesCounter[passport] -= 1;
    }
  }

  /**
   * @notice Updates the whitelist counter for a passport based on the increment flag.
   * @dev This private function adjusts the whitelist counter of the passport by either incrementing or decrementing it.
   * The function checks whether the user is different from the passport before updating the counter.
   * @param self The storage reference for PassportStorage.
   * @param user The address of the user whose whitelist status is being checked.
   * @param increment A boolean flag indicating whether to increment (true) or decrement (false) the whitelist counter.
   */
  function _updatePassportWhitelistCounter(
    PassportStorageTypesV1.PassportStorage storage self,
    address user,
    bool increment
  ) private {
    address passport = PassportEntityLogicV1._getPassportForEntity(self, user);

    // If the user is the passport, no need to update the counter
    if (passport == user) {
      return;
    } else if (increment) {
      self.whitelistedEntitiesCounter[passport] += 1;
    } else {
      self.whitelistedEntitiesCounter[passport] -= 1;
    }
  }

  /**
   * @notice Checks if a passport is whitelisted based on a threshold percentage of linked entities.
   * @dev This function checks if the passport itself is whitelisted or if the number of whitelisted entities
   * linked to the passport exceeds the given threshold percentage of the total entities linked to the passport.
   * It first checks if the passport is directly whitelisted. If not, it calculates the percentage of whitelisted
   * entities linked to the passport and compares it to the threshold.
   * @param self The storage reference for PassportStorage.
   * @param passport The address of the passport being checked.
   * @return True if the passport is whitelisted based on the threshold, otherwise false.
   */
  function _isPassportWhitelisted(
    PassportStorageTypesV1.PassportStorage storage self,
    address passport
  ) internal view returns (bool) {
    passport = PassportEntityLogicV1._getPassportForEntity(self, passport);

    // Check if the passport itself is whitelisted
    if (isWhitelisted(self, passport)) {
      return true;
    }

    // Get the number of entities the passport has attached
    uint256 totalEntities = PassportEntityLogicV1.getEntitiesLinkedToPassport(self, passport).length;

    // If there are no entities, the passport can't be considered whitelisted based on app interactions
    if (totalEntities == 0) {
      return false;
    }

    // Get the number of whitelisted entities attached to the passport
    uint256 whitelistedEntities = self.whitelistedEntitiesCounter[passport];

    // Calculate the percentage of whitelisted entities
    uint256 whitelistPercentage = (whitelistedEntities * 100) / totalEntities;

    // Return true if the whitelist percentage exceeds the given threshold percentage
    return whitelistPercentage >= self.whitelistThreshold;
  }

  /**
   * @notice Checks if a passport is blacklisted based on a threshold percentage of linked entities.
   * @dev This function checks if the passport itself is blacklisted or if the number of blacklisted entities
   * linked to the passport exceeds the given threshold percentage of the total entities linked to the passport.
   * It first checks if the passport is directly blacklisted. If not, it calculates the percentage of blacklisted
   * entities linked to the passport and compares it to the specified threshold.
   * @param self The storage reference for PassportStorage.
   * @param passport The address of the passport being checked.
   * @return True if the passport is blacklisted based on the threshold, otherwise false.
   */
  function _isPassportBlacklisted(
    PassportStorageTypesV1.PassportStorage storage self,
    address passport
  ) internal view returns (bool) {
    passport = PassportEntityLogicV1._getPassportForEntity(self, passport);

    // Check if the passport itself is blacklisted
    if (isBlacklisted(self, passport)) {
      return true;
    }

    // Get the number of entities the passport has interacted with
    uint256 totalEntities = PassportEntityLogicV1.getEntitiesLinkedToPassport(self, passport).length;
    if (totalEntities == 0) {
      // If there are no entities, the passport can't be considered blacklisted based on app interactions
      return false;
    }

    // Get the number of blacklisted entities attached to the passport
    uint256 blacklistedEntities = self.blacklistedEntitiesCounter[passport];

    // Calculate the percentage of blacklisted entities
    uint256 blacklistPercentage = (blacklistedEntities * 100) / totalEntities;

    // Return true if the blacklist percentage exceeds the given threshold percentage
    return blacklistPercentage >= self.blacklistThreshold;
  }
}

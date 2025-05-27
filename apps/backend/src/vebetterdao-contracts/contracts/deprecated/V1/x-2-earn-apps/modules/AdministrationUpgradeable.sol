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

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { X2EarnAppsUpgradeableV1 } from "../X2EarnAppsUpgradeableV1.sol";

/**
 * @title AdministrationUpgradeable
 * @dev Contract module that provides the administration functionalities of the x2earn apps.
 * Each app has one admin and can have many moderators, the use of those should be definied by the contract inheriting this module.
 * Each app has a metadataURI that returns the information of the app.
 * The team wallet address is the address that receives the allocation funds each round.
 * The team allocation percentage is the percentage funds sent to the team at each distribution of allocation rewards.
 * The reward distributors are the addresses that can distribute rewards from the X2EarnRewardsPool.
 */
abstract contract AdministrationUpgradeable is Initializable, X2EarnAppsUpgradeableV1 {
  uint256 public constant MAX_MODERATORS = 100;
  uint256 public constant MAX_REWARD_DISTRIBUTORS = 100;

  /// @custom:storage-location erc7201:b3tr.storage.X2EarnApps.Administration
  struct AdministrationStorage {
    mapping(bytes32 appId => address) _admin;
    mapping(bytes32 appId => address[]) _moderators;
    mapping(bytes32 appId => address[]) _rewardDistributors; // addresses that can distribute rewards from X2EarnRewardsPool
    mapping(bytes32 appId => address) _teamWalletAddress;
    mapping(bytes32 appId => uint256) _teamAllocationPercentage; // by default this is 0 and all funds are sent to the X2EarnRewardsPool
    mapping(bytes32 appId => string) _metadataURI;
  }

  // keccak256(abi.encode(uint256(keccak256("b3tr.storage.X2EarnApps.Administration")) - 1)) & ~bytes32(uint256(0xff))
  bytes32 private constant AdministrationStorageLocation =
    0x5830f0e95c01712d916c34d9e2fa42e9f749b325b67bce7382d70bb99c623500;

  function _getAdministrationStorage() internal pure returns (AdministrationStorage storage $) {
    assembly {
      $.slot := AdministrationStorageLocation
    }
  }

  /**
   * @dev Initializes the contract
   */
  function __Administration_init() internal onlyInitializing {
    __Administration_init_unchained();
  }

  function __Administration_init_unchained() internal onlyInitializing {}

  // ---------- Internal ---------- //
  /**
   * @dev Internal function to set the admin address of the app
   *
   * @param appId the hashed name of the app
   * @param newAdmin the address of the new admin
   */
  function _setAppAdmin(bytes32 appId, address newAdmin) internal override {
    if (!appExists(appId)) {
      revert X2EarnNonexistentApp(appId);
    }

    if (newAdmin == address(0)) {
      revert X2EarnInvalidAddress(newAdmin);
    }

    AdministrationStorage storage $ = _getAdministrationStorage();

    emit AppAdminUpdated(appId, $._admin[appId], newAdmin);

    $._admin[appId] = newAdmin;
  }

  /**
   * @dev Internal function to add a moderator to the app
   *
   * @param appId the hashed name of the app
   * @param moderator the address of the moderator
   */
  function _addAppModerator(bytes32 appId, address moderator) internal {
    if (moderator == address(0)) {
      revert X2EarnInvalidAddress(moderator);
    }

    if (!appExists(appId)) {
      revert X2EarnNonexistentApp(appId);
    }

    AdministrationStorage storage $ = _getAdministrationStorage();

    if ($._moderators[appId].length >= MAX_MODERATORS) {
      revert X2EarnMaxModeratorsReached(appId);
    }

    $._moderators[appId].push(moderator);

    emit ModeratorAddedToApp(appId, moderator);
  }

  /**
   * @dev Internal function to remove a moderator from the app
   *
   * @param appId the hashed name of the app
   * @param moderator the address of the moderator
   */
  function _removeAppModerator(bytes32 appId, address moderator) internal {
    if (moderator == address(0)) {
      revert X2EarnInvalidAddress(moderator);
    }

    if (!appExists(appId)) {
      revert X2EarnNonexistentApp(appId);
    }

    if (!isAppModerator(appId, moderator)) {
      revert X2EarnNonexistentModerator(appId, moderator);
    }

    AdministrationStorage storage $ = _getAdministrationStorage();

    address[] storage moderators = $._moderators[appId];
    for (uint256 i; i < moderators.length; i++) {
      if (moderators[i] == moderator) {
        moderators[i] = moderators[moderators.length - 1];
        moderators.pop();
        emit ModeratorRemovedFromApp(appId, moderator);
        break;
      }
    }
  }

  /**
   * @dev Internal function to add a reward distributor to the app
   *
   * @param appId the hashed name of the app
   * @param distributor the address of the reward distributor
   */
  function _addRewardDistributor(bytes32 appId, address distributor) internal {
    if (distributor == address(0)) {
      revert X2EarnInvalidAddress(distributor);
    }

    if (!appExists(appId)) {
      revert X2EarnNonexistentApp(appId);
    }

    AdministrationStorage storage $ = _getAdministrationStorage();

    if ($._rewardDistributors[appId].length >= MAX_REWARD_DISTRIBUTORS) {
      revert X2EarnMaxRewardDistributorsReached(appId);
    }

    $._rewardDistributors[appId].push(distributor);

    emit RewardDistributorAddedToApp(appId, distributor);
  }

  /**
   * @dev Internal function to remove a reward distributor from the app
   *
   * @param appId the hashed name of the app
   * @param distributor the address of the reward distributor
   */
  function _removeRewardDistributor(bytes32 appId, address distributor) internal {
    if (distributor == address(0)) {
      revert X2EarnInvalidAddress(distributor);
    }

    if (!appExists(appId)) {
      revert X2EarnNonexistentApp(appId);
    }

    if (!isRewardDistributor(appId, distributor)) {
      revert X2EarnNonexistentRewardDistributor(appId, distributor);
    }

    AdministrationStorage storage $ = _getAdministrationStorage();

    address[] storage distributors = $._rewardDistributors[appId];
    for (uint256 i; i < distributors.length; i++) {
      if (distributors[i] == distributor) {
        distributors[i] = distributors[distributors.length - 1];
        distributors.pop();
        emit RewardDistributorRemovedFromApp(appId, distributor);
        break;
      }
    }
  }

  /**
   * @dev Update the address where the x2earn app receives allocation funds
   *
   * @param appId the hashed name of the app
   * @param newTeamWalletAddress the address of the new wallet where the team will receive the funds
   */
  function _updateTeamWalletAddress(bytes32 appId, address newTeamWalletAddress) internal override {
    if (newTeamWalletAddress == address(0)) {
      revert X2EarnInvalidAddress(newTeamWalletAddress);
    }

    if (!appExists(appId)) {
      revert X2EarnNonexistentApp(appId);
    }

    AdministrationStorage storage $ = _getAdministrationStorage();
    address oldTeamWalletAddress = $._teamWalletAddress[appId];
    $._teamWalletAddress[appId] = newTeamWalletAddress;

    emit TeamWalletAddressUpdated(appId, oldTeamWalletAddress, newTeamWalletAddress);
  }

  /**
   * @dev Update the metadata URI of the app
   *
   * @param appId the hashed name of the app
   * @param newMetadataURI the metadata URI of the app
   *
   * Emits a {AppMetadataURIUpdated} event.
   */
  function _updateAppMetadata(bytes32 appId, string memory newMetadataURI) internal override {
    if (!appExists(appId)) {
      revert X2EarnNonexistentApp(appId);
    }

    AdministrationStorage storage $ = _getAdministrationStorage();
    string memory oldMetadataURI = $._metadataURI[appId];
    $._metadataURI[appId] = newMetadataURI;

    emit AppMetadataURIUpdated(appId, oldMetadataURI, newMetadataURI);
  }

  /**
   * @dev Update the allocation percentage to reserve for the team
   *
   * @param appId the app id
   * @param newAllocationPercentage the new allocation percentage
   */
  function _setTeamAllocationPercentage(bytes32 appId, uint256 newAllocationPercentage) internal virtual override {
    if (!appExists(appId)) {
      revert X2EarnNonexistentApp(appId);
    }

    if (newAllocationPercentage > 100) {
      revert X2EarnInvalidAllocationPercentage(newAllocationPercentage);
    }

    AdministrationStorage storage $ = _getAdministrationStorage();
    uint256 oldAllocationPercentage = $._teamAllocationPercentage[appId];
    $._teamAllocationPercentage[appId] = newAllocationPercentage;

    emit TeamAllocationPercentageUpdated(appId, oldAllocationPercentage, newAllocationPercentage);
  }

  // ---------- Getters ---------- //

  /**
   * @dev Check if an account is the admin of the app
   *
   * @param appId the hashed name of the app
   * @param account the address of the account
   */
  function isAppAdmin(bytes32 appId, address account) public view returns (bool) {
    AdministrationStorage storage $ = _getAdministrationStorage();

    return $._admin[appId] == account;
  }

  /**
   * @dev See {IX2EarnApps-appAdmin}
   */
  function appAdmin(bytes32 appId) public view override returns (address) {
    AdministrationStorage storage $ = _getAdministrationStorage();

    return $._admin[appId];
  }

  /**
   * @dev Returns the list of moderators of the app
   *
   * @param appId the hashed name of the app
   */
  function appModerators(bytes32 appId) public view override returns (address[] memory) {
    AdministrationStorage storage $ = _getAdministrationStorage();

    return $._moderators[appId];
  }

  /**
   * @dev Returns true if an account is moderator of the app
   *
   * @param appId the hashed name of the app
   * @param account the address of the account
   */
  function isAppModerator(bytes32 appId, address account) public view returns (bool) {
    AdministrationStorage storage $ = _getAdministrationStorage();

    address[] memory moderators = $._moderators[appId];
    for (uint256 i; i < moderators.length; i++) {
      if (moderators[i] == account) {
        return true;
      }
    }

    return false;
  }

  /**
   * @dev Get the address where the x2earn app receives allocation funds
   *
   * @param appId the hashed name of the app
   */
  function teamWalletAddress(bytes32 appId) public view override returns (address) {
    AdministrationStorage storage $ = _getAdministrationStorage();

    return $._teamWalletAddress[appId];
  }

  /**
   * @dev Function to get the percentage of the allocation reserved for the team
   *
   * @param appId the app id
   */
  function teamAllocationPercentage(bytes32 appId) public view override returns (uint256) {
    AdministrationStorage storage $ = _getAdministrationStorage();

    return $._teamAllocationPercentage[appId];
  }

  /**
   * @dev Returns the list of reward distributors of the app
   *
   * @param appId the hashed name of the app
   */
  function rewardDistributors(bytes32 appId) public view returns (address[] memory) {
    AdministrationStorage storage $ = _getAdministrationStorage();

    return $._rewardDistributors[appId];
  }

  /**
   * @dev Returns true if an account is a reward distributor of the app
   *
   * @param appId the hashed name of the app
   * @param account the address of the account
   */
  function isRewardDistributor(bytes32 appId, address account) public view returns (bool) {
    AdministrationStorage storage $ = _getAdministrationStorage();

    address[] memory distributors = $._rewardDistributors[appId];
    for (uint256 i; i < distributors.length; i++) {
      if (distributors[i] == account) {
        return true;
      }
    }

    return false;
  }

  /**
   * @dev Get the metadata URI of the app
   *
   * @param appId the app id
   */
  function metadataURI(bytes32 appId) public view override returns (string memory) {
    AdministrationStorage storage $ = _getAdministrationStorage();

    return $._metadataURI[appId];
  }
}

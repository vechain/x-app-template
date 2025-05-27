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
import { X2EarnAppsUpgradeable } from "../X2EarnAppsUpgradeable.sol";
import { AdministrationUtils } from "../libraries/AdministrationUtils.sol";
import { IX2EarnCreator } from "../../interfaces/IX2EarnCreator.sol";

/**
 * @title AdministrationUpgradeable
 * @dev Contract module that provides the administration functionalities of the x2earn apps.
 * Each app has one admin and can have many moderators, the use of those should be definied by the contract inheriting this module.
 * Each app has a metadataURI that returns the information of the app.
 * The team wallet address is the address that receives the allocation funds each round.
 * The team allocation percentage is the percentage funds sent to the team at each distribution of allocation rewards.
 * The reward distributors are the addresses that can distribute rewards from the X2EarnRewardsPool.
 */
abstract contract AdministrationUpgradeable is Initializable, X2EarnAppsUpgradeable {
  uint256 public constant MAX_MODERATORS = 100;
  uint256 public constant MAX_REWARD_DISTRIBUTORS = 100;
  uint256 public constant MAX_CREATORS = 3;

  /// @custom:storage-location erc7201:b3tr.storage.X2EarnApps.Administration
  struct AdministrationStorage {
    mapping(bytes32 appId => address) _admin;
    mapping(bytes32 appId => address[]) _moderators;
    mapping(bytes32 appId => address[]) _rewardDistributors; // addresses that can distribute rewards from X2EarnRewardsPool
    mapping(bytes32 appId => address) _teamWalletAddress;
    mapping(bytes32 appId => uint256) _teamAllocationPercentage; // by default this is 0 and all funds are sent to the X2EarnRewardsPool
    mapping(bytes32 appId => string) _metadataURI;
    mapping(bytes32 appId => address[]) _creators; // addresses that have a creators NFT and can manage interactions with Node holders
    mapping(address creator => uint256 apps) _creatorApps; // number of apps created by a creator
    IX2EarnCreator _x2EarnCreatorContract;
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
   * @dev Initializes the contract for version 2
   * @notice This function adds initialization logic for the V2 upgrade.
   */
  function __Administration_init_v2(address _x2EarnCreatorContract) internal {
    __Administration_init_v2_unchained(_x2EarnCreatorContract);
  }

  function __Administration_init_v2_unchained(address _x2EarnCreatorContract) internal onlyInitializing {
    // Set the x2EarnCreator contract
    _setX2EarnCreatorContract(_x2EarnCreatorContract);
  }

  // ---------- Internal ---------- //
  /**
   * @dev Internal function to set the admin address of the app
   *
   * @param appId the hashed name of the app
   * @param newAdmin the address of the new admin
   */
  function _setAppAdmin(bytes32 appId, address newAdmin) internal override {
    AdministrationStorage storage $ = _getAdministrationStorage();
    AdministrationUtils.setAppAdmin($._admin, appId, newAdmin, _appSubmitted(appId));
  }

  /**
   * @dev Internal function to add a moderator to the app
   *
   * @param appId the hashed name of the app
   * @param moderator the address of the moderator
   */
  function _addAppModerator(bytes32 appId, address moderator) internal {
    AdministrationStorage storage $ = _getAdministrationStorage();
    AdministrationUtils.addAppModerator($._moderators, appId, moderator, _appSubmitted(appId), MAX_MODERATORS);
  }

  /**
   * @dev Internal function to remove a moderator from the app
   *
   * @param appId the hashed name of the app
   * @param moderator the address of the moderator
   */
  function _removeAppModerator(bytes32 appId, address moderator) internal {
    AdministrationStorage storage $ = _getAdministrationStorage();
    AdministrationUtils.removeAppModerator($._moderators, appId, moderator, _appSubmitted(appId));
  }

  /**
   * @dev Internal function to remove a creator from the app
   *
   * @param appId the hashed name of the app
   * @param creator the address of the creator
   */
  function _removeAppCreator(bytes32 appId, address creator) internal {
    AdministrationStorage storage $ = _getAdministrationStorage();
    AdministrationUtils.removeAppCreator(
      $._creators,
      $._creatorApps,
      $._x2EarnCreatorContract,
      appId,
      creator,
      _appSubmitted(appId)
    );
  }

  /**
   * @dev Internal function to add a creator to the app
   *
   * @param appId the hashed name of the app
   * @param creator the address of the creator
   */
  function _addCreator(bytes32 appId, address creator) internal override {
    AdministrationStorage storage $ = _getAdministrationStorage();
    AdministrationUtils.addCreator(
      $._creators,
      $._creatorApps,
      $._x2EarnCreatorContract,
      appId,
      creator,
      _appSubmitted(appId),
      MAX_CREATORS
    );
  }

  /**
   * @dev Internal function to add a reward distributor to the app
   *
   * @param appId the hashed name of the app
   * @param distributor the address of the reward distributor
   */
  function _addRewardDistributor(bytes32 appId, address distributor) internal {
    AdministrationStorage storage $ = _getAdministrationStorage();
    AdministrationUtils.addRewardDistributor(
      $._rewardDistributors,
      appId,
      distributor,
      _appSubmitted(appId),
      MAX_REWARD_DISTRIBUTORS
    );
  }

  /**
   * @dev Internal function to remove a reward distributor from the app
   *
   * @param appId the hashed name of the app
   * @param distributor the address of the reward distributor
   */
  function _removeRewardDistributor(bytes32 appId, address distributor) internal {
    AdministrationStorage storage $ = _getAdministrationStorage();
    AdministrationUtils.removeRewardDistributor($._rewardDistributors, appId, distributor, _appSubmitted(appId));
  }

  /**
   * @dev Update the address where the x2earn app receives allocation funds
   *
   * @param appId the hashed name of the app
   * @param newTeamWalletAddress the address of the new wallet where the team will receive the funds
   */
  function _updateTeamWalletAddress(bytes32 appId, address newTeamWalletAddress) internal override {
    AdministrationStorage storage $ = _getAdministrationStorage();
    AdministrationUtils.updateTeamWalletAddress(
      $._teamWalletAddress,
      appId,
      newTeamWalletAddress,
      _appSubmitted(appId)
    );
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
    AdministrationStorage storage $ = _getAdministrationStorage();
    AdministrationUtils.updateAppMetadata($._metadataURI, appId, newMetadataURI, _appSubmitted(appId));
  }

  /**
   * @dev Update the allocation percentage to reserve for the team
   *
   * @param appId the app id
   * @param newAllocationPercentage the new allocation percentage
   */
  function _setTeamAllocationPercentage(bytes32 appId, uint256 newAllocationPercentage) internal virtual override {
    AdministrationStorage storage $ = _getAdministrationStorage();
    AdministrationUtils.setTeamAllocationPercentage(
      $._teamAllocationPercentage,
      appId,
      newAllocationPercentage,
      _appSubmitted(appId)
    );
  }

  /**
   * @dev Function to revoke all creator roles from an app and burn the creator NFTs
   *
   * @param appId the app id
   */
  function _revokeAppCreators(bytes32 appId) internal {
    AdministrationStorage storage $ = _getAdministrationStorage();
    if (!isBlacklisted(appId))
      AdministrationUtils.revokeAppCreators($._creators, $._creatorApps, $._x2EarnCreatorContract, appId);
  }

  /**
   * @dev Function to revoke all creator roles from an app and burn the creator NFTs
   *
   * @param appId the app id
   */
  function _validateAppCreators(bytes32 appId) internal {
    AdministrationStorage storage $ = _getAdministrationStorage();
    if (isBlacklisted(appId))
      AdministrationUtils.validateAppCreators($._creators, $._creatorApps, $._x2EarnCreatorContract, appId);
  }

  /**
   * @dev Set the x2EarnCreator contract
   *
   * @param x2EarnCreatorContractAddress the address of the x2EarnCreator contract
   */
  function _setX2EarnCreatorContract(address x2EarnCreatorContractAddress) internal {
    AdministrationStorage storage $ = _getAdministrationStorage();

    require(x2EarnCreatorContractAddress != address(0), "X2EarnApps: Invalid x2EarnCreatorContract address");

    $._x2EarnCreatorContract = IX2EarnCreator(x2EarnCreatorContractAddress);
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
   * @dev Returns the list of creators of the app
   */
  function appCreators(bytes32 appId) external view returns (address[] memory) {
    AdministrationStorage storage $ = _getAdministrationStorage();

    return $._creators[appId];
  }

  /**
   * @dev Returns true if an account is a creator of the app
   *
   * @param appId the hashed name of the app
   * @param account the address of the account
   */
  function isAppCreator(bytes32 appId, address account) external view returns (bool) {
    AdministrationStorage storage $ = _getAdministrationStorage();

    return AdministrationUtils.isAppCreator($._creators, appId, account);
  }

  /**
   * @dev Returns true if an account is moderator of the app
   *
   * @param appId the hashed name of the app
   * @param account the address of the account
   */
  function isAppModerator(bytes32 appId, address account) public view returns (bool) {
    AdministrationStorage storage $ = _getAdministrationStorage();
    return AdministrationUtils.isAppModerator($._moderators, appId, account);
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

    return AdministrationUtils.isRewardDistributor($._rewardDistributors, appId, account);
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

  /**
   * @dev Get the number of apps created by a creator
   */
  function creatorApps(address creator) external view returns (uint256) {
    AdministrationStorage storage $ = _getAdministrationStorage();

    return $._creatorApps[creator];
  }

  /**
   * @dev See {IX2EarnApps-getX2EarnCreator}.
   */
  function x2EarnCreatorContract() public view override returns (IX2EarnCreator) {
    AdministrationStorage storage $ = _getAdministrationStorage();
    return $._x2EarnCreatorContract;
  }
}

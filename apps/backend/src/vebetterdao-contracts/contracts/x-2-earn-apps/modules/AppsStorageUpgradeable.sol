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
import { X2EarnAppsDataTypes } from "../../libraries/X2EarnAppsDataTypes.sol";
import { AppStorageUtils } from "../libraries/AppStorageUtils.sol";

/**
 * @title AppsStorageUpgradeable
 * @dev Contract to manage the x2earn apps storage.
 * Through this contract, the x2earn apps can be added, retrieved and indexed.
 */
abstract contract AppsStorageUpgradeable is Initializable, X2EarnAppsUpgradeable {
  /// @custom:storage-location erc7201:b3tr.storage.X2EarnApps.AppsStorage
  struct AppsStorageStorage {
    // Mapping from app ID to app
    mapping(bytes32 appId => X2EarnAppsDataTypes.App) _apps;
    // List of app IDs to enable retrieval of all _apps
    bytes32[] _appIds;
  }

  // keccak256(abi.encode(uint256(keccak256("b3tr.storage.X2EarnApps.AppsStorage")) - 1)) & ~bytes32(uint256(0xff))
  bytes32 private constant AppsStorageStorageLocation =
    0xb6909058bd527140b8d55a44344c5e42f1f148f1b3b16df7641882df8dd72900;

  function _getAppsStorageStorage() internal pure returns (AppsStorageStorage storage $) {
    assembly {
      $.slot := AppsStorageStorageLocation
    }
  }

  // ---------- Internal ---------- //
  /**
   * @dev Get the app data saved in storage
   *
   * @param appId the if of the app
   */
  function _getAppStorage(bytes32 appId) internal view returns (X2EarnAppsDataTypes.App memory) {
    if (!_appSubmitted(appId)) {
      revert X2EarnNonexistentApp(appId);
    }

    AppsStorageStorage storage $ = _getAppsStorageStorage();
    return $._apps[appId];
  }

  /**
   * @dev Add app.
   * Will be eligible for voting by default from the next round and
   * the team allocation percentage will be 0%.
   *
   * @param appId the id of the app
   *
   * Emits a {AppAdded} event.
   */
  function _addApp(bytes32 appId) internal virtual override {
    AppsStorageStorage storage $ = _getAppsStorageStorage();

    $._apps[appId].createdAtTimestamp = block.timestamp;

    // Store the new app
    $._appIds.push(appId);
    _setVotingEligibility(appId, true);

    emit AppAdded(appId, teamWalletAddress(appId), $._apps[appId].name, true);
  }

  /**
   * @dev Create app.
   * The id of the app is the hash of the app name.
   * Will be pending endorsement.
   *
   * @param teamWalletAddress the address where the app should receive allocation funds
   * @param admin the address of the admin
   * @param appName the name of the app
   * @param metadataURI the metadata URI of the app
   *
   * Emits a {AppAdded} event.
   */
  function _registerApp(
    address teamWalletAddress,
    address admin,
    string memory appName,
    string memory metadataURI
  ) internal {
    if (teamWalletAddress == address(0)) {
      revert X2EarnInvalidAddress(teamWalletAddress);
    }
    if (admin == address(0)) {
      revert X2EarnInvalidAddress(admin);
    }

    bytes32 id = hashAppName(appName);

    if (_appSubmitted(id)) {
      revert X2EarnAppAlreadyExists(id);
    }

    AppsStorageStorage storage $ = _getAppsStorageStorage();

    if(x2EarnCreatorContract().balanceOf(msg.sender) == 0) {
      revert X2EarnUnverifiedCreator(msg.sender);
    }

    // Store the new app
    $._apps[id] = X2EarnAppsDataTypes.App(id, appName, 0);
    _setAppAdmin(id, admin);
    _updateTeamWalletAddress(id, teamWalletAddress);
    _updateAppMetadata(id, metadataURI);
    _setTeamAllocationPercentage(id, 0);
    _setEndorsementStatus(id, false);
    _addCreator(id, msg.sender);

    emit AppAdded(id, teamWalletAddress, appName, false);
  }

  /**
   * @notice Retrieves detailed information for multiple applications.
   * @dev This function is an internal view function that overrides a virtual function.
   * It fetches data from storage and constructs an array of AppWithDetailsReturnType objects.
   * @param appIds An array of application IDs for which details are to be retrieved.
   * @return allApps An array of AppWithDetailsReturnType containing detailed information about each application.
   */
  function _getAppsInfo(
    bytes32[] memory appIds
  ) internal view virtual override returns (X2EarnAppsDataTypes.AppWithDetailsReturnType[] memory) {
    AppsStorageStorage storage $ = _getAppsStorageStorage();

    uint256 length = appIds.length;
    X2EarnAppsDataTypes.AppWithDetailsReturnType[] memory allApps = new X2EarnAppsDataTypes.AppWithDetailsReturnType[](
      length
    );

    for (uint i; i < length; i++) {
      X2EarnAppsDataTypes.App memory _app = $._apps[appIds[i]];
      allApps[i] = X2EarnAppsDataTypes.AppWithDetailsReturnType(
        _app.id,
        teamWalletAddress(_app.id),
        _app.name,
        metadataURI(_app.id),
        _app.createdAtTimestamp,
        isEligibleNow(_app.id)
      );
    }
    return allApps;
  }

  /**
   * @dev Check if the apps registration has been submitted.
   *
   * @param appId the id of the app
   */
  function _appSubmitted(bytes32 appId) internal view override returns (bool) {
    AppsStorageStorage storage $ = _getAppsStorageStorage();

    return $._apps[appId].id != bytes32(0);
  }

  // ---------- Getters ---------- //
  /**
   * @dev See {IX2EarnApps-appExists}.
   *
   * @notice An XApp must have been included in at least one allocation round to return true here.
   */
  function appExists(bytes32 appId) public view override returns (bool) {
    AppsStorageStorage storage $ = _getAppsStorageStorage();

    return $._apps[appId].createdAtTimestamp != 0;
  }

  /**
   * @dev See {IX2EarnApps-app}.
   *
   * @param appId the id of the app
   */
  function app(
    bytes32 appId
  ) public view virtual override returns (X2EarnAppsDataTypes.AppWithDetailsReturnType memory) {
    X2EarnAppsDataTypes.App memory _app = _getAppStorage(appId);

    return
      X2EarnAppsDataTypes.AppWithDetailsReturnType(
        _app.id,
        teamWalletAddress(appId),
        _app.name,
        metadataURI(appId),
        _app.createdAtTimestamp,
        isEligibleNow(_app.id)
      );
  }

  /**
   * @dev See {IX2EarnApps-apps}.
   *
   * @notice This function could not be efficient with a large number of apps, in that case, use {IX2EarnApps-getPaginatedApps}
   * and then call {IX2EarnApps-app} for each app id
   * An XApp must have been included in at least one allocation round to be considered an existing app.
   */
  function apps() external view returns (X2EarnAppsDataTypes.AppWithDetailsReturnType[] memory) {
    AppsStorageStorage storage $ = _getAppsStorageStorage();
    return _getAppsInfo($._appIds);
  }

  /**
   * @dev See {IX2EarnApps-getPaginatedApps}.
   */
  function getPaginatedApps(uint startIndex, uint count) external view returns (X2EarnAppsDataTypes.App[] memory) {
    AppsStorageStorage storage $ = _getAppsStorageStorage();

    return AppStorageUtils.getPaginatedApps($._apps, $._appIds, startIndex, count);
  }

  /**
   * @dev See {IX2EarnApps-appsCount}.
   */
  function appsCount() external view returns (uint256) {
    AppsStorageStorage storage $ = _getAppsStorageStorage();
    return $._appIds.length;
  }
}

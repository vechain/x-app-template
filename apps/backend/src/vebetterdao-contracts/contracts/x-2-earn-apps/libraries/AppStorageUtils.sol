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

import { VechainNodesDataTypes } from "../../libraries/VechainNodesDataTypes.sol";
import { PassportTypes } from "../../ve-better-passport/libraries/PassportTypes.sol";
import { INodeManagement } from "../../interfaces/INodeManagement.sol";
import { X2EarnAppsDataTypes } from "../../libraries/X2EarnAppsDataTypes.sol";
import { IVeBetterPassport } from "../../interfaces/IVeBetterPassport.sol";

/**
 * @title AppStorageUtils
 * @dev Utility library for managing paginated access to app data stored in a mapping.
 * Provides functionality for retrieving a subset of apps based on specified start index and count.
 */
library AppStorageUtils {

  /**
   * @dev Error thrown when the specified start index for pagination is invalid.
   * This typically occurs when the start index exceeds the total number of available apps.
   */
  error X2EarnInvalidStartIndex();

  /**
   * @notice Retrieves a subset of apps from the app storage based on pagination parameters.
   * @param _apps Mapping of app IDs to `X2EarnAppsDataTypes.App` structs representing each app's data.
   * @param _appIds Array of app IDs used to reference apps in the `_apps` mapping.
   * @param startIndex The starting index in `_appIds` from which to begin retrieval.
   * @param count The number of apps to retrieve from `startIndex`.
   * @return X2EarnAppsDataTypes.App[] An array of apps retrieved from the specified range.
   *
   * Requirements:
   * - `startIndex` must be less than the length of `_appIds`.
   * - If `startIndex + count` exceeds `_appIds` length, only available apps up to the end of `_appIds` are returned.
   *
   * Reverts:
   * - If `startIndex` is invalid (i.e., greater than or equal to the length of `_appIds`), reverts with `X2EarnInvalidStartIndex`.
   */
  function getPaginatedApps(
    mapping(bytes32 appId => X2EarnAppsDataTypes.App) storage _apps,
    bytes32[] memory _appIds,
    uint startIndex,
    uint count
  ) internal view returns (X2EarnAppsDataTypes.App[] memory) {
    uint256 length = _appIds.length;
    if (length <= startIndex) {
      revert X2EarnInvalidStartIndex();
    }

    // Calculate the end index based on the requested count, limited by available apps
    uint256 endIndex = startIndex + count;
    if (endIndex > length) {
      endIndex = length;
    }

    // Create an array to hold the paginated apps
    X2EarnAppsDataTypes.App[] memory paginatedApps = new X2EarnAppsDataTypes.App[](endIndex - startIndex);

    // Populate the paginated array with the apps in the specified range
    for (uint i = startIndex; i < endIndex; i++) {
      paginatedApps[i - startIndex] = _apps[_appIds[i]];
    }

    return paginatedApps;
  }
}

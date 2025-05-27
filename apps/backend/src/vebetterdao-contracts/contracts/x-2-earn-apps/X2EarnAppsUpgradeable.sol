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

import { Time } from "@openzeppelin/contracts/utils/types/Time.sol";
import { IX2EarnApps } from "../interfaces/IX2EarnApps.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { X2EarnAppsDataTypes } from "../libraries/X2EarnAppsDataTypes.sol";
import { IX2EarnCreator } from "../interfaces/IX2EarnCreator.sol";

/**
 * @title X2EarnAppsUpgradeable
 * @dev Core of x-2-earn applications management, designed to be extended through various modules.
 *
 * This contract is abstract and requires several functions to be implemented in various modules:
 * - a module to handle the storage of the apps
 * - a module to handle the voting eligibility of the apps
 * - a module to handle the administration of the app (handle moderators, admin, metadata, team address and percentage)
 * - a module to handle the settings of the contract
 */
abstract contract X2EarnAppsUpgradeable is Initializable, IX2EarnApps {

  // ---------- Getters ---------- //
  /**
   * @dev Get the baseURI and metadata URI of the app concatenated
   *
   * @param appId the hashed name of the app
   */
  function appURI(bytes32 appId) public view returns (string memory) {
    if (!_appSubmitted(appId)) {
      revert X2EarnNonexistentApp(appId);
    }

    return string(abi.encodePacked(baseURI(), metadataURI(appId)));
  }

  /**
   * @dev Clock used for flagging checkpoints or to retrieve the current block number. Can be overridden to implement timestamp based
   * checkpoints (and voting), in which case {CLOCK_MODE} should be overridden as well to match.
   */
  function clock() public view virtual returns (uint48) {
    return Time.blockNumber();
  }

  /**
   * @dev Machine-readable description of the clock as specified in EIP-6372.
   */
  // solhint-disable-next-line func-name-mixedcase
  function CLOCK_MODE() external view virtual returns (string memory) {
    // Check that the clock was not modified
    if (clock() != Time.blockNumber()) {
      revert ERC6372InconsistentClock();
    }
    return "mode=blocknumber&from=default";
  }

  /**
   * @dev See {IX2EarnApps-hashAppName}.
   */
  function hashAppName(string memory appName) public pure returns (bytes32) {
    return keccak256(abi.encodePacked(appName));
  }

  // --- To be implemented by the inheriting contract --- //

  /**
   * @inheritdoc IX2EarnApps
   */
  function appExists(bytes32 appId) public view virtual returns (bool);

  /**
   * @inheritdoc IX2EarnApps
   */
  function isBlacklisted(bytes32 appId) public view virtual returns (bool);

  /**
   * @inheritdoc IX2EarnApps
   */
  function baseURI() public view virtual returns (string memory);

  /**
   * @inheritdoc IX2EarnApps
   */
  function isAppUnendorsed(bytes32 appId) public view virtual returns (bool);

  /**
   * @inheritdoc IX2EarnApps
   */
  function teamWalletAddress(bytes32 appId) public view virtual returns (address);

  /**
   * @dev See {IX2EarnApps-appAdmin}
   */
  function appAdmin(bytes32 appId) public view virtual returns (address);

  /**
   * @dev See {IX2EarnApps-teamAllocationPercentage}
   */
  function teamAllocationPercentage(bytes32 appId) public view virtual returns (uint256);

  /**
   * @dev Returns the list of moderators of the app
   */
  function appModerators(bytes32 appId) public view virtual returns (address[] memory);

  /**
   * @dev Function to get the metadataURI of an app.
   */
  function metadataURI(bytes32 appId) public view virtual returns (string memory);

  /**
   * @dev Returns true if an app is eligible for voting in the current block.
   */
  function isEligibleNow(bytes32 appId) public view virtual returns (bool);

  /**
   * @dev Function to get X2EarnCreator contract
   */
  function x2EarnCreatorContract() public view virtual returns (IX2EarnCreator);

  /**
   * @dev Function to set the voting Eligibility of an app.
   */
  function _setVotingEligibility(bytes32 _appId, bool _isEligible) internal virtual;

  /**
   * @dev Function to update the admin of the app.
   */
  function _setAppAdmin(bytes32 appId, address admin) internal virtual;

  /**
   * @dev Function to update the team wallet address.
   */
  function _updateTeamWalletAddress(bytes32 appId, address newTeamWalletAddress) internal virtual;

  /**
   * @dev Function to update the metadata URI of the app.
   */
  function _updateAppMetadata(bytes32 appId, string memory metadataURI) internal virtual;

  /**
   * @dev Update the allocation percentage of the team.
   */
  function _setTeamAllocationPercentage(bytes32 appId, uint256 percentage) internal virtual;

  /**
   * @dev Function to set the endorsement status of an app.
   */
  function _setEndorsementStatus(bytes32 appId, bool status) internal virtual;

  /**
   * @dev Function to add app to the  list of apps in VeBetterDAO ecosystem.
   */
  function _addApp(bytes32 appId) internal virtual;

  /**
   * @dev Function to get the apps info.
   */
  function _getAppsInfo(
    bytes32[] memory appIds
  ) internal view virtual returns (X2EarnAppsDataTypes.AppWithDetailsReturnType[] memory);

  /**
   * @dev Function to check if an apo is registered.
   */
  function _appSubmitted(bytes32 appId) internal view virtual returns (bool);

  /**
   * @dev Function to add a creator to the app.
   */
  function _addCreator(bytes32 appId, address creator) internal virtual;
}

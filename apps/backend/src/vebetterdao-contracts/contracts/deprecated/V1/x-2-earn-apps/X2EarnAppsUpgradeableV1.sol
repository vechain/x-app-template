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
import { IX2EarnAppsV1 } from "../interfaces/IX2EarnAppsV1.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { X2EarnAppsDataTypes } from "../../../libraries/X2EarnAppsDataTypes.sol";

/**
 * @title X2EarnAppsUpgradeableV1
 * @dev Core of x-2-earn applications management, designed to be extended through various modules.
 *
 * This contract is abstract and requires several functions to be implemented in various modules:
 * - a module to handle the storage of the apps
 * - a module to handle the voting eligibility of the apps
 * - a module to handle the administration of the app (handle moderators, admin, metadata, team address and percentage)
 * - a module to handle the settings of the contract
 */
abstract contract X2EarnAppsUpgradeableV1 is Initializable, IX2EarnAppsV1 {
  /**
   * @dev Initializes the contract
   */
  function __X2EarnApps_init() internal onlyInitializing {
    __X2EarnApps_init_unchained();
  }

  function __X2EarnApps_init_unchained() internal onlyInitializing {}

  // ---------- Getters ---------- //

  /**
   * @dev Get the baseURI and metadata URI of the app concatenated
   *
   * @param appId the hashed name of the app
   */
  function appURI(bytes32 appId) public view returns (string memory) {
    if (!appExists(appId)) {
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
   * @dev See {IX2EarnAppsV1-hashAppName}.
   */
  function hashAppName(string memory appName) public pure returns (bytes32) {
    return keccak256(abi.encodePacked(appName));
  }

  // --- To be implemented by the inheriting contract --- //

  /**
   * @inheritdoc IX2EarnAppsV1
   */
  function appExists(bytes32 appId) public view virtual returns (bool);

  /**
   * @inheritdoc IX2EarnAppsV1
   */
  function baseURI() public view virtual returns (string memory);

  /**
   * @inheritdoc IX2EarnAppsV1
   */
  function teamWalletAddress(bytes32 appId) public view virtual returns (address);

  /**
   * @dev See {IX2EarnAppsV1-appAdmin}
   */
  function appAdmin(bytes32 appId) public view virtual returns (address);

  /**
   * @dev See {IX2EarnAppsV1-teamAllocationPercentage}
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
}

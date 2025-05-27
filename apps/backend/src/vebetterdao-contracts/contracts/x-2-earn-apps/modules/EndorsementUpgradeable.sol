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
import { VechainNodesDataTypes } from "../../libraries/VechainNodesDataTypes.sol";
import { X2EarnAppsUpgradeable } from "../X2EarnAppsUpgradeable.sol";
import { X2EarnAppsDataTypes } from "../../libraries/X2EarnAppsDataTypes.sol";
import { EndorsementUtils } from "../libraries/EndorsementUtils.sol";
import { INodeManagement } from "../../interfaces/INodeManagement.sol";
import { IVeBetterPassport } from "../../interfaces/IVeBetterPassport.sol";
import { PassportTypes } from "../../ve-better-passport/libraries/PassportTypes.sol";

abstract contract EndorsementUpgradeable is Initializable, X2EarnAppsUpgradeable {
  /// @custom:storage-location erc7201:b3tr.storage.X2EarnApps.Endorsment
  struct EndorsementStorage {
    bytes32[] _unendorsedApps; // List of apps pending endorsement
    mapping(bytes32 => uint256) _unendorsedAppsIndex; // Mapping from app ID to index in the _unendorsedApps array, so we can remove an app in O(1)
    mapping(bytes32 => uint256[]) _appEndorsers; // Maps each app ID to an array of node IDs that have endorsed it
    mapping(VechainNodesDataTypes.NodeStrengthLevel => uint256) _nodeEnodorsmentScore; // The endorsement score for each node level
    mapping(bytes32 => uint48) _appGracePeriodStart; // The grace period elapsed by the app since endorsed
    mapping(uint256 => bytes32) _nodeToEndorsedApp; // Maps a node ID to the app it currently endorses
    uint48 _gracePeriodDuration; // The grace period threshold for no endorsement in blocks
    uint256 _endorsementScoreThreshold; // The endorsement score threshold for an app to be eligible for voting
    mapping(bytes32 => uint256) _appScores; // The score of each app
    mapping(bytes32 => PassportTypes.APP_SECURITY) _appSecurity; // The security score of each app
    INodeManagement _nodeManagementContract; // The token auction contract
    IVeBetterPassport _veBetterPassport; // The VeBetterPassport contract
  }

  // keccak256(abi.encode(uint256(keccak256("b3tr.storage.X2EarnApps.Endorsement")) - 1)) & ~bytes32(uint256(0xff))
  bytes32 private constant EndorsementStorageLocation =
    0xc1a7bcdc0c77e8c77ade4541d1777901ab96ca598d164d89afa5c8dfbfc44300;

  function _getEndorsementStorage() internal pure returns (EndorsementStorage storage $) {
    assembly {
      $.slot := EndorsementStorageLocation
    }
  }

  /**
   * @dev Sets the value for the grace period ane the endorsement score for each node level.
   * @param gracePeriodDuration The initial grace period.
   */
  function __Endorsement_init(
    uint48 gracePeriodDuration,
    address vechainNodesContract,
    address veBetterPassportContract
  ) internal onlyInitializing {
    __Endorsement_init_unchained(gracePeriodDuration, vechainNodesContract, veBetterPassportContract);
  }

  function __Endorsement_init_unchained(
    uint48 gracePeriodDuration,
    address nodeManagementContract,
    address veBetterPassportContract
  ) internal onlyInitializing {
    EndorsementStorage storage $ = _getEndorsementStorage();
    $._gracePeriodDuration = gracePeriodDuration;
    $._nodeManagementContract = INodeManagement(nodeManagementContract);
    $._veBetterPassport = IVeBetterPassport(veBetterPassportContract);

    // Set the endorsement score for each node level
    $._nodeEnodorsmentScore[VechainNodesDataTypes.NodeStrengthLevel.Strength] = 2; // Strength Node score
    $._nodeEnodorsmentScore[VechainNodesDataTypes.NodeStrengthLevel.Thunder] = 13; // Thunder Node score
    $._nodeEnodorsmentScore[VechainNodesDataTypes.NodeStrengthLevel.Mjolnir] = 50; // Mjolnir Node score

    $._nodeEnodorsmentScore[VechainNodesDataTypes.NodeStrengthLevel.VeThorX] = 3; // VeThor X Node score
    $._nodeEnodorsmentScore[VechainNodesDataTypes.NodeStrengthLevel.StrengthX] = 9; // Strength X Node score
    $._nodeEnodorsmentScore[VechainNodesDataTypes.NodeStrengthLevel.ThunderX] = 35; // Thunder X Node score
    $._nodeEnodorsmentScore[VechainNodesDataTypes.NodeStrengthLevel.MjolnirX] = 100; // Mjolnir X Node score

    // Set the score threshold for an app to be eligible for voting
    $._endorsementScoreThreshold = 100;
  }

  // ---------- Public ---------- //

  /**
   * @dev See {IX2EarnApps-checkEndorsement}.
   */
  function checkEndorsement(bytes32 appId) public virtual returns (bool) {
    // Ensure the app is registered
    if (!_appSubmitted(appId)) {
      revert X2EarnNonexistentApp(appId);
    }

    // If the app is blacklisted, endorsement status should be false
    if (isBlacklisted(appId)) {
      return false;
    }

    // Calculate the score of the app, considering if any endorser needs to be removed
    uint256 score = _getScoreAndRemoveEndorsement(appId, 0);

    // Check the total score and update the grace period and voting eligibility accordingly
    if (score < _endorsementScoreThreshold()) {
      return _updateStatusIfThresholdNotMet(appId);
    } else {
      _updateStatusIfThresholdMet(appId);
    }

    // Return true indicating the app is eligible for voting
    return true;
  }

  /**
   * @notice Endorses an app.
   * @param appId The unique identifier of the app being endorsed.
   * @param nodeId The unique identifier of the node they wish to use for endorsing app.
   */
  function endorseApp(bytes32 appId, uint256 nodeId) public virtual {
    // Get the endorsement storage
    EndorsementStorage storage $ = _getEndorsementStorage();

    // Check if the app exists
    if (!_appSubmitted(appId)) {
      revert X2EarnNonexistentApp(appId);
    }

    // Check if the app is blacklisted
    if (isBlacklisted(appId)) {
      revert X2EarnAppBlacklisted(appId);
    }

    // Check if the caller is a node holder
    if (nodeId == 0) {
      revert X2EarnNonNodeHolder();
    }

    // Check if the app is pending endorsement
    if (!isAppUnendorsed(appId)) {
      revert X2EarnAppAlreadyEndorsed(appId);
    }

    // Check if the user is managing the specified nodeId either through delegation or ownership
    if (!$._nodeManagementContract.isNodeManager(msg.sender, nodeId)) {
      revert X2EarnNonNodeHolder();
    }

    // Check if the callers Node ID is already an endorser
    if ($._nodeToEndorsedApp[nodeId] != bytes32(0)) {
      revert X2EarnAlreadyEndorser();
    }

    // Add the caller to the list of endorsers for the app
    $._appEndorsers[appId].push(nodeId);
    $._nodeToEndorsedApp[nodeId] = appId;

    // Calculate the score of the app, considering the new endorsement
    uint256 score = _getScoreAndRemoveEndorsement(appId, 0);

    // Check if the score is equal to or greater than the score threshold (100)
    if (score >= _endorsementScoreThreshold()) {
      _updateStatusIfThresholdMet(appId);
    }

    // Emit an event indicating the app has been endorsed by the caller
    emit AppEndorsed(appId, nodeId, true);
  }

  /**
   * @notice Unendorses an app.
   * @param appId The unique identifier of the app being unendorsed.
   */
  function unendorseApp(bytes32 appId, uint256 nodeId) public virtual {
    // Get the endorsement storage
    EndorsementStorage storage $ = _getEndorsementStorage();

    // Check if the user is managing the specified nodeId either through delegation or ownership
    if (!$._nodeManagementContract.isNodeManager(msg.sender, nodeId)) {
      revert X2EarnNonNodeHolder();
    }

    // Remove nodes delegation
    return _removeNodeEndorsement(appId, nodeId);
  }

  /**
   * @notice this function returns the app that a node ID is endorsing
   * @param nodeId The unique identifier of the node ID.
   * @return bytes32 The unique identifier of the app that the node ID is endorsing.
   */
  function nodeToEndorsedApp(uint256 nodeId) external view returns (bytes32) {
    EndorsementStorage storage $ = _getEndorsementStorage();
    return $._nodeToEndorsedApp[nodeId];
  }

  /**
   * @notice this function returns the endorsement score of a node ID
   * @param nodeLevel The node level of the node ID.
   * @return uint256 The endorsement score of the node ID.
   */
  function nodeLevelEndorsementScore(
    VechainNodesDataTypes.NodeStrengthLevel nodeLevel
  ) external view returns (uint256) {
    EndorsementStorage storage $ = _getEndorsementStorage();
    return $._nodeEnodorsmentScore[nodeLevel];
  }

  // ---------- Internal ---------- //
  /**
   * @dev Internal function to get the score of an app and optionally remove an endorser's endorsement.
   * @param appId The unique identifier of the app.
   * @param endorserToRemove The node ID of the endorser to remove.
   * @return uint256 The score of the app.
   */
  function _getScoreAndRemoveEndorsement(bytes32 appId, uint256 endorserToRemove) internal returns (uint256) {
    // Retrieve the endorsement storage
    EndorsementStorage storage $ = _getEndorsementStorage();
    return
      EndorsementUtils.getScoreAndRemoveEndorsement(
        $._nodeEnodorsmentScore,
        $._nodeToEndorsedApp,
        $._appEndorsers,
        $._appScores,
        $._nodeManagementContract,
        appId,
        endorserToRemove
      );
  }

  /**
   * @dev Internal function to update the endorsement scores of each node level.
   * @param nodeStrengthScores The node level scores to update.
   */
  function _updateNodeEndorsementScores(VechainNodesDataTypes.NodeStrengthScores calldata nodeStrengthScores) internal {
    EndorsementStorage storage $ = _getEndorsementStorage();
    EndorsementUtils.updateNodeEndorsementScores($._nodeEnodorsmentScore, nodeStrengthScores);
  }

  /**
   * @dev Update the endorsement status of an app.
   * @param appId The unique identifier of the app.
   * @param endorsed The endorsement status to set.
   *
   * Emits a {AppEndorsementStatusUpdated} event.
   */
  function _setEndorsementStatus(bytes32 appId, bool endorsed) internal override {
    _updateAppsPendingEndorsement(appId, endorsed);
    emit AppEndorsementStatusUpdated(appId, endorsed);
  }

  /**
   * @dev Internal function to update the apps pending endorsement list.
   * @param appId The unique identifier of the app.
   * @param remove True if the app should be removed from the list.
   */
  function _updateAppsPendingEndorsement(bytes32 appId, bool remove) internal {
    EndorsementStorage storage $ = _getEndorsementStorage();
    EndorsementUtils.updateAppsPendingEndorsement($._unendorsedApps, $._unendorsedAppsIndex, appId, remove);
  }

  /**
   * @dev Internal function to update the grace period.
   *
   * @param gracePeriodDuration The new grace period.
   *
   * Emits a {GracePeriodUpdated} event.
   */
  function _setGracePeriod(uint48 gracePeriodDuration) internal {
    EndorsementStorage storage $ = _getEndorsementStorage();

    emit GracePeriodUpdated($._gracePeriodDuration, gracePeriodDuration);

    $._gracePeriodDuration = gracePeriodDuration;
  }

  /**
   * @dev Internal function to update the score threshold.
   *
   * @param scoreThreshold The new score threshold.
   *
   * Emits a {EndorsementScoreThresholdUpdated} event
   */
  function _updateEndorsementScoreThreshold(uint256 scoreThreshold) internal {
    EndorsementStorage storage $ = _getEndorsementStorage();

    emit EndorsementScoreThresholdUpdated($._endorsementScoreThreshold, scoreThreshold);

    $._endorsementScoreThreshold = scoreThreshold;
  }

  /**
   * @dev Internal function to get the score threshold.
   * @return uint256 The score threshold.
   */
  function _endorsementScoreThreshold() internal view returns (uint256) {
    EndorsementStorage storage $ = _getEndorsementStorage();

    return $._endorsementScoreThreshold;
  }

  /**
   * @dev Internal function to remove a nodes endorsement of an XAPP
   * @notice This function can be called by an XAPP admin that wishes to remove an endorserment from a specific node ID
   * @param appId The unique identifier of the app that wishes to be unendorsed.
   * @param nodeId The unique identifier of the node they wish to remove from their list of endorsers.
   */
  function _removeNodeEndorsement(bytes32 appId, uint256 nodeId) internal {
    EndorsementStorage storage $ = _getEndorsementStorage();

    // Check if the app exists
    if (!_appSubmitted(appId)) {
      revert X2EarnNonexistentApp(appId);
    }

    // Check if the node ID is the apps endorser
    if ($._nodeToEndorsedApp[nodeId] != appId) {
      revert X2EarnNonEndorser();
    }

    // Calculate the new score of the app after removing the node ID's endorsement
    uint256 score = _getScoreAndRemoveEndorsement(appId, nodeId);

    // Check if the app is no longer in the voting allocation rounds due to lack of endorsement or from being blacklisted
    if (!isEligibleNow(appId) || isBlacklisted(appId)) {
      return;
    }

    // Check if the score is less than endorsement score threshold (100)
    if (score < _endorsementScoreThreshold()) {
      _updateStatusIfThresholdNotMet(appId);
    }

    return;
  }

  /**
   * @notice This fucntion can be called by an XAPP admin or contract admin that wishes to remove an XAPP submission
   * @param appId The unique identifier of the app that wishes to be removed.
   */
  function _removeXAppSubmission(bytes32 appId) internal virtual {
    // Check if the app has been submitted
    if (!_appSubmitted(appId)) {
      revert X2EarnNonexistentApp(appId);
    }

    // Check if the app is already included in the list of apps
    if (appExists(appId)) {
      revert NodeManagementXAppAlreadyIncluded(appId);
    }

    _updateAppsPendingEndorsement(appId, true);
  }

  /**
   * @notice This function can be called to update the node management contract
   */
  function _setNodeManagementContract(address nodeManagementContract) internal virtual {
    EndorsementStorage storage $ = _getEndorsementStorage();
    $._nodeManagementContract = INodeManagement(nodeManagementContract);
  }

  /**
   * @notice This function can be called to update the VeBetterPassport contract
   */
  function _setVeBetterPassportContract(address veBetterPassportContract) internal virtual {
    EndorsementStorage storage $ = _getEndorsementStorage();
    $._veBetterPassport = IVeBetterPassport(veBetterPassportContract);
  }

  // ---------- Private ---------- //

  /**
   * @dev Internal function to update the status of an app if the score threshold is met.
   * @param appId The unique identifier of the app.
   */
  function _updateStatusIfThresholdMet(bytes32 appId) private {
    // Get the endorsement storage
    EndorsementStorage storage $ = _getEndorsementStorage();

    if (!appExists(appId)) {
      // Add the app to the list of apps it will be eligible for voting by default from the next round
      _addApp(appId);
      // Set the XAPP security score to LOW in VeBetterPassport
      $._veBetterPassport.setAppSecurity(appId, PassportTypes.APP_SECURITY.LOW);
    } else if (!isEligibleNow(appId)) {
      // Mark the app as eligible for voting
      _setVotingEligibility(appId, true);
      // Set the XAPP security score in VeBetterPassport the same as it was when it was unendorsed
      $._veBetterPassport.setAppSecurity(appId, $._appSecurity[appId]);
    }

    // If the app is pending endorsement
    if (isAppUnendorsed(appId)) {
      // Mark the app as endorsed so that it is removed from the list of apps pending endorsement
      _setEndorsementStatus(appId, true);
    }

    // Reset the grace period if the app has more than 100 points
    $._appGracePeriodStart[appId] = 0;
  }

  /**
   * @dev Internal function to update the status of an app if the score threshold is not met.
   * @param appId The unique identifier of the app.
   * @return stillEligble True if the app is still eligible for voting.
   */
  function _updateStatusIfThresholdNotMet(bytes32 appId) private returns (bool) {
    // Get the endorsement storage
    EndorsementStorage storage $ = _getEndorsementStorage();

    // Use the EndorsementUtils library to update the status of the app
    bool stillEligible = EndorsementUtils.updateStatusIfThresholdNotMet(
      $._appGracePeriodStart,
      $._appSecurity,
      $._unendorsedApps,
      $._unendorsedAppsIndex,
      $._veBetterPassport,
      $._gracePeriodDuration,
      isAppUnendorsed(appId),
      clock(),
      appId,
      isEligibleNow(appId)
    );

    // If the app is no longer eligible for voting, remove it from the list of apps
    if (!stillEligible) {
      _setVotingEligibility(appId, false);
    }

    return stillEligible;
  }

  // ---------- Getters ---------- //

  /**
   * @dev See {IX2EarnApps-gracePeriod}.
   * @return The current grace period duration in blocks.
   */
  function gracePeriod() external view returns (uint256) {
    EndorsementStorage storage $ = _getEndorsementStorage();

    return $._gracePeriodDuration;
  }

  /**
   * @dev See {IX2EarnApps-isAppUnendorsed}.
   * @param appId The unique identifier of the app.
   * @return True if the app is pending endorsement.
   */
  function isAppUnendorsed(bytes32 appId) public view override returns (bool) {
    EndorsementStorage storage $ = _getEndorsementStorage();

    // If the app is blacklisted, it cannot be pending endorsement
    if (isBlacklisted(appId)) {
      return false;
    }

    // Check if the app is in the list of apps pending endorsement
    return $._unendorsedAppsIndex[appId] > 0;
  }

  /**
   * @dev See {IX2EarnApps-unendorsedAppIds}.
   */
  function unendorsedAppIds() public view returns (bytes32[] memory) {
    EndorsementStorage storage $ = _getEndorsementStorage();

    return $._unendorsedApps;
  }

  /**
   * @dev See {IX2EarnApps-unendorsedApps}.
   */
  function unendorsedApps() external view returns (X2EarnAppsDataTypes.AppWithDetailsReturnType[] memory) {
    bytes32[] memory appIds = unendorsedAppIds();
    return _getAppsInfo(appIds);
  }

  /**
   * @dev See {IX2EarnApps-getScore}.
   */
  function getScore(bytes32 appId) external view returns (uint256) {
    EndorsementStorage storage $ = _getEndorsementStorage();
    return $._appScores[appId];
  }

  /**
   * @dev See {IX2EarnApps-getEndorsers}.
   */
  function getEndorsers(bytes32 appId) external view returns (address[] memory) {
    EndorsementStorage storage $ = _getEndorsementStorage();
    return EndorsementUtils.getEndorsers($._appEndorsers, $._nodeManagementContract, appId);
  }

  /**
   * @dev See {IX2EarnApps-getUsersEndorsementScore}.
   */
  function getUsersEndorsementScore(address user) external view returns (uint256) {
    EndorsementStorage storage $ = _getEndorsementStorage();
    return EndorsementUtils.getUsersEndorsementScore($._nodeEnodorsmentScore, $._nodeManagementContract, user);
  }

  /**
   * @dev See {IX2EarnApps-getNodeEndorsementScore}.
   */
  function getNodeEndorsementScore(uint256 nodeId) external view returns (uint256) {
    EndorsementStorage storage $ = _getEndorsementStorage();

    VechainNodesDataTypes.NodeStrengthLevel nodeLevel = $._nodeManagementContract.getNodeLevel(nodeId);
    return $._nodeEnodorsmentScore[nodeLevel];
  }

  function getNodeManagementContract() external view returns (INodeManagement) {
    EndorsementStorage storage $ = _getEndorsementStorage();
    return $._nodeManagementContract;
  }

  function getVeBetterPassportContract() external view returns (IVeBetterPassport) {
    EndorsementStorage storage $ = _getEndorsementStorage();
    return $._veBetterPassport;
  }
}
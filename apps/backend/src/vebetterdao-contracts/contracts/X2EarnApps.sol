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

import { X2EarnAppsUpgradeable } from "./x-2-earn-apps/X2EarnAppsUpgradeable.sol";
import { AdministrationUpgradeable } from "./x-2-earn-apps/modules/AdministrationUpgradeable.sol";
import { AppsStorageUpgradeable } from "./x-2-earn-apps/modules/AppsStorageUpgradeable.sol";
import { ContractSettingsUpgradeable } from "./x-2-earn-apps/modules/ContractSettingsUpgradeable.sol";
import { VoteEligibilityUpgradeable } from "./x-2-earn-apps/modules//VoteEligibilityUpgradeable.sol";
import { EndorsementUpgradeable } from "./x-2-earn-apps/modules/EndorsementUpgradeable.sol";
import { VechainNodesDataTypes } from "./libraries/VechainNodesDataTypes.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

/**
 * @title X2EarnApps
 * @notice This contract handles the x-2-earn applications of the VeBetterDAO ecosystem. The contract allows the insert, management and
 * eligibility of apps for the B3TR allocation rounds.
 * @dev The contract is using AccessControl to handle the admin and upgrader roles.
 * Only users with the DEFAULT_ADMIN_ROLE can add new apps, set the base URI and set the voting eligibility for an app.
 * Admins can also control the app metadata and management.
 * Each app has a set of admins and moderators that can manage the app and settings.
 */
contract X2EarnApps is
  X2EarnAppsUpgradeable,
  AdministrationUpgradeable,
  ContractSettingsUpgradeable,
  VoteEligibilityUpgradeable,
  AppsStorageUpgradeable,
  EndorsementUpgradeable,
  AccessControlUpgradeable,
  UUPSUpgradeable
{
  /// @notice The role that can upgrade the contract.
  bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
  /// @notice The role that can manage the contract settings.
  bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  /**
   * @notice Initialize the version 2 contract
   * @param _gracePeriod the grace period to be reendorsed
   * @param _nodeManagementContract the address of the vechain node management contract
   * @param _veBetterPassportContract the address of the VeBetterPassport contract
   *
   * @dev This function is called only once during the contract deployment
   */
  function initializeV2(
    uint48 _gracePeriod,
    address _nodeManagementContract,
    address _veBetterPassportContract,
    address _x2EarnCreatorContract
  ) public reinitializer(2) {
    require(_nodeManagementContract != address(0), "X2EarnApps: Invalid Node Managementcontract address");
    require(_veBetterPassportContract != address(0), "X2EarnApps: Invalid VeBetterPassport contract address");
    require(_x2EarnCreatorContract != address(0), "X2EarnApps: Invalid X2EarnCreator contract address");
    __Endorsement_init(_gracePeriod, _nodeManagementContract, _veBetterPassportContract);
    __Administration_init_v2(_x2EarnCreatorContract);
  }

  // ---------- Modifiers ------------ //

  /**
   * @dev Modifier to restrict access to only the admin role and the app admin role.
   * @param appId the app ID
   */
  modifier onlyRoleAndAppAdmin(bytes32 role, bytes32 appId) {
    if (!hasRole(role, msg.sender) && !isAppAdmin(appId, msg.sender)) {
      revert X2EarnUnauthorizedUser(msg.sender);
    }
    _;
  }

  /**
   * @dev Modifier to restrict access to only the admin role, the app admin role and the app moderator role.
   * @param appId the app ID
   */
  modifier onlyRoleAndAppAdminOrModerator(bytes32 role, bytes32 appId) {
    if (!hasRole(role, msg.sender) && !isAppAdmin(appId, msg.sender) && !isAppModerator(appId, msg.sender)) {
      revert X2EarnUnauthorizedUser(msg.sender);
    }
    _;
  }

  // ---------- Authorizations ------------ //

  /**
   * @dev See {UUPSUpgradeable-_authorizeUpgrade}
   */
  function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

  // ---------- Getters ------------ //

  /**
   * @notice Returns the version of the contract
   * @dev This should be updated every time a new version of implementation is deployed
   * @return sting The version of the contract
   */
  function version() public pure virtual returns (string memory) {
    return "2";
  }

  // ---------- Overrides ------------ //

  /**
   * @dev Update the base URI to retrieve the metadata of the x2earn apps
   *
   * @param _baseURI the base URI for the contract
   *
   * Emits a {BaseURIUpdated} event.
   */
  function setBaseURI(string memory _baseURI) public onlyRole(DEFAULT_ADMIN_ROLE) {
    _setBaseURI(_baseURI);
  }

  /**
   * @dev See {IX2EarnApps-setVotingEligibility}.
   */
  function setVotingEligibility(bytes32 _appId, bool _isEligible) public virtual onlyRole(GOVERNANCE_ROLE) {
    if (!_appSubmitted(_appId)) {
      revert X2EarnNonexistentApp(_appId);
    }

    if (appExists(_appId)) {
      _setVotingEligibility(_appId, _isEligible);
    }

    // If the app is pending endorsement and the app is getting blacklisted remove it from the pending endorsement list
    if (isAppUnendorsed(_appId) && !_isEligible) {
      _updateAppsPendingEndorsement(_appId, true);
    }

    // Validate the app creators if the app is eligible and if not revoke the creators and burn their creator tokens
    _isEligible ? _validateAppCreators(_appId) : _revokeAppCreators(_appId);

    // Set the app in the blacklist if not eligible and called by governance
    _setBlacklist(_appId, !_isEligible);
  }

  /**
   * @dev See {IX2EarnApps-submitApp}.
   */
  function submitApp(
    address _teamWalletAddress,
    address _admin,
    string memory _appName,
    string memory _appMetadataURI
  ) public virtual {
    _registerApp(_teamWalletAddress, _admin, _appName, _appMetadataURI);
  }

  /**
   * @dev See {IX2EarnApps-setAppAdmin}.
   */
  function setAppAdmin(bytes32 _appId, address _newAdmin) public onlyRoleAndAppAdmin(DEFAULT_ADMIN_ROLE, _appId) {
    _setAppAdmin(_appId, _newAdmin);
  }

  /**
   * @dev See {IX2EarnApps-updateTeamWalletAddress}.
   */
  function updateTeamWalletAddress(
    bytes32 _appId,
    address _newReceiverAddress
  ) public onlyRoleAndAppAdmin(DEFAULT_ADMIN_ROLE, _appId) {
    _updateTeamWalletAddress(_appId, _newReceiverAddress);
  }

  /**
   * @dev See {IX2EarnApps-setTeamAllocationPercentage}.
   */
  function setTeamAllocationPercentage(
    bytes32 _appId,
    uint256 _percentage
  ) public onlyRoleAndAppAdmin(DEFAULT_ADMIN_ROLE, _appId) {
    _setTeamAllocationPercentage(_appId, _percentage);
  }

  /**
   * @dev See {IX2EarnApps-addAppModerator}.
   */
  function addAppModerator(bytes32 _appId, address _moderator) public onlyRoleAndAppAdmin(DEFAULT_ADMIN_ROLE, _appId) {
    _addAppModerator(_appId, _moderator);
  }

  /**
   * @dev See {IX2EarnApps-removeAppModerator}.
   */
  function removeAppModerator(
    bytes32 _appId,
    address _moderator
  ) public onlyRoleAndAppAdmin(DEFAULT_ADMIN_ROLE, _appId) {
    _removeAppModerator(_appId, _moderator);
  }

  /**
   * @dev See {IX2EarnApps-removeAppCreator}.
   */
  function removeAppCreator(bytes32 _appId, address _creator) public onlyRoleAndAppAdmin(DEFAULT_ADMIN_ROLE, _appId) {
    _removeAppCreator(_appId, _creator);
  }

  /**
   * @dev See {IX2EarnApps-addRewardDistributor}.
   */
  function addRewardDistributor(
    bytes32 _appId,
    address _distributor
  ) public onlyRoleAndAppAdmin(DEFAULT_ADMIN_ROLE, _appId) {
    _addRewardDistributor(_appId, _distributor);
  }

  /**
   * @dev See {IX2EarnApps-addCreator}.
   */
  function addCreator(bytes32 _appId, address _creator) public onlyRoleAndAppAdmin(DEFAULT_ADMIN_ROLE, _appId) {
    _addCreator(_appId, _creator);
  }

  /**
   * @dev See {IX2EarnApps-removeRewardDistributor}.
   */
  function removeRewardDistributor(
    bytes32 _appId,
    address _distributor
  ) public onlyRoleAndAppAdmin(DEFAULT_ADMIN_ROLE, _appId) {
    _removeRewardDistributor(_appId, _distributor);
  }

  /**
   * @dev See {IX2EarnApps-updateAppMetadata}.
   */
  function updateAppMetadata(
    bytes32 _appId,
    string memory _newMetadataURI
  ) public onlyRoleAndAppAdminOrModerator(DEFAULT_ADMIN_ROLE, _appId) {
    _updateAppMetadata(_appId, _newMetadataURI);
  }

  /**
   * @dev See {IX2EarnApps-updateGracePeriod}.
   */
  function updateGracePeriod(uint48 _newGracePeriod) public virtual onlyRole(GOVERNANCE_ROLE) {
    _setGracePeriod(_newGracePeriod);
  }

  /**
   * @dev See {IX2EarnApps-updateNodeEndorsementScores}.
   */
  function updateNodeEndorsementScores(
    VechainNodesDataTypes.NodeStrengthScores calldata _nodeStrengthScores
  ) external onlyRole(GOVERNANCE_ROLE) {
    _updateNodeEndorsementScores(_nodeStrengthScores);
  }

  /**
   * @dev See {IX2EarnApps-updateEndorsementScoreThreshold}.
   */
  function updateEndorsementScoreThreshold(uint256 _scoreThreshold) external onlyRole(GOVERNANCE_ROLE) {
    _updateEndorsementScoreThreshold(_scoreThreshold);
  }

  /**
   * @dev See {IX2EarnApps-endorsementScoreThreshold}.
   */
  function endorsementScoreThreshold() external view returns (uint256) {
    return _endorsementScoreThreshold();
  }

  /**
   * @dev See {IX2EarnApps-removeNodeEndorsement}.
   */
  function removeNodeEndorsement(
    bytes32 _appId,
    uint256 _nodeId
  ) public virtual onlyRoleAndAppAdmin(DEFAULT_ADMIN_ROLE, _appId) {
    _removeNodeEndorsement(_appId, _nodeId);
  }

  /**
   * @dev See {IX2EarnApps-removeXAppSubmission}.
   */
  function removeXAppSubmission(bytes32 _appId) public virtual onlyRoleAndAppAdmin(DEFAULT_ADMIN_ROLE, _appId) {
    _removeXAppSubmission(_appId);
  }

  /**
   * @dev See {IX2EarnApps-setNodeManagementContract}.
   */
  function setNodeManagementContract(address _nodeManagementContract) public virtual onlyRole(DEFAULT_ADMIN_ROLE) {
    _setNodeManagementContract(_nodeManagementContract);
  }

  /**
   * @dev See {IX2EarnApps-setVeBetterPassportContract}.
   */
  function setVeBetterPassportContract(address _veBetterPassportContract) public virtual onlyRole(DEFAULT_ADMIN_ROLE) {
    _setVeBetterPassportContract(_veBetterPassportContract);
  }

  /**
   * @dev See {IX2EarnApps-setX2EarnCreatorContract}.
   */
  function setX2EarnCreatorContract(address _x2EarnCreatorContract) public onlyRole(DEFAULT_ADMIN_ROLE) {
    _setX2EarnCreatorContract(_x2EarnCreatorContract);
  }
}

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

import { X2EarnAppsUpgradeableV1 } from "./x-2-earn-apps/X2EarnAppsUpgradeableV1.sol";
import { AdministrationUpgradeable } from "./x-2-earn-apps/modules/AdministrationUpgradeable.sol";
import { AppsStorageUpgradeable } from "./x-2-earn-apps/modules/AppsStorageUpgradeable.sol";
import { ContractSettingsUpgradeable } from "./x-2-earn-apps/modules/ContractSettingsUpgradeable.sol";
import { VoteEligibilityUpgradeable } from "./x-2-earn-apps/modules/VoteEligibilityUpgradeable.sol";
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
contract X2EarnAppsV1 is
  X2EarnAppsUpgradeableV1,
  AdministrationUpgradeable,
  ContractSettingsUpgradeable,
  VoteEligibilityUpgradeable,
  AppsStorageUpgradeable,
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
   * @notice Initialize the contract
   * @param _baseURI the base URI for the contract
   * @param _admins the addresses of the admins
   * @param _upgrader the address of the upgrader
   * @param _governor the address that will be granted the governance role
   *
   * @dev This function is called only once during the contract deployment
   */
  function initialize(
    string memory _baseURI,
    address[] memory _admins,
    address _upgrader,
    address _governor
  ) external initializer {
    __X2EarnApps_init();
    __Administration_init();
    __AppsStorage_init();
    __ContractSettings_init(_baseURI);
    __VoteEligibility_init();
    __UUPSUpgradeable_init();
    __AccessControl_init();

    for (uint256 i; i < _admins.length; i++) {
      require(_admins[i] != address(0), "X2EarnApps: admin address cannot be zero");
      _grantRole(DEFAULT_ADMIN_ROLE, _admins[i]);
    }

    _grantRole(UPGRADER_ROLE, _upgrader);
    _grantRole(GOVERNANCE_ROLE, _governor);
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
    return "1";
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
  function setVotingEligibility(bytes32 _appId, bool _isEligible) public onlyRole(GOVERNANCE_ROLE) {
    _setVotingEligibility(_appId, _isEligible);
  }

  /**
   * @dev See {IX2EarnApps-addApp}.
   */
  function addApp(
    address _teamWalletAddress,
    address _admin,
    string memory _appName,
    string memory _appMetadataURI
  ) public onlyRole(GOVERNANCE_ROLE) {
    _addApp(_teamWalletAddress, _admin, _appName, _appMetadataURI);
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
   * @dev See {IX2EarnApps-addRewardDistributor}.
   */
  function addRewardDistributor(
    bytes32 _appId,
    address _distributor
  ) public onlyRoleAndAppAdmin(DEFAULT_ADMIN_ROLE, _appId) {
    _addRewardDistributor(_appId, _distributor);
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
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {IX2EarnAppsMock} from "./interfaces/IX2EarnAppsMock.sol";
import {X2EarnAppsDataTypes} from "./interfaces/X2EarnAppsDataTypes.sol";

/**
 * @title X2EarnApps
 *
 * @notice DEV MOCKED VERSION of the VeBetterDAO's X2EarnApps contract.
 * @dev This contract can be used to add an app, set the admin of the app, add reward distributors to the app, and remove reward distributors from the app.
 * It has a function to check the existence of an app, check if an account is the admin of the app, and check if an account is a reward distributor of the app.
 * This is the minimum required functionality for the VeBetterDAO's X2EarnRewardsPool contract to function.
 *
 */
contract X2EarnAppsMock is IX2EarnAppsMock {
    uint256 public constant MAX_MODERATORS = 100;
    uint256 public constant MAX_REWARD_DISTRIBUTORS = 100;

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

    function _getAppsStorageStorage()
        internal
        pure
        returns (AppsStorageStorage storage $)
    {
        assembly {
            $.slot := AppsStorageStorageLocation
        }
    }

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

    function _getAdministrationStorage()
        internal
        pure
        returns (AdministrationStorage storage $)
    {
        assembly {
            $.slot := AdministrationStorageLocation
        }
    }

    constructor() {}

    // ---------- Modifiers ------------ //

    /**
     * @dev Throws if called by any account that is not an app admin.
     * @param appId the app ID
     */
    modifier onlyAppAdmin(bytes32 appId) {
        if (!isAppAdmin(appId, msg.sender)) {
            revert X2EarnUnauthorizedUser(msg.sender);
        }
        _;
    }

    // ---------- Getters ------------ //
    /**
     * @dev See {IX2EarnApps-hashAppName}.
     */
    function hashAppName(string memory appName) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(appName));
    }

    /**
     * @dev See {IX2EarnApps-appExists}.
     */
    function appExists(bytes32 appId) public view returns (bool) {
        AppsStorageStorage storage $ = _getAppsStorageStorage();

        return $._apps[appId].createdAtTimestamp != 0;
    }

    /**
     * @dev Check if an account is the admin of the app
     *
     * @param appId the hashed name of the app
     * @param account the address of the account
     */
    function isAppAdmin(
        bytes32 appId,
        address account
    ) public view returns (bool) {
        AdministrationStorage storage $ = _getAdministrationStorage();

        return $._admin[appId] == account;
    }

    /**
     * @dev Returns true if an account is a reward distributor of the app
     *
     * @param appId the hashed name of the app
     * @param account the address of the account
     */
    function isRewardDistributor(
        bytes32 appId,
        address account
    ) public view returns (bool) {
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
     * @dev Get the address where the x2earn app receives allocation funds
     *
     * @param appId the hashed name of the app
     */
    function teamWalletAddress(
        bytes32 appId
    ) public view override returns (address) {
        AdministrationStorage storage $ = _getAdministrationStorage();

        return $._teamWalletAddress[appId];
    }

    // ---------- Overrides ------------ //

    /**
     * @dev See {IX2EarnApps-addApp}.
     *
     * DEV-TESTNET: Everyone can add an app for testing purposes.
     */
    function addApp(
        address _teamWalletAddress,
        address _admin,
        string memory _appName
    ) public {
        _addApp(_teamWalletAddress, _admin, _appName);
    }

    /**
     * @dev See {IX2EarnApps-setAppAdmin}.
     */
    function setAppAdmin(
        bytes32 _appId,
        address _newAdmin
    ) public onlyAppAdmin(_appId) {
        _setAppAdmin(_appId, _newAdmin);
    }

    /**
     * @dev See {IX2EarnApps-addRewardDistributor}.
     */
    function addRewardDistributor(
        bytes32 _appId,
        address _distributor
    ) public onlyAppAdmin(_appId) {
        _addRewardDistributor(_appId, _distributor);
    }

    /**
     * @dev See {IX2EarnApps-removeRewardDistributor}.
     */
    function removeRewardDistributor(
        bytes32 _appId,
        address _distributor
    ) public onlyAppAdmin(_appId) {
        _removeRewardDistributor(_appId, _distributor);
    }

    /**
     * @dev Create app.
     * The id of the app is the hash of the app name.
     * Will be eligible for voting by default from the next round and
     * the team allocation percentage will be 0%.
     *
     * @param _teamWalletAddress the address where the app should receive allocation funds
     * @param _admin the address of the admin
     * @param _appName the name of the app
     *
     * Emits a {AppAdded} event.
     */
    function _addApp(
        address _teamWalletAddress,
        address _admin,
        string memory _appName
    ) internal {
        if (_teamWalletAddress == address(0)) {
            revert X2EarnInvalidAddress(_teamWalletAddress);
        }
        if (_admin == address(0)) {
            revert X2EarnInvalidAddress(_admin);
        }

        AppsStorageStorage storage $ = _getAppsStorageStorage();
        bytes32 id = hashAppName(_appName);

        if (appExists(id)) {
            revert X2EarnAppAlreadyExists(id);
        }

        // Store the new app
        $._apps[id] = X2EarnAppsDataTypes.App(id, _appName, block.timestamp);
        $._appIds.push(id);
        _setAppAdmin(id, _admin);
        _updateTeamWalletAddress(id, _teamWalletAddress);

        emit AppAdded(id, _teamWalletAddress, _appName, true);
    }

    /**
     * @dev Get the app data saved in storage
     *
     * @param appId the if of the app
     */
    function _getAppStorage(
        bytes32 appId
    ) internal view returns (X2EarnAppsDataTypes.App memory) {
        if (!appExists(appId)) {
            revert X2EarnNonexistentApp(appId);
        }

        AppsStorageStorage storage $ = _getAppsStorageStorage();
        return $._apps[appId];
    }

    /**
     * @dev Internal function to set the admin address of the app
     *
     * @param appId the hashed name of the app
     * @param newAdmin the address of the new admin
     */
    function _setAppAdmin(bytes32 appId, address newAdmin) internal {
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
     * @dev Internal function to add a reward distributor to the app
     *
     * @param appId the hashed name of the app
     * @param distributor the address of the reward distributor
     */
    function _addRewardDistributor(
        bytes32 appId,
        address distributor
    ) internal {
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
    function _removeRewardDistributor(
        bytes32 appId,
        address distributor
    ) internal {
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
    function _updateTeamWalletAddress(
        bytes32 appId,
        address newTeamWalletAddress
    ) internal {
        if (newTeamWalletAddress == address(0)) {
            revert X2EarnInvalidAddress(newTeamWalletAddress);
        }

        if (!appExists(appId)) {
            revert X2EarnNonexistentApp(appId);
        }

        AdministrationStorage storage $ = _getAdministrationStorage();
        address oldTeamWalletAddress = $._teamWalletAddress[appId];
        $._teamWalletAddress[appId] = newTeamWalletAddress;

        emit TeamWalletAddressUpdated(
            appId,
            oldTeamWalletAddress,
            newTeamWalletAddress
        );
    }
}

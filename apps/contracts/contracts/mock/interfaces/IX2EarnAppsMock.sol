// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {X2EarnAppsDataTypes} from "./X2EarnAppsDataTypes.sol";

/**
 * Mocked interface updated with only a subset of the functions that should mimic some
 * functionality of the VeBetterDAO X2EarnApps contract.
 *
 * @title IX2EarnApps
 * @notice Interface for the X2EarnApps contract.
 */
interface IX2EarnAppsMock {
    /**
     * @dev The `appId` doesn't exist.
     */
    error X2EarnNonexistentApp(bytes32 appId);

    /**
     * @dev The `addr` is not valid (eg: is the ZERO ADDRESS).
     */
    error X2EarnInvalidAddress(address addr);

    /**
     * @dev An app with the specified `appId` already exists.
     */
    error X2EarnAppAlreadyExists(bytes32 appId);

    /**
     * @dev The user is not authorized to perform the action.
     */
    error X2EarnUnauthorizedUser(address user);

    /**
     * @dev The maximum number of reward distributors has been reached.
     */
    error X2EarnMaxRewardDistributorsReached(bytes32 appId);

    /**
     * @dev The `distributorAddress` is not valid.
     */
    error X2EarnNonexistentRewardDistributor(
        bytes32 appId,
        address distributorAddress
    );

    /**
     * @dev Event fired when a new app is added.
     */
    event AppAdded(
        bytes32 indexed id,
        address addr,
        string name,
        bool appAvailableForAllocationVoting
    );

    /**
     * @dev Event fired when the admin adds a new reward distributor to the app.
     */
    event RewardDistributorAddedToApp(
        bytes32 indexed appId,
        address distributorAddress
    );

    /**
     * @dev Event fired when the admin removes a reward distributor from the app.
     */
    event RewardDistributorRemovedFromApp(
        bytes32 indexed appId,
        address distributorAddress
    );

    /**
     * @dev Event fired when the admin of an app changes.
     */
    event AppAdminUpdated(
        bytes32 indexed appId,
        address oldAdmin,
        address newAdmin
    );

    /**
     * @dev Event fired when the address where the x2earn app receives allocation funds is changed.
     */
    event TeamWalletAddressUpdated(
        bytes32 indexed appId,
        address oldTeamWalletAddress,
        address newTeamWalletAddress
    );

    /**
     * @dev Get the address where the x2earn app receives allocation funds.
     *
     * @param appId the id of the app
     */
    function teamWalletAddress(bytes32 appId) external view returns (address);

    /**
     * @dev Add a new app to the x2earn apps.
     *
     * @param teamWalletAddress the address where the app should receive allocation funds
     * @param admin the address of the admin that will be able to manage the app and perform all administration actions
     * @param appName the name of the app
     *
     * Emits a {AppAdded} event.
     */
    function addApp(
        address teamWalletAddress,
        address admin,
        string memory appName
    ) external;

    /**
     * @dev Check if an account is the admin of the app
     *
     * @param appId the hashed name of the app
     * @param account the address of the account
     */
    function isAppAdmin(
        bytes32 appId,
        address account
    ) external view returns (bool);

    /**
     * @dev Add a new reward distributor to the app.
     *
     * @param appId the id of the app
     * @param distributorAddress the address of the reward distributor
     *
     * Emits a {RewardDistributorAddedToApp} event.
     */
    function addRewardDistributor(
        bytes32 appId,
        address distributorAddress
    ) external;

    /**
     * @dev Remove a reward distributor from the app.
     *
     * @param appId the id of the app
     * @param distributorAddress the address of the reward distributor
     *
     * Emits a {RewardDistributorRemovedFromApp} event.
     */
    function removeRewardDistributor(
        bytes32 appId,
        address distributorAddress
    ) external;

    /**
     * @dev Returns true if an account is a reward distributor of the app
     *
     * @param appId the id of the app
     * @param distributorAddress the address of the account
     */
    function isRewardDistributor(
        bytes32 appId,
        address distributorAddress
    ) external view returns (bool);

    /**
     * @dev Check if there is an app with the specified `appId`.
     *
     * @param appId the id of the app
     */
    function appExists(bytes32 appId) external view returns (bool);
}

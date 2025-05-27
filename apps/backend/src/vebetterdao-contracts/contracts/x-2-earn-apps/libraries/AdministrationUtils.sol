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

import { IX2EarnCreator } from "../../interfaces/IX2EarnCreator.sol";

/**
 * @title AdministrationUtils
 * @dev Utility library for administrative tasks in the X2Earn framework, including setting app administrators,
 *      managing moderators and reward distributors, updating team wallet addresses and allocation percentages,
 *      and handling metadata URIs with proper validation and event emission.
 */
library AdministrationUtils {
  /**
   * @dev Thrown when an invalid allocation percentage is set (greater than 100).
   * @param percentage The invalid allocation percentage.
   */
  error X2EarnInvalidAllocationPercentage(uint256 percentage);

  /**
   * @dev Thrown when an operation is attempted on a non-existent app.
   * @param appId The ID of the non-existent app.
   */
  error X2EarnNonexistentApp(bytes32 appId);

  /**
   * @dev Thrown when an invalid address is provided (e.g., zero address).
   * @param addr The invalid address.
   */
  error X2EarnInvalidAddress(address addr);

  /**
   * @dev Thrown when an attempt is made to remove a non-existent reward distributor.
   * @param appId The ID of the app.
   * @param distributorAddress The address of the non-existent reward distributor.
   */
  error X2EarnNonexistentRewardDistributor(bytes32 appId, address distributorAddress);

  /**
   * @dev Thrown when the maximum number of reward distributors for an app has been reached.
   * @param appId The ID of the app.
   */
  error X2EarnMaxRewardDistributorsReached(bytes32 appId);

  /**
   * @dev Thrown when an attempt is made to add a creator when the maximum number of creators has been reached.
   * @param appId The ID of the app.
   */
  error X2EarnMaxCreatorsReached(bytes32 appId);

  /**
   * @dev Thrown when an attempt is made to add a creator that is already a creator of the app.
   * @param creator The address of the creator.
   */
  error X2EarnAlreadyCreator(address creator);

  /**
   * @dev Thrown when an attempt is made to remove a non-existent creator.
   */
  error X2EarnNonexistentCreator(bytes32 appId, address creator);

  /**
   * @dev Thrown when an attempt is made to remove a non-existent moderator.
   * @param appId The ID of the app.
   * @param moderator The address of the non-existent moderator.
   */
  error X2EarnNonexistentModerator(bytes32 appId, address moderator);

  /**
   * @dev Thrown when the maximum number of moderators for an app has been reached.
   * @param appId The ID of the app.
   */
  error X2EarnMaxModeratorsReached(bytes32 appId);

  /**
   * @dev Emitted when the team allocation percentage is updated.
   * @param appId The ID of the app.
   * @param oldPercentage The previous allocation percentage.
   * @param newPercentage The new allocation percentage.
   */
  event TeamAllocationPercentageUpdated(bytes32 indexed appId, uint256 oldPercentage, uint256 newPercentage);

  /**
   * @dev Emitted when the team wallet address is updated.
   * @param appId The ID of the app.
   * @param oldTeamWalletAddress The previous team wallet address.
   * @param newTeamWalletAddress The new team wallet address.
   */
  event TeamWalletAddressUpdated(bytes32 indexed appId, address oldTeamWalletAddress, address newTeamWalletAddress);

  /**
   * @dev Emitted when the metadata URI of an app is updated.
   * @param appId The ID of the app.
   * @param oldMetadataURI The previous metadata URI.
   * @param newMetadataURI The new metadata URI.
   */
  event AppMetadataURIUpdated(bytes32 indexed appId, string oldMetadataURI, string newMetadataURI);

  /**
   * @dev Emitted when a reward distributor is removed from an app.
   * @param appId The ID of the app.
   * @param distributorAddress The address of the removed reward distributor.
   */
  event RewardDistributorRemovedFromApp(bytes32 indexed appId, address distributorAddress);

  /**
   * @dev Emitted when a reward distributor is added to an app.
   * @param appId The ID of the app.
   * @param distributorAddress The address of the added reward distributor.
   */
  event RewardDistributorAddedToApp(bytes32 indexed appId, address distributorAddress);

  /**
   * @dev Emitted when a moderator is removed from an app.
   * @param appId The ID of the app.
   * @param moderator The address of the removed moderator.
   */
  event ModeratorRemovedFromApp(bytes32 indexed appId, address moderator);

  /**
   * @dev Emitted when a moderator is added to an app.
   * @param appId The ID of the app.
   * @param moderator The address of the added moderator.
   */
  event ModeratorAddedToApp(bytes32 indexed appId, address moderator);

  /**
   * @dev Emitted when the admin of an app is updated.
   * @param appId The ID of the app.
   * @param oldAdmin The previous admin address.
   * @param newAdmin The new admin address.
   */
  event AppAdminUpdated(bytes32 indexed appId, address oldAdmin, address newAdmin);

  /**
   * @dev Event fired when the admin adds a new creator to the app and new creator NFT is minted.
   * @param appId The ID of the app.
   * @param creatorAddress The address of the creator.
   */
  event CreatorAddedToApp(bytes32 indexed appId, address creatorAddress);

  // ------------------------------- Getter Functions -------------------------------
  /**
   * @dev Checks if an account is a reward distributor for an app.
   * @param rewardDistributors Mapping of app IDs to arrays of reward distributor addresses.
   * @param appId The ID of the app.
   * @param account The account address to check.
   * @return True if the account is a reward distributor, false otherwise.
   */
  function isRewardDistributor(
    mapping(bytes32 appId => address[]) storage rewardDistributors,
    bytes32 appId,
    address account
  ) public view returns (bool) {
    return contains(rewardDistributors[appId], account);
  }

  /**
   * @dev Checks if an account is a moderator for an app.
   * @param moderators Mapping of app IDs to arrays of moderator addresses.
   * @param appId The ID of the app.
   * @param account The account address to check.
   * @return True if the account is a moderator, false otherwise.
   */
  function isAppModerator(
    mapping(bytes32 appId => address[]) storage moderators,
    bytes32 appId,
    address account
  ) public view returns (bool) {
    return contains(moderators[appId], account);
  }

  /**
   * @dev Checks if an account is a creator for an app.
   * @param creators Mapping of app IDs to arrays of creator addresses.
   * @param appId The ID of the app.
   * @param account The account address to check.
   * @return True if the account is a creator, false otherwise.
   */
  function isAppCreator(
    mapping(bytes32 appId => address[]) storage creators,
    bytes32 appId,
    address account
  ) public view returns (bool) {
    return contains(creators[appId], account);
  }

  // ------------------------------- Setter Functions -------------------------------
  /**
   * @dev Sets the team allocation percentage for an app.
   * @param teamAllocationPercentage Mapping of app IDs to their respective allocation percentages.
   * @param appId The ID of the app.
   * @param newAllocationPercentage The new allocation percentage.
   * @param appSubmitted Flag indicating if the app has been submitted.
   */
  function setTeamAllocationPercentage(
    mapping(bytes32 appId => uint256) storage teamAllocationPercentage,
    bytes32 appId,
    uint256 newAllocationPercentage,
    bool appSubmitted
  ) external {
    if (!appSubmitted) {
      revert X2EarnNonexistentApp(appId);
    }

    if (newAllocationPercentage > 100) {
      revert X2EarnInvalidAllocationPercentage(newAllocationPercentage);
    }

    uint256 oldAllocationPercentage = teamAllocationPercentage[appId];
    teamAllocationPercentage[appId] = newAllocationPercentage;

    emit TeamAllocationPercentageUpdated(appId, oldAllocationPercentage, newAllocationPercentage);
  }

  /**
   * @dev Updates the metadata URI of an app.
   * @param metadataURI Mapping of app IDs to metadata URIs.
   * @param appId The ID of the app.
   * @param newMetadataURI The new metadata URI.
   * @param appSubmitted Flag indicating if the app has been submitted.
   */
  function updateAppMetadata(
    mapping(bytes32 appId => string) storage metadataURI,
    bytes32 appId,
    string memory newMetadataURI,
    bool appSubmitted
  ) external {
    if (!appSubmitted) {
      revert X2EarnNonexistentApp(appId);
    }

    string memory oldMetadataURI = metadataURI[appId];
    metadataURI[appId] = newMetadataURI;

    emit AppMetadataURIUpdated(appId, oldMetadataURI, newMetadataURI);
  }

  /**
   * @dev Updates the team wallet address for an app.
   * @param teamWalletAddress Mapping of app IDs to team wallet addresses.
   * @param appId The ID of the app.
   * @param newTeamWalletAddress The new team wallet address.
   * @param appSubmitted Flag indicating if the app has been submitted.
   */
  function updateTeamWalletAddress(
    mapping(bytes32 appId => address) storage teamWalletAddress,
    bytes32 appId,
    address newTeamWalletAddress,
    bool appSubmitted
  ) external {
    if (newTeamWalletAddress == address(0)) {
      revert X2EarnInvalidAddress(newTeamWalletAddress);
    }

    if (!appSubmitted) {
      revert X2EarnNonexistentApp(appId);
    }

    address oldTeamWalletAddress = teamWalletAddress[appId];
    teamWalletAddress[appId] = newTeamWalletAddress;

    emit TeamWalletAddressUpdated(appId, oldTeamWalletAddress, newTeamWalletAddress);
  }

  /**
   * @dev Removes a reward distributor from an app.
   * @param rewardDistributors Mapping of app IDs to arrays of reward distributor addresses.
   * @param appId The ID of the app.
   * @param distributor The address of the reward distributor to remove.
   * @param appSubmitted Flag indicating if the app has been submitted.
   */
  function removeRewardDistributor(
    mapping(bytes32 => address[]) storage rewardDistributors,
    bytes32 appId,
    address distributor,
    bool appSubmitted
  ) external {
    if (distributor == address(0)) {
      revert X2EarnInvalidAddress(distributor);
    }

    if (!appSubmitted) {
      revert X2EarnNonexistentApp(appId);
    }

    if (!isRewardDistributor(rewardDistributors, appId, distributor)) {
      revert X2EarnNonexistentRewardDistributor(appId, distributor);
    }

    bool removed = remove(rewardDistributors[appId], distributor);
    if (removed) {
      emit RewardDistributorRemovedFromApp(appId, distributor);
    }
  }

  /**
   * @dev Adds a reward distributor to an app.
   * @param rewardDistributors Mapping of app IDs to arrays of reward distributor addresses.
   * @param appId The ID of the app.
   * @param distributor The address of the reward distributor.
   * @param appSubmitted Flag indicating if the app has been submitted.
   * @param maxRewardDistributors The maximum number of reward distributors allowed.
   */
  function addRewardDistributor(
    mapping(bytes32 appId => address[]) storage rewardDistributors,
    bytes32 appId,
    address distributor,
    bool appSubmitted,
    uint256 maxRewardDistributors
  ) external {
    if (distributor == address(0)) {
      revert X2EarnInvalidAddress(distributor);
    }

    if (!appSubmitted) {
      revert X2EarnNonexistentApp(appId);
    }

    if (rewardDistributors[appId].length >= maxRewardDistributors) {
      revert X2EarnMaxRewardDistributorsReached(appId);
    }

    rewardDistributors[appId].push(distributor);

    emit RewardDistributorAddedToApp(appId, distributor);
  }

  /**
   * @dev Removes a moderator from an app.
   * @param moderators Mapping of app IDs to arrays of moderator addresses.
   * @param appId The ID of the app.
   * @param moderator The address of the moderator to remove.
   * @param appSubmitted Flag indicating if the app has been submitted.
   */
  function removeAppModerator(
    mapping(bytes32 appId => address[]) storage moderators,
    bytes32 appId,
    address moderator,
    bool appSubmitted
  ) external {
    if (moderator == address(0)) {
      revert X2EarnInvalidAddress(moderator);
    }

    if (!appSubmitted) {
      revert X2EarnNonexistentApp(appId);
    }

    if (!isAppModerator(moderators, appId, moderator)) {
      revert X2EarnNonexistentModerator(appId, moderator);
    }

    bool removed = remove(moderators[appId], moderator);
    if (removed) {
      emit ModeratorRemovedFromApp(appId, moderator);
    }
  }

  /**
   * @dev Removes a creator from an app.
   * @param creators Mapping of app IDs to arrays of creator addresses.
   * @param creatorApps Mapping of creator addresses to the number of apps they have created.
   * @param x2EarnCreatorContract The X2EarnCreator contract instance.
   * @param appId The ID of the app.
   * @param creator The address of the creator to remove.
   * @param appSubmitted Flag indicating if the app has been submitted.
   */
  function removeAppCreator(
    mapping(bytes32 appId => address[]) storage creators,
    mapping(address creator => uint256 apps) storage creatorApps,
    IX2EarnCreator x2EarnCreatorContract,
    bytes32 appId,
    address creator,
    bool appSubmitted
  ) external {
    if (creator == address(0)) {
      revert X2EarnInvalidAddress(creator);
    }

    if (!appSubmitted) {
      revert X2EarnNonexistentApp(appId);
    }

    if (!isAppCreator(creators, appId, creator)) {
      revert X2EarnNonexistentCreator(appId, creator);
    }

    // Remove the creator from the app
    remove(creators[appId], creator);

    // Burn the creator NFT if the creator doesn't have any apps
    if (creatorApps[creator] == 1) {
      x2EarnCreatorContract.burn(x2EarnCreatorContract.tokenOfOwnerByIndex(creator, 0));
    }

    // Decrease the number of apps created by the creator
    creatorApps[creator]--;

    emit ModeratorRemovedFromApp(appId, creator);
  }

  /**
   * @dev Adds a moderator to an app.
   * @param moderators Mapping of app IDs to arrays of moderator addresses.
   * @param appId The ID of the app.
   * @param moderator The address of the moderator.
   * @param appSubmitted Flag indicating if the app has been submitted.
   * @param maxModerators The maximum number of moderators allowed.
   */
  function addAppModerator(
    mapping(bytes32 => address[]) storage moderators,
    bytes32 appId,
    address moderator,
    bool appSubmitted,
    uint256 maxModerators
  ) external {
    if (moderator == address(0)) {
      revert X2EarnInvalidAddress(moderator);
    }

    if (!appSubmitted) {
      revert X2EarnNonexistentApp(appId);
    }

    if (moderators[appId].length >= maxModerators) {
      revert X2EarnMaxModeratorsReached(appId);
    }

    moderators[appId].push(moderator);

    emit ModeratorAddedToApp(appId, moderator);
  }

  /**
   * @dev Sets the admin address for an app.
   * @param admin Mapping of app IDs to admin addresses.
   * @param appId The ID of the app.
   * @param newAdmin The new admin address.
   * @param appSubmitted Flag indicating if the app has been submitted.
   */
  function setAppAdmin(
    mapping(bytes32 appId => address) storage admin,
    bytes32 appId,
    address newAdmin,
    bool appSubmitted
  ) external {
    if (!appSubmitted) {
      revert X2EarnNonexistentApp(appId);
    }

    if (newAdmin == address(0)) {
      revert X2EarnInvalidAddress(newAdmin);
    }

    emit AppAdminUpdated(appId, admin[appId], newAdmin);

    admin[appId] = newAdmin;
  }

  /**
   * @dev Internal function to add a creator to the app
   *
   * @param appId the hashed name of the app
   * @param creator the address of the creator
   */
  function addCreator(
    mapping(bytes32 appId => address[]) storage creators,
    mapping(address creator => uint256 apps) storage creatorApps,
    IX2EarnCreator x2EarnCreatorContract,
    bytes32 appId,
    address creator,
    bool appSubmitted,
    uint256 MAX_CREATORS
  ) external {
    if (creator == address(0)) {
      revert X2EarnInvalidAddress(creator);
    }

    if (!appSubmitted) {
      revert X2EarnNonexistentApp(appId);
    }

    // Check if max number of managers has been reached
    if (creators[appId].length >= MAX_CREATORS) {
      revert X2EarnMaxCreatorsReached(appId);
    }

    if (contains(creators[appId], creator)) {
      revert X2EarnAlreadyCreator(creator);
    }

    // Increase the number of apps created by the creator
    creatorApps[creator]++;

    // Add the creator to the app
    creators[appId].push(creator);

    // Mint a creator NFT if the creator doesn't have one
    if (x2EarnCreatorContract.balanceOf(creator) == 0) {
      x2EarnCreatorContract.safeMint(creator);
    }

    emit CreatorAddedToApp(appId, creator);
  }

  /**
   * @dev Internal function to remove all creators from the app
   *
   * @param appId the hashed name of the app
   */
  function revokeAppCreators(
    mapping(bytes32 => address[]) storage creators,
    mapping(address => uint256) storage creatorApps,
    IX2EarnCreator x2EarnCreatorContract,
    bytes32 appId
  ) external {
    for (uint256 i = 0; i < creators[appId].length; i++) {
      address creator = creators[appId][i];

      // Burn the creator NFT if the creator doesn't have any other apps
      if (creatorApps[creator] == 1) {
        x2EarnCreatorContract.burn(x2EarnCreatorContract.tokenOfOwnerByIndex(creator, 0));
      }

      // Decrease the number of apps created by the creator
      creatorApps[creator]--;
    }
  }

  /**
   * @dev Internal function to re-add all creators of an app
   *
   * @param appId the hashed name of the app
   */
  function validateAppCreators(
    mapping(bytes32 => address[]) storage creators,
    mapping(address => uint256) storage creatorApps,
    IX2EarnCreator x2EarnCreatorContract,
    bytes32 appId
  ) external {
    for (uint256 i = 0; i < creators[appId].length; i++) {
      address creator = creators[appId][i];

      // Mint a creator NFT if the creator doesn't have one
      if (creatorApps[creator] == 0) {
        x2EarnCreatorContract.safeMint(creator);
      }

      // Increase the number of apps created by the creator
      creatorApps[creator]++;
    }
  }

  // ------------------------------- Private Functions -------------------------------
  /**
   * @dev Removes an element from an array.‰
   */
  function remove(address[] storage list, address element) private returns (bool) {
    for (uint256 i = 0; i < list.length; i++) {
      if (list[i] == element) {
        list[i] = list[list.length - 1];
        list.pop();
        return true;
      }
    }
    return false;
  }

  /**
   * @dev Checks if an element is in an array.
   */
  function contains(address[] storage list, address element) private view returns (bool) {
    for (uint256 i = 0; i < list.length; i++) {
      if (list[i] == element) return true;
    }
    return false;
  }
}

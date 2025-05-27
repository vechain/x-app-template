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

import { PassportStorageTypesV1 } from "./PassportStorageTypesV1.sol";
import { PassportClockLogicV1 } from "./PassportClockLogicV1.sol";
import { PassportEIP712SigningLogicV1 } from "./PassportEIP712SigningLogicV1.sol";
import { PassportSignalingLogicV1 } from "./PassportSignalingLogicV1.sol";
import { PassportWhitelistAndBlacklistLogicV1 } from "./PassportWhitelistAndBlacklistLogicV1.sol";
import { PassportDelegationLogicV1 } from "./PassportDelegationLogicV1.sol";
import { PassportTypesV1} from "./PassportTypesV1.sol";
import { Checkpoints } from "@openzeppelin/contracts/utils/structs/Checkpoints.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";

/**
 * @title PassportEntityLogic
 * @notice This library manages the core logic for linking and managing entities associated with a passport.
 *
 * @dev The passport serves as the central identity in the system, and entities (such as wallets, accounts, etc.)
 * can be linked to the passport. Each entity linked to the passport contributes to the overall makeup of the passport,
 * including its score, whitelist/blacklist status, VeChain node holder status, and other attributes.
 *
 * Each passport maintains a history of the entities that have been linked to it over time. This library provides
 * functions to link entities to passports, verify the links, and maintain the historical state through checkpoints.
 *
 * The passport is the core identity, and all linked entities are secondary but critical components, each
 * contributing to the overall score and state of the passport.
 *
 * Linking entities to a passport won't move the past entitie's score to the passport, but only the score of the future actions.
 *
 * The linkage process is secured using signatures to ensure that the entities and passports are linked with consent.
 */
library PassportEntityLogicV1{
  // Ethereum addresses are uint160, we can store addresses as uint160 values within the Checkpoints.Trace160
  using Checkpoints for Checkpoints.Trace160;
  // Extends the bytes32 type to support ECDSA signatures
  using ECDSA for bytes32;

  // ---------- Constants ---------- //
  string private constant SIGNING_DOMAIN = "VeBetterPassport";
  string private constant SIGNATURE_VERSION = "1";
  bytes32 private constant LINK_TYPEHASH = keccak256("LinkEntity(address entity,address passport,uint256 deadline)");

  // ---------- Errors ---------- //
  /**
   * @notice Thrown when the user is not authorized to perform the action.
   * @param user The address of the unauthorized user.
   */
  error UnauthorizedUser(address user);

  /**
   * @notice Thrown when an entity is already linked.
   * @param entity The address of the entity that is already linked.
   */
  error AlreadyLinked(address entity);

  /**
   * @notice Thrown when a user attempts to link to themselves, which is not allowed.
   * @param user The address of the user attempting to link to themselves.
   */
  error CannotLinkToSelf(address user);

  /**
   * @notice Thrown when a user tries to perform an action but is not linked.
   * @param user The address of the user that is not linked.
   */
  error NotLinked(address user);

  /**
   * @notice Thrown when only one link is allowed, but the user tries to create more links.
   */
  error OnlyOneLinkAllowed();

  /**
   * @notice Thrown when a signature provided for an action has expired.
   */
  error SignatureExpired();

  /**
   * @notice Thrown when a signature provided for an action is invalid.
   */
  error InvalidSignature();

  /**
   * @notice Thrown when a user tries to link a entity to a passport that has reached the maximum number of entities.
   */
  error MaxEntitiesPerPassportReached();

  /**
   * @notice Thrown when a user tries to link a entity that has delegated to another passport.
   */
  error DelegatedEntity(address entity);

  // ---------- Events ---------- //
  /**
   * @notice Emitted when a link between an entity and a passport is successfully created.
   * @param entity The address of the entity being linked.
   * @param passport The address of the passport that the entity is linked to.
   */
  event LinkCreated(address indexed entity, address indexed passport);

  /**
   * @notice Emitted when a link is initiated but still pending confirmation.
   * @param entity The address of the entity being linked.
   * @param passport The address of the passport awaiting confirmation.
   */
  event LinkPending(address indexed entity, address indexed passport);

  /**
   * @notice Emitted when a link between an entity and a passport is removed.
   * @param entity The address of the entity being unlinked.
   * @param passport The address of the passport being unlinked.
   */
  event LinkRemoved(address indexed entity, address indexed passport);

  // ---------- Getters ---------- //

  /**
   * @notice Returns the passport linked to an entity.
   * @param entity The address of the entity whose linked passport is being retrieved.
   * @return The address of the linked passport.
   */
  function getPassportForEntity(
    PassportStorageTypesV1.PassportStorage storage self,
    address entity
  ) external view returns (address) {
    return _getPassportForEntity(self, entity);
  }

  /**
   * @notice Returns the passport linked to an entity at a specific timepoint.
   * @param entity The address of the entity whose linked passport is being queried.
   * @param timepoint The timepoint to query.
   * @return The address of the passport linked at the specified timepoint.
   */
  function getPassportForEntityAtTimepoint(
    PassportStorageTypesV1.PassportStorage storage self,
    address entity,
    uint256 timepoint
  ) external view returns (address) {
    return _addressFromUint160(self.entityToPassport[entity].upperLookupRecent(SafeCast.toUint48(timepoint)));
  }

  /**
   * @notice Returns the latest entities linked to a passport.
   * @param passport The address of the passport.
   * @return An array of addresses representing the entities currently linked to the passport.
   */
  function getEntitiesLinkedToPassport(
    PassportStorageTypesV1.PassportStorage storage self,
    address passport
  ) internal view returns (address[] memory) {
    return self.passportToEntities[passport];
  }

  /**
   * @notice Returns whether an entity is currently linked to a passport.
   * @param entity The address of the entity being checked.
   * @return True if the entity is linked to a passport, false otherwise.
   */
  function isEntity(PassportStorageTypesV1.PassportStorage storage self, address entity) internal view returns (bool) {
    return self.entityToPassport[entity].latest() != 0;
  }

  /**
   * @notice Checks if an entity was linked to a passport at a specific timepoint.
   * @dev This function allows historical queries to determine if an entity was linked to a passport at a particular time.
   * The function uses a checkpointing mechanism to retrieve the state at the given timepoint.
   * @param self The storage reference for PassportStorage.
   * @param entity The address of the entity.
   * @param timepoint The timepoint (block number) at which to check the linkage.
   * @return True if the entity was linked to the passport at the specified timepoint, false otherwise.
   */
  function isEntityInTimepoint(
    PassportStorageTypesV1.PassportStorage storage self,
    address entity,
    uint256 timepoint
  ) external view returns (bool) {
    return _isEntityInTimepoint(self, entity, timepoint);
  }

  /**
   * @notice Checks if the given address is a passport, i.e., not linked to an entity.
   * @dev A passport is defined as an account that is not an entity for another passport, i.e., it is not linked to any passport.
   * This function checks whether the given address is not an entity by checking it does not exist in the `passportEntitiesIndexes` mapping.
   * @param self The storage reference for PassportStorage.
   * @param passport The address to be checked.
   * @return True if the address is a passport, false otherwise.
   */
  function isPassport(
    PassportStorageTypesV1.PassportStorage storage self,
    address passport
  ) internal view returns (bool) {
    return self.passportEntitiesIndexes[passport] == 0;
  }

  /**
   * @notice Checks if the given address was a passport at a specific timepoint, i.e., not linked to an entity.
   * @dev A passport is defined as an account that is not an entity for another passport at the given timepoint.
   * This function checks whether the given address was not an entity at the specified timepoint by ensuring it was
   * not linked to any other passport.
   *
   * It uses the `Checkpoints.Trace160` mechanism to perform an upper bound lookup to retrieve the state at the given timepoint.
   * @param self The storage reference for PassportStorage.
   * @param passport The address to be checked.
   * @param timepoint The timepoint (block number) at which to check if the address was a passport.
   * @return True if the address was a passport (i.e., not linked to any entity) at the specified timepoint, false otherwise.
   */
  function isPassportInTimepoint(
    PassportStorageTypesV1.PassportStorage storage self,
    address passport,
    uint256 timepoint
  ) external view returns (bool) {
    return self.entityToPassport[passport].upperLookupRecent(SafeCast.toUint48(timepoint)) == 0;
  }

  /**
   * @notice Returns the pending links for a user (both incoming and outgoing)
   * @param user The address of the user
   * @return incoming The addresss of users that want to link to the user.
   * @return outgoing The address that the user wants to link to.
   */
  function getPendingLinkings(
    PassportStorageTypesV1.PassportStorage storage self,
    address user
  ) internal view returns (address[] memory incoming, address outgoing) {
    return (self.pendingLinksPassportToEntities[user], self.pendingLinksEntityToPassport[user]);
  }

  /**
   * @notice Returns the maximum number of entities that can be linked to a passport.
   */
  function getMaxEntitiesPerPassport(
    PassportStorageTypesV1.PassportStorage storage self
  ) internal view returns (uint256) {
    return self.maxEntitiesPerPassport;
  }

  // ---------- Setters ------------ //

  /**
   * @notice Links an entity to a passport with a signature, ensuring consent for the link.
   * @param entity The address of the entity being linked.
   * @param deadline The expiration time for the link signature.
   * @param signature The signature authorizing the link.
   */
  function linkEntityToPassportWithSignature(
    PassportStorageTypesV1.PassportStorage storage self,
    address entity,
    uint256 deadline,
    bytes memory signature
  ) external {
    if (block.timestamp > deadline) {
      revert SignatureExpired();
    }

    bytes32 structHash = keccak256(abi.encode(LINK_TYPEHASH, entity, msg.sender, deadline));
    bytes32 digest = PassportEIP712SigningLogicV1.hashTypedDataV4(structHash);
    address signer = digest.recover(signature);

    // Ensure the signature is valid
    if (signer != entity) {
      revert InvalidSignature();
    }

    // Check if the entity is ok to link
    _checkLink(self, msg.sender, entity);

    // Check if the passport has reached the maximum number of entities, if so, revert
    if (self.passportToEntities[msg.sender].length >= self.maxEntitiesPerPassport) {
      revert MaxEntitiesPerPassportReached();
    }

    // Add the entity to the list of links for the passport
    _linkEntity(self, entity, msg.sender);
  }

  /**
   * @notice Links an entity to a passport.
   * @param passport The address of the passport to which the entity is being linked.
   */
  function linkEntityToPassport(PassportStorageTypesV1.PassportStorage storage self, address passport) external {
    _checkLink(self, passport, msg.sender);

    // Add the entity to the list of pending links for the passport
    uint256 length = self.pendingLinksPassportToEntities[passport].length;
    self.pendingLinksIndexes[msg.sender] = length + 1;
    self.pendingLinksPassportToEntities[passport].push(msg.sender);
    self.pendingLinksEntityToPassport[msg.sender] = passport;

    emit LinkPending(msg.sender, passport);
  }

  /**
   * @notice Accepts the pending entity link to a passport.
   * @dev The entity must have been previously linked in a pending state.
   * @param entity The address of the entity to link to the passport.
   */
  function acceptEntityLink(PassportStorageTypesV1.PassportStorage storage self, address entity) external {
    address passport = self.pendingLinksEntityToPassport[entity];

    // Ensure the entity is in a pending link state
    if (passport == address(0)) {
      revert NotLinked(entity);
    }

    // Ensure that the caller is the passport that the entity is trying to link to
    if (passport != msg.sender) {
      revert UnauthorizedUser(msg.sender);
    }

    // Check if the passport has reached the maximum number of entities
    if (self.passportToEntities[msg.sender].length >= self.maxEntitiesPerPassport) {
      revert MaxEntitiesPerPassportReached();
    }

    // Remove the pending link
    _removePendingEntityLink(self, entity, msg.sender);

    // Link the entity to the passport
    _linkEntity(self, entity, msg.sender);
  }

  /**
   * @notice Removes an entity link from a passport.
   * @dev Only the passport or the entity itself can remove the link.
   * @param entity The address of the entity to be unlinked.
   */
  function removeEntityLink(PassportStorageTypesV1.PassportStorage storage self, address entity) external {
    // Get the passport linked to the entity
    address passport = _getPassportForEntity(self, entity);

    // Revert if the entity is not linked to any passport
    if (passport == entity) {
      revert NotLinked(entity);
    }

    // Ensure the caller is either the passport or the entity
    if (msg.sender != entity && msg.sender != passport) {
      revert UnauthorizedUser(msg.sender);
    }

    // Push a checkpoint to mark the entity as unlinked from the passport
    _pushCheckpoint(self.entityToPassport[entity], address(0));

    // Remove the entity link from the passport
    _removeEntityLink(self, entity, passport);

    emit LinkRemoved(entity, passport);
  }

  /**
   * @notice Deny an incoming pending entity link to the sender's passport.
   * @dev Only the passport can deny an incoming pending link.
   * @param entity The address of the entity with a pending link to the passport.
   */
  function denyIncomingPendingEntityLink(PassportStorageTypesV1.PassportStorage storage self, address entity) external {
    address passport = self.pendingLinksEntityToPassport[entity];
    if (passport == address(0)) {
      revert NotLinked(entity);
    }

    // Ensure the caller is the passport that the entity is trying to link to
    if (passport != msg.sender) {
      revert UnauthorizedUser(msg.sender);
    }

    _removePendingEntityLink(self, entity, passport);

    emit LinkRemoved(entity, passport);
  }

  /**
   * @notice Cancel an outgoing pending entity link from the sender.
   */
  function cancelOutgoingPendingEntityLink(PassportStorageTypesV1.PassportStorage storage self) external {
    address passport = self.pendingLinksEntityToPassport[msg.sender];
    if (passport == address(0)) {
      revert NotLinked(msg.sender);
    }

    _removePendingEntityLink(self, msg.sender, passport);

    emit LinkRemoved(msg.sender, passport);
  }

  /**
   * @notice Sets the maximum number of entities that can be linked to a passport.
   * @param maxEntities The maximum number of entities that can be linked to a passport.
   */
  function setMaxEntitiesPerPassport(PassportStorageTypesV1.PassportStorage storage self, uint256 maxEntities) external {
    self.maxEntitiesPerPassport = maxEntities;
  }

  // ---------- Private Helper Functions ---------- //

  /**
   * @notice Internal function to push a checkpoint to the entity-to-passport mapping.
   * @param store The Checkpoints.Trace160 storage where the link will be updated.
   * @param value The address of the passport (or address(0) if unlinking).
   */
  function _pushCheckpoint(Checkpoints.Trace160 storage store, address value) private {
    store.push(PassportClockLogicV1.clock(), uint160(value));
  }

  /**
   * @notice Internal function to remove a pending entity link between an entity and a passport.
   * @param self The storage reference for PassportStorage.
   * @param entity The address of the entity being unlinked from the passport.
   * @param passport The address of the passport.
   */

  function _removePendingEntityLink(
    PassportStorageTypesV1.PassportStorage storage self,
    address entity,
    address passport
  ) private {
    // Get the index of the entity in the pending links array
    uint256 index = self.pendingLinksIndexes[entity];

    // Get the length of the pending links array
    uint256 pendingLinksLength = self.pendingLinksPassportToEntities[passport].length;

    // Decrement the index to match the array index
    index -= 1;

    // If the entity is not the last in the array, move the last entity to the removed entity's position
    if (index != pendingLinksLength - 1) {
      address lastEntity = self.pendingLinksPassportToEntities[passport][pendingLinksLength - 1];
      self.pendingLinksPassportToEntities[passport][index] = lastEntity;
      self.pendingLinksIndexes[lastEntity] = index + 1;
    }

    // Remove the entity from the pending links array
    self.pendingLinksPassportToEntities[passport].pop();

    // Remove the entity from the pending links indexes
    delete self.pendingLinksIndexes[entity];
    delete self.pendingLinksEntityToPassport[entity];
  }

  /**
   * @notice Removes an entity linked to a passport, preserving the snapshot history.
   * @param self The storage reference for PassportStorage.
   * @param entity The address of the entity to be removed from the passport.
   * @param passport The address of the passport from which the entity is being removed.
   */
  function _removeEntityLink(
    PassportStorageTypesV1.PassportStorage storage self,
    address entity,
    address passport
  ) private {
    // Get the index of the entity in the passport's entities array
    uint256 index = self.passportEntitiesIndexes[entity];

    // Get the length of the entities array
    uint256 linksLength = self.passportToEntities[passport].length;

    // Decrement the index to match the array index
    index -= 1;

    // If the entity is not the last in the array, move the last entity to the removed entity's position
    if (index != linksLength - 1) {
      address lastEntity = self.passportToEntities[passport][linksLength - 1];
      self.passportToEntities[passport][index] = lastEntity;
      self.passportEntitiesIndexes[lastEntity] = index + 1;
    }

    // Remove the entity from the passport's entities array
    self.passportToEntities[passport].pop();

    // Remove the entity from the passport's entities indexes
    delete self.passportEntitiesIndexes[entity];
    delete self.passportToEntities[entity];

    // Remove signals, and black/white lists from the passport
    PassportSignalingLogicV1.removeEntitySignalsFromPassport(self, entity, passport);
    PassportWhitelistAndBlacklistLogicV1.removeEntitiesBlackAndWhiteListsFromPassport(self, entity, passport);
  }

  /**
   * @notice Links an entity to a passport and creates a snapshot at the current timepoint.
   * @param self The storage reference for PassportStorage.
   * @param entity The address of the entity to be linked to the passport.
   * @param passport The address of the passport to which the entity is being linked.
   */
  function _linkEntity(PassportStorageTypesV1.PassportStorage storage self, address entity, address passport) private {
    // Push a checkpoint to mark the entity as linked to the passport
    _pushCheckpoint(self.entityToPassport[entity], passport);

    // Get the index of the entity in the passport's entities array
    uint256 length = self.passportToEntities[passport].length;

    // Increment the index to match the array index
    self.passportEntitiesIndexes[entity] = length + 1;
    self.passportToEntities[passport].push(entity);

    // Assign the signals, and black/white lists to the passport
    PassportSignalingLogicV1.attachEntitySignalsToPassport(self, entity, passport);
    PassportWhitelistAndBlacklistLogicV1.attachEntitiesBlackAndWhiteListsToPassport(self, entity, passport);

    emit LinkCreated(entity, passport);
  }

  function _addressFromUint160(uint160 value) private pure returns (address) {
    return address(uint160(value));
  }

  /**
   * @dev Internal function for getting the passport linked to an entity.
   * @param entity The address of the entity whose linked passport is being retrieved.
   * @return The address of the linked passport.
   */
  function _getPassportForEntity(
    PassportStorageTypesV1.PassportStorage storage self,
    address entity
  ) internal view returns (address) {
    address passport = _addressFromUint160(self.entityToPassport[entity].latest());
    // If the entity is not linked to a passport, return the entity itself
    if (passport == address(0)) {
      return entity;
    }
    // Otherwise, return the linked passport
    return passport;
  }

  /**
   * @notice Checks if an entity is linked to a passport.
   * @param entity The address of the entity being checked.
   * @return True if the entity is linked to a passport, false otherwise.
   */
  function _isEntityInTimepoint(
    PassportStorageTypesV1.PassportStorage storage self,
    address entity,
    uint256 timepoint
  ) internal view returns (bool) {
    return self.entityToPassport[entity].upperLookupRecent(SafeCast.toUint48(timepoint)) != 0;
  }

  /**
   * @notice Checks if passport and entity are eligible for linking.
   * @param passport The address of the passport being checked.
   * @param entity The address of the entity being checked.
   */
  function _checkLink(
    PassportStorageTypesV1.PassportStorage storage self,
    address passport,
    address entity
  ) private view {
    // Check if the entity is already an entity, if so revert
    if (self.entityToPassport[entity].latest() != 0 || self.pendingLinksIndexes[entity] != 0) {
      revert AlreadyLinked(entity);
    }

    // Check if the passport is an entity, if so revert
    if (self.entityToPassport[passport].latest() != 0 || self.pendingLinksEntityToPassport[passport] != address(0)) {
      revert AlreadyLinked(passport);
    }

    // Check if the entity is a passport, if so revert
    if (self.passportToEntities[entity].length != 0) {
      revert AlreadyLinked(passport);
    }

    // Check if entity has delegated to another passport or has a pending delegation
    if (
      PassportDelegationLogicV1.isDelegator(self, entity) ||
      self.pendingDelegationsDelegatorToDelegatee[entity] != address(0)
    ) {
      revert DelegatedEntity(entity);
    }

    // Prevent self-linking (an entity cannot be its own passport)
    if (entity == passport) {
      revert CannotLinkToSelf(entity);
    }
  }
}

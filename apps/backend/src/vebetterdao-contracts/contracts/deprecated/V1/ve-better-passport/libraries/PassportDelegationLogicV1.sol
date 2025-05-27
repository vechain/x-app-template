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
import { PassportEntityLogicV1 } from "./PassportEntityLogicV1.sol";
import { PassportTypesV1 } from "./PassportTypesV1.sol";
import { Checkpoints } from "@openzeppelin/contracts/utils/structs/Checkpoints.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";

/**
 * @title PassportDelegationLogicV1
 * @dev A library that manages the delegation of passports between users in the Passport system.
 * It allows users to delegate their passports to others, revoke delegations, and check the delegation status.
 * Delegations can be created with or without signatures, and certain rules are enforced, such as preventing
 * delegation to oneself or to entities associated with a passport.
 *
 * This library also emits various events for delegation creation, revocation, and pending delegations, allowing
 * external systems to track delegation status.
 */
library PassportDelegationLogicV1 {
  // Ethereum addresses are uint160, we can store addresses as uint160 values within the Checkpoints.Trace160
  using Checkpoints for Checkpoints.Trace160;
  // Extends the bytes32 type to support ECDSA signatures
  using ECDSA for bytes32;

  // ---------- Constants ---------- //
  string private constant SIGNING_DOMAIN = "VeBetterPassport";
  string private constant SIGNATURE_VERSION = "1";
  bytes32 private constant DELEGATION_TYPEHASH =
    keccak256("Delegation(address delegator,address delegatee,uint256 deadline)");

  // ---------- Errors ---------- //
  /// @notice Emitted when a user does not have permission to delegate passport.
  error PassportDelegationUnauthorizedUser(address user);

  /// @notice Emitted when a user tries to delegate passport to themselves.
  error CannotDelegateToSelf(address user);

  /// @notice Emitted when a user tries to revoke a delegation that does not exist.
  error NotDelegated(address user);

  /// @notice Emitted when a user tries to delegate passport to more than one user.
  error OnlyOneUserAllowed();

  /// @notice Emitted when an entity tries to delegate a passport.
  error PassportDelegationFromEntity();

  /// @notice Emitted when a user tries to delegate a passport to another entity.
  error PassportDelegationToEntity();

  /// @notice Emitted when a user tries to delegate with a
  error SignatureExpired();

  /// @notice Emitted when a user tries to delegate with a
  error InvalidSignature();

  // ---------- Events ---------- //
  /// @notice Emitted when a user delegates passport to another user.
  event DelegationCreated(address indexed delegator, address indexed delegatee);

  /// @notice Emitted when a user delegates passport to another user pending acceptance.
  event DelegationPending(address indexed delegator, address indexed delegatee);

  /// @notice Emitted when a user revokes the delegation of passport to another user.
  event DelegationRevoked(address indexed delegator, address indexed delegatee);

  // ---------- Getters ---------- //

  /**
   * @notice Returns the delegatee for a given delegator.
   * @param self The storage object for the Passport contract containing delegation data.
   * @param delegator The address of the delegator.
   * @return The address of the delegatee for the given delegator.
   */
  function getDelegatee(
    PassportStorageTypesV1.PassportStorage storage self,
    address delegator
  ) public view returns (address) {
    return _addressFromUint160(self.delegatorToDelegatee[delegator].latest());
  }

  /**
   * @notice Returns the delegatee for a delegator at a specific timepoint.
   * @param self The storage object for the Passport contract containing delegation data.
   * @param delegator The address of the delegator.
   * @param timepoint The timepoint to query.
   * @return The delegatee address at the given timepoint.
   */
  function getDelegateeInTimepoint(
    PassportStorageTypesV1.PassportStorage storage self,
    address delegator,
    uint256 timepoint
  ) external view returns (address) {
    return _addressFromUint160(self.delegatorToDelegatee[delegator].upperLookupRecent(SafeCast.toUint48(timepoint)));
  }

  /**
   * @notice Returns the delegator for a given delegatee.
   * @param self The storage object for the Passport contract containing delegation data.
   * @param delegatee The address of the delegatee.
   * @return The address of the delegator for the given delegatee.
   */
  function getDelegator(
    PassportStorageTypesV1.PassportStorage storage self,
    address delegatee
  ) public view returns (address) {
    return _addressFromUint160(self.delegateeToDelegator[delegatee].latest());
  }

  /**
   * @notice Returns the delegator for a deleagtee at a specific timepoint.
   * @param self The storage object for the Passport contract containing delegation data.
   * @param delegatee The address of the delegatee.
   * @param timepoint The timepoint to query.
   * @return The delegator address at the given timepoint.
   */
  function getDelegatorInTimepoint(
    PassportStorageTypesV1.PassportStorage storage self,
    address delegatee,
    uint256 timepoint
  ) external view returns (address) {
    return _getDelegatorInTimepoint(self, delegatee, timepoint);
  }

  /**
   * @notice Checks if the given user is currently a delegator.
   * @param self The storage object for the Passport contract containing delegation data.
   * @param user The address of the user being queried.
   * @return True if the user is a delegator, false otherwise.
   */
  function isDelegator(PassportStorageTypesV1.PassportStorage storage self, address user) internal view returns (bool) {
    return self.delegatorToDelegatee[user].latest() != 0;
  }

  /**
   * @notice Checks if the given user is a delegator at a specific timepoint.
   * @param self The storage object for the Passport contract containing delegation data.
   * @param user The address of the user being queried.
   * @param timepoint The specific timepoint (block number or timestamp) to check.
   * @return True if the user is a delegator at the given timepoint, false otherwise.
   */
  function isDelegatorInTimepoint(
    PassportStorageTypesV1.PassportStorage storage self,
    address user,
    uint256 timepoint
  ) external view returns (bool) {
    return _isDelegatorInTimepoint(self, user, timepoint);
  }

  /**
   * @notice Checks if the given user is currently a delegatee.
   * @param self The storage object for the Passport contract containing delegation data.
   * @param user The address of the user being queried.
   * @return True if the user is a delegatee, false otherwise.
   */
  function isDelegatee(PassportStorageTypesV1.PassportStorage storage self, address user) internal view returns (bool) {
    return self.delegateeToDelegator[user].latest() != 0;
  }

  /**
   * @notice Checks if the given user is a delegatee at a specific timepoint.
   * @param self The storage object for the Passport contract containing delegation data.
   * @param user The address of the user being queried.
   * @param timepoint The specific timepoint (block number or timestamp) to check.
   * @return True if the user is a delegatee at the given timepoint, false otherwise.
   */
  function isDelegateeInTimepoint(
    PassportStorageTypesV1.PassportStorage storage self,
    address user,
    uint256 timepoint
  ) external view returns (bool) {
    return _isDelegateeInTimepoint(self, user, timepoint);
  }

  /**
   * @notice Returns a list of pending delegations for the given user.
   * @param self The storage object for the Passport contract containing delegation data.
   * @param user The address of the user whose pending delegations are being queried.
   * @return incoming The addresses of users that are delegating to the user.
   * @return outgoing The address that the user is delegating to.
   */
  function getPendingDelegations(
    PassportStorageTypesV1.PassportStorage storage self,
    address user
  ) internal view returns (address[] memory incoming, address outgoing) {
    return (self.pendingDelegationsDelegateeToDelegators[user], self.pendingDelegationsDelegatorToDelegatee[user]);
  }

  // ---------- Setters ------------ //

  /**
   * @notice Allows a delegator to delegate their passport to a delegatee with a signed message.
   * The signature ensures the delegation is authorized by the delegator.
   * Eg: Alice has a passport where she is not considered a person, she delegates her passport to Bob, which
   * is considered a person. Bob now cannot vote because he is not considered a person anymore.
   * @param self The storage object for the Passport contract.
   * @param delegator The address of the delegator.
   * @param deadline The expiration time of the delegation.
   * @param signature The ECDSA signature for authorization.
   */
  function delegateWithSignature(
    PassportStorageTypesV1.PassportStorage storage self,
    address delegator,
    uint256 deadline,
    bytes memory signature
  ) external {
    if (block.timestamp > deadline) {
      revert SignatureExpired();
    }

    // Recover the signer address from the signature
    bytes32 structHash = keccak256(abi.encode(DELEGATION_TYPEHASH, delegator, msg.sender, deadline));
    bytes32 digest = PassportEIP712SigningLogicV1.hashTypedDataV4(structHash);
    address signer = digest.recover(signature);

    // Check if the signer is the delegator
    if (signer != delegator) {
      revert InvalidSignature();
    }

    // Check delegation rules
    _checkDelegation(self, delegator, msg.sender);

    // Check if the delegatee has already been delegated
    if (isDelegatee(self, msg.sender)) {
      _removeDelegation(self, _addressFromUint160(self.delegateeToDelegator[msg.sender].latest()), msg.sender);
    }

    _pushCheckpoint(self.delegatorToDelegatee[delegator], msg.sender);
    _pushCheckpoint(self.delegateeToDelegator[msg.sender], delegator);

    emit DelegationCreated(delegator, msg.sender);
  }

  /**
   * @notice Allows a delegator to delegate their passport to a delegatee.
   * The delegatee must accept the delegation for it to become active.
   * Eg: Alice has a passport where she is not considered a person, she delegates her passport to Bob, which
   * is considered a person. Bob now cannot vote because he is not considered a person anymore.
   * @param self The storage object for the Passport contract.
   * @param delegatee The address of the delegatee.
   */
  function delegatePassport(PassportStorageTypesV1.PassportStorage storage self, address delegatee) external {
    // Check delegation rules
    _checkDelegation(self, msg.sender, delegatee);

    // Get the length of the pending delegations
    uint256 length = self.pendingDelegationsDelegateeToDelegators[delegatee].length;

    // Add the delegator to the pending delegations indexes
    self.pendingDelegationsIndexes[msg.sender] = length + 1;

    // Add the delegator to the pending delegations of the delegatee
    self.pendingDelegationsDelegateeToDelegators[delegatee].push(msg.sender);
    self.pendingDelegationsDelegatorToDelegatee[msg.sender] = delegatee;

    emit DelegationPending(msg.sender, delegatee);
  }

  /**
   * @notice Allows the delegatee to accept a pending delegation.
   * @param self The storage object for the Passport contract.
   * @param delegator The address of the delegator.
   */
  function acceptDelegation(PassportStorageTypesV1.PassportStorage storage self, address delegator) external {
    address delegatee = self.pendingDelegationsDelegatorToDelegatee[delegator];

    // Check if the pending delegation exists
    if (delegatee == address(0)) {
      revert NotDelegated(msg.sender); // Delegator not found in the pending delegations
    }

    // Check if the caller is the delegatee
    if (delegatee != msg.sender) {
      revert PassportDelegationUnauthorizedUser(msg.sender); // Delegation does not match
    }

    // Check if the delegatee has already accepted a delegation
    if (isDelegatee(self, msg.sender)) {
      _removeDelegation(self, _addressFromUint160(self.delegateeToDelegator[msg.sender].latest()), msg.sender);
    }

    // Add the delegator to the delegatee and the delegatee to the delegator
    _pushCheckpoint(self.delegateeToDelegator[msg.sender], delegator);
    _pushCheckpoint(self.delegatorToDelegatee[delegator], msg.sender);

    // Remove the pending delegation
    _removePendingDelegation(self, delegator, msg.sender);

    emit DelegationCreated(delegator, msg.sender);
  }

  /**
   * @notice Allows a user to deny (and remove) an incoming pending delegation.
   * @param self The storage object for the Passport contract.
   * @param delegator the user who is delegating to me (aka the delegator)
   */
  function denyIncomingPendingDelegation(
    PassportStorageTypesV1.PassportStorage storage self,
    address delegator
  ) external {
    address delegatee = self.pendingDelegationsDelegatorToDelegatee[delegator];

    // Check if the pending delegation exists
    if (delegatee == address(0)) {
      revert NotDelegated(delegator);
    }

    // Check caller is the delegatee
    if (msg.sender != delegatee) {
      revert PassportDelegationUnauthorizedUser(msg.sender);
    }

    // Use the _removePendingDelegation function to handle the deletion logic
    _removePendingDelegation(self, delegator, delegatee);

    emit DelegationRevoked(delegator, delegatee);
  }

  /**
   * @notice Allows a delegator to cancel (and remove) the outgoing pending delegation.
   * @param self The storage object for the Passport contract.
   */
  function cancelOutgoingPendingDelegation(PassportStorageTypesV1.PassportStorage storage self) external {
    address delegatee = self.pendingDelegationsDelegatorToDelegatee[msg.sender];

    // Check if the pending delegation exists
    if (delegatee == address(0)) {
      revert NotDelegated(msg.sender);
    }

    // Use the _removePendingDelegation function to handle the deletion logic
    _removePendingDelegation(self, msg.sender, delegatee);

    emit DelegationRevoked(msg.sender, delegatee);
  }

  /**
   * @notice Allows a delegator or delegatee to revoke an existing delegation.
   * This removes the delegation between the delegator and the delegatee.
   * @param self The storage object for the Passport contract.
   */
  function revokeDelegation(PassportStorageTypesV1.PassportStorage storage self) external {
    address user = msg.sender;
    address delegator;
    address delegatee;

    // Check if user is either a delegator or delegatee
    if (isDelegator(self, user)) {
      delegator = user;
      delegatee = getDelegatee(self, user);
    } else if (isDelegatee(self, user)) {
      delegatee = user;
      delegator = getDelegator(self, user);
    } else {
      revert NotDelegated(user);
    }

    // Revoke the delegation and reset the checkpoints
    _removeDelegation(self, delegator, delegatee);
  }

  // ---------- Private ---------- //
  /// @notice Push a new checkpoint for the delegator and delegatee
  function _pushCheckpoint(Checkpoints.Trace160 storage store, address value) private {
    store.push(PassportClockLogicV1.clock(), uint160(value));
  }

  /// @notice Removes a pending delegation between a delegator and a delegatee.
  /// @dev This function removes the delegator from the delegatee's pending delegation list and updates the pendingDelegationsIndexes for the delegator.
  ///     The function swaps the last element in the pending delegation array with the one being removed and pops the last element to avoid leaving gaps.
  /// @param self The PassportStorage structure containing delegation mappings and lists.
  /// @param delegator The address of the delegator who initiated the pending delegation.
  /// @param delegatee The address of the delegatee to whom the delegator is delegating.
  function _removePendingDelegation(
    PassportStorageTypesV1.PassportStorage storage self,
    address delegator,
    address delegatee
  ) private {
    uint256 index = self.pendingDelegationsIndexes[delegator];

    uint256 pendingDelegationsLength = self.pendingDelegationsDelegateeToDelegators[delegatee].length;

    // Adjust index (since it's stored as index + 1)
    index -= 1;

    // Swap the last element with the element to delete
    if (index != pendingDelegationsLength - 1) {
      address lastDelegator = self.pendingDelegationsDelegateeToDelegators[delegatee][pendingDelegationsLength - 1];
      self.pendingDelegationsDelegateeToDelegators[delegatee][index] = lastDelegator;
      self.pendingDelegationsIndexes[lastDelegator] = index + 1; // Update the index
    }

    // Pop the last element (removes the duplicate or the swapped one)
    self.pendingDelegationsDelegateeToDelegators[delegatee].pop();

    // Clear the pending delegation index for the removed delegator
    delete self.pendingDelegationsIndexes[delegator];
    delete self.pendingDelegationsDelegatorToDelegatee[delegator];
  }

  /// @dev Removes the delegation relationship between a delegator and a delegatee.
  function _removeDelegation(
    PassportStorageTypesV1.PassportStorage storage self,
    address delegator,
    address delegatee
  ) private {
    _pushCheckpoint(self.delegatorToDelegatee[delegator], address(0));
    _pushCheckpoint(self.delegateeToDelegator[delegatee], address(0));

    emit DelegationRevoked(delegator, delegatee);
  }

  /// @notice Convert a uint160 value to an address
  function _addressFromUint160(uint160 value) private pure returns (address) {
    return address(uint160(value));
  }

  /// @notice Checks if user is a delegatee at a specific timepoint
  function _isDelegateeInTimepoint(
    PassportStorageTypesV1.PassportStorage storage self,
    address user,
    uint256 timepoint
  ) internal view returns (bool) {
    return self.delegateeToDelegator[user].upperLookupRecent(SafeCast.toUint48(timepoint)) != 0;
  }

  /// @notice Returns the delegator for a given delegatee.
  function _getDelegatorInTimepoint(
    PassportStorageTypesV1.PassportStorage storage self,
    address delegatee,
    uint256 timepoint
  ) internal view returns (address) {
    return _addressFromUint160(self.delegateeToDelegator[delegatee].upperLookupRecent(SafeCast.toUint48(timepoint)));
  }

  /// @notice Checks if the given user is a delegator at a specific timepoint.
  function _isDelegatorInTimepoint(
    PassportStorageTypesV1.PassportStorage storage self,
    address user,
    uint256 timepoint
  ) internal view returns (bool) {
    return self.delegatorToDelegatee[user].upperLookupRecent(SafeCast.toUint48(timepoint)) != 0;
  }

  function _checkDelegation(
    PassportStorageTypesV1.PassportStorage storage self,
    address delegator,
    address delegatee
  ) private {
    // Check if the delegator is trying to delegate to themselves
    if (delegator == delegatee) {
      revert CannotDelegateToSelf(delegator);
    }

    // Check if the delegator is an entity linked to a passport or has a pending link
    if (PassportEntityLogicV1.isEntity(self, delegator) || self.pendingLinksEntityToPassport[delegator] != address(0)) {
      revert PassportDelegationFromEntity();
    }

    // Check if the delegatee is an entity linked to a passport or has a pending link
    if (PassportEntityLogicV1.isEntity(self, delegatee) || self.pendingLinksEntityToPassport[delegatee] != address(0)) {
      revert PassportDelegationToEntity();
    }

    // Check if the passport has already been delegated removing the previous delegation
    if (isDelegator(self, delegator)) {
      _removeDelegation(self, delegator, _addressFromUint160(self.delegatorToDelegatee[delegator].latest()));
    }

    // Check if the passport is already pending delegation
    if (self.pendingDelegationsDelegatorToDelegatee[delegator] != address(0)) {
      _removePendingDelegation(self, delegator, self.pendingDelegationsDelegatorToDelegatee[delegator]);
    }
  }
}

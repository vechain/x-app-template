// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

contract ModuleInitializable is Initializable, AccessControlUpgradeable {
  error UnauthorizedUser(address user);

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  // ---------- Storage ------------ //

  struct ModuleInitializableStorage {
    uint256 version; // TODO: remove to standalone function
  }

  // keccak256(abi.encode(uint256(keccak256("storage.ModuleInitializable")) - 1)) & ~bytes32(uint256(0xff))
  bytes32 private constant ModuleInitializableStorageLocation =
    0xc9931bd7ecbba177fc71b0ded00eb01d4035361d4a0ee711add00987aca69000;

  function _getModuleInitializableStorage() private pure returns (ModuleInitializableStorage storage $) {
    assembly {
      $.slot := ModuleInitializableStorageLocation
    }
  }

  /**
   * @dev Initializes the contract
   */
  function __ModuleInitializable_init() internal onlyInitializing {
    __ModuleInitializable_init_unchained();
  }

  function __ModuleInitializable_init_unchained() internal onlyInitializing {
    // ModuleInitializableStorage storage $ = _getModuleInitializableStorage();
  }

  // ---------- Modifiers ------------ //

  /**
   * @dev Modifier to restrict access to only the admin role and the app admin role.
   * @param appId the app ID
   */
  /// @notice Modifier to check if the user has the required role or is the DEFAULT_ADMIN_ROLE
  /// @param role - the role to check
  modifier onlyRoleOrAdmin(bytes32 role) virtual {
    if (!hasRole(role, msg.sender) && !hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
      revert UnauthorizedUser(msg.sender);
    }
    _;
  }

  // ---------- Setters ---------- //

  // ---------- Getters ---------- //
}

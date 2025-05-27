// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

contract BaseUpgradeable is AccessControlUpgradeable, UUPSUpgradeable {
  bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

  error UnauthorizedUser(address user);

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  // ---------- Storage ------------ //

  struct BaseUpgradeableStorage {
    uint256 version; // TODO: remove to standalone function
  }

  // keccak256(abi.encode(uint256(keccak256("storage.BaseUpgradeable")) - 1)) & ~bytes32(uint256(0xff))
  bytes32 private constant BaseUpgradeableStorageLocation =
    0xc9931bd7ecbba177fc71b0ded00eb01d4035361d4a0ee711add00987aca69000;

  function _getBaseUpgradeableStorage() private pure returns (BaseUpgradeableStorage storage $) {
    assembly {
      $.slot := BaseUpgradeableStorageLocation
    }
  }

  /// @notice Initializes the contract
  function initialize(address _upgrader, address[] memory _admins) external initializer {
    require(_upgrader != address(0), "BaseUpgradeable: upgrader is the zero address");

    __UUPSUpgradeable_init();
    __AccessControl_init();

    _grantRole(UPGRADER_ROLE, _upgrader);

    for (uint256 i; i < _admins.length; i++) {
      require(_admins[i] != address(0), "BaseUpgradeable: admin address cannot be zero");
      _grantRole(DEFAULT_ADMIN_ROLE, _admins[i]);
    }
  }

  // ---------- Modifiers ------------ //

  /**
   * @dev Modifier to restrict access to only the admin role and the app admin role.
   * @param appId the app ID
   */
  /// @notice Modifier to check if the user has the required role or is the DEFAULT_ADMIN_ROLE
  /// @param role - the role to check
  modifier onlyRoleOrAdmin(bytes32 role) {
    if (!hasRole(role, msg.sender) && !hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
      revert UnauthorizedUser(msg.sender);
    }
    _;
  }

  // ---------- Authorizers ---------- //

  /// @notice Authorizes the upgrade of the contract
  /// @param newImplementation - the new implementation address
  function _authorizeUpgrade(address newImplementation) internal virtual override onlyRole(UPGRADER_ROLE) {}

  // ---------- Setters ---------- //

  // ---------- Getters ---------- //
}

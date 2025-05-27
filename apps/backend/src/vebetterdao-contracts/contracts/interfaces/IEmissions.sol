// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

interface IEmissions {
  struct Emission {
    uint256 xAllocations;
    uint256 vote2Earn;
    uint256 treasury;
  }

  struct InitializationData {
    address minter;
    address admin;
    address upgrader;
    address contractsAddressManager;
    address decaySettingsManager;
    address b3trAddress;
    address[4] destinations;
    uint256 migrationAmount;
    uint256 initialXAppAllocation;
    uint256 cycleDuration;
    uint256[4] decaySettings;
    uint256 treasuryPercentage;
    uint256 maxVote2EarnDecay;
  }

  error AccessControlBadConfirmation();

  error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);

  error AddressEmptyCode(address target);

  error ERC1967InvalidImplementation(address implementation);

  error ERC1967NonPayable();

  error FailedInnerCall();

  error InvalidInitialization();

  error NotInitializing();

  error ReentrancyGuardReentrantCall();

  error UUPSUnauthorizedCallContext();

  error UUPSUnsupportedProxiableUUID(bytes32 slot);

  event EmissionCycleDurationUpdated(uint256 indexed newDuration, uint256 indexed oldDuration);

  event EmissionDistributed(uint256 indexed cycle, uint256 xAllocations, uint256 vote2Earn, uint256 treasury);

  event Initialized(uint64 version);

  event MaxVote2EarnDecayUpdated(uint256 indexed newDecay, uint256 indexed oldDecay);

  event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);

  event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);

  event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

  event TreasuryAddressUpdated(address indexed newAddress, address indexed oldAddress);

  event TreasuryPercentageUpdated(uint256 indexed newPercentage, uint256 indexed oldPercentage);

  event Upgraded(address indexed implementation);

  event Vote2EarnAddressUpdated(address indexed newAddress, address indexed oldAddress);

  event Vote2EarnDecayPeriodUpdated(uint256 indexed newPeriod, uint256 indexed oldPeriod);

  event Vote2EarnDecayUpdated(uint256 indexed newDecay, uint256 indexed oldDecay);

  event XAllocationsAddressUpdated(address indexed newAddress, address indexed oldAddress);

  event XAllocationsDecayPeriodUpdated(uint256 indexed newPeriod, uint256 indexed oldPeriod);

  event XAllocationsDecayUpdated(uint256 indexed newDecay, uint256 indexed oldDecay);

  event XAllocationsGovernorAddressUpdated(address indexed newAddress, address indexed oldAddress);

  function CONTRACTS_ADDRESS_MANAGER_ROLE() external view returns (bytes32);

  function DECAY_SETTINGS_MANAGER_ROLE() external view returns (bytes32);

  function DEFAULT_ADMIN_ROLE() external view returns (bytes32);

  function MINTER_ROLE() external view returns (bytes32);

  function SCALING_FACTOR() external view returns (uint256);

  function UPGRADER_ROLE() external view returns (bytes32);

  function UPGRADE_INTERFACE_VERSION() external view returns (string memory);

  function b3tr() external view returns (address);

  function bootstrap() external;

  function cycleDuration() external view returns (uint256);

  function distribute() external;

  function emissions(uint256 cycle) external view returns (Emission memory);

  function getCurrentCycle() external view returns (uint256);

  function getNextCycleBlock() external view returns (uint256);

  function getRemainingEmissions() external view returns (uint256);

  function getRoleAdmin(bytes32 role) external view returns (bytes32);

  function getTreasuryAmount(uint256 cycle) external view returns (uint256);

  function getVote2EarnAmount(uint256 cycle) external view returns (uint256);

  function getXAllocationAmount(uint256 cycle) external view returns (uint256);

  function grantRole(bytes32 role, address account) external;

  function hasRole(bytes32 role, address account) external view returns (bool);

  function initialXAppAllocation() external view returns (uint256);

  function initialize(InitializationData memory data) external;

  function initializeV2(bool _isEmissionsNotAligned) external;

  function isCycleDistributed(uint256 cycle) external view returns (bool);

  function isCycleEnded(uint256 cycle) external view returns (bool);

  function isEmissionsNotAligned() external view returns (bool);

  function isNextCycleDistributable() external view returns (bool);

  function lastEmissionBlock() external view returns (uint256);

  function maxVote2EarnDecay() external view returns (uint256);

  function nextCycle() external view returns (uint256);

  function proxiableUUID() external view returns (bytes32);

  function renounceRole(bytes32 role, address callerConfirmation) external;

  function revokeRole(bytes32 role, address account) external;

  function setCycleDuration(uint256 _cycleDuration) external;

  function setMaxVote2EarnDecay(uint256 _maxVote2EarnDecay) external;

  function setTreasuryAddress(address treasuryAddress) external;

  function setTreasuryPercentage(uint256 _percentage) external;

  function setVote2EarnAddress(address vote2EarnAddress) external;

  function setVote2EarnDecay(uint256 _decay) external;

  function setVote2EarnDecayPeriod(uint256 _period) external;

  function setXAllocationsDecay(uint256 _decay) external;

  function setXAllocationsDecayPeriod(uint256 _period) external;

  function setXAllocationsGovernorAddress(address _xAllocationsGovernor) external;

  function setXallocationsAddress(address xAllocationAddress) external;

  function start() external;

  function supportsInterface(bytes4 interfaceId) external view returns (bool);

  function totalEmissions() external view returns (uint256);

  function treasury() external view returns (address);

  function treasuryPercentage() external view returns (uint256);

  function upgradeToAndCall(address newImplementation, bytes memory data) external payable;

  function version() external pure returns (string memory);

  function vote2Earn() external view returns (address);

  function vote2EarnDecay() external view returns (uint256);

  function vote2EarnDecayPeriod() external view returns (uint256);

  function xAllocations() external view returns (address);

  function xAllocationsDecay() external view returns (uint256);

  function xAllocationsDecayPeriod() external view returns (uint256);

  function xAllocationsGovernor() external view returns (address);
}

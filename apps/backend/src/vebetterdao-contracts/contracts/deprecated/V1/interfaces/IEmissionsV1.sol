// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import "./IB3TR.sol";
import "./IXAllocationVotingGovernorV1.sol";

interface IEmissionsV1 {
  struct Emission {
    uint256 xAllocations;
    uint256 vote2Earn;
    uint256 treasury;
  }

  error AccessControlBadConfirmation();

  error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);

  error ReentrancyGuardReentrantCall();

  event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);

  event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);

  event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

  event EmissionDistributed(uint256 indexed cycle, uint256 xAllocations, uint256 vote2Earn, uint256 treasury);

  event XAllocationsAddressUpdated(address indexed newAddress, address indexed oldAddress);

  event Vote2EarnAddressUpdated(address indexed newAddress, address indexed oldAddress);

  event XAllocationsGovernorAddressUpdated(address indexed newAddress, address indexed oldAddress);

  event TreasuryAddressUpdated(address indexed newAddress, address indexed oldAddress);

  event EmissionCycleDurationUpdated(uint256 indexed newDuration, uint256 indexed oldDuration);

  event XAllocationsDecayUpdated(uint256 indexed newDecay, uint256 indexed oldDecay);

  event Vote2EarnDecayUpdated(uint256 indexed newDecay, uint256 indexed oldDecay);

  event Vote2EarnDecayPeriodUpdated(uint256 indexed newPeriod, uint256 indexed oldPeriod);

  event MaxVote2EarnDecayUpdated(uint256 indexed newDecay, uint256 indexed oldDecay);

  event XAllocationsDecayPeriodUpdated(uint256 indexed newPeriod, uint256 indexed oldPeriod);

  event TreasuryPercentageUpdated(uint256 indexed newPercentage, uint256 indexed oldPercentage);

  function DEFAULT_ADMIN_ROLE() external view returns (bytes32);

  function MINTER_ROLE() external view returns (bytes32);

  function b3tr() external view returns (IB3TR);

  function bootstrap() external;

  function start() external;

  function cycleDuration() external view returns (uint256);

  function distribute() external;

  function emissions(uint256) external view returns (Emission memory);

  function getCurrentCycle() external view returns (uint256);

  function getNextCycleBlock() external view returns (uint256);

  function getRemainingEmissions() external view returns (uint256);

  function getRoleAdmin(bytes32 role) external view returns (bytes32);

  function getTreasuryAmount(uint256 cycle) external view returns (uint256);

  function getVote2EarnAmount(uint256 cycle) external view returns (uint256);

  function getXAllocationAmount(uint256 cycle) external view returns (uint256);

  function grantRole(bytes32 role, address account) external;

  function hasRole(bytes32 role, address account) external view returns (bool);

  function isCycleDistributed(uint256 cycle) external view returns (bool);

  function isCycleEnded(uint256 cycle) external view returns (bool);

  function isNextCycleDistributable() external view returns (bool);

  function lastEmissionBlock() external view returns (uint256);

  function maxVote2EarnDecay() external view returns (uint256);

  function nextCycle() external view returns (uint256);

  function renounceRole(bytes32 role, address callerConfirmation) external;

  function revokeRole(bytes32 role, address account) external;

  function setCycleDuration(uint256 _cycleDuration) external;

  function setMaxVote2EarnDecay(uint256 _maxVote2EarnDecay) external;

  function setTreasuryAddress(address treasuryAddress) external;

  function setTreasuryPercentage(uint256 _percentage) external;

  function setVote2EarnAddress(address vote2EarnAddress) external;

  function setVote2EarnDecay(uint256 _decay) external;

  function setVote2EarnDecayPeriod(uint256 _delay) external;

  function setXAllocationsDecay(uint256 _decay) external;

  function setXAllocationsDecayPeriod(uint256 _delay) external;

  function setXAllocationsGovernorAddress(address _xAllocationsGovernor) external;

  function setXallocationsAddress(address xAllocationAddress) external;

  function supportsInterface(bytes4 interfaceId) external view returns (bool);

  function totalEmissions() external view returns (uint256);

  function treasury() external view returns (address);

  function treasuryPercentage() external view returns (uint256);

  function vote2Earn() external view returns (address);

  function vote2EarnDecay() external view returns (uint256);

  function xAllocations() external view returns (address);

  function xAllocationsDecay() external view returns (uint256);

  function xAllocationsGovernor() external view returns (IXAllocationVotingGovernorV1);

  function version() external view returns (string memory);
}

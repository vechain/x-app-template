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

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "./interfaces/IB3TR.sol";
import "./interfaces/IXAllocationVotingGovernorV1.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/// @title Emissions Distribution Contract
/// @dev Manages the periodic distribution of B3TR tokens to XAllocation, Vote2Earn, and Treasury allocations.
/// @dev This contract leverages openzeppelin's AccessControl, ReentrancyGuard, and UUPSUpgradeable libraries for access control, reentrancy protection, and upgradability.
/// @notice This contract is responsible for the scheduled distribution of emissions based on predefined cycles and decay settings.
contract EmissionsV1 is AccessControlUpgradeable, ReentrancyGuardUpgradeable, UUPSUpgradeable {
  /// @notice Role for addresses allowed to mint new tokens
  bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
  /// @notice Role for addresses that can upgrade the contract
  bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
  /// @notice The role that can set external contracts addresses
  bytes32 public constant CONTRACTS_ADDRESS_MANAGER_ROLE = keccak256("CONTRACTS_ADDRESS_MANAGER_ROLE");
  /// @notice Role for addresses that can update the decay settings
  bytes32 public constant DECAY_SETTINGS_MANAGER_ROLE = keccak256("DECAY_SETTINGS_MANAGER_ROLE");

  // Scaling factor to handle decimal places
  uint256 public constant SCALING_FACTOR = 1e6;

  // ---------------- Events ---------------- //
  /// @notice Emitted when emissions are distributed for a cycle
  event EmissionDistributed(uint256 indexed cycle, uint256 xAllocations, uint256 vote2Earn, uint256 treasury);
  /// @notice Emitted when XAllocations address is updated
  event XAllocationsAddressUpdated(address indexed newAddress, address indexed oldAddress);
  /// @notice Emitted when Vote2Earn address is updated
  event Vote2EarnAddressUpdated(address indexed newAddress, address indexed oldAddress);
  /// @notice Emitted when XAllocationsGovernor address is updated
  event XAllocationsGovernorAddressUpdated(address indexed newAddress, address indexed oldAddress);
  /// @notice Emitted when Treasury address is updated
  event TreasuryAddressUpdated(address indexed newAddress, address indexed oldAddress);
  /// @notice Emitted when the emission cycle duration is updated
  event EmissionCycleDurationUpdated(uint256 indexed newDuration, uint256 indexed oldDuration);
  /// @notice Emitted when the xAllocations decay rate is updated
  event XAllocationsDecayUpdated(uint256 indexed newDecay, uint256 indexed oldDecay);
  /// @notice Emitted when the vote2Earn decay rate is updated
  event Vote2EarnDecayUpdated(uint256 indexed newDecay, uint256 indexed oldDecay);
  /// @notice Emitted when the vote2Earn decay period is updated
  event Vote2EarnDecayPeriodUpdated(uint256 indexed newPeriod, uint256 indexed oldPeriod);
  /// @notice Emitted when the max vote2Earn decay rate is updated
  event MaxVote2EarnDecayUpdated(uint256 indexed newDecay, uint256 indexed oldDecay);
  /// @notice Emitted when the xAllocations decay period is updated
  event XAllocationsDecayPeriodUpdated(uint256 indexed newPeriod, uint256 indexed oldPeriod);
  /// @notice Emitted when the treasury percentage is updated
  event TreasuryPercentageUpdated(uint256 indexed newPercentage, uint256 indexed oldPercentage);

  /// @notice Initialization data for the Emissions contract
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

  struct Emission {
    uint256 xAllocations;
    uint256 vote2Earn;
    uint256 treasury;
  }

  /// @notice Storage structure for the Emissions contract
  /// @dev Struct to store the state of emissions
  /// @custom:storage-location erc7201:b3tr.storage.Emissions
  struct EmissionsStorage {
    IB3TR b3tr; // B3TR token contract
    IXAllocationVotingGovernorV1 xAllocationsGovernor; // XAllocationVotingGovernor contract
    // Destinations for emissions
    address _xAllocations;
    address _vote2Earn;
    address _treasury;
    // Migration
    address _migration;
    uint256 _migrationAmount;
    // ----------- Cycle attributes ----------- //
    uint256 nextCycle; // Next cycle number
    uint256 cycleDuration; // Duration of a cycle in blocks
    // ----------- Decay rates ----------- //
    uint256 xAllocationsDecay; // Decay rate for xAllocations in percentage
    uint256 vote2EarnDecay; // Decay rate for vote2Earn in percentage
    uint256 maxVote2EarnDecay; // Maximum decay rate for vote2Earn in percentage
    // ----------- Decay periods ----------- //
    uint256 xAllocationsDecayPeriod; // Decay period for xAllocations in number of cycles
    uint256 vote2EarnDecayPeriod; // Decay period for vote2Earn in number of cycles
    // ----------- Emissions ----------- //
    uint256 initialXAppAllocation; // Initial emissions for xAllocations scaled with SCALING_FACTOR
    uint256 treasuryPercentage; // Percentage of total allocation for treasury (in percentage)
    uint256 lastEmissionBlock; // Block number for last emissions
    mapping(uint256 => Emission) emissions; // Past emissions for each distributed cycle
    uint256 totalEmissions; // Total emissions distributed
  }

  /// @dev Storage slot for the EmissionsStorage struct
  // keccak256(abi.encode(uint256(keccak256("b3tr.storage.Emissions")) - 1)) & ~bytes32(uint256(0xff))
  bytes32 private constant EmissionsStorageLocation =
    0xa3a4dbdafa3539d2a7f76379fff3516428de5d09ad2bbe195434cac5e7193900;

  /// @dev Retrieves the stored `EmissionsStorage` from its designated slot
  function _getEmissionsStorage() private pure returns (EmissionsStorage storage $) {
    assembly {
      $.slot := EmissionsStorageLocation
    }
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  /// @notice Initializes the contract with specific operational parameters for emissions management
  /// @dev Sets up the initial configurations including token addresses, allocation destinations, cycle parameters, and decay mechanics
  /// @param data A struct containing all necessary initialization data:
  ///  - minter: Address with the minter role who can initiate token distributions
  ///  - admin: Address with administrative rights
  ///  - upgrader: Address authorized to upgrade the contract
  ///  - b3trAddress: Contract address of the B3TR token
  ///  - destinations: Array of addresses for emissions allocations: [XAllocations, Vote2Earn, Treasury, Migration]
  ///  - initialXAppAllocation: Initial amount of tokens allocated for XAllocations
  ///  - cycleDuration: Duration of each emission cycle in blocks
  ///  - decaySettings: Array with decay rates and periods [XAllocations Decay Rate, Vote2Earn Decay Rate, XAllocations Decay Period, Vote2Earn Decay Period]
  ///  - treasuryPercentage: Percentage of total emissions allocated to the treasury
  ///  - maxVote2EarnDecay: Maximum allowable decay rate for Vote2Earn allocations to ensure sustainability
  ///  - migrationAmount: Amount of tokens seed the migration account with
  function initialize(InitializationData memory data) external initializer {
    // Assertions
    require(data.destinations.length == 4, "Emissions: Invalid destinations input length. Expected 4.");
    require(data.initialXAppAllocation > 0, "Emissions: Initial xApp allocation must be greater than 0");
    require(data.cycleDuration > 0, "Emissions: Cycle duration must be greater than 0");
    require(data.decaySettings.length == 4, "Emissions: Invalid decay settings input length. Expected 4.");
    require(
      data.treasuryPercentage > 0 && data.treasuryPercentage <= 10000,
      "Emissions: Treasury percentage must be between 1 and 10000"
    );
    require(
      data.decaySettings[0] > 0 && data.decaySettings[0] <= 100,
      "Emissions: xAllocations decay must be between 1 and 100"
    );
    require(
      data.decaySettings[1] > 0 && data.decaySettings[1] <= 100,
      "Emissions: vote2Earn decay must be between 1 and 100"
    );
    require(data.decaySettings[2] > 0, "Emissions: xAllocations decay delay must be greater than 0");
    require(data.decaySettings[3] > 0, "Emissions: vote2Earn decay delay must be greater than 0");
    require(
      data.maxVote2EarnDecay > 0 && data.maxVote2EarnDecay <= 100,
      "Emissions: Max vote2Earn decay must be between 0 and 100"
    );

    require(data.destinations[0] != address(0), "Emissions: XAllocations destination cannot be zero address");
    require(data.destinations[1] != address(0), "Emissions: Vote2Earn destination cannot be zero address");
    require(data.destinations[2] != address(0), "Emissions: Treasury destination cannot be zero address");

    require(data.admin != address(0), "Emissions: Admin address cannot be zero address");

    __AccessControl_init();
    __ReentrancyGuard_init();
    __UUPSUpgradeable_init();

    EmissionsStorage storage $ = _getEmissionsStorage();

    // Set B3TR token contract
    $.b3tr = IB3TR(data.b3trAddress);

    // Set destinations
    $._xAllocations = data.destinations[0];
    $._vote2Earn = data.destinations[1];
    $._treasury = data.destinations[2];

    // Migration
    $._migration = data.destinations[3];
    $._migrationAmount = data.migrationAmount;

    // Set cycle duration
    $.cycleDuration = data.cycleDuration;

    // Set decay settings
    $.xAllocationsDecay = data.decaySettings[0];
    $.vote2EarnDecay = data.decaySettings[1];
    $.xAllocationsDecayPeriod = data.decaySettings[2];
    $.vote2EarnDecayPeriod = data.decaySettings[3];

    // Set initial emissions
    $.initialXAppAllocation = data.initialXAppAllocation;

    // Set treasury percentage
    $.treasuryPercentage = data.treasuryPercentage;

    // Set max vote2Earn decay
    $.maxVote2EarnDecay = data.maxVote2EarnDecay;

    // Set roles
    _grantRole(DEFAULT_ADMIN_ROLE, data.admin);
    _grantRole(MINTER_ROLE, data.minter);
    _grantRole(UPGRADER_ROLE, data.upgrader);
    _grantRole(CONTRACTS_ADDRESS_MANAGER_ROLE, data.contractsAddressManager);
    _grantRole(DECAY_SETTINGS_MANAGER_ROLE, data.decaySettingsManager);
  }

  /// @notice Authorized upgrading of the contract implementation
  /// @dev This function can only be called by addresses with the UPGRADER_ROLE
  /// @param newImplementation Address of the new contract implementation
  function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

  /// @notice Handles the bootstrapping of the initial emission cycle.
  /// @dev This function can only be called by addresses with the MINTER_ROLE and only when the next cycle is 0.
  function bootstrap() external onlyRole(MINTER_ROLE) nonReentrant {
    EmissionsStorage storage $ = _getEmissionsStorage();
    require($.nextCycle == 0, "Emissions: Can only bootstrap emissions when next cycle = 0");
    $.nextCycle++;

    // Calculate initial emissions
    uint256 initialVote2EarnAllocation = _calculateVote2EarnAmount();
    uint256 initialTreasuryAllocation = _calculateTreasuryAmount();

    // Mint initial allocations
    $.emissions[$.nextCycle] = Emission($.initialXAppAllocation, initialVote2EarnAllocation, initialTreasuryAllocation);
    $.totalEmissions +=
      $.initialXAppAllocation +
      initialVote2EarnAllocation +
      initialTreasuryAllocation +
      $._migrationAmount;
    $.b3tr.mint($._xAllocations, $.initialXAppAllocation);
    $.b3tr.mint($._vote2Earn, initialVote2EarnAllocation);
    $.b3tr.mint($._treasury, initialTreasuryAllocation);
    $.b3tr.mint($._migration, $._migrationAmount);

    emit EmissionDistributed(
      $.nextCycle,
      $.initialXAppAllocation,
      initialVote2EarnAllocation,
      initialTreasuryAllocation
    );
  }

  /// @notice Starts the emission process after the initial bootstrap.
  /// @dev This function can only be called by addresses with the MINTER_ROLE and only when the next cycle is 1.
  function start() external onlyRole(MINTER_ROLE) nonReentrant {
    EmissionsStorage storage $ = _getEmissionsStorage();
    require($.b3tr.paused() == false, "Emissions: B3TR token is paused");
    require($.nextCycle == 1, "Emissions: Can only start emissions when next cycle = 1");

    $.lastEmissionBlock = block.number;

    $.xAllocationsGovernor.startNewRound();

    $.nextCycle++;
  }

  /// @notice Distributes the tokens for the current cycle, calculates allocations based on decay rates.
  function distribute() external nonReentrant {
    EmissionsStorage storage $ = _getEmissionsStorage();
    require($.nextCycle > 1, "Emissions: Please start emissions first");
    require(isNextCycleDistributable(), "Emissions: Next cycle not started yet");

    // Mint emissions for current cycle
    uint256 xAllocationsAmount = _calculateNextXAllocation();
    uint256 vote2EarnAmount = _calculateVote2EarnAmount();
    uint256 treasuryAmount = _calculateTreasuryAmount();

    require(
      xAllocationsAmount + vote2EarnAmount + treasuryAmount <= getRemainingEmissions(),
      "Emissions: emissions would exceed B3TR supply cap"
    );

    $.lastEmissionBlock = block.number;
    $.emissions[$.nextCycle] = Emission(xAllocationsAmount, vote2EarnAmount, treasuryAmount);
    $.totalEmissions += xAllocationsAmount + vote2EarnAmount + treasuryAmount;

    $.b3tr.mint($._xAllocations, xAllocationsAmount);
    $.b3tr.mint($._vote2Earn, vote2EarnAmount);
    $.b3tr.mint($._treasury, treasuryAmount);

    $.xAllocationsGovernor.startNewRound();

    emit EmissionDistributed($.nextCycle, xAllocationsAmount, vote2EarnAmount, treasuryAmount);
    $.nextCycle++;
  }

  // ------ Emissions calculations ------ //

  /// @notice Calculates the token allocation for XAllocations for the upcoming cycle, taking into account decay rates
  /// @dev Calculates emissions based on the previous cycle's emissions and applies decay if a new decay period has started
  /// @dev If it's the first cycle, returns the initial allocation
  /// @return uint256 The calculated number of tokens for the next cycle
  function _calculateNextXAllocation() internal view returns (uint256) {
    EmissionsStorage storage $ = _getEmissionsStorage();

    // If this is the first cycle, return the initial amount
    if ($.nextCycle < 2) {
      return initialXAppAllocation();
    }

    // Get emissions from the previous cycle
    uint256 lastCycleEmissions = $.emissions[$.nextCycle - 1].xAllocations * SCALING_FACTOR;

    // Check if we need to decay again by getting the modulus
    if (($.nextCycle - 1) % $.xAllocationsDecayPeriod == 0) {
      lastCycleEmissions = (lastCycleEmissions * (100 - $.xAllocationsDecay)) / 100;
    }
    return lastCycleEmissions / SCALING_FACTOR;
  }

  /// @notice Calculates the number of decay periods that have passed since the start of the emissions
  /// @dev Used to determine how many times the decay rate should be applied to the Vote2Earn emissions
  /// @dev The number of decay periods is calculated as follows: `number of decay periods = floor(number of periods / decay period)`
  /// @return uint256 The number of decay periods since the start of emissions
  function _calculateVote2EarnDecayPeriods() internal view returns (uint256) {
    EmissionsStorage storage $ = _getEmissionsStorage();

    require($.nextCycle > 0, "Emissions: Invalid cycle number");
    if ($.nextCycle == 1) {
      return 0;
    }

    return ($.nextCycle - 1) / $.vote2EarnDecayPeriod;
  }

  /// @notice Calculates the decay percentage for Vote2Earn allocations for the next cycle
  /// @dev The decay percentage is determined by the elapsed decay periods and the specified decay rate, capped at a maximum decay rate
  /// @dev The decay percentage is calculated as follows: `decay percentage = decay rate * number of decay periods`
  /// @dev The decay percentage is capped at a maximum value to ensure sustainability
  /// @return uint256 The calculated decay percentage for the next cycle
  function _calculateVote2EarnDecayPercentage() internal view returns (uint256) {
    EmissionsStorage storage $ = _getEmissionsStorage();
    uint256 vote2earnDecayPeriods = _calculateVote2EarnDecayPeriods();

    uint256 percentageToDecay = $.vote2EarnDecay * vote2earnDecayPeriods;

    return percentageToDecay > $.maxVote2EarnDecay ? $.maxVote2EarnDecay : percentageToDecay;
  }

  /// @notice Calculates the token allocation for Vote2Earn for the upcoming cycle
  /// @dev Applies the calculated decay percentage to the XAllocation from the upcoming cycle to determine Vote2Earn allocation
  /// @return uint256 The calculated number of tokens for Vote2Earn for the next cycle
  function _calculateVote2EarnAmount() internal view returns (uint256) {
    uint256 percentageToDecay = _calculateVote2EarnDecayPercentage();

    uint256 scaledXAllocation = _calculateNextXAllocation() * SCALING_FACTOR;

    uint256 vote2EarnScaled = (scaledXAllocation * (100 - percentageToDecay)) / 100;

    return vote2EarnScaled / SCALING_FACTOR;
  }

  /// @notice Calculates the token allocation for the Treasury based on the total allocations to XAllocations and Vote2Earn
  /// @dev Treasury gets a percentage of the combined XAllocations and Vote2Earn amounts, adjusted by the treasury percentage
  /// @return unit256 The calculated number of tokens for the Treasury for the next cycle
  function _calculateTreasuryAmount() internal view returns (uint256) {
    EmissionsStorage storage $ = _getEmissionsStorage();
    uint256 scaledAllocations = (_calculateNextXAllocation() + _calculateVote2EarnAmount()) * SCALING_FACTOR;
    uint256 treasuryAmount = (scaledAllocations * $.treasuryPercentage) / 10000;

    return treasuryAmount / SCALING_FACTOR;
  }

  // ----------- Getters ----------- //

  /// @notice Retrieves the XAllocation amount for a specified cycle
  /// @dev Returns the allocated amount if the cycle has been distributed, otherwise calculates the expected allocation
  /// @param cycle The cycle number to query
  /// @return uint256 The amount of XAllocations for the specified cycle
  function getXAllocationAmount(uint256 cycle) public view returns (uint256) {
    EmissionsStorage storage $ = _getEmissionsStorage();

    require(cycle <= $.nextCycle, "Emissions: Cycle not reached yet");
    return isCycleDistributed(cycle) ? $.emissions[cycle].xAllocations : _calculateNextXAllocation();
  }

  /// @notice Retrieves the Vote2Earn allocation for a specified cycle
  /// @dev Returns the allocated amount if the cycle has been distributed, otherwise calculates the expected allocation
  /// @param cycle The cycle number to query
  /// @return uint256 The amount of Vote2Earn for the specified cycle
  function getVote2EarnAmount(uint256 cycle) public view returns (uint256) {
    EmissionsStorage storage $ = _getEmissionsStorage();

    require(cycle <= $.nextCycle, "Emissions: Cycle not reached yet");
    return isCycleDistributed(cycle) ? $.emissions[cycle].vote2Earn : _calculateVote2EarnAmount();
  }

  /// @notice Retrieves the Treasury allocation for a specified cycle
  /// @dev Returns the allocated amount if the cycle has been distributed, otherwise calculates the expected allocation
  /// @param cycle The cycle number to query
  /// @return uint256 The amount of Treasury allocation for the specified cycle
  function getTreasuryAmount(uint256 cycle) public view returns (uint256) {
    EmissionsStorage storage $ = _getEmissionsStorage();

    require(cycle <= $.nextCycle, "Emissions: Cycle not reached yet");
    return isCycleDistributed(cycle) ? $.emissions[cycle].treasury : _calculateTreasuryAmount();
  }

  /// @notice Checks if a specific cycle's allocations have been distributed
  /// @param cycle The cycle number to check
  /// @return True if the cycle has been distributed, false otherwise
  function isCycleDistributed(uint256 cycle) public view returns (bool) {
    EmissionsStorage storage $ = _getEmissionsStorage();
    return $.emissions[cycle].xAllocations != 0;
  }

  /// @notice Determines if a specific cycle has ended
  /// @param cycle The cycle number to check
  /// @return True if the cycle has ended, false otherwise
  function isCycleEnded(uint256 cycle) public view returns (bool) {
    require(cycle <= getCurrentCycle(), "Emissions: Cycle not reached yet");

    if (cycle < getCurrentCycle()) {
      return true;
    }

    EmissionsStorage storage $ = _getEmissionsStorage();
    return block.number >= $.lastEmissionBlock + $.cycleDuration;
  }

  /// @notice Retrieves the current cycle number
  /// @dev The current cycle is the next cycle minus one
  /// @return uint256 The current cycle number
  function getCurrentCycle() public view returns (uint256) {
    EmissionsStorage storage $ = _getEmissionsStorage();
    require($.nextCycle > 0, "Emissions: not bootstrapped yet");
    return $.nextCycle - 1;
  }

  /// @notice Retrieves the block number when the next cycle will start
  /// @return uint256 The starting block number of the next cycle
  function getNextCycleBlock() public view returns (uint256) {
    EmissionsStorage storage $ = _getEmissionsStorage();
    return $.lastEmissionBlock + $.cycleDuration;
  }

  /// @notice Checks if the next cycle can start based on the block number
  /// @return True if the next cycle can be started, false otherwise
  function isNextCycleDistributable() public view returns (bool) {
    EmissionsStorage storage $ = _getEmissionsStorage();
    return block.number >= $.lastEmissionBlock + $.cycleDuration;
  }

  /// @notice Calculates the remaining emissions available for distribution
  /// @return uint256 The total number of tokens still available for emission
  function getRemainingEmissions() public view returns (uint256) {
    EmissionsStorage storage $ = _getEmissionsStorage();
    return $.b3tr.cap() - $.totalEmissions;
  }

  /// @notice Returns the address of the Treasury
  function treasury() public view returns (address) {
    return _getEmissionsStorage()._treasury;
  }

  /// @notice Returns the address of the Vote2Earn allocation
  function vote2Earn() public view returns (address) {
    return _getEmissionsStorage()._vote2Earn;
  }

  /// @notice Returns the address for XAllocations
  function xAllocations() public view returns (address) {
    return _getEmissionsStorage()._xAllocations;
  }

  /// @notice Returns the B3TR contract
  function b3tr() public view returns (IB3TR) {
    return _getEmissionsStorage().b3tr;
  }

  /// @notice Returns the XAllocations Governance contract
  function xAllocationsGovernor() public view returns (IXAllocationVotingGovernorV1) {
    return _getEmissionsStorage().xAllocationsGovernor;
  }

  /// @notice Retrieves the cycle duration in blocks
  function cycleDuration() public view returns (uint256) {
    return _getEmissionsStorage().cycleDuration;
  }

  /// @notice Retrieves the block number of the next emission cycle
  /// @return uint256 The block number of the next cycle
  function nextCycle() public view returns (uint256) {
    return _getEmissionsStorage().nextCycle;
  }

  /// @notice Retrieves the current decay rate for XAllocations
  /// @return uint256 The decay rate as a percentage
  function xAllocationsDecay() public view returns (uint256) {
    return _getEmissionsStorage().xAllocationsDecay;
  }

  /// @notice Retrieves the current decay rate for Vote2Earn allocations
  /// @return uint256 The decay rate as a percentage
  function vote2EarnDecay() public view returns (uint256) {
    return _getEmissionsStorage().vote2EarnDecay;
  }

  /// @notice Retrieves the maximum allowed decay rate for Vote2Earn
  /// @return uint256 The maximum decay rate as a percentage
  function maxVote2EarnDecay() public view returns (uint256) {
    return _getEmissionsStorage().maxVote2EarnDecay;
  }

  /// @notice Retrieves the decay period for XAllocations
  /// @return uint256 The number of blocks between decay periods
  function xAllocationsDecayPeriod() public view returns (uint256) {
    return _getEmissionsStorage().xAllocationsDecayPeriod;
  }

  /// @notice Retrieves the decay period for Vote2Earn allocations
  /// @return uint256 The number of cycles between decay applications
  function vote2EarnDecayPeriod() public view returns (uint256) {
    return _getEmissionsStorage().vote2EarnDecayPeriod;
  }

  /// @notice Retrieves the initial allocation for XAllocations at the start of the first cycle
  /// @return uint256 The amount of tokens initially allocated
  function initialXAppAllocation() public view returns (uint256) {
    return _getEmissionsStorage().initialXAppAllocation;
  }

  /// @notice Retrieves the percentage of total emissions allocated to the Treasury
  /// @return uint256 The treasury percentage
  function treasuryPercentage() public view returns (uint256) {
    return _getEmissionsStorage().treasuryPercentage;
  }

  /// @notice Retrieves the block number when the last emission occurred
  /// @return uint256 The block number of the last emission
  function lastEmissionBlock() public view returns (uint256) {
    return _getEmissionsStorage().lastEmissionBlock;
  }

  /// @notice Retrieves the total amount of emissions that have been distributed across all cycles
  /// @return uint256 The total emissions distributed
  function totalEmissions() public view returns (uint256) {
    return _getEmissionsStorage().totalEmissions;
  }

  /// @notice Retrieves the emission details for a specific cycle
  /// @param cycle The cycle number to query
  /// @return Emission A struct containing the allocations for XAllocations, Vote2Earn, and Treasury
  function emissions(uint256 cycle) public view returns (Emission memory) {
    return _getEmissionsStorage().emissions[cycle];
  }

  /// @notice Retrieves the current version of the contract
  /// @dev This function is used to identify the version of the contract and should be overridden in each new version
  /// @return The version of the contract
  function version() public pure virtual returns (string memory) {
    return "1";
  }

  // ----------- Setters ----------- //

  /// @notice Sets the address for XAllocations
  /// @dev Requires admin privileges and a non-zero address
  /// @param xAllocationAddress The new address to set for XAllocations
  function setXallocationsAddress(address xAllocationAddress) public onlyRole(CONTRACTS_ADDRESS_MANAGER_ROLE) {
    require(xAllocationAddress != address(0), "Emissions: xAllocationAddress cannot be the zero address");
    EmissionsStorage storage $ = _getEmissionsStorage();
    emit XAllocationsAddressUpdated(xAllocationAddress, $._xAllocations);
    $._xAllocations = xAllocationAddress;
  }

  /// @notice Sets the address for Vote2Earn allocations
  /// @dev Requires admin privileges and a non-zero address
  /// @param vote2EarnAddress The new address to set for Vote2Earn
  function setVote2EarnAddress(address vote2EarnAddress) public onlyRole(CONTRACTS_ADDRESS_MANAGER_ROLE) {
    require(vote2EarnAddress != address(0), "Emissions: vote2EarnAddress cannot be the zero address");
    EmissionsStorage storage $ = _getEmissionsStorage();
    emit Vote2EarnAddressUpdated(vote2EarnAddress, $._vote2Earn);
    $._vote2Earn = vote2EarnAddress;
  }

  /// @notice Sets the address for the Treasury
  /// @dev Requires admin privileges and a non-zero address
  /// @param treasuryAddress The new address to set for the Treasury
  function setTreasuryAddress(address treasuryAddress) public onlyRole(CONTRACTS_ADDRESS_MANAGER_ROLE) {
    require(treasuryAddress != address(0), "Emissions: treasuryAddress cannot be the zero address");
    EmissionsStorage storage $ = _getEmissionsStorage();
    emit TreasuryAddressUpdated(treasuryAddress, $._treasury);
    $._treasury = treasuryAddress;
  }

  /// @notice Sets the duration of each emission cycle
  /// @dev Requires admin privileges and a duration greater than 0
  /// @param _cycleDuration The duration of the cycle in blocks
  function setCycleDuration(uint256 _cycleDuration) public onlyRole(DECAY_SETTINGS_MANAGER_ROLE) {
    require(_cycleDuration > 0, "Emissions: Cycle duration must be greater than 0");
    EmissionsStorage storage $ = _getEmissionsStorage();
    require(
      IXAllocationVotingGovernorV1($.xAllocationsGovernor).votingPeriod() < _cycleDuration,
      "Emissions: Voting period must be less than cycle duration"
    );
    emit EmissionCycleDurationUpdated(_cycleDuration, $.cycleDuration);
    $.cycleDuration = _cycleDuration;
  }

  /// @notice Sets the decay rate for XAllocations
  /// @dev Requires admin privileges
  /// @param _decay Decay rate as a percentage
  function setXAllocationsDecay(uint256 _decay) public onlyRole(DECAY_SETTINGS_MANAGER_ROLE) {
    require(_decay <= 100, "Emissions: xAllocations decay must be between 0 and 100");
    EmissionsStorage storage $ = _getEmissionsStorage();
    emit XAllocationsDecayUpdated(_decay, $.xAllocationsDecay);
    $.xAllocationsDecay = _decay;
  }

  /// @notice Sets the decay rate for Vote2Earn allocations
  /// @dev Requires admin privileges
  /// @param _decay Decay rate as a percentage
  function setVote2EarnDecay(uint256 _decay) public onlyRole(DECAY_SETTINGS_MANAGER_ROLE) {
    require(_decay <= 100, "Emissions: vote2Earn decay must be between 0 and 100");
    EmissionsStorage storage $ = _getEmissionsStorage();
    emit Vote2EarnDecayUpdated(_decay, $.vote2EarnDecay);
    $.vote2EarnDecay = _decay;
  }

  /// @notice Sets the number of cycles after which the XAllocations decay rate is applied
  /// @dev Requires admin privileges and a period greater than 0
  /// @param _period Number of cycles
  function setXAllocationsDecayPeriod(uint256 _period) public onlyRole(DECAY_SETTINGS_MANAGER_ROLE) {
    require(_period > 0, "Emissions: xAllocations decay period must be greater than 0");
    EmissionsStorage storage $ = _getEmissionsStorage();
    emit XAllocationsDecayPeriodUpdated(_period, $.xAllocationsDecayPeriod);
    $.xAllocationsDecayPeriod = _period;
  }

  /// @notice Sets the number of cycles after which the Vote2Earn decay rate is applied
  /// @dev Requires admin privileges and a period greater than 0
  /// @param _period Number of cycles
  function setVote2EarnDecayPeriod(uint256 _period) public onlyRole(DECAY_SETTINGS_MANAGER_ROLE) {
    require(_period > 0, "Emissions: vote2Earn decay period must be greater than 0");
    EmissionsStorage storage $ = _getEmissionsStorage();
    emit Vote2EarnDecayPeriodUpdated(_period, $.vote2EarnDecayPeriod);
    $.vote2EarnDecayPeriod = _period;
  }

  /// @notice Sets the treasury percentage allocation
  /// @dev The treasury percentage is a value between 0 and 10000, scaled by 100 to allow fractional percentages (87.5% for example)
  /// @dev Requires admin privileges
  /// @param _percentage Treasury percentage (scaled by 100)
  function setTreasuryPercentage(uint256 _percentage) public onlyRole(DECAY_SETTINGS_MANAGER_ROLE) {
    require(_percentage <= 10000, "Emissions: Treasury percentage must be between 0 and 10000");
    EmissionsStorage storage $ = _getEmissionsStorage();
    emit TreasuryPercentageUpdated(_percentage, $.treasuryPercentage);
    $.treasuryPercentage = _percentage;
  }

  /// @notice Sets the maximum decay rate for Vote2Earn allocations
  /// @dev Requires admin privileges and a decay rate between 0 and 100
  /// @param _maxVote2EarnDecay Maximum decay rate as a percentage
  function setMaxVote2EarnDecay(uint256 _maxVote2EarnDecay) public onlyRole(DECAY_SETTINGS_MANAGER_ROLE) {
    require(_maxVote2EarnDecay <= 100, "Emissions: Max vote2Earn decay must be between 0 and 100");
    EmissionsStorage storage $ = _getEmissionsStorage();
    emit MaxVote2EarnDecayUpdated(_maxVote2EarnDecay, $.maxVote2EarnDecay);
    $.maxVote2EarnDecay = _maxVote2EarnDecay;
  }

  /// @notice Sets the address for the XAllocations Governor
  /// @dev Requires that the voting period of the governor is less than the cycle duration
  /// @dev Requires admin privileges and a non-zero address
  /// @param _xAllocationsGovernor The new XAllocations Governor address
  function setXAllocationsGovernorAddress(
    address _xAllocationsGovernor
  ) public onlyRole(CONTRACTS_ADDRESS_MANAGER_ROLE) {
    require(_xAllocationsGovernor != address(0), "Emissions: _xAllocationsGovernor cannot be the zero address");
    require(
      IXAllocationVotingGovernorV1(_xAllocationsGovernor).votingPeriod() < cycleDuration(),
      "Emissions: Voting period must be less than cycle duration"
    );

    EmissionsStorage storage $ = _getEmissionsStorage();
    emit XAllocationsGovernorAddressUpdated(_xAllocationsGovernor, address($.xAllocationsGovernor));
    $.xAllocationsGovernor = IXAllocationVotingGovernorV1(_xAllocationsGovernor);
  }
}

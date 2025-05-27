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
import "./interfaces/IGalaxyMember.sol";
import "./interfaces/IB3TRGovernor.sol";
import "./interfaces/IXAllocationVotingGovernor.sol";
import "./interfaces/IEmissions.sol";
import "./interfaces/IB3TR.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/utils/structs/Checkpoints.sol";
import "@openzeppelin/contracts/utils/types/Time.sol";

/**
 * @title VoterRewards
 * @author VeBetterDAO
 *
 * @notice This contract handles the rewards for voters in the VeBetterDAO ecosystem.
 * It calculates the rewards for voters based on their voting power and the level of their Galaxy Member NFT.
 *
 * @dev The contract is
 * - upgradeable using UUPSUpgradeable.
 * - using AccessControl to handle the admin and upgrader roles.
 * - using ReentrancyGuard to prevent reentrancy attacks.
 * - following the ERC-7201 standard for storage layout.
 *
 * Roles:
 * - DEFAULT_ADMIN_ROLE: The role that can add new admins and upgraders. It is also the role that can set scaling factor and the Galaxy Member level to multiplier mapping.
 * - UPGRADER_ROLE: The role that can upgrade the contract.
 * - VOTE_REGISTRAR_ROLE: The role that can register votes for rewards calculation.
 * - CONTRACTS_ADDRESS_MANAGER_ROLE: The role that can set the addresses of the contracts used by the VoterRewards contract.
 *
 * ------------------ Version 2 Changes ------------------
 * - Added quadratic rewarding disabled checkpoints to disable quadratic rewarding for a specific cycle.
 * - Added the clock function to get the current block number.
 * - Added functions to check if quadratic rewarding is disabled at a specific block number or for the current cycle.
 * - Added function to disable quadratic rewarding or re-enable it.
 *
 * ------------------ Version 3 Changes ------------------
 * - Added the ability to track if a Galaxy Member NFT has voted in a proposal.
 * - Added the ability to track if a Vechain node attached to a Galaxy Member NFT has voted in a proposal.
 * - Proposal Id is now required when registering votes instead of proposal snapshot.
 * - Core logic functions are now virtual allowing to be overridden through inheritance.
 */
contract VoterRewards is AccessControlUpgradeable, ReentrancyGuardUpgradeable, UUPSUpgradeable {
  using Checkpoints for Checkpoints.Trace208; // Checkpoints library for managing checkpoints of the selected level of the user

  /// @notice The role that can register votes for rewards calculation.
  bytes32 public constant VOTE_REGISTRAR_ROLE = keccak256("VOTE_REGISTRAR_ROLE");

  /// @notice The role that can upgrade the contract.
  bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

  /// @notice The role that can set the addresses of the contracts used by the VoterRewards contract.
  bytes32 public constant CONTRACTS_ADDRESS_MANAGER_ROLE = keccak256("CONTRACTS_ADDRESS_MANAGER_ROLE");

  /// @notice The scaling factor for the rewards calculation.
  uint256 public constant SCALING_FACTOR = 1e6;

  /// @custom:storage-location erc7201:b3tr.storage.VoterRewards
  struct VoterRewardsStorage {
    IGalaxyMember galaxyMember;
    IB3TR b3tr;
    IEmissions emissions;
    // level => percentage multiplier for the level of the GM NFT
    mapping(uint256 => uint256) levelToMultiplier;
    // cycle => total weighted votes in the cycle
    mapping(uint256 => uint256) cycleToTotal;
    // cycle => voter => total weighted votes for the voter in the cycle
    mapping(uint256 cycle => mapping(address voter => uint256 total)) cycleToVoterToTotal;
    // ----------------- V2 Additions ---------------- //
    // checkpoints for the quadratic rewarding status for each cycle
    Checkpoints.Trace208 quadraticRewardingDisabled;
    // --------------------------- V3 Additions --------------------------- //
    // proposalId => tokenId => hasVoted (keeps track of whether a galaxy member has voted in a proposal)
    mapping(uint256 proposalId => mapping(uint256 tokenId => bool)) proposalToGalaxyMemberToHasVoted;
    // proposalId => nodeId => hasVoted (keeps track of whether a vechain node has been used while attached to a galaxy member NFT when voting for a proposal)
    mapping(uint256 proposalId => mapping(uint256 nodeId => bool)) proposalToNodeToHasVoted;
  }

  // keccak256(abi.encode(uint256(keccak256("b3tr.storage.VoterRewards")) - 1)) & ~bytes32(uint256(0xff))
  bytes32 private constant VoterRewardsStorageLocation =
    0x114e7ffaaf205d38cd05b17b56f3357806ef2ce889cb4748445ae91cdfc37c00;

  /// @notice Get the VoterRewardsStorage struct from the specified storage slot specified by the VoterRewardsStorageLocation.
  function _getVoterRewardsStorage() internal pure returns (VoterRewardsStorage storage $) {
    assembly {
      $.slot := VoterRewardsStorageLocation
    }
  }

  /// @notice Emitted when a user registers their votes for rewards calculation.
  /// @param cycle - The cycle in which the votes were registered.
  /// @param voter- The address of the voter.
  /// @param votes - The number of votes cast by the voter.
  /// @param rewardWeightedVote - The reward-weighted vote power for the voter based on their voting power and GM NFT level.
  event VoteRegistered(uint256 indexed cycle, address indexed voter, uint256 votes, uint256 rewardWeightedVote);

  /// @notice Emitted when a user claims their rewards.
  /// @param cycle - The cycle in which the rewards were claimed.
  /// @param voter - The address of the voter.
  /// @param reward - The amount of B3TR reward claimed by the voter.
  event RewardClaimed(uint256 indexed cycle, address indexed voter, uint256 reward);

  /// @notice Emitted when the Galaxy Member contract address is set.
  /// @param newAddress - The address of the new Galaxy Member contract.
  /// @param oldAddress - The address of the old Galaxy Member contract.
  event GalaxyMemberAddressUpdated(address indexed newAddress, address indexed oldAddress);

  /// @notice Emitted when the Emissions contract address is set.
  /// @param newAddress - The address of the new Emissions contract.
  /// @param oldAddress - The address of the old Emissions contract.
  event EmissionsAddressUpdated(address indexed newAddress, address indexed oldAddress);

  /// @notice Emitted when the level to multiplier mapping is set.
  /// @param level - The level of the Galaxy Member NFT.
  /// @param multiplier - The percentage multiplier for the level of the Galaxy Member NFT.
  event LevelToMultiplierSet(uint256 indexed level, uint256 multiplier);

  /// @notice Emits true if quadratic rewarding is disabled, false otherwise.
  /// @param disabled - The flag to enable or disable quadratic rewarding.
  event QuadraticRewardingToggled(bool indexed disabled);

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  /// @notice Initialize the VoterRewards contract.
  /// @param admin - The address of the admin.
  /// @param upgrader - The address of the upgrader.
  /// @param contractsAddressManager - The address of the contract address manager.
  /// @param _emissions - The address of the emissions contract.
  /// @param _galaxyMember - The address of the Galaxy Member contract.
  /// @param _b3tr - The address of the B3TR token contract.
  /// @param levels - The levels of the Galaxy Member NFTs.
  /// @param multipliers  - The multipliers for the levels of the Galaxy Member NFTs.
  function initialize(
    address admin,
    address upgrader,
    address contractsAddressManager,
    address _emissions,
    address _galaxyMember,
    address _b3tr,
    uint256[] memory levels,
    uint256[] memory multipliers
  ) external initializer {
    require(_galaxyMember != address(0), "VoterRewards: _galaxyMember cannot be the zero address");
    require(_emissions != address(0), "VoterRewards: emissions cannot be the zero address");
    require(_b3tr != address(0), "VoterRewards: _b3tr cannot be the zero address");

    require(levels.length > 0, "VoterRewards: levels must have at least one element");
    require(levels.length == multipliers.length, "VoterRewards: levels and multipliers must have the same length");

    __AccessControl_init();
    __ReentrancyGuard_init();
    __UUPSUpgradeable_init();

    VoterRewardsStorage storage $ = _getVoterRewardsStorage();

    $.galaxyMember = IGalaxyMember(_galaxyMember);
    $.b3tr = IB3TR(_b3tr);
    $.emissions = IEmissions(_emissions);

    // Set the level to multiplier mapping.
    for (uint256 i; i < levels.length; i++) {
      $.levelToMultiplier[levels[i]] = multipliers[i];
    }

    require(admin != address(0), "VoterRewards: admin cannot be the zero address");
    _grantRole(DEFAULT_ADMIN_ROLE, admin);
    _grantRole(UPGRADER_ROLE, upgrader);
    _grantRole(CONTRACTS_ADDRESS_MANAGER_ROLE, contractsAddressManager);
  }

  /// @notice Upgrade the implementation of the VoterRewards contract.
  /// @dev Only the address with the UPGRADER_ROLE can call this function.
  /// @param newImplementation - The address of the new implementation contract.
  function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

  /// @notice Register the votes of a user for rewards calculation.
  /// @dev Quadratic rewarding is used to reward users with quadratic-weight based on their voting power and the level of their Galaxy Member NFT.
  /// @param proposalId - The ID of the proposal.
  /// @param voter - The address of the voter.
  /// @param votes - The number of votes cast by the voter.
  /// @param votePower - The square root of the total votes cast by the voter.
  function registerVote(
    uint256 proposalId,
    address voter,
    uint256 votes,
    uint256 votePower
  ) public virtual onlyRole(VOTE_REGISTRAR_ROLE) {
    // If votePower is zero, exit the function to avoid unnecessary computations.
    if (votePower == 0) {
      return;
    }

    require(proposalId != 0, "VoterRewards: proposalId cannot be 0");
    require(voter != address(0), "VoterRewards: voter cannot be the zero address");

    VoterRewardsStorage storage $ = _getVoterRewardsStorage();

    uint256 selectedGMNFT = $.galaxyMember.getSelectedTokenId(voter);

    // Get the current cycle number.
    uint256 cycle = $.emissions.getCurrentCycle();

    // Determine the reward multiplier based on the GM NFT level and if the GM NFT or Vechain node attached have already voted on this proposal.
    uint256 multiplier = getMultiplier(selectedGMNFT, proposalId);

    // Set the scaled vote power to the total votes cast by the voter.
    uint256 scaledVotePower = votes;

    // Get the block number the emission cycle started.
    uint48 emissionCycleStartBlock = SafeCast.toUint48($.emissions.lastEmissionBlock());

    // If quadratic rewarding is enabled, scale the vote power by 1e9 to counteract the square root operation on 1e18. (0: enabled, 1: disabled)
    if ($.quadraticRewardingDisabled.upperLookupRecent(emissionCycleStartBlock) == 0) {
      scaledVotePower = votePower * 1e9;
    }

    // Calculate the weighted vote power for rewards, adjusting vote power with the level-based multiplier.
    // votePower is the square root of the total votes cast by the voter.
    uint256 rewardWeightedVote = scaledVotePower + ((scaledVotePower * multiplier) / 100); // Adjusted vote power used for rewards calculation.

    // Update the total reward-weighted votes in the cycle.
    $.cycleToTotal[cycle] += rewardWeightedVote;

    // Record the reward-weighted vote power for the voter in the cycle.
    $.cycleToVoterToTotal[cycle][voter] += rewardWeightedVote;

    // Record that the GM NFT has voted in the proposal, if it exists.
    if (selectedGMNFT != 0) {
      $.proposalToGalaxyMemberToHasVoted[proposalId][selectedGMNFT] = true;
    }

    uint256 nodeIdAttached = $.galaxyMember.getNodeIdAttached(selectedGMNFT);

    // Record that the Vechain node attached to the GM NFT has voted in the proposal, if it exists.
    if (nodeIdAttached != 0) {
      $.proposalToNodeToHasVoted[proposalId][nodeIdAttached] = true;
    }

    // Emit an event to log the registration of the votes.
    emit VoteRegistered(cycle, voter, votes, rewardWeightedVote);
  }

  /// @notice Claim the rewards for a user in a specific cycle.
  /// @dev The rewards are claimed based on the reward-weighted votes of the user in the cycle.
  /// @param cycle - The cycle in which the rewards are claimed.
  /// @param voter - The address of the voter.
  function claimReward(uint256 cycle, address voter) public virtual nonReentrant {
    require(cycle > 0, "VoterRewards: cycle must be greater than 0");
    require(voter != address(0), "VoterRewards: voter cannot be the zero address");
    VoterRewardsStorage storage $ = _getVoterRewardsStorage();

    // Check if the cycle has ended before claiming rewards.
    require($.emissions.isCycleEnded(cycle), "VoterRewards: cycle must be ended");

    // Get the reward for the voter in the cycle.
    uint256 reward = getReward(cycle, voter);

    require(reward > 0, "VoterRewards: reward must be greater than 0");
    require($.b3tr.balanceOf(address(this)) >= reward, "VoterRewards: not enough B3TR in the contract to pay reward");

    // Reset the reward-weighted votes for the voter in the cycle.
    $.cycleToVoterToTotal[cycle][voter] = 0;

    // transfer reward to voter
    require($.b3tr.transfer(voter, reward), "VoterRewards: transfer failed");

    // Emit an event to log the reward claimed by the voter.
    emit RewardClaimed(cycle, voter, reward);
  }

  // ----------------- Getters ----------------- //

  /// @notice Get the reward multiplier for a user in a specific proposal.
  /// @param tokenId Id of the Galaxy Member NFT
  /// @param proposalId Id of the proposal
  function getMultiplier(uint256 tokenId, uint256 proposalId) public view virtual returns (uint256) {
    VoterRewardsStorage storage $ = _getVoterRewardsStorage();

    if (hasTokenVoted(tokenId, proposalId)) return 0;

    uint256 nodeIdAttached = $.galaxyMember.getNodeIdAttached(tokenId);

    if (hasNodeVoted(nodeIdAttached, proposalId)) return 0;

    uint256 gmNftLevel = $.galaxyMember.levelOf(tokenId);

    return $.levelToMultiplier[gmNftLevel];
  }

  /// @notice Check if a Vechain Node has voted in a proposal
  /// @param nodeId Id of the Vechain node
  /// @param proposalId Id of the proposal
  function hasNodeVoted(uint256 nodeId, uint256 proposalId) public view virtual returns (bool) {
    VoterRewardsStorage storage $ = _getVoterRewardsStorage();

    return $.proposalToNodeToHasVoted[proposalId][nodeId];
  }

  /// @notice Check if a Galaxy Member has voted in a proposal
  /// @param tokenId Id of the Galaxy Member NFT
  /// @param proposalId Id of the proposal
  function hasTokenVoted(uint256 tokenId, uint256 proposalId) public view virtual returns (bool) {
    VoterRewardsStorage storage $ = _getVoterRewardsStorage();

    return $.proposalToGalaxyMemberToHasVoted[proposalId][tokenId];
  }

  /// @notice Get the reward for a user in a specific cycle.
  /// @param cycle - The cycle in which the rewards are claimed.
  /// @param voter - The address of the voter.
  function getReward(uint256 cycle, address voter) public view virtual returns (uint256) {
    VoterRewardsStorage storage $ = _getVoterRewardsStorage();

    // Get the total reward-weighted votes for the voter in the cycle.
    uint256 total = $.cycleToVoterToTotal[cycle][voter];

    // If total is zero, return 0
    if (total == 0) {
      return 0;
    }

    // Get the total reward-weighted votes in the cycle.
    uint256 totalCycle = $.cycleToTotal[cycle];

    // If totalCycle is zero, return 0
    if (totalCycle == 0) {
      return 0;
    }

    // Get the emissions for voter rewards in the cycle.
    uint256 emissionsAmount = $.emissions.getVote2EarnAmount(cycle);

    // If emissionsAmount is zero, return 0
    if (emissionsAmount == 0) {
      return 0;
    }

    // Scale up the numerator before division to improve precision
    uint256 scaledNumerator = total * emissionsAmount * SCALING_FACTOR; // Scale by a factor of SCALING_FACTOR for precision
    uint256 reward = scaledNumerator / totalCycle;

    // Scale down the reward to the original scale
    return reward / SCALING_FACTOR;
  }

  /// @notice Get the total reward-weighted votes for a user in a specific cycle.
  /// @param cycle - The cycle in which the rewards are claimed.
  /// @param voter - The address of the voter.
  function cycleToVoterToTotal(uint256 cycle, address voter) external view returns (uint256) {
    VoterRewardsStorage storage $ = _getVoterRewardsStorage();
    return $.cycleToVoterToTotal[cycle][voter];
  }

  /// @notice Get the total reward-weighted votes in a specific cycle.
  /// @param cycle - The cycle in which the rewards are claimed.
  function cycleToTotal(uint256 cycle) external view returns (uint256) {
    VoterRewardsStorage storage $ = _getVoterRewardsStorage();
    return $.cycleToTotal[cycle];
  }

  /// @notice Get the reward multiplier for a specific level of the Galaxy Member NFT.
  /// @param level - The level of the Galaxy Member NFT.
  function levelToMultiplier(uint256 level) external view returns (uint256) {
    VoterRewardsStorage storage $ = _getVoterRewardsStorage();
    return $.levelToMultiplier[level];
  }

  /// @notice Get the Galaxy Member contract.
  function galaxyMember() external view returns (IGalaxyMember) {
    VoterRewardsStorage storage $ = _getVoterRewardsStorage();
    return $.galaxyMember;
  }

  /// @notice Get the Emissions contract.
  function emissions() external view returns (IEmissions) {
    VoterRewardsStorage storage $ = _getVoterRewardsStorage();
    return $.emissions;
  }

  /// @notice Get the B3TR token contract.
  function b3tr() external view returns (IB3TR) {
    VoterRewardsStorage storage $ = _getVoterRewardsStorage();
    return $.b3tr;
  }

  /// @notice Check if quadratic rewarding is disabled at a specific block number.
  /// @dev To check if quadratic rewarding was disabled for a cycle, use the block number the cycle started.
  /// @param blockNumber - The block number to check the quadratic rewarding status.
  /// @return true if quadratic rewarding is disabled, false otherwise.
  function isQuadraticRewardingDisabledAtBlock(uint48 blockNumber) public view returns (bool) {
    VoterRewardsStorage storage $ = _getVoterRewardsStorage();

    // Check if quadratic rewarding is enabled or disabled at the block number.
    return $.quadraticRewardingDisabled.upperLookupRecent(blockNumber) == 1; // 0: enabled, 1: disabled
  }

  /// @notice Check if quadratic rewarding is disabled for the current cycle.
  /// @return true if quadratic rewarding is disabled, false otherwise.
  function isQuadraticRewardingDisabledForCurrentCycle() public view returns (bool) {
    VoterRewardsStorage storage $ = _getVoterRewardsStorage();
    // Get the block number the emission cycle started.
    uint256 emissionCycleStartBlock = $.emissions.lastEmissionBlock();

    uint208 currentStatus = $.quadraticRewardingDisabled.upperLookupRecent(SafeCast.toUint48(emissionCycleStartBlock));

    // Check if quadratic rewarding is enabled or disabled for the current cycle.
    return currentStatus == 1; // 0: enabled, 1: disabled
  }

  // ----------------- Setters ----------------- //

  /// @notice Set the Galaxy Member contract.
  /// @param _galaxyMember - The address of the Galaxy Member contract.
  function setGalaxyMember(address _galaxyMember) public virtual onlyRole(CONTRACTS_ADDRESS_MANAGER_ROLE) {
    require(_galaxyMember != address(0), "VoterRewards: _galaxyMember cannot be the zero address");

    VoterRewardsStorage storage $ = _getVoterRewardsStorage();

    emit GalaxyMemberAddressUpdated(_galaxyMember, address($.galaxyMember));

    $.galaxyMember = IGalaxyMember(_galaxyMember);
  }

  /// @notice Set the Galaxy Member level to multiplier mapping.
  /// @param level - The level of the Galaxy Member NFT.
  /// @param multiplier - The percentage multiplier for the level of the Galaxy Member NFT.
  function setLevelToMultiplier(uint256 level, uint256 multiplier) public virtual onlyRole(DEFAULT_ADMIN_ROLE) {
    require(level > 0, "VoterRewards: level must be greater than 0");
    require(multiplier > 0, "VoterRewards: multiplier must be greater than 0");

    VoterRewardsStorage storage $ = _getVoterRewardsStorage();
    $.levelToMultiplier[level] = multiplier;

    emit LevelToMultiplierSet(level, multiplier);
  }

  /// @notice Set the Emmissions contract.
  /// @param _emissions - The address of the emissions contract.
  function setEmissions(address _emissions) public virtual onlyRole(CONTRACTS_ADDRESS_MANAGER_ROLE) {
    require(_emissions != address(0), "VoterRewards: emissions cannot be the zero address");

    VoterRewardsStorage storage $ = _getVoterRewardsStorage();

    emit EmissionsAddressUpdated(_emissions, address($.emissions));

    $.emissions = IEmissions(_emissions);
  }

  /// @notice Toggle quadratic rewarding for a specific cycle.
  /// @dev This function toggles the state of quadratic rewarding for a specific cycle.
  /// The state will flip between enabled and disabled each time the function is called.
  function toggleQuadraticRewarding() external onlyRole(DEFAULT_ADMIN_ROLE) {
    VoterRewardsStorage storage $ = _getVoterRewardsStorage();

    // Get the current status
    bool currentStatus = isQuadraticRewardingDisabledForCurrentCycle();

    // Toggle the status -> 0: enabled, 1: disabled
    $.quadraticRewardingDisabled.push(clock(), currentStatus ? 0 : 1);

    // Emit an event to log the new quadratic rewarding status.
    emit QuadraticRewardingToggled(!currentStatus);
  }

  /// @notice Returns the version of the contract
  /// @dev This should be updated every time a new version of implementation is deployed
  /// @return string The version of the contract
  function version() external pure virtual returns (string memory) {
    return "3";
  }

  /// @dev Clock used for flagging checkpoints.
  function clock() public view virtual returns (uint48) {
    return Time.blockNumber();
  }
}

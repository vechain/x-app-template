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

import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { IB3TR } from "../../interfaces/IB3TR.sol";
import { IX2EarnAppsV1 } from "../V1/interfaces/IX2EarnAppsV1.sol";
import { IX2EarnRewardsPoolV2 } from "./interfaces/IX2EarnRewardsPoolV2.sol";
import { IERC1155Receiver } from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title X2EarnRewardsPool
 * @dev This contract is used by x2Earn apps to reward users that performed sustainable actions.
 * The XAllocationPool contract or other contracts/users can deposit funds into this contract by specifying the app
 * that can access the funds.
 * Admins of x2EarnApps can withdraw funds from the rewards pool, whihch are sent to the team wallet.
 * Reward distributors of a x2Earn app can distribute rewards to users that performed sustainable actions or withdraw funds
 * to the team wallet.
 * The contract is upgradable through the UUPS proxy pattern and UPGRADER_ROLE can authorize the upgrade.
 */
contract X2EarnRewardsPoolV2 is
  IX2EarnRewardsPoolV2,
  UUPSUpgradeable,
  AccessControlUpgradeable,
  ReentrancyGuardUpgradeable
{
  bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
  bytes32 public constant CONTRACTS_ADDRESS_MANAGER_ROLE = keccak256("CONTRACTS_ADDRESS_MANAGER_ROLE");
  bytes32 public constant IMPACT_KEY_MANAGER_ROLE = keccak256("IMPACT_KEY_MANAGER_ROLE");

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  /// @custom:storage-location erc7201:b3tr.storage.X2EarnRewardsPool
  struct X2EarnRewardsPoolStorage {
    IB3TR b3tr;
    IX2EarnAppsV1 x2EarnApps;
    mapping(bytes32 appId => uint256) availableFunds; // Funds that the app can use to reward users
    mapping(string => uint256) impactKeyIndex; // Mapping from impact key to its index (1-based to distinguish from non-existent)
    string[] allowedImpactKeys; // Array storing impact keys
  }

  // keccak256(abi.encode(uint256(keccak256("b3tr.storage.X2EarnRewardsPool")) - 1)) & ~bytes32(uint256(0xff))
  bytes32 private constant X2EarnRewardsPoolStorageLocation =
    0x7c0dcc5654efea34bf150fefe2d7f927494d4026026590e81037cb4c7a9cdc00;

  function _getX2EarnRewardsPoolStorage() private pure returns (X2EarnRewardsPoolStorage storage $) {
    assembly {
      $.slot := X2EarnRewardsPoolStorageLocation
    }
  }

  function initialize(
    address _admin,
    address _contractsManagerAdmin,
    address _upgrader,
    IB3TR _b3tr,
    IX2EarnAppsV1 _x2EarnApps
  ) external initializer {
    require(_admin != address(0), "X2EarnRewardsPool: admin is the zero address");
    require(_contractsManagerAdmin != address(0), "X2EarnRewardsPool: contracts manager admin is the zero address");
    require(_upgrader != address(0), "X2EarnRewardsPool: upgrader is the zero address");
    require(address(_b3tr) != address(0), "X2EarnRewardsPool: b3tr is the zero address");
    require(address(_x2EarnApps) != address(0), "X2EarnRewardsPool: x2EarnApps is the zero address");

    __UUPSUpgradeable_init();
    __AccessControl_init();
    __ReentrancyGuard_init();

    _grantRole(DEFAULT_ADMIN_ROLE, _admin);
    _grantRole(UPGRADER_ROLE, _upgrader);
    _grantRole(CONTRACTS_ADDRESS_MANAGER_ROLE, _contractsManagerAdmin);

    X2EarnRewardsPoolStorage storage $ = _getX2EarnRewardsPoolStorage();
    $.b3tr = _b3tr;
    $.x2EarnApps = _x2EarnApps;
  }

  function initializeV2(address _impactKeyManager, string[] memory _initialImpactKeys) external reinitializer(2) {
    require(_impactKeyManager != address(0), "X2EarnRewardsPool: impactKeyManager is the zero address");
    require(_initialImpactKeys.length > 0, "X2EarnRewardsPool: initialImpactKeys is empty");

    _grantRole(IMPACT_KEY_MANAGER_ROLE, _impactKeyManager);

    X2EarnRewardsPoolStorage storage $ = _getX2EarnRewardsPoolStorage();

    for (uint256 i; i < _initialImpactKeys.length; i++) {
      _addImpactKey(_initialImpactKeys[i], $);
    }
  }

  // ---------- Modifiers ---------- //
  /**
   * @notice Modifier to check if the user has the required role or is the DEFAULT_ADMIN_ROLE
   * @param role - the role to check
   */
  modifier onlyRoleOrAdmin(bytes32 role) {
    if (!hasRole(role, msg.sender) && !hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
      revert("X2EarnRewardsPool: sender is not an admin nor has the required role");
    }
    _;
  }

  // ---------- Authorizers ---------- //

  function _authorizeUpgrade(address newImplementation) internal virtual override onlyRole(UPGRADER_ROLE) {}

  // ---------- Setters ---------- //

  /**
   * @dev See {IX2EarnRewardsPoolV1-deposit}
   */
  function deposit(uint256 amount, bytes32 appId) external returns (bool) {
    X2EarnRewardsPoolStorage storage $ = _getX2EarnRewardsPoolStorage();

    // check that app exists
    require($.x2EarnApps.appExists(appId), "X2EarnRewardsPool: app does not exist");

    // increase available amount for the app
    $.availableFunds[appId] += amount;

    // transfer tokens to this contract
    require($.b3tr.transferFrom(msg.sender, address(this), amount), "X2EarnRewardsPool: deposit transfer failed");

    emit NewDeposit(amount, appId, msg.sender);

    return true;
  }

  /**
   * @dev See {IX2EarnRewardsPoolV1-withdraw}
   */
  function withdraw(uint256 amount, bytes32 appId, string memory reason) external nonReentrant {
    X2EarnRewardsPoolStorage storage $ = _getX2EarnRewardsPoolStorage();

    require($.x2EarnApps.appExists(appId), "X2EarnRewardsPool: app does not exist");

    require(
      $.x2EarnApps.isAppAdmin(appId, msg.sender) || $.x2EarnApps.isRewardDistributor(appId, msg.sender),
      "X2EarnRewardsPool: not an app admin nor a reward distributor"
    );

    // check if the app has enough available funds to withdraw
    require($.availableFunds[appId] >= amount, "X2EarnRewardsPool: app has insufficient funds");

    // check if the contract has enough funds
    require($.b3tr.balanceOf(address(this)) >= amount, "X2EarnRewardsPool: insufficient funds on contract");

    // Get the team wallet address
    address teamWalletAddress = $.x2EarnApps.teamWalletAddress(appId);

    // transfer the rewards to the team wallet
    $.availableFunds[appId] -= amount;
    require($.b3tr.transfer(teamWalletAddress, amount), "X2EarnRewardsPool: Allocation transfer to app failed");

    emit TeamWithdrawal(amount, appId, teamWalletAddress, msg.sender, reason);
  }

  /**
   * @dev Distribute rewards to a user with a self provided proof.
   * @notice This function is deprecated and kept for backwards compatibility, will be removed in future versions.
   */
  function distributeRewardDeprecated(bytes32 appId, uint256 amount, address receiver, string memory proof) external {
    // emit event with provided json proof
    emit RewardDistributed(amount, appId, receiver, proof, msg.sender);

    _distributeReward(appId, amount, receiver);
  }

  /**
   * @dev {IX2EarnRewardsPoolV1-distributeReward}
   * @notice the proof argument is unused but kept for backwards compatibility
   */
  function distributeReward(bytes32 appId, uint256 amount, address receiver, string memory /*proof*/) external {
    // emit event with empty proof
    emit RewardDistributed(amount, appId, receiver, "", msg.sender);

    _distributeReward(appId, amount, receiver);
  }

  /**
   * @dev See {IX2EarnRewardsPoolV1-distributeRewardWithProof}
   */
  function distributeRewardWithProof(
    bytes32 appId,
    uint256 amount,
    address receiver,
    string[] memory proofTypes,
    string[] memory proofValues,
    string[] memory impactCodes,
    uint256[] memory impactValues,
    string memory description
  ) external {
    _emitProof(appId, amount, receiver, proofTypes, proofValues, impactCodes, impactValues, description);
    _distributeReward(appId, amount, receiver);
  }

  /**
   * @dev See {IX2EarnRewardsPoolV1-distributeReward}
   * @notice The impact is an array of integers and codes that represent the impact of the action.
   * Each index of the array represents a different impact.
   * The codes are predefined and the values are the impact values.
   * Example: ["carbon", "water", "energy"], [100, 200, 300]
   */
  function _distributeReward(bytes32 appId, uint256 amount, address receiver) internal nonReentrant {
    X2EarnRewardsPoolStorage storage $ = _getX2EarnRewardsPoolStorage();

    // check authorization
    require($.x2EarnApps.appExists(appId), "X2EarnRewardsPool: app does not exist");
    require($.x2EarnApps.isRewardDistributor(appId, msg.sender), "X2EarnRewardsPool: not a reward distributor");

    // check if the app has enough available funds to distribute
    require($.availableFunds[appId] >= amount, "X2EarnRewardsPool: app has insufficient funds");
    require($.b3tr.balanceOf(address(this)) >= amount, "X2EarnRewardsPool: insufficient funds on contract");

    // Transfer the rewards to the receiver
    $.availableFunds[appId] -= amount;
    require($.b3tr.transfer(receiver, amount), "X2EarnRewardsPool: Allocation transfer to app failed");
  }

  /**
   * @dev Emits the RewardDistributed event with the provided proofs and impacts.
   */
  function _emitProof(
    bytes32 appId,
    uint256 amount,
    address receiver,
    string[] memory proofTypes,
    string[] memory proofValues,
    string[] memory impactCodes,
    uint256[] memory impactValues,
    string memory description
  ) internal {
    // Build the JSON proof string from the proof and impact data
    string memory jsonProof = buildProof(proofTypes, proofValues, impactCodes, impactValues, description);

    // emit event
    emit RewardDistributed(amount, appId, receiver, jsonProof, msg.sender);
  }

  /**
   * @dev see {IX2EarnRewardsPoolV1-buildProof}
   */
  function buildProof(
    string[] memory proofTypes,
    string[] memory proofValues,
    string[] memory impactCodes,
    uint256[] memory impactValues,
    string memory description
  ) public view virtual returns (string memory) {
    bool hasProof = proofTypes.length > 0 && proofValues.length > 0;
    bool hasImpact = impactCodes.length > 0 && impactValues.length > 0;
    bool hasDescription = bytes(description).length > 0;

    // If neither proof nor impact is provided, return an empty string
    if (!hasProof && !hasImpact) {
      return "";
    }

    // Initialize an empty JSON bytes array with version
    bytes memory json = abi.encodePacked('{"version": 2');

    // Add description if available
    if (hasDescription) {
      json = abi.encodePacked(json, ',"description": "', description, '"');
    }

    // Add proof if available
    if (hasProof) {
      bytes memory jsonProof = _buildProofJson(proofTypes, proofValues);

      json = abi.encodePacked(json, ',"proof": ', jsonProof);
    }

    // Add impact if available
    if (hasImpact) {
      bytes memory jsonImpact = _buildImpactJson(impactCodes, impactValues);

      json = abi.encodePacked(json, ',"impact": ', jsonImpact);
    }

    // Close the JSON object
    json = abi.encodePacked(json, "}");

    return string(json);
  }

  /**
   * @dev Builds the proof JSON string from the proof data.
   * @param proofTypes the proof types
   * @param proofValues the proof values
   */
  function _buildProofJson(
    string[] memory proofTypes,
    string[] memory proofValues
  ) internal pure returns (bytes memory) {
    require(proofTypes.length == proofValues.length, "X2EarnRewardsPool: Mismatched input lengths for Proof");

    bytes memory json = abi.encodePacked("{");

    for (uint256 i; i < proofTypes.length; i++) {
      if (_isValidProofType(proofTypes[i])) {
        json = abi.encodePacked(json, '"', proofTypes[i], '":', '"', proofValues[i], '"');
        if (i < proofTypes.length - 1) {
          json = abi.encodePacked(json, ",");
        }
      } else {
        revert("X2EarnRewardsPool: Invalid proof type");
      }
    }

    json = abi.encodePacked(json, "}");

    return json;
  }

  /**
   * @dev Builds the impact JSON string from the impact data.
   *
   * @param impactCodes the impact codes
   * @param impactValues the impact values
   */
  function _buildImpactJson(
    string[] memory impactCodes,
    uint256[] memory impactValues
  ) internal view returns (bytes memory) {
    require(impactCodes.length == impactValues.length, "X2EarnRewardsPool: Mismatched input lengths for Impact");

    bytes memory json = abi.encodePacked("{");

    for (uint256 i; i < impactValues.length; i++) {
      if (_isAllowedImpactKey(impactCodes[i])) {
        json = abi.encodePacked(json, '"', impactCodes[i], '":', Strings.toString(impactValues[i]));
        if (i < impactValues.length - 1) {
          json = abi.encodePacked(json, ",");
        }
      } else {
        revert("X2EarnRewardsPool: Invalid impact key");
      }
    }

    json = abi.encodePacked(json, "}");

    return json;
  }

  /**
   * @dev Checks if the key is allowed.
   */
  function _isAllowedImpactKey(string memory key) internal view returns (bool) {
    X2EarnRewardsPoolStorage storage $ = _getX2EarnRewardsPoolStorage();
    return $.impactKeyIndex[key] > 0;
  }

  /**
   * @dev Checks if the proof type is valid.
   */
  function _isValidProofType(string memory proofType) internal pure returns (bool) {
    return
      keccak256(abi.encodePacked(proofType)) == keccak256(abi.encodePacked("image")) ||
      keccak256(abi.encodePacked(proofType)) == keccak256(abi.encodePacked("link")) ||
      keccak256(abi.encodePacked(proofType)) == keccak256(abi.encodePacked("text")) ||
      keccak256(abi.encodePacked(proofType)) == keccak256(abi.encodePacked("video"));
  }

  /**
   * @dev Sets the X2EarnApps contract address.
   *
   * @param _x2EarnApps the new X2EarnApps contract
   */
  function setX2EarnApps(IX2EarnAppsV1 _x2EarnApps) external onlyRole(CONTRACTS_ADDRESS_MANAGER_ROLE) {
    require(address(_x2EarnApps) != address(0), "X2EarnRewardsPool: x2EarnApps is the zero address");

    X2EarnRewardsPoolStorage storage $ = _getX2EarnRewardsPoolStorage();
    $.x2EarnApps = _x2EarnApps;
  }

  /**
   * @dev Adds a new allowed impact key.
   * @param newKey the new key to add
   */
  function addImpactKey(string memory newKey) external onlyRoleOrAdmin(IMPACT_KEY_MANAGER_ROLE) {
    X2EarnRewardsPoolStorage storage $ = _getX2EarnRewardsPoolStorage();
    _addImpactKey(newKey, $);
  }

  /**
   * @dev Internal function to add a new allowed impact key.
   * @param key the new key to add
   * @param $ the storage pointer
   */
  function _addImpactKey(string memory key, X2EarnRewardsPoolStorage storage $) internal {
    require($.impactKeyIndex[key] == 0, "X2EarnRewardsPool: Key already exists");
    $.allowedImpactKeys.push(key);
    $.impactKeyIndex[key] = $.allowedImpactKeys.length; // Store 1-based index
  }

  /**
   * @dev Removes an allowed impact key.
   * @param keyToRemove the key to remove
   */
  function removeImpactKey(string memory keyToRemove) external onlyRoleOrAdmin(IMPACT_KEY_MANAGER_ROLE) {
    X2EarnRewardsPoolStorage storage $ = _getX2EarnRewardsPoolStorage();
    uint256 index = $.impactKeyIndex[keyToRemove];
    require(index > 0, "X2EarnRewardsPool: Key not found");

    // Move the last element into the place to delete
    string memory lastKey = $.allowedImpactKeys[$.allowedImpactKeys.length - 1];
    $.allowedImpactKeys[index - 1] = lastKey;
    $.impactKeyIndex[lastKey] = index; // Update the index of the last key

    // Remove the last element
    $.allowedImpactKeys.pop();
    delete $.impactKeyIndex[keyToRemove];
  }

  // ---------- Getters ---------- //

  /**
   * @dev See {IX2EarnRewardsPoolV1-availableFunds}
   */
  function availableFunds(bytes32 appId) external view returns (uint256) {
    X2EarnRewardsPoolStorage storage $ = _getX2EarnRewardsPoolStorage();
    return $.availableFunds[appId];
  }

  /**
   * @dev See {IX2EarnRewardsPoolV1-version}
   */
  function version() external pure virtual returns (string memory) {
    return "2";
  }

  /**
   * @dev Retrieves the B3TR token contract.
   */
  function b3tr() external view returns (IB3TR) {
    X2EarnRewardsPoolStorage storage $ = _getX2EarnRewardsPoolStorage();
    return $.b3tr;
  }

  /**
   * @dev Retrieves the X2EarnApps contract.
   */
  function x2EarnApps() external view returns (IX2EarnAppsV1) {
    X2EarnRewardsPoolStorage storage $ = _getX2EarnRewardsPoolStorage();
    return $.x2EarnApps;
  }

  /**
   * @dev Retrieves the allowed impact keys.
   */
  function getAllowedImpactKeys() external view returns (string[] memory) {
    X2EarnRewardsPoolStorage storage $ = _getX2EarnRewardsPoolStorage();
    return $.allowedImpactKeys;
  }

  // ---------- Fallbacks ---------- //

  /**
   * @dev Transfers of VET to this contract are not allowed.
   */
  receive() external payable virtual {
    revert("X2EarnRewardsPool: contract does not accept VET");
  }

  /**
   * @dev Contract does not accept calls/data.
   */
  fallback() external payable {
    revert("X2EarnRewardsPool: contract does not accept calls/data");
  }

  /**
   * @dev Transfers of ERC721 tokens to this contract are not allowed.
   *
   * @notice supported only when safeTransferFrom is used
   */
  function onERC721Received(address, address, uint256, bytes memory) public virtual returns (bytes4) {
    revert("X2EarnRewardsPool: contract does not accept ERC721 tokens");
  }

  /**
   * @dev Transfers of ERC1155 tokens to this contract are not allowed.
   */
  function onERC1155Received(address, address, uint256, uint256, bytes memory) public virtual returns (bytes4) {
    revert("X2EarnRewardsPool: contract does not accept ERC1155 tokens");
  }

  /**
   * @dev Transfers of ERC1155 tokens to this contract are not allowed.
   */
  function onERC1155BatchReceived(
    address,
    address,
    uint256[] memory,
    uint256[] memory,
    bytes memory
  ) public virtual returns (bytes4) {
    revert("X2EarnRewardsPool: contract does not accept batch transfers of ERC1155 tokens");
  }
}

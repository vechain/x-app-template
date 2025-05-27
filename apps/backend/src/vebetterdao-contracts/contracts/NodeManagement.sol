// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { VechainNodesDataTypes } from "./libraries/VechainNodesDataTypes.sol";
import { ITokenAuction } from "./interfaces/ITokenAuction.sol";
import { INodeManagement } from "./interfaces/INodeManagement.sol";

contract NodeManagement is INodeManagement, AccessControlUpgradeable, UUPSUpgradeable {
  using EnumerableSet for EnumerableSet.UintSet;

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

  /// @custom:storage-location erc7201:b3tr.storage.NodeManagement
  struct NodeManagementStorage {
    ITokenAuction vechainNodesContract; // The token auction contract
    mapping(address => EnumerableSet.UintSet) delegateeToNodeIds; // Map delegatee address to set of node IDs
    mapping(uint256 => address) nodeIdToDelegatee; // Map node ID to delegatee address
  }

  // keccak256(abi.encode(uint256(keccak256("b3tr.storage.NodeManagement")) - 1)) & ~bytes32(uint256(0xff))
  bytes32 private constant NodeManagementStorageLocation =
    0x895b04a03424f581b1c6717e3715bbb5ceb9c40a4e5b61a13e84096251cf8f00;

  /**
   * @notice Retrieve the storage reference for node delegation data.
   * @dev Internal pure function to get the storage slot for node delegation data using inline assembly.
   * @return $ The storage reference for node delegation data.
   */
  function _getNodeManagementStorage() internal pure returns (NodeManagementStorage storage $) {
    assembly {
      $.slot := NodeManagementStorageLocation
    }
  }

  /**
   * @notice Initialize the contract with the specified VeChain Nodes contract, admin, and upgrader addresses.
   * @dev This function initializes the contract and sets the initial values for the VeChain Nodes contract address and other roles. It should be called only once during deployment.
   * @param _vechainNodesContract The address of the VeChain Nodes contract.
   * @param _admin The address to be granted the default admin role.
   * @param _upgrader The address to be granted the upgrader role.
   */
  function initialize(address _vechainNodesContract, address _admin, address _upgrader) external initializer {
    __UUPSUpgradeable_init();
    __AccessControl_init();

    require(_admin != address(0), "NodeManagement: admin address cannot be zero");
    _grantRole(DEFAULT_ADMIN_ROLE, _admin);
    _grantRole(UPGRADER_ROLE, _upgrader);

    NodeManagementStorage storage $ = _getNodeManagementStorage();
    $.vechainNodesContract = ITokenAuction(_vechainNodesContract);
    emit VechainNodeContractSet(address(0), _vechainNodesContract);
  }

  // ---------- Setters ---------- //

  /**
   * @notice Delegate a node to another address.
   * @dev This function allows a node owner to delegate their node to another address.
   * @param delegatee The address to delegate the node to.
   */
  function delegateNode(address delegatee) public virtual {
    NodeManagementStorage storage $ = _getNodeManagementStorage();

    // Check if the delegatee address is the zero address
    if (delegatee == address(0)) {
      revert NodeManagementZeroAddress();
    }

    // Get the node ID of the caller
    uint256 nodeId = $.vechainNodesContract.ownerToId(msg.sender);

    // If node ID is equal to zero, user does not own a node
    if (nodeId == 0) {
      revert NodeManagementNonNodeHolder();
    }

    // Check if the delegatee is the same as the caller, a node owner by defualt is the node manager and cannot delegate to themselves
    if (msg.sender == delegatee) {
      revert NodeManagementSelfDelegation();
    }

    // Check if node ID is already delegated to another user and if so remove the delegation
    if ($.nodeIdToDelegatee[nodeId] != address(0)) {
      // Emit event for delegation removal
      emit NodeDelegated(nodeId, $.nodeIdToDelegatee[nodeId], false);
      // Remove delegation
      $.delegateeToNodeIds[delegatee].remove(nodeId);
    }

    // Update mappings for delegation
    $.delegateeToNodeIds[delegatee].add(nodeId); // Add node ID to delegatee's set
    $.nodeIdToDelegatee[nodeId] = delegatee; // Map node ID to delegatee

    // Emit event for delegation
    emit NodeDelegated(nodeId, delegatee, true);
  }

  /**
   * @notice Remove the delegation of a node.
   * @dev This function allows a node owner to remove the delegation of their node, effectively revoking the delegatee's access to the node.
   */
  function removeNodeDelegation() public virtual {
    NodeManagementStorage storage $ = _getNodeManagementStorage();

    // Get the node ID of the caller
    uint256 nodeId = $.vechainNodesContract.ownerToId(msg.sender);

    // If node ID is equal to zero, user does not own a node
    if (nodeId == 0) {
      revert NodeManagementNonNodeHolder();
    }

    // Check if node is delegated
    address delegatee = $.nodeIdToDelegatee[nodeId];
    if (delegatee == address(0)) {
      revert NodeManagementNodeNotDelegated();
    }

    // Remove delegation
    $.delegateeToNodeIds[delegatee].remove(nodeId);
    delete $.nodeIdToDelegatee[nodeId];

    // Emit event for delegation removal
    emit NodeDelegated(nodeId, delegatee, false);
  }

  /**
   * @notice Set the address of the VeChain Nodes contract.
   * @dev This function allows the admin to update the address of the VeChain Nodes contract.
   * @param vechainNodesContract The new address of the VeChain Nodes contract.
   */
  function setVechainNodesContract(address vechainNodesContract) external onlyRole(DEFAULT_ADMIN_ROLE) {
    require(vechainNodesContract != address(0), "NodeManagement: vechainNodesContract cannot be the zero address");

    NodeManagementStorage storage $ = _getNodeManagementStorage();

    emit VechainNodeContractSet(address($.vechainNodesContract), vechainNodesContract);
    $.vechainNodesContract = ITokenAuction(vechainNodesContract);
  }

  // ---------- Getters ---------- //

  /**
   * @notice Retrieves the address of the user managing the node ID endorsement either through ownership or delegation.
   * @dev If the node is delegated, this function returns the delegatee's address. If the node is not delegated, it returns the owner's address.
   * @param nodeId The ID of the node for which the manager address is being retrieved.
   * @return The address of the manager of the specified node.
   */
  function getNodeManager(uint256 nodeId) public view returns (address) {
    NodeManagementStorage storage $ = _getNodeManagementStorage();

    // Get the address of the delegatee for the given nodeId
    address user = $.nodeIdToDelegatee[nodeId];

    // Return the delegated node ID if it exists, otherwise return the node ID directly owned by the user
    return user != address(0) ? user : $.vechainNodesContract.idToOwner(nodeId);
  }

  /**
   * @notice Retrieve the node IDs associated with a user, either through direct ownership or delegation.
   * @param user The address of the user to check.
   * @return uint256[] The node IDs associated with the user.
   */
  function getNodeIds(address user) public view returns (uint256[] memory) {
    NodeManagementStorage storage $ = _getNodeManagementStorage();

    // Get the set of node IDs delegated to the user
    EnumerableSet.UintSet storage nodeIdsSet = $.delegateeToNodeIds[user];

    // Calculate the total number of node IDs
    uint256 count = nodeIdsSet.length();

    // Create an array to hold the node IDs
    uint256[] memory nodeIds = new uint256[](count);

    // Populate the array with node IDs from the set
    for (uint256 i = 0; i < count; i++) {
      nodeIds[i] = nodeIdsSet.at(i);
    }

    // Get the node ID directly owned by the user
    uint256 ownedNodeId = $.vechainNodesContract.ownerToId(user);
    if (ownedNodeId != 0 && $.nodeIdToDelegatee[ownedNodeId] == address(0)) {
      // If the user directly owns a node, add it to the array
      nodeIds = _appendToArray(nodeIds, ownedNodeId);
    }

    return nodeIds;
  }

  /**
   * @notice Check if a user is holding a specific node ID either directly or through delegation.
   * @param user The address of the user to check.
   * @param nodeId The node ID to check for.
   * @return bool True if the user is holding the node ID and it is a valid node.
   */
  function isNodeManager(address user, uint256 nodeId) public view virtual returns (bool) {
    NodeManagementStorage storage $ = _getNodeManagementStorage();

    // Check if the user has the node ID delegated to them and if it is valid
    if ($.nodeIdToDelegatee[nodeId] == user) {
      // Return true if the owner of the token ID is not the zero address (valid nodeId)
      return $.vechainNodesContract.idToOwner(nodeId) != address(0);
    }

    if ($.nodeIdToDelegatee[nodeId] != address(0)) {
      // If the node ID is delegated to another user, return false
      return false;
    }

    // Check if the user owns the node ID
    return $.vechainNodesContract.idToOwner(nodeId) == user;
  }

  /**
   * @notice Retrieves the node level of a given node ID.
   * @dev Internal function to get the node level of a token ID. The node level is determined based on the metadata associated with the token ID.
   * @param nodeId The token ID of the endorsing node.
   * @return The node level of the specified token ID as a VechainNodesDataTypes.NodeStrengthLevel enum.
   */
  function getNodeLevel(uint256 nodeId) public view returns (VechainNodesDataTypes.NodeStrengthLevel) {
    NodeManagementStorage storage $ = _getNodeManagementStorage();

    // Retrieve the metadata for the specified node ID
    (, uint8 nodeLevel, , , , , ) = $.vechainNodesContract.getMetadata(nodeId);

    // Cast the uint8 node level to VechainNodesDataTypes.NodeStrengthLevel enum and return
    return VechainNodesDataTypes.NodeStrengthLevel(nodeLevel);
  }

  /**
   * @notice Retrieves the node levels of a user's managed nodes.
   * @dev This function retrieves the node levels of the nodes managed by the specified user, either through ownership or delegation.
   * @param user The address of the user managing the nodes.
   * @return VechainNodesDataTypes.NodeStrengthLevel[] The node levels of the nodes managed by the user.
   */
  function getUsersNodeLevels(address user) public view returns (VechainNodesDataTypes.NodeStrengthLevel[] memory) {
    // Retrieve the node IDs managed by the specified user
    uint256[] memory nodeIds = getNodeIds(user);

    // Initialize an array to hold the node levels
    VechainNodesDataTypes.NodeStrengthLevel[] memory nodeLevels = new VechainNodesDataTypes.NodeStrengthLevel[](
      nodeIds.length
    );

    // Retrieve the node level for each node ID and store it in the nodeLevels array
    for (uint256 i; i < nodeIds.length; i++) {
      nodeLevels[i] = getNodeLevel(nodeIds[i]);
    }

    // Return the array of node levels
    return nodeLevels;
  }

  /**
   * @notice Returns the Vechain node contract instance.
   * @return ITokenAuction The instance of the Vechain node contract.
   */
  function getVechainNodesContract() external view returns (ITokenAuction) {
    NodeManagementStorage storage $ = _getNodeManagementStorage();
    return $.vechainNodesContract;
  }

  /**
   * @notice Retrieves the current version of the contract.
   * @return string The current version of the contract.
   */
  function version() external pure virtual returns (string memory) {
    return "1";
  }

  // ---------- Internal ---------- //

  /**
   * @notice Appends an element to an array.
   * @dev Internal function to append an element to an array.
   * @param array The array to append to.
   * @param element The element to append.
   * @return uint256[] The new array with the appended element.
   */
  function _appendToArray(uint256[] memory array, uint256 element) internal pure returns (uint256[] memory) {
    uint256[] memory newArray = new uint256[](array.length + 1);
    for (uint256 i; i < array.length; i++) {
      newArray[i] = array[i];
    }
    newArray[array.length] = element;
    return newArray;
  }

  /**
   * @notice Authorize the upgrade to a new implementation.
   * @dev Internal function to authorize the upgrade to a new contract implementation. This function is restricted to addresses with the upgrader role.
   * @param newImplementation The address of the new contract implementation.
   */
  function _authorizeUpgrade(address newImplementation) internal virtual override onlyRole(UPGRADER_ROLE) {}
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import { VechainNodesDataTypes } from "../libraries/VechainNodesDataTypes.sol";

interface INodeManagement {
  /**
   * @notice Error indicating that the caller does not own a node.
   */
  error NodeManagementNonNodeHolder();

  /**
   * @notice Error indicating that the node is not currently delegated.
   */
  error NodeManagementNodeNotDelegated();

  /**
   * @notice Error indicating that an address is being set to the zero address.
   */
  error NodeManagementZeroAddress();

  /**
   * @notice Error indicating that an address is being set to the zero address.
   */
  error NodeManagementSelfDelegation();

  /**
   * @notice Error indicating that the node is already delegated to another user.
   * @param nodeId The ID of the node that is already delegated.
   * @param delegatee The address of the current delegatee.
   */
  error NodeManagementNodeAlreadyDelegated(uint256 nodeId, address delegatee);

  /**
   * @notice Event emitted when a node is delegated or the delegation is removed.
   * @param nodeId The ID of the node being delegated or having its delegation removed.
   * @param delegatee The address to which the node is delegated or from which the delegation is removed.
   * @param delegated A boolean indicating whether the node is delegated (true) or the delegation is removed (false).
   */
  event NodeDelegated(uint256 indexed nodeId, address indexed delegatee, bool delegated);

  /**
   *  @dev Emit when the vechain node contract address is set or updated
   */
  event VechainNodeContractSet(address oldContractAddress, address newContractAddress);

  /**
   * @notice Initialize the contract with the specified VeChain Nodes contract, admin, and upgrader addresses.
   * @param vechainNodesContract The address of the VeChain Nodes contract.
   * @param admin The address to be granted the default admin role.
   * @param upgrader The address to be granted the upgrader role.
   */
  function initialize(address vechainNodesContract, address admin, address upgrader) external;

  /**
   * @notice Set the address of the VeChain Nodes contract.
   * @param vechainNodesContract The new address of the VeChain Nodes contract.
   */
  function setVechainNodesContract(address vechainNodesContract) external;

  /**
   * @notice Delegate a node to another address.
   * @param delegatee The address to delegate the node to.
   */
  function delegateNode(address delegatee) external;

  /**
   * @notice Remove the delegation of a node.
   */
  function removeNodeDelegation() external;

  /**
   * @notice Retrieve the node ID associated with a user, either through direct ownership or delegation.
   * @param user The address of the user to check.
   * @return uint256 The node ID associated with the user.
   */
  function getNodeIds(address user) external view returns (uint256[] memory);

  /**
   * @notice Retrieves the address of the user managing the node ID endorsement either through ownership or delegation.
   * @param nodeId The ID of the node for which the manager address is being retrieved.
   * @return address The address of the manager of the specified node.
   */
  function getNodeManager(uint256 nodeId) external view returns (address);

  /**
   * @notice Check if a user is holding a specific node ID either directly or through delegation.
   * @param user The address of the user to check.
   * @param nodeId The node ID to check for.
   * @return bool True if the user is holding the node ID and it is a valid node.
   */
  function isNodeManager(address user, uint256 nodeId) external view returns (bool);

  /**
   * @notice Retrieves the node level of a given node ID.
   * @param nodeId The token ID of the endorsing node.
   * @return VechainNodesDataTypes.NodeStrengthLevel The node level of the specified token ID.
   */
  function getNodeLevel(uint256 nodeId) external view returns (VechainNodesDataTypes.NodeStrengthLevel);

  /**
   * @notice Retrieves the node level of a user's managed node.
   * @param user The address of the user managing the node.
   * @return VechainNodesDataTypes.NodeStrengthLevel The node level of the node managed by the user.
   */
  function getUsersNodeLevels(address user) external view returns (VechainNodesDataTypes.NodeStrengthLevel[] memory);
}

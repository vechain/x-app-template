// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import "@openzeppelin/contracts/utils/structs/Checkpoints.sol";

/**
 * @title IGalaxyMember
 * @notice Interface for the GalaxyMember contract which handles NFT membership and governance functionality
 * @dev Implements ERC721 with additional features for level upgrades, node attachments, and governance participation
 */
interface IGalaxyMember {
  // Custom errors
  error AccessControlBadConfirmation();
  error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);
  error AddressEmptyCode(address target);
  error ERC1967InvalidImplementation(address implementation);
  error ERC1967NonPayable();
  error ERC5805FutureLookup(uint256 timepoint, uint48 clock);
  error ERC6372InconsistentClock();
  error ERC721EnumerableForbiddenBatchMint();
  error ERC721IncorrectOwner(address sender, uint256 tokenId, address owner);
  error ERC721InsufficientApproval(address operator, uint256 tokenId);
  error ERC721InvalidApprover(address approver);
  error ERC721InvalidOperator(address operator);
  error ERC721InvalidOwner(address owner);
  error ERC721InvalidReceiver(address receiver);
  error ERC721InvalidSender(address sender);
  error ERC721NonexistentToken(uint256 tokenId);
  error ERC721OutOfBoundsIndex(address owner, uint256 index);
  error EnforcedPause();
  error ExpectedPause();
  error FailedInnerCall();
  error InvalidInitialization();
  error NotInitializing();
  error ReentrancyGuardReentrantCall();
  error UUPSUnauthorizedCallContext();
  error UUPSUnsupportedProxiableUUID(bytes32 slot);

  // Events
  event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
  event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
  event B3TRtoUpgradeToLevelUpdated(uint256[] indexed b3trToUpgradeToLevel);
  event B3trGovernorAddressUpdated(address indexed newAddress, address indexed oldAddress);
  event BaseURIUpdated(string indexed newBaseURI, string indexed oldBaseURI);
  event Initialized(uint64 version);
  event MaxLevelUpdated(uint256 oldLevel, uint256 newLevel);
  event Paused(address account);
  event PublicMintingPaused(bool isPaused);
  event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);
  event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
  event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);
  event Selected(address indexed owner, uint256 tokenId);
  event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
  event Unpaused(address account);
  event Upgraded(address indexed implementation);
  event Upgraded(uint256 indexed tokenId, uint256 oldLevel, uint256 newLevel);
  event XAllocationsGovernorAddressUpdated(address indexed newAddress, address indexed oldAddress);
  event NodeDetached(uint256 indexed nodeTokenId, uint256 indexed tokenId);
  event NodeAttached(uint256 indexed nodeTokenId, uint256 indexed tokenId);

  /// @notice Returns the role identifier for contracts address manager
  function CONTRACTS_ADDRESS_MANAGER_ROLE() external view returns (bytes32);

  /// @notice Returns the role identifier for default admin
  function DEFAULT_ADMIN_ROLE() external view returns (bytes32);

  /// @notice Returns the maximum level achievable for a token
  function MAX_LEVEL() external view returns (uint256);

  /// @notice Returns the role identifier for minter
  function MINTER_ROLE() external view returns (bytes32);

  /// @notice Returns the role identifier for nodes manager
  function NODES_MANAGER_ROLE() external view returns (bytes32);

  /// @notice Returns the role identifier for pauser
  function PAUSER_ROLE() external view returns (bytes32);

  /// @notice Returns the role identifier for upgrader
  function UPGRADER_ROLE() external view returns (bytes32);

  /// @notice Returns the interface version string
  function UPGRADE_INTERFACE_VERSION() external view returns (string memory);

  /// @notice Approves an address to transfer a specific token
  /// @param to Address to be approved
  /// @param tokenId ID of the token to be approved
  function approve(address to, uint256 tokenId) external;

  /// @notice Attaches a node to a token
  /// @param nodeTokenId ID of the node to attach
  /// @param tokenId ID of the token to attach to
  function attachNode(uint256 nodeTokenId, uint256 tokenId) external;

  /// @notice Returns the B3TR token contract address
  function b3tr() external view returns (address);

  /// @notice Returns the B3TR governor contract address
  function b3trGovernor() external view returns (address);

  /// @notice Returns the number of tokens owned by an address
  /// @param owner Address to query
  /// @return Number of tokens owned
  function balanceOf(address owner) external view returns (uint256);

  /// @notice Returns the base URI for token metadata
  function baseURI() external view returns (string memory);

  /// @notice Burns a specific token
  /// @param tokenId ID of the token to burn
  function burn(uint256 tokenId) external;

  /// @notice Detaches a node from a token
  /// @param nodeTokenId ID of the node to detach
  /// @param tokenId ID of the token to detach from
  function detachNode(uint256 nodeTokenId, uint256 tokenId) external;

  /// @notice Allows eligible addresses to mint a token for free
  function freeMint() external;

  /// @notice Returns the approved address for a token
  /// @param tokenId ID of the token to query
  /// @return Address approved for the token
  function getApproved(uint256 tokenId) external view returns (address);

  /// @notice Returns the amount of B3TR donated for a token
  /// @param tokenId ID of the token to query
  /// @return Amount of B3TR donated
  function getB3TRdonated(uint256 tokenId) external view returns (uint256);

  /// @notice Returns the amount of B3TR needed to upgrade a token
  /// @param tokenId ID of the token to query
  /// @return Amount of B3TR needed
  function getB3TRtoUpgrade(uint256 tokenId) external view returns (uint256);

  /// @notice Returns the amount of B3TR needed to upgrade to a specific level
  /// @param level Target level
  /// @return Amount of B3TR needed
  function getB3TRtoUpgradeToLevel(uint256 level) external view returns (uint256);

  /// @notice Returns the token ID attached to a node
  /// @param nodeId ID of the node to query
  /// @return Token ID attached to the node
  function getIdAttachedToNode(uint256 nodeId) external view returns (uint256);

  /// @notice Calculates the level after attaching a node
  /// @param tokenId ID of the token
  /// @param nodeTokenId ID of the node to attach
  /// @return New level after attachment
  function getLevelAfterAttachingNode(uint256 tokenId, uint256 nodeTokenId) external view returns (uint256);

  /// @notice Calculates the level after detaching a node
  /// @param tokenId ID of the token
  /// @return New level after detachment
  function getLevelAfterDetachingNode(uint256 tokenId) external view returns (uint256);

  /// @notice Returns the node ID attached to a token
  /// @param tokenId ID of the token to query
  /// @return ID of the attached node
  function getNodeIdAttached(uint256 tokenId) external view returns (uint256);

  /// @notice Returns the level of a node
  /// @param nodeId ID of the node to query
  /// @return Level of the node
  function getNodeLevelOf(uint256 nodeId) external view returns (uint8);

  /// @notice Returns the free level granted by a node level
  /// @param nodeLevel Level of the node
  /// @return Free level granted
  function getNodeToFreeLevel(uint8 nodeLevel) external view returns (uint256);

  /// @notice Returns the admin role for a given role
  /// @param role Role to query
  /// @return Admin role
  function getRoleAdmin(bytes32 role) external view returns (bytes32);

  /// @notice Returns the selected token ID for an owner
  /// @param owner Address to query
  /// @return Selected token ID
  function getSelectedTokenId(address owner) external view returns (uint256);

  /// @notice Grants a role to an account
  /// @param role Role to grant
  /// @param account Account to receive the role
  function grantRole(bytes32 role, address account) external;

  /// @notice Checks if an account has a role
  /// @param role Role to check
  /// @param account Account to check
  /// @return True if account has the role
  function hasRole(bytes32 role, address account) external view returns (bool);

  /// @notice Initializes the contract V2
  /// @param _vechainNodes Address of the VeChain nodes contract
  /// @param _nodesAdmin Address of the nodes admin
  /// @param _nodeFreeLevels Array of free levels for nodes
  function initializeV2(address _vechainNodes, address _nodesAdmin, uint256[] memory _nodeFreeLevels) external;

  /// @notice Checks if an operator is approved for all tokens of an owner
  /// @param owner Owner address
  /// @param operator Operator address
  /// @return True if operator is approved for all
  function isApprovedForAll(address owner, address operator) external view returns (bool);

  /// @notice Returns the level of a token
  /// @param tokenId ID of the token to query
  /// @return Level of the token
  function levelOf(uint256 tokenId) external view returns (uint256);

  /// @notice Returns the name of the token collection
  function name() external view returns (string memory);

  /// @notice Returns the owner of a token
  /// @param tokenId ID of the token to query
  /// @return Address of the owner
  function ownerOf(uint256 tokenId) external view returns (address);

  /// @notice Checks if a user has participated in governance
  /// @param user Address to check
  /// @return True if user has participated
  function participatedInGovernance(address user) external view returns (bool);

  /// @notice Pauses all token transfers
  function pause() external;

  /// @notice Returns the paused status of the contract
  /// @return True if contract is paused
  function paused() external view returns (bool);

  /// @notice Returns the storage slot for the implementation
  function proxiableUUID() external view returns (bytes32);

  /// @notice Allows an account to renounce a role
  /// @param role Role to renounce
  /// @param callerConfirmation Address of the caller for confirmation
  function renounceRole(bytes32 role, address callerConfirmation) external;

  /// @notice Revokes a role from an account
  /// @param role Role to revoke
  /// @param account Account to revoke from
  function revokeRole(bytes32 role, address account) external;

  /// @notice Safely transfers a token
  /// @param from Current owner
  /// @param to New owner
  /// @param tokenId ID of the token to transfer
  function safeTransferFrom(address from, address to, uint256 tokenId) external;

  /// @notice Safely transfers a token with additional data
  /// @param from Current owner
  /// @param to New owner
  /// @param tokenId ID of the token to transfer
  /// @param data Additional data
  function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) external;

  /// @notice Selects a token for an owner
  /// @param tokenID ID of the token to select
  function select(uint256 tokenID) external;

  /// @notice Sets approval for all tokens
  /// @param operator Address to approve
  /// @param approved Approval status
  function setApprovalForAll(address operator, bool approved) external;

  /// @notice Sets the B3TR amounts needed for level upgrades
  /// @param b3trToUpgradeToLevel Array of B3TR amounts
  function setB3TRtoUpgradeToLevel(uint256[] memory b3trToUpgradeToLevel) external;

  /// @notice Sets the B3TR governor address
  /// @param _b3trGovernor New governor address
  function setB3trGovernorAddress(address _b3trGovernor) external;

  /// @notice Sets the base URI for token metadata
  /// @param baseTokenURI New base URI
  function setBaseURI(string memory baseTokenURI) external;

  /// @notice Sets the public minting pause status
  /// @param isPaused New pause status
  function setIsPublicMintingPaused(bool isPaused) external;

  /// @notice Sets the maximum level
  /// @param level New maximum level
  function setMaxLevel(uint256 level) external;

  /// @notice Sets the free upgrade level for a node level
  /// @param nodeLevel Level of the node
  /// @param level Free upgrade level
  function setNodeToFreeUpgradeLevel(uint8 nodeLevel, uint256 level) external;

  /// @notice Sets the VeChain nodes contract address
  /// @param _vechainNodes New nodes contract address
  function setVechainNodes(address _vechainNodes) external;

  /// @notice Sets the X-Allocations governor address
  /// @param _xAllocationsGovernor New governor address
  function setXAllocationsGovernorAddress(address _xAllocationsGovernor) external;

  /// @notice Checks if the contract supports an interface
  /// @param interfaceId Interface identifier
  /// @return True if interface is supported
  function supportsInterface(bytes4 interfaceId) external view returns (bool);

  /// @notice Returns the symbol of the token collection
  function symbol() external view returns (string memory);

  /// @notice Returns a token by its index
  /// @param index Index of the token
  /// @return Token ID at the index
  function tokenByIndex(uint256 index) external view returns (uint256);

  /// @notice Returns a token owned by an address by index
  /// @param owner Owner address
  /// @param index Index of the token
  /// @return Token ID at the index
  function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256);

  /// @notice Returns the URI for a token's metadata
  /// @param tokenId ID of the token
  /// @return Metadata URI
  function tokenURI(uint256 tokenId) external view returns (string memory);

  /// @notice Returns the total supply of tokens
  /// @return Total number of tokens
  function totalSupply() external view returns (uint256);

  /// @notice Transfers a token
  /// @param from Current owner
  /// @param to New owner
  /// @param tokenId ID of the token to transfer
  function transferFrom(address from, address to, uint256 tokenId) external;

  /// @notice Returns the treasury address
  function treasury() external view returns (address);

  /// @notice Unpauses all token transfers
  function unpause() external;

  /// @notice Upgrades a token's level
  /// @param tokenId ID of the token to upgrade
  function upgrade(uint256 tokenId) external;

  /// @notice Upgrades the contract implementation
  /// @param newImplementation Address of the new implementation
  /// @param data Additional data for the upgrade
  function upgradeToAndCall(address newImplementation, bytes memory data) external payable;

  /// @notice Returns the contract version
  /// @return Version string
  function version() external pure returns (string memory);

  /// @notice Returns the X-Allocations governor address
  function xAllocationsGovernor() external view returns (address);
}

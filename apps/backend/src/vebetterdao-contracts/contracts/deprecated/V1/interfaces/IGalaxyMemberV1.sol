// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import "@openzeppelin/contracts/utils/structs/Checkpoints.sol";

interface IGalaxyMemberV1 {
  error AccessControlBadConfirmation();

  error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);

  error AddressEmptyCode(address target);

  error CheckpointUnorderedInsertion();

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

  error SafeCastOverflowedUintDowncast(uint8 bits, uint256 value);

  error UUPSUnauthorizedCallContext();

  error UUPSUnsupportedProxiableUUID(bytes32 slot);

  event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

  event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

  event Initialized(uint64 version);

  event Paused(address account);

  event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);

  event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);

  event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

  event Selected(address indexed owner, uint256 tokenId);

  event SelectedLevel(address indexed owner, uint256 oldLevel, uint256 newLevel);

  event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

  event Unpaused(address account);

  event Upgraded(address indexed implementation);

  event Upgraded(uint256 indexed tokenId, uint256 oldLevel, uint256 newLevel);

  event MaxLevelUpdated(uint256 oldLevel, uint256 indexed newLevel);

  event XAllocationsGovernorAddressUpdated(address indexed newAddress, address indexed oldAddress);

  event B3trGovernorAddressUpdated(address indexed newAddress, address indexed oldAddress);

  event BaseURIUpdated(string indexed newBaseURI, string indexed oldBaseURI);

  event B3TRtoUpgradeToLevelUpdated(uint256[] indexed b3trToUpgradeToLevel);

  event PublicMintingPaused(bool isPaused);

  function CLOCK_MODE() external view returns (string memory);

  function DEFAULT_ADMIN_ROLE() external view returns (bytes32);

  function MAX_LEVEL() external view returns (uint256);

  function UPGRADER_ROLE() external view returns (bytes32);

  function UPGRADE_INTERFACE_VERSION() external view returns (string memory);

  function approve(address to, uint256 tokenId) external;

  function b3tr() external view returns (address);

  function b3trGovernor() external view returns (address);

  function balanceOf(address owner) external view returns (uint256);

  function baseURI() external view returns (string memory);

  function checkpoints(address account, uint32 pos) external view returns (Checkpoints.Checkpoint208 memory);

  function clock() external view returns (uint48);

  function freeMint() external;

  function getApproved(uint256 tokenId) external view returns (address);

  function getB3TRtoUpgrade(uint256 tokenId) external view returns (uint256);

  function getB3TRtoUpgradeToLevel(uint256 level) external view returns (uint256);

  function getHighestLevel(address owner) external view returns (uint256);

  function getMaxMintableLevelOfXNode(uint8 xNodeType) external view returns (uint256);

  function getNextLevel(uint256 tokenId) external view returns (uint256);

  function getPastHighestLevel(address owner, uint256 timepoint) external view returns (uint256);

  function getRoleAdmin(bytes32 role) external view returns (bytes32);

  function grantRole(bytes32 role, address account) external;

  function hasRole(bytes32 role, address account) external view returns (bool);

  function initialize(
    string memory name,
    string memory symbol,
    address admin,
    address upgrader,
    uint256 maxLevel,
    string memory baseTokenURI,
    uint256[] memory xNodeMaxMintableLevels,
    uint256[] memory b3trToUpgradeToLevel,
    address _b3tr,
    address _treasury
  ) external;

  function isApprovedForAll(address owner, address operator) external view returns (bool);

  function levelOf(uint256 tokenId) external view returns (uint256);

  function name() external view returns (string memory);

  function numCheckpoints(address account) external view returns (uint32);

  function ownerOf(uint256 tokenId) external view returns (address);

  function participatedInGovernance(address user) external view returns (bool);

  function pause() external;

  function paused() external view returns (bool);

  function proxiableUUID() external view returns (bytes32);

  function renounceRole(bytes32 role, address callerConfirmation) external;

  function revokeRole(bytes32 role, address account) external;

  function safeTransferFrom(address from, address to, uint256 tokenId) external;

  function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) external;

  function selectHighestLevel() external;

  function setApprovalForAll(address operator, bool approved) external;

  function setB3TRtoUpgradeToLevel(uint256[] memory b3trToUpgradeToLevel) external;

  function setB3trGovernorAddress(address _b3trGovernor) external;

  function setBaseURI(string memory baseTokenURI) external;

  function setMaxLevel(uint256 level) external;

  function setMaxMintableLevels(uint8[] memory maxMintableLevels) external;

  function setXAllocationsGovernorAddress(address _xAllocationsGovernor) external;

  function supportsInterface(bytes4 interfaceId) external view returns (bool);

  function symbol() external view returns (string memory);

  function tokenByIndex(uint256 index) external view returns (uint256);

  function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256);

  function tokenURI(uint256 tokenId) external view returns (string memory);

  function totalSupply() external view returns (uint256);

  function transferFrom(address from, address to, uint256 tokenId) external;

  function treasury() external view returns (address);

  function unpause() external;

  function upgrade(uint256 tokenId) external;

  function upgradeToAndCall(address newImplementation, bytes memory data) external payable;

  function xAllocationsGovernor() external view returns (address);

  function version() external view returns (string memory);
}

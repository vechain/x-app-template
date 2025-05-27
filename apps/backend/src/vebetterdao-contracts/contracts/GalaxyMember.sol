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

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { Checkpoints } from "@openzeppelin/contracts/utils/structs/Checkpoints.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { IXAllocationVotingGovernor } from "./interfaces/IXAllocationVotingGovernor.sol";
import { IB3TRGovernor } from "./interfaces/IB3TRGovernor.sol";
import { IB3TR } from "./interfaces/IB3TR.sol";
import { ITokenAuction } from "./interfaces/ITokenAuction.sol";
import { INodeManagement } from "./interfaces/INodeManagement.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title GalaxyMember
 * @notice This contract manages the unique assets owned by users within the Galaxy Member ecosystem.
 * @dev Extends ERC721 Non-Fungible Token Standard basic implementation with upgradeable pattern, burnable, pausable, and access control functionalities.
 *
 * --------------------------------- VERSION ---------------------------------
 * - Added Vechain Nodes contract to attach and detach nodes to tokens
 * - Added NODES_MANAGER_ROLE to manage Vechain Nodes Contract address and free upgrade levels
 * - Added free upgrade levels for each Vechain node level
 * - Removed automatic highest level owned selection
 * - Added dynamic level fetching of the token based on the attached Vechain node and B3TR donated for upgrading
 * - Core logic functions are now overridable through inheritance
 * - B3TRGovernor has been updated to V2 thus pointing to the new interface
 * - NodeManagement contract has been added to permit attaching and detaching nodes from managed nodes too
 */
contract GalaxyMember is
  ERC721Upgradeable,
  ERC721EnumerableUpgradeable,
  ERC721PausableUpgradeable,
  ERC721BurnableUpgradeable,
  AccessControlUpgradeable,
  ReentrancyGuardUpgradeable,
  UUPSUpgradeable
{
  bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
  bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
  bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
  bytes32 public constant CONTRACTS_ADDRESS_MANAGER_ROLE = keccak256("CONTRACTS_ADDRESS_MANAGER_ROLE");
  bytes32 public constant NODES_MANAGER_ROLE = keccak256("NODES_MANAGER_ROLE");

  /// @notice Storage structure for GalaxyMember
  /// @dev GalaxyMemberStorage structure holds all the state variables in a single location.
  /// @custom:storage-location erc7201:b3tr.storage.GalaxyMember
  struct GalaxyMemberStorage {
    IXAllocationVotingGovernor xAllocationsGovernor; // XAllocationVotingGovernor contract
    IB3TRGovernor b3trGovernor; // B3TRGovernor contract
    IB3TR b3tr; // B3TR token contract
    address treasury; // Treasury contract address
    string _baseTokenURI; // Base URI for the Token
    uint256 _nextTokenId; // Next Token ID to be minted
    uint256 MAX_LEVEL; // Current Maximum level the Token can be minted or upgraded to
    mapping(uint256 => uint256) levelOf; // Mapping from token ID to level of the Token
    mapping(uint256 => uint256) _b3trToUpgradeToLevel; // Mapping from level to B3TR required to upgrade to that level
    mapping(address owner => Checkpoints.Trace208) _selectedLevelCheckpoints; // Checkpoints for selected level of the user
    mapping(address => mapping(uint256 => uint256)) _ownedLevels; // Value-Frequency map tracking levels owned by users
    bool isPublicMintingPaused; // Flag to pause public minting
    // --------------------------- V2 Additions --------------------------- //
    ITokenAuction vechainNodes; // Vechain Nodes contract
    INodeManagement nodeManagement; // Node Management contract
    mapping(uint256 => uint256) _nodeToTokenId; // Mapping from Vechain node ID to GalaxyMember Token ID. Used to track the XNode tied to the GM token ID
    mapping(uint256 => uint256) _tokenIdToNode; // Mapping from GalaxyMember Token ID to Vechain node ID. Used to track the GM token ID tied to the XNode token ID
    mapping(uint8 => uint256) _nodeToFreeUpgradeLevel; // Mapping from Vechain node level to GalaxyMember level. Used to track the GM level that can be upgraded for free for a given Vechain node level
    mapping(uint256 => uint256) _tokenIdToB3TRdonated; // Mapping from GM Token ID to B3TR donated for upgrading
    mapping(address => uint256) _selectedTokenID; // Mapping from user address to selected GM token ID
  }

  /// @notice Storage slot for GalaxyMemberStorage
  /// @dev keccak256(abi.encode(uint256(keccak256("b3tr.storage.GalaxyMember")) - 1)) & ~bytes32(uint256(0xff))
  bytes32 private constant GalaxyMemberStorageLocation =
    0x7a79e46844ed04411e4579c7bc49d053e59b0854fa4e9a8df3d5a0597ce45200;

  /// @dev Retrieves the current state from the GalaxyMemberStorage mapping
  function _getGalaxyMemberStorage() private pure returns (GalaxyMemberStorage storage $) {
    assembly {
      $.slot := GalaxyMemberStorageLocation
    }
  }

  /// @dev Emitted when an account changes the selected token for voting rewards.
  event Selected(address indexed owner, uint256 tokenId);

  /// @dev Emitted when a token is upgraded.
  event Upgraded(uint256 indexed tokenId, uint256 oldLevel, uint256 newLevel);

  /// @dev Emitted when the max level is updated.
  event MaxLevelUpdated(uint256 oldLevel, uint256 newLevel);

  /// @dev Emitted when XAllocationVotingGovernor contract address is updated
  event XAllocationsGovernorAddressUpdated(address indexed newAddress, address indexed oldAddress);

  /// @dev Emitted when B3TRGovernor contract address is updated
  event B3trGovernorAddressUpdated(address indexed newAddress, address indexed oldAddress);

  /// @dev Emitted when base URI is updated
  event BaseURIUpdated(string indexed newBaseURI, string indexed oldBaseURI);

  /// @dev Emitted when B3TR required to upgrade to each level is updated
  event B3TRtoUpgradeToLevelUpdated(uint256[] indexed b3trToUpgradeToLevel);

  /// @dev Emitted when public minting is paused
  event PublicMintingPaused(bool isPaused);

  /// @dev Emitted when a node is attached to a token
  event NodeAttached(uint256 indexed nodeTokenId, uint256 indexed tokenId);

  /// @dev Emitted when a node is detached from a token
  event NodeDetached(uint256 indexed nodeTokenId, uint256 indexed tokenId);

  /// @notice Modifier to check if public minting is not paused
  modifier whenPublicMintingNotPaused() {
    GalaxyMemberStorage storage $ = _getGalaxyMemberStorage();
    require(!$.isPublicMintingPaused, "Galaxy Member: Public minting is paused");
    _;
  }

  /// @notice Ensures only initializer functions are called when deploying a proxy
  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  /// @notice Data for initializing the contract
  /// @param name Name of the ERC721 token
  /// @param symbol Symbol of the ERC721 token
  /// @param admin Address to grant the admin role
  /// @param upgrader Address to grant the upgrader role
  /// @param pauser Address to grant the pauser role
  /// @param minter Address to grant the minter role
  /// @param contractsAddressManager Address that can update external contracts address
  /// @param maxLevel Maximum level tokens can achieve
  /// @param baseTokenURI Base URI for computing {tokenURI}
  /// @param b3trToUpgradeToLevel Mapping of B3TR requirements per level
  /// @param _b3tr B3TR token contract address
  /// @param _treasury Address of the treasury
  struct InitializationData {
    string name;
    string symbol;
    address admin;
    address upgrader;
    address pauser;
    address minter;
    address contractsAddressManager;
    uint256 maxLevel;
    string baseTokenURI;
    uint256[] b3trToUpgradeToLevel;
    address b3tr;
    address treasury;
  }

  /// @notice Initializes a new GalaxyMember contract
  /// @dev Sets initial values for all relevant contract properties and state variables.
  /// @custom:oz-upgrades-unsafe-allow constructor
  function initialize(InitializationData memory data) external initializer {
    require(data.maxLevel > 0, "Galaxy Member: Max level must be greater than 0");
    require(bytes(data.baseTokenURI).length > 0, "Galaxy Member: Base URI must be set");
    require(data.b3tr != address(0), "Galaxy Member: B3TR token address cannot be the zero address");
    require(data.treasury != address(0), "Galaxy Member: Treasury address cannot be the zero address");
    require(
      data.b3trToUpgradeToLevel.length >= data.maxLevel - 1,
      "Galaxy Member: B3TR to upgrade must be set for all unlocked levels"
    );

    __ERC721_init(data.name, data.symbol);
    __ERC721Enumerable_init();
    __ERC721Pausable_init();
    __ERC721Burnable_init();
    __AccessControl_init();
    __ReentrancyGuard_init();
    __UUPSUpgradeable_init();

    GalaxyMemberStorage storage $ = _getGalaxyMemberStorage();

    $._baseTokenURI = data.baseTokenURI;

    for (uint256 i = 0; i < data.b3trToUpgradeToLevel.length; i++) {
      require(data.b3trToUpgradeToLevel[i] > 0, "Galaxy Member: B3TR to upgrade must be greater than 0");
      $._b3trToUpgradeToLevel[i + 2] = data.b3trToUpgradeToLevel[i]; // First Level that requires B3TR is level 2
    }

    $.MAX_LEVEL = data.maxLevel;

    $.b3tr = IB3TR(data.b3tr);
    $.treasury = data.treasury;

    require(data.admin != address(0), "Galaxy Member: Admin address cannot be the zero address");
    _grantRole(DEFAULT_ADMIN_ROLE, data.admin);
    _grantRole(UPGRADER_ROLE, data.upgrader);
    _grantRole(PAUSER_ROLE, data.pauser);
    _grantRole(MINTER_ROLE, data.minter);
    _grantRole(CONTRACTS_ADDRESS_MANAGER_ROLE, data.contractsAddressManager);
  }

  /// @notice Initializes a new GalaxyMember contract
  /// @dev Sets initial values for all relevant contract properties and state variables.
  /// @custom:oz-upgrades-unsafe-allow constructor
  function initializeV2(
    address _vechainNodes,
    address _nodesMangaement,
    address _nodesAdmin,
    uint256[] memory _nodeFreeLevels
  ) external reinitializer(2) {
    require(_nodeFreeLevels.length == 8, "GalaxyMember: invalid node free levels. Must be 7 levels");
    require(_vechainNodes != address(0), "GalaxyMember: _vechainNodes cannot be the zero address");
    require(_nodesMangaement != address(0), "GalaxyMember: _nodesMangaement cannot be the zero address");

    GalaxyMemberStorage storage $ = _getGalaxyMemberStorage();

    $.vechainNodes = ITokenAuction(_vechainNodes);
    $.nodeManagement = INodeManagement(_nodesMangaement);

    $._nextTokenId = $._nextTokenId == 0 ? 1 : $._nextTokenId;

    for (uint8 i; i < _nodeFreeLevels.length; i++) {
      require(_nodeFreeLevels[i] >= 1, "GalaxyMember: invalid node free level");
      $._nodeToFreeUpgradeLevel[i] = _nodeFreeLevels[i];
    }

    _grantRole(NODES_MANAGER_ROLE, _nodesAdmin);
  }

  /// @notice Internal function to authorize contract upgrades
  /// @dev Restricts upgrade authorization to addresses with UPGRADER_ROLE
  /// @param newImplementation Address of the new contract implementation
  function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

  /// @notice Pauses the Galaxy Member contract
  /// @dev pausing the contract will prevent minting, upgrading, and transferring of tokens
  /// @dev Only callable by the pauser role
  function pause() public virtual onlyRole(PAUSER_ROLE) {
    _pause();
  }

  /// @notice Unpauses the Galaxy Member contract
  /// @dev Only callable by the pauser role
  function unpause() public virtual onlyRole(PAUSER_ROLE) {
    _unpause();
  }

  /// @notice Allows a user to freely mint a token if they have participated in governance
  /// @dev Mints a token with level 1 and ensures that the public minting is not paused
  function freeMint() public virtual whenPublicMintingNotPaused {
    require(participatedInGovernance(msg.sender), "Galaxy Member: User has not participated in governance");

    safeMint(msg.sender);
  }

  /// @notice Upgrades a token to the next level
  /// @dev Requires the owner to have enough B3TR tokens and sufficient allowance for the contract to use them
  /// @param tokenId Token ID to upgrade
  function upgrade(uint256 tokenId) public virtual nonReentrant whenNotPaused {
    require(ownerOf(tokenId) == msg.sender, "Galaxy Member: you must own the Token to upgrade it");
    GalaxyMemberStorage storage $ = _getGalaxyMemberStorage();

    uint256 currentLevel = levelOf(tokenId);

    require(currentLevel < MAX_LEVEL(), "Galaxy Member: Token is already at max level");

    uint256 b3trRequired = getB3TRtoUpgrade(tokenId);

    require($.b3tr.balanceOf(msg.sender) >= b3trRequired, "Galaxy Member: Insufficient balance to upgrade");

    require(
      $.b3tr.allowance(msg.sender, address(this)) >= b3trRequired,
      "Galaxy Member: Insufficient allowance to upgrade"
    );

    $._tokenIdToB3TRdonated[tokenId] += b3trRequired;

    require($.b3tr.transferFrom(msg.sender, $.treasury, b3trRequired), "GalaxyMember: Transfer failed");

    emit Upgraded(tokenId, currentLevel, levelOf(tokenId));
  }

  /// @notice Allows the user to select a token for voting rewards multiplier
  /// @param tokenID Token ID to select
  function select(uint256 tokenID) public virtual {
    _select(msg.sender, tokenID);
  }

  /// @notice selects the specified token for the user
  /// @param owner The address of the owner to check
  /// @param tokenId the token ID to select
  function _select(address owner, uint256 tokenId) internal virtual {
    require(ownerOf(tokenId) == owner, "Galaxy Member: caller is not the owner of the token");

    GalaxyMemberStorage storage $ = _getGalaxyMemberStorage();

    $._selectedTokenID[owner] = tokenId;

    emit Selected(owner, tokenId);
  }

  /// @notice Allows the token owner to burn their token
  /// @dev Overrides the ERC721BurnableUpgradeable function to include custom burning logic
  /// @param tokenId Token ID to burn
  function burn(uint256 tokenId) public virtual override(ERC721BurnableUpgradeable) {
    require(ownerOf(tokenId) == msg.sender, "Galaxy Member: caller is not the owner of the token");

    super.burn(tokenId);
  }

  // ------------------------------- VECHAIN NODES FUNCTIONS ------------------------------- //

  function attachNode(uint256 nodeTokenId, uint256 tokenId) public virtual whenNotPaused {
    GalaxyMemberStorage storage $ = _getGalaxyMemberStorage();

    require(ownerOf(tokenId) == msg.sender, "GalaxyMember: token not owned by caller");
    require(
      $.nodeManagement.getNodeManager(nodeTokenId) == msg.sender,
      "GalaxyMember: vechain node not owned or managed by caller"
    );
    require(getIdAttachedToNode(nodeTokenId) == 0, "GalaxyMember: node already attached to a token");
    require(getNodeIdAttached(tokenId) == 0, "GalaxyMember: token already attached to a node");

    $._nodeToTokenId[nodeTokenId] = tokenId;
    $._tokenIdToNode[tokenId] = nodeTokenId;

    emit NodeAttached(nodeTokenId, tokenId);
  }

  function detachNode(uint256 nodeTokenId, uint256 tokenId) public virtual whenNotPaused {
    GalaxyMemberStorage storage $ = _getGalaxyMemberStorage();

    require(
      ownerOf(tokenId) == msg.sender ||
        $.nodeManagement.getNodeManager(nodeTokenId) == msg.sender ||
        $.vechainNodes.idToOwner(nodeTokenId) == msg.sender,
      "GalaxyMember: vechain node not owned or managed by caller or token not owned by caller"
    );
    require(getIdAttachedToNode(nodeTokenId) == tokenId, "GalaxyMember: node not attached to the token");
    require(getNodeIdAttached(tokenId) == nodeTokenId, "GalaxyMember: token not attached to the node");

    delete $._nodeToTokenId[nodeTokenId];
    delete $._tokenIdToNode[tokenId];

    emit NodeDetached(nodeTokenId, tokenId);
  }

  // ----------- Internal & Private ----------- //

  /// @notice Internal function to safely mint a token
  /// @dev Adds a token to the total supply and assigns it to an address, incrementing the owner's balance
  /// @param to Address to mint the token to
  function safeMint(address to) internal virtual {
    GalaxyMemberStorage storage $ = _getGalaxyMemberStorage();

    uint256 tokenId = $._nextTokenId++;
    _safeMint(to, tokenId);
  }

  // ---------- Setters ---------- //

  /// @notice Sets the maximum level that tokens can be minted or upgraded to
  /// @dev Only callable by the admin role
  function setMaxLevel(uint256 level) public virtual onlyRole(DEFAULT_ADMIN_ROLE) {
    GalaxyMemberStorage storage $ = _getGalaxyMemberStorage();

    require(level > $.MAX_LEVEL, "Galaxy Member: Max level must be greater than the current max level");

    // First Level that requires B3TR is level 2
    for (uint256 i = 2; i <= level; i++) {
      require($._b3trToUpgradeToLevel[i] > 0, "Galaxy Member: B3TR to upgrade must be set for all levels unlocked"); // Require all levels til the new max level to have a B3TR requirement
    }

    uint256 oldLevel = $.MAX_LEVEL;

    $.MAX_LEVEL = level;

    emit MaxLevelUpdated(oldLevel, level);
  }

  /// @notice Sets the XAllocationVotingGovernor contract address
  /// @dev Only callable by the contractsAddressManager role
  /// @param _xAllocationsGovernor XAllocationVotingGovernor contract address
  function setXAllocationsGovernorAddress(
    address _xAllocationsGovernor
  ) public virtual onlyRole(CONTRACTS_ADDRESS_MANAGER_ROLE) {
    require(_xAllocationsGovernor != address(0), "Galaxy Member: _xAllocationsGovernor cannot be the zero address");
    GalaxyMemberStorage storage $ = _getGalaxyMemberStorage();

    emit XAllocationsGovernorAddressUpdated(_xAllocationsGovernor, address($.xAllocationsGovernor));
    $.xAllocationsGovernor = IXAllocationVotingGovernor(_xAllocationsGovernor);
  }

  /// @notice Sets the B3TRGovernor contract address
  /// @dev Only callable by the contractsAddressManager role
  /// @param _b3trGovernor B3TRGovernor contract address
  function setB3trGovernorAddress(address _b3trGovernor) public virtual onlyRole(CONTRACTS_ADDRESS_MANAGER_ROLE) {
    require(_b3trGovernor != address(0), "Galaxy Member: _b3trGovernor cannot be the zero address");
    GalaxyMemberStorage storage $ = _getGalaxyMemberStorage();

    emit B3trGovernorAddressUpdated(_b3trGovernor, address($.b3trGovernor));
    $.b3trGovernor = IB3TRGovernor(payable(_b3trGovernor));
  }

  /// @notice Sets the base URI for computing the tokenURI
  /// @dev Only callable by the admin role
  /// @param baseTokenURI Base URI for the Token
  function setBaseURI(string memory baseTokenURI) public virtual onlyRole(DEFAULT_ADMIN_ROLE) {
    require(bytes(baseTokenURI).length > 0, "Galaxy Member: Base URI must be set");
    GalaxyMemberStorage storage $ = _getGalaxyMemberStorage();
    emit BaseURIUpdated(baseTokenURI, $._baseTokenURI);
    $._baseTokenURI = baseTokenURI;
  }

  /// @notice Sets the amount of B3TR required to upgrade to each level
  /// @dev Only callable by the admin role
  /// @param b3trToUpgradeToLevel Mapping of B3TR requirements per level
  function setB3TRtoUpgradeToLevel(uint256[] memory b3trToUpgradeToLevel) public virtual onlyRole(DEFAULT_ADMIN_ROLE) {
    GalaxyMemberStorage storage $ = _getGalaxyMemberStorage();
    for (uint256 i; i < b3trToUpgradeToLevel.length; i++) {
      require(b3trToUpgradeToLevel[i] > 0, "Galaxy Member: B3TR to upgrade must be greater than 0");
      $._b3trToUpgradeToLevel[i + 2] = b3trToUpgradeToLevel[i]; // First Level that requires B3TR is level 2
    }
    emit B3TRtoUpgradeToLevelUpdated(b3trToUpgradeToLevel);
  }

  /// @notice Pauses public minting
  /// @dev Only callable by the admin role
  /// @param isPaused Flag to pause or unpause public minting
  function setIsPublicMintingPaused(bool isPaused) public virtual onlyRole(DEFAULT_ADMIN_ROLE) {
    GalaxyMemberStorage storage $ = _getGalaxyMemberStorage();
    emit PublicMintingPaused(isPaused);
    $.isPublicMintingPaused = isPaused;
  }

  /// @notice Sets the Vechain Nodes contract address
  /// @param _vechainNodes Vechain Nodes contract address
  function setVechainNodes(address _vechainNodes) public virtual onlyRole(NODES_MANAGER_ROLE) {
    require(_vechainNodes != address(0), "GalaxyMember: _vechainNodes cannot be the zero address");
    GalaxyMemberStorage storage $ = _getGalaxyMemberStorage();
    $.vechainNodes = ITokenAuction(_vechainNodes);
  }

  /// @notice Sets the treasury contract address
  /// @param nodeLevel Vechain node level (i.e., 1, 2, 3, 4, 5, 6, 7, 8 => Strength, Thunder, Mjolnir, VeThorX, StrengthX, ThunderX, MjolnirX)
  /// @param level new free upgrade level
  function setNodeToFreeUpgradeLevel(uint8 nodeLevel, uint256 level) public virtual onlyRole(NODES_MANAGER_ROLE) {
    require(level >= 1, "GalaxyMember: invalid level");
    require(nodeLevel >= 1, "GalaxyMember: invalid node level");

    GalaxyMemberStorage storage $ = _getGalaxyMemberStorage();

    require(level <= $.MAX_LEVEL, "GalaxyMember: level must be less than or equal to MAX_LEVEL");

    $._nodeToFreeUpgradeLevel[nodeLevel] = level;
  }

  // ---------- Getters ---------- //

  /// @notice Gets the level of the GM token
  /// @param tokenId Token ID to check
  function levelOf(uint256 tokenId) public view virtual returns (uint256) {
    uint256 nodeId = getNodeIdAttached(tokenId);

    (uint256 level, ) = _getLevelOfAndB3TRleft(tokenId, nodeId);

    return level;
  }

  /// @notice Gets the B3TR required to upgrade to the next level
  /// @param tokenId Token ID to check
  function getB3TRtoUpgrade(uint256 tokenId) public view virtual returns (uint256) {
    if (_ownerOf(tokenId) == address(0)) return 0;

    uint256 nodeId = getNodeIdAttached(tokenId);

    // Get the level of the token and the B3TR donated left to upgrade
    (uint256 currentLevel, uint256 b3trDonatedLeft) = _getLevelOfAndB3TRleft(tokenId, nodeId);

    // If the current level is the max level, return 0
    if (currentLevel == MAX_LEVEL()) {
      return 0;
    }

    // Get the B3TR required to upgrade to the next level by subtracting the B3TR donated left from the B3TR required to upgrade to the next level
    return getB3TRtoUpgradeToLevel(currentLevel + 1) - b3trDonatedLeft;
  }

  /// @notice Gets the level of the GM token and the B3TR Donated left to upgrade
  /// @param tokenId Token ID to check
  /// @return level The level of the token
  /// @return b3trDonatedLeft The B3TR donated left to upgrade
  function _getLevelOfAndB3TRleft(uint256 tokenId, uint256 nodeId) internal view virtual returns (uint256, uint256) {
    GalaxyMemberStorage storage $ = _getGalaxyMemberStorage();

    // Default level is 1 if the token is not attached to a node or the token has not been upgraded
    uint256 level = 1;

    // if the token is attached to a node and the node is managed by the caller
    if (nodeId != 0 && $.nodeManagement.getNodeManager(nodeId) == ownerOf(tokenId)) {
      // Get the level of the node (i.e., Strength, Thunder, Mjolnir, VeThorX, StrengthX, ThunderX, MjolnirX)
      uint8 nodeLevel = getNodeLevelOf(nodeId);

      // If the node level is not 0 (i.e., None)
      if (nodeLevel != 0) {
        // Get the level of the token that can be upgraded for free
        uint256 nodeToFreeLevel = getNodeToFreeLevel(nodeLevel);

        // If the free upgrade level is greater than the current max level, set the level to the max level
        level = nodeToFreeLevel <= $.MAX_LEVEL ? nodeToFreeLevel : $.MAX_LEVEL;
      }
    }

    // Initialise the B3TR donated which keeps track of the B3TR left after upgrading the token
    uint256 b3trDonatedLeft = $._tokenIdToB3TRdonated[tokenId];

    // Loop through the levels starting from the current level and check if the B3TR donated is enough to upgrade to the next level
    for (uint256 i = level + 1; i <= $.MAX_LEVEL; i++) {
      if (b3trDonatedLeft >= $._b3trToUpgradeToLevel[i]) {
        level = i;
        b3trDonatedLeft -= $._b3trToUpgradeToLevel[i];
      } else {
        // If the B3TR donated is not enough to upgrade to the next level, break the loop
        break;
      }
    }

    // Return the level and the B3TR donated left.
    return (level, b3trDonatedLeft);
  }

  /// @notice Gets the strength level of the Vechain node
  /// @param nodeId Vechain Node Token ID
  function getNodeLevelOf(uint256 nodeId) public view virtual returns (uint8) {
    GalaxyMemberStorage storage $ = _getGalaxyMemberStorage();

    (, uint8 nodeLevel, , , , , ) = $.vechainNodes.getMetadata(nodeId);

    return nodeLevel;
  }

  /// @notice Gets the selected token ID for the user
  /// @param owner The address of the owner to check
  function getSelectedTokenId(address owner) public view virtual returns (uint256) {
    GalaxyMemberStorage storage $ = _getGalaxyMemberStorage();
    return $._selectedTokenID[owner];
  }

  /// @notice Gets the level of the token after attaching a node
  /// @param tokenId - GM Token ID
  /// @param nodeTokenId - Vechain Node Token ID
  function getLevelAfterAttachingNode(uint256 tokenId, uint256 nodeTokenId) public view virtual returns (uint256) {
    (uint256 level, ) = _getLevelOfAndB3TRleft(tokenId, nodeTokenId);

    return level;
  }

  /// @notice Gets the level of the token after detaching a node
  /// @param tokenId - GM Token ID
  function getLevelAfterDetachingNode(uint256 tokenId) public view virtual returns (uint256) {
    (uint256 level, ) = _getLevelOfAndB3TRleft(tokenId, 0);

    return level;
  }

  /// @notice Gets whether the user has participated in governance
  /// @param user The address of the user to check
  function participatedInGovernance(address user) public view virtual returns (bool) {
    GalaxyMemberStorage storage $ = _getGalaxyMemberStorage();
    require(
      $.xAllocationsGovernor != IXAllocationVotingGovernor(address(0)),
      "Galaxy Member: XAllocationVotingGovernor not set"
    );
    require($.b3trGovernor != IB3TRGovernor(payable(address(0))), "Galaxy Member: B3TRGovernor not set");

    if ($.xAllocationsGovernor.hasVotedOnce(user) || $.b3trGovernor.hasVotedOnce(user)) {
      return true;
    }

    return false;
  }

  /// @notice Gets the base URI for computing the tokenURI
  function baseURI() public view virtual returns (string memory) {
    return _baseURI();
  }

  /// @notice Gets the B3TR required to upgrade to a specific level
  /// @param level Level to upgrade to
  function getB3TRtoUpgradeToLevel(uint256 level) public view virtual returns (uint256) {
    GalaxyMemberStorage storage $ = _getGalaxyMemberStorage();
    return $._b3trToUpgradeToLevel[level];
  }

  /// @notice gets the token URI for a specific token
  /// @dev computes the token URI based on the base URI and the level of the token
  /// @param tokenId Token ID to get the URI for
  function tokenURI(uint256 tokenId) public view virtual override(ERC721Upgradeable) returns (string memory) {
    if (_ownerOf(tokenId) == address(0)) return "";

    uint256 levelOfToken = levelOf(tokenId);
    return levelOfToken > 0 ? string.concat(baseURI(), Strings.toString(levelOfToken), ".json") : "";
  }

  /// @notice Gets the xAllocationsGovernor contract address
  function xAllocationsGovernor() external view returns (IXAllocationVotingGovernor) {
    GalaxyMemberStorage storage $ = _getGalaxyMemberStorage();
    return $.xAllocationsGovernor;
  }

  /// @notice Gets the b3trGovernor contract address
  function b3trGovernor() external view returns (IB3TRGovernor) {
    GalaxyMemberStorage storage $ = _getGalaxyMemberStorage();
    return $.b3trGovernor;
  }

  /// @notice Gets the B3TR token contract address
  function b3tr() external view returns (IB3TR) {
    GalaxyMemberStorage storage $ = _getGalaxyMemberStorage();
    return $.b3tr;
  }

  /// @notice Gets the treasury contract address
  function treasury() external view returns (address) {
    GalaxyMemberStorage storage $ = _getGalaxyMemberStorage();
    return $.treasury;
  }

  /// @notice Gets the maximum level that tokens can be minted or upgraded to
  function MAX_LEVEL() public view virtual returns (uint256) {
    GalaxyMemberStorage storage $ = _getGalaxyMemberStorage();
    return $.MAX_LEVEL;
  }

  /// @notice Get the GM Token ID attached to the Vechain Node Token ID
  /// @param nodeId Vechain node Token ID
  function getIdAttachedToNode(uint256 nodeId) public view virtual returns (uint256) {
    return _getGalaxyMemberStorage()._nodeToTokenId[nodeId];
  }

  /// @notice Get the Vechain Node Token ID attached to the GM Token ID
  /// @param tokenId GM Token ID
  function getNodeIdAttached(uint256 tokenId) public view virtual returns (uint256) {
    return _getGalaxyMemberStorage()._tokenIdToNode[tokenId];
  }

  /// @notice Get the GM level that can be upgraded for free for a given Vechain node level
  /// @param nodeLevel Vechain node level
  function getNodeToFreeLevel(uint8 nodeLevel) public view virtual returns (uint256) {
    return _getGalaxyMemberStorage()._nodeToFreeUpgradeLevel[nodeLevel];
  }

  /// @notice Get the B3TR donated for upgrading a token
  /// @param tokenId Token ID to check
  function getB3TRdonated(uint256 tokenId) public view virtual returns (uint256) {
    return _getGalaxyMemberStorage()._tokenIdToB3TRdonated[tokenId];
  }

  /// @notice Retrieves the current version of the contract
  /// @dev This function is used to identify the version of the contract and should be updated in each new version
  /// @return string The version of the contract
  function version() external pure virtual returns (string memory) {
    return "2";
  }

  struct TokenInfo {
    uint256 tokenId;
    string tokenURI;
    uint256 tokenLevel;
    uint256 b3trToUpgrade;
  }

  /// @notice Gets the token info by token ID
  /// @param tokenId Token ID to get the info for
  /// @return TokenInfo The token info
  function getTokenInfoByTokenId(uint256 tokenId) public view virtual returns (TokenInfo memory) {
    // Check if the token ID exists
    require(_ownerOf(tokenId) != address(0), "GalaxyMember: tokenId doesn't exist");

    TokenInfo memory tokenInfo;
    tokenInfo.tokenId = tokenId;
    tokenInfo.tokenURI = tokenURI(tokenId);
    tokenInfo.tokenLevel = levelOf(tokenId);
    tokenInfo.b3trToUpgrade = getB3TRtoUpgrade(tokenId);
    return tokenInfo;
  }

  /// @notice Gets the selected token info for an address
  /// @param owner The address of the owner to check
  /// @return TokenInfo The selected token info
  function getSelectedTokenInfoByOwner(address owner) public view returns (TokenInfo memory) {
    uint256 tokenId = getSelectedTokenId(owner);
    return getTokenInfoByTokenId(tokenId);
  }

  /// @notice Gets the tokens owned by an address
  /// @param owner The address of the owner to check
  /// @param page The page number to fetch
  /// @param size The number of tokens to fetch (cannot exceed 100)
  /// @return TokenInfo[] The tokens owned by the address
  function getTokensInfoByOwner(address owner, uint256 page, uint256 size) public view returns (TokenInfo[] memory) {
    // Ensure size is not 0
    if (size == 0) {
      revert("GalaxyMember: Invalid size, cannot be 0");
    }

    // Maximum number of tokens to fetch per page
    uint256 MAX_PAGINATION_SIZE = 100;

    // Ensure size is not greater than the maximum allowed value
    if (size > MAX_PAGINATION_SIZE) {
      revert(
        string(
          abi.encodePacked("GalaxyMember: Invalid size, cannot be greater than ", Strings.toString(MAX_PAGINATION_SIZE))
        )
      );
    }

    uint256 balance = balanceOf(owner); // Get the number of tokens owned by the address

    // Calculate the starting index for the current page
    uint256 start = page * size;

    // If start index is greater than or equal to balance, return an empty array
    if (start >= balance) {
      return new TokenInfo[](0);
    }

    // Calculate the end index (exclusive)
    uint256 end = start + size;
    if (end > balance) {
      end = balance; // Ensure the end index doesn't exceed the owner's balance
    }

    // Calculate the number of tokens to return
    uint256 numTokens = end - start;

    TokenInfo[] memory tokens = new TokenInfo[](numTokens);

    for (uint256 i = 0; i < numTokens; i++) {
      uint256 tokenIndex = start + i;
      uint256 tokenId = tokenOfOwnerByIndex(owner, tokenIndex);
      tokens[i] = getTokenInfoByTokenId(tokenId);
    }

    return tokens;
  }

  // ---------- Overrides ---------- //

  /// @notice Performs automatic level updating upon token updates
  /// @dev Overrides the _update function to update the highest level owned by the owner
  /// @param to The address to transfer the token to
  /// @param tokenId The token ID to update
  /// @param auth The address of the sender
  function _update(
    address to,
    uint256 tokenId,
    address auth
  )
    internal
    override(ERC721Upgradeable, ERC721EnumerableUpgradeable, ERC721PausableUpgradeable)
    whenNotPaused
    returns (address)
  {
    require(getNodeIdAttached(tokenId) == 0, "GalaxyMember: token attached to a node, detach before transfer");

    address _previousOwner = super._update(to, tokenId, auth);

    // If the owner has no tokens, don't select any token
    if (_previousOwner != address(0) && balanceOf(_previousOwner) == 0) {
      delete _getGalaxyMemberStorage()._selectedTokenID[_previousOwner];
    }

    // If the owner transfers out the selected token, select the first token he owns
    if (
      _previousOwner != address(0) && getSelectedTokenId(_previousOwner) == tokenId && balanceOf(_previousOwner) > 0
    ) {
      _select(_previousOwner, tokenOfOwnerByIndex(_previousOwner, 0));
    }

    // If the new owner has only one token, select it
    if (to != address(0) && balanceOf(to) == 1) {
      _select(to, tokenOfOwnerByIndex(to, 0));
    }

    return _previousOwner;
  }

  /// @dev Overrides the _increaseBalance for ERC721Upgradeable and ERC721EnumerableUpgradeable
  function _increaseBalance(
    address account,
    uint128 value
  ) internal override(ERC721Upgradeable, ERC721EnumerableUpgradeable) {
    super._increaseBalance(account, value);
  }

  /// @dev Overrides the supportsInterface for ERC721Upgradeable, ERC721EnumerableUpgradeable, and AccessControlUpgradeable
  function supportsInterface(
    bytes4 interfaceId
  ) public view override(ERC721Upgradeable, ERC721EnumerableUpgradeable, AccessControlUpgradeable) returns (bool) {
    return super.supportsInterface(interfaceId);
  }

  /// @dev Overrides the _baseURI for ERC721URIStorageUpgradeable
  function _baseURI() internal view override returns (string memory) {
    GalaxyMemberStorage storage $ = _getGalaxyMemberStorage();
    return $._baseTokenURI;
  }
}

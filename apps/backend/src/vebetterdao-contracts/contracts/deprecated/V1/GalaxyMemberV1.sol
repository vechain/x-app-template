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
import "@openzeppelin/contracts/interfaces/IERC6372.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { Checkpoints } from "@openzeppelin/contracts/utils/structs/Checkpoints.sol";
import { Time } from "@openzeppelin/contracts/utils/types/Time.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { IXAllocationVotingGovernorV2 } from "../V2/interfaces/IXAllocationVotingGovernorV2.sol";
import { IB3TRGovernorV4 } from "../V4/interfaces/IB3TRGovernorV4.sol";
import { IB3TR } from "./interfaces/IB3TR.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/// @title GalaxyMember NFT Contract
/// @dev Extends ERC721 Non-Fungible Token Standard basic implementation with upgradeable pattern, burnable, pausable, and access control functionalities.
/// @notice This contract manages the unique assets owned by users within the Galaxy Member ecosystem.
contract GalaxyMemberV1 is
  ERC721Upgradeable,
  ERC721EnumerableUpgradeable,
  ERC721PausableUpgradeable,
  ERC721BurnableUpgradeable,
  AccessControlUpgradeable,
  IERC6372,
  ReentrancyGuardUpgradeable,
  UUPSUpgradeable
{
  using Checkpoints for Checkpoints.Trace208; // Checkpoints library for managing checkpoints of the selected level of the user
  bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
  bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
  bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
  bytes32 public constant CONTRACTS_ADDRESS_MANAGER_ROLE = keccak256("CONTRACTS_ADDRESS_MANAGER_ROLE");

  /// @notice Storage structure for GalaxyMember
  /// @dev GalaxyMemberStorage structure holds all the state variables in a single location.
  /// @custom:storage-location erc7201:b3tr.storage.GalaxyMember
  struct GalaxyMemberStorage {
    IXAllocationVotingGovernorV2 xAllocationsGovernor; // XAllocationVotingGovernor contract
    IB3TRGovernorV4 b3trGovernor; // B3TRGovernor contract
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

  /// @dev The clock was incorrectly modified.
  error ERC6372InconsistentClock();

  /// @dev Lookup to future votes is not available.
  error ERC5805FutureLookup(uint256 timepoint, uint48 clock);

  /// @dev Emitted when an account changes the selected token for voting rewards.
  event Selected(address indexed owner, uint256 tokenId);

  /// @dev Emitted when an account changes the selected level for voting rewards.
  event SelectedLevel(address indexed owner, uint256 oldLevel, uint256 newLevel);

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

  /// @notice Internal function to authorize contract upgrades
  /// @dev Restricts upgrade authorization to addresses with UPGRADER_ROLE
  /// @param newImplementation Address of the new contract implementation
  function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

  /// @notice Pauses the Galaxy Member contract
  /// @dev pausing the contract will prevent minting, upgrading, and transferring of tokens
  /// @dev Only callable by the pauser role
  function pause() external onlyRole(PAUSER_ROLE) {
    _pause();
  }

  /// @notice Unpauses the Galaxy Member contract
  /// @dev Only callable by the pauser role
  function unpause() external onlyRole(PAUSER_ROLE) {
    _unpause();
  }

  /// @notice Allows a user to freely mint a token if they have participated in governance
  /// @dev Mints a token with level 1 and ensures that the public minting is not paused
  function freeMint() external whenPublicMintingNotPaused {
    require(participatedInGovernance(msg.sender), "Galaxy Member: User has not participated in governance");
    GalaxyMemberStorage storage $ = _getGalaxyMemberStorage();

    uint256 tokenId = $._nextTokenId;

    $.levelOf[tokenId] = 1;

    safeMint(msg.sender);
  }

  /// @notice Mints a new token to a specified address
  /// @dev Only callable by the minter role
  /// @dev Can be used to mint when public minting is paused
  /// @param to Address to mint the token to
  function mint(address to) external onlyRole(MINTER_ROLE) {
    GalaxyMemberStorage storage $ = _getGalaxyMemberStorage();

    uint256 tokenId = $._nextTokenId;

    $.levelOf[tokenId] = 1;

    safeMint(to);
  }

  /// @notice Upgrades a token to the next level
  /// @dev Requires the owner to have enough B3TR tokens and sufficient allowance for the contract to use them
  /// @param tokenId Token ID to upgrade
  function upgrade(uint256 tokenId) external nonReentrant whenNotPaused {
    require(ownerOf(tokenId) == msg.sender, "Galaxy Member: you must own the Token to upgrade it");
    GalaxyMemberStorage storage $ = _getGalaxyMemberStorage();

    uint256 currentLevel = $.levelOf[tokenId];

    require(currentLevel < $.MAX_LEVEL, "Galaxy Member: Token is already at max level");

    uint256 b3trRequired = $._b3trToUpgradeToLevel[currentLevel + 1];

    require($.b3tr.balanceOf(msg.sender) >= b3trRequired, "Galaxy Member: Insufficient balance to upgrade");

    require(
      $.b3tr.allowance(msg.sender, address(this)) >= b3trRequired,
      "Galaxy Member: Insufficient allowance to upgrade"
    );

    $.levelOf[tokenId] = currentLevel + 1;

    $._ownedLevels[msg.sender][currentLevel]--;
    $._ownedLevels[msg.sender][currentLevel + 1]++;

    uint256 currentHighestLevel = getHighestLevel(msg.sender);

    if ($.levelOf[tokenId] > currentHighestLevel) {
      _updateLevelSelected(msg.sender, $.levelOf[tokenId]);
    }

    require($.b3tr.transferFrom(msg.sender, $.treasury, b3trRequired), "GalaxyMember: Transfer failed");

    emit Upgraded(tokenId, currentLevel, $.levelOf[tokenId]);
  }

  /// @notice Automatically selects the highest level token owned by the caller for voting rewards
  function selectHighestLevel() external {
    _selectHighestLevel(msg.sender);
  }

  /// @notice Allows the token owner to burn their token
  /// @dev Overrides the ERC721BurnableUpgradeable function to include custom burning logic
  /// @param tokenId Token ID to burn
  function burn(uint256 tokenId) public override(ERC721BurnableUpgradeable) {
    require(ownerOf(tokenId) == msg.sender, "Galaxy Member: caller is not the owner of the token");

    super.burn(tokenId);
  }

  // ----------- Internal & Private ----------- //

  /// @notice Internal function to safely mint a token
  /// @dev Adds a token to the total supply and assigns it to an address, incrementing the owner's balance
  /// @param to Address to mint the token to
  function safeMint(address to) internal {
    GalaxyMemberStorage storage $ = _getGalaxyMemberStorage();

    uint256 tokenId = $._nextTokenId++;
    _safeMint(to, tokenId);
  }

  /// @notice Internal function to select the highest level owned by the owner
  /// @dev Loops through the levels owned by the user and selects the highest level by updating the selected level checkpoint
  function _selectHighestLevel(address owner) internal {
    GalaxyMemberStorage storage $ = _getGalaxyMemberStorage();

    /**
     * @dev Loop through the levels owned by the user and select the highest level
     * Out-of-gas safe as the loop will break as soon as the highest level is found and the MAX_LEVEL should not be too high
     */
    for (uint256 level = $.MAX_LEVEL; level > 0; level--) {
      if ($._ownedLevels[owner][level] > 0) {
        _updateLevelSelected(owner, level);
        break;
      }
    }
  }

  /// @notice Internal function to update the highest level owned by the owner
  /// @dev Updates the highest level owned by the owner and updates the selected level checkpoint
  function _updateHighestLevelOwned(address from, address to, uint256 tokenId) internal {
    if (from != to) {
      GalaxyMemberStorage storage $ = _getGalaxyMemberStorage();

      if (from != address(0)) {
        // If the owner is transferring their only token then we checkpoint the selected level to 0
        if (balanceOf(from) == 1) _updateLevelSelected(from, 0);

        $._ownedLevels[from][$.levelOf[tokenId]]--;

        // If the user is transferring a token of the highest level they own then we select the next highest level
        // note that it might be the same level if they own multiple tokens of the same level
        if ($.levelOf[tokenId] == getHighestLevel(from) && balanceOf(from) > 1) _selectHighestLevel(from);
      }
      if (to != address(0)) {
        $._ownedLevels[to][$.levelOf[tokenId]]++;

        // If the user is receiving a token of a higher level than they currently have selected then we update the selected level
        if ($.levelOf[tokenId] > getHighestLevel(to)) {
          _updateLevelSelected(to, $.levelOf[tokenId]);
        }
      }
    }
  }

  /// @notice Internal function to update the selected level checkpoint
  /// @dev Updates the selected level checkpoint for the owner
  function _updateLevelSelected(address owner, uint256 level) internal {
    GalaxyMemberStorage storage $ = _getGalaxyMemberStorage();
    // If the selected level is different from the new level then we checkpoint the selected level to the new level
    if (getHighestLevel(owner) != level) {
      (uint256 oldLevel, uint256 newLevel) = _push($._selectedLevelCheckpoints[owner], SafeCast.toUint208(level));

      emit SelectedLevel(owner, oldLevel, newLevel);
    }
  }

  /// @notice Internal function to push a new checkpoint
  /// @dev Pushes a new checkpoint to the selected level checkpoints
  function _push(Checkpoints.Trace208 storage store, uint208 delta) private returns (uint208, uint208) {
    return store.push(clock(), delta);
  }

  /// @dev Get number of checkpoints for `account`.
  function _numCheckpoints(address account) internal view virtual returns (uint32) {
    GalaxyMemberStorage storage $ = _getGalaxyMemberStorage();
    return SafeCast.toUint32($._selectedLevelCheckpoints[account].length());
  }

  /// @dev Get the `pos`-th checkpoint for `account`.
  function _checkpoints(address account, uint32 pos) internal view virtual returns (Checkpoints.Checkpoint208 memory) {
    GalaxyMemberStorage storage $ = _getGalaxyMemberStorage();

    return $._selectedLevelCheckpoints[account].at(pos);
  }

  // ---------- Setters ---------- //

  /// @notice Sets the maximum level that tokens can be minted or upgraded to
  /// @dev Only callable by the admin role
  function setMaxLevel(uint256 level) external onlyRole(DEFAULT_ADMIN_ROLE) {
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
  ) external onlyRole(CONTRACTS_ADDRESS_MANAGER_ROLE) {
    require(_xAllocationsGovernor != address(0), "Galaxy Member: _xAllocationsGovernor cannot be the zero address");
    GalaxyMemberStorage storage $ = _getGalaxyMemberStorage();

    emit XAllocationsGovernorAddressUpdated(_xAllocationsGovernor, address($.xAllocationsGovernor));
    $.xAllocationsGovernor = IXAllocationVotingGovernorV2(_xAllocationsGovernor);
  }

  /// @notice Sets the B3TRGovernor contract address
  /// @dev Only callable by the contractsAddressManager role
  /// @param _b3trGovernor B3TRGovernor contract address
  function setB3trGovernorAddress(address _b3trGovernor) external onlyRole(CONTRACTS_ADDRESS_MANAGER_ROLE) {
    require(_b3trGovernor != address(0), "Galaxy Member: _b3trGovernor cannot be the zero address");
    GalaxyMemberStorage storage $ = _getGalaxyMemberStorage();

    emit B3trGovernorAddressUpdated(_b3trGovernor, address($.b3trGovernor));
    $.b3trGovernor = IB3TRGovernorV4(payable(_b3trGovernor));
  }

  /// @notice Sets the base URI for computing the tokenURI
  /// @dev Only callable by the admin role
  /// @param baseTokenURI Base URI for the Token
  function setBaseURI(string memory baseTokenURI) external onlyRole(DEFAULT_ADMIN_ROLE) {
    require(bytes(baseTokenURI).length > 0, "Galaxy Member: Base URI must be set");
    GalaxyMemberStorage storage $ = _getGalaxyMemberStorage();
    emit BaseURIUpdated(baseTokenURI, $._baseTokenURI);
    $._baseTokenURI = baseTokenURI;
  }

  /// @notice Sets the amount of B3TR required to upgrade to each level
  /// @dev Only callable by the admin role
  /// @param b3trToUpgradeToLevel Mapping of B3TR requirements per level
  function setB3TRtoUpgradeToLevel(uint256[] memory b3trToUpgradeToLevel) external onlyRole(DEFAULT_ADMIN_ROLE) {
    GalaxyMemberStorage storage $ = _getGalaxyMemberStorage();
    for (uint256 i = 0; i < b3trToUpgradeToLevel.length; i++) {
      require(b3trToUpgradeToLevel[i] > 0, "Galaxy Member: B3TR to upgrade must be greater than 0");
      $._b3trToUpgradeToLevel[i + 2] = b3trToUpgradeToLevel[i]; // First Level that requires B3TR is level 2
    }
    emit B3TRtoUpgradeToLevelUpdated(b3trToUpgradeToLevel);
  }

  /// @notice Pauses public minting
  /// @dev Only callable by the admin role
  /// @param isPaused Flag to pause or unpause public minting
  function setIsPublicMintingPaused(bool isPaused) external onlyRole(DEFAULT_ADMIN_ROLE) {
    GalaxyMemberStorage storage $ = _getGalaxyMemberStorage();
    emit PublicMintingPaused(isPaused);
    $.isPublicMintingPaused = isPaused;
  }

  // ---------- Getters ---------- //

  /// @notice Gets the highest level owned by the owner
  /// @param owner The address of the owner
  function getHighestLevel(address owner) public view returns (uint256) {
    GalaxyMemberStorage storage $ = _getGalaxyMemberStorage();
    return $._selectedLevelCheckpoints[owner].latest();
  }

  /// @notice Gets the highest level owned by the owner at a specific timepoint
  /// @dev Reverts if the timepoint is in the future
  /// @param owner The address of the owner
  /// @param timepoint The timepoint to check
  function getPastHighestLevel(address owner, uint256 timepoint) external view returns (uint256) {
    uint48 currentTimepoint = clock();
    if (timepoint >= currentTimepoint) {
      revert ERC5805FutureLookup(timepoint, currentTimepoint);
    }
    GalaxyMemberStorage storage $ = _getGalaxyMemberStorage();
    return $._selectedLevelCheckpoints[owner].upperLookupRecent(SafeCast.toUint48(timepoint));
  }

  /// @notice Gets the selected level of the owner
  /// @param account The address of the account to check
  function numCheckpoints(address account) external view returns (uint32) {
    return _numCheckpoints(account);
  }

  /// @notice Gets the checkpoints of a specific account at a specific position
  /// @dev Get the `pos`-th checkpoint for `account`.
  /// @param account The address of the account to check
  /// @param pos The position of the checkpoint to check
  function checkpoints(address account, uint32 pos) public view virtual returns (Checkpoints.Checkpoint208 memory) {
    return _checkpoints(account, pos);
  }

  /// @notice Gets whether the user has participated in governance
  /// @param user The address of the user to check
  function participatedInGovernance(address user) public view returns (bool) {
    GalaxyMemberStorage storage $ = _getGalaxyMemberStorage();
    require(
      $.xAllocationsGovernor != IXAllocationVotingGovernorV2(address(0)),
      "Galaxy Member: XAllocationVotingGovernor not set"
    );
    require($.b3trGovernor != IB3TRGovernorV4(payable(address(0))), "Galaxy Member: B3TRGovernor not set");

    if ($.xAllocationsGovernor.hasVotedOnce(user) || $.b3trGovernor.hasVotedOnce(user)) {
      return true;
    }

    return false;
  }

  /// @notice Gets the base URI for computing the tokenURI
  function baseURI() public view returns (string memory) {
    return _baseURI();
  }

  /// @notice Gets the B3TR required to upgrade to a specific level
  /// @param level Level to upgrade to
  function getB3TRtoUpgradeToLevel(uint256 level) external view returns (uint256) {
    GalaxyMemberStorage storage $ = _getGalaxyMemberStorage();
    return $._b3trToUpgradeToLevel[level];
  }

  /// @notice Gets the next level of the token
  /// @param tokenId Token ID to check
  function getNextLevel(uint256 tokenId) external view returns (uint256) {
    GalaxyMemberStorage storage $ = _getGalaxyMemberStorage();
    return $.levelOf[tokenId] + 1;
  }

  /// @notice Gets the B3TR required to upgrade to the next level of the token
  /// @param tokenId Token ID to check
  function getB3TRtoUpgrade(uint256 tokenId) external view returns (uint256) {
    GalaxyMemberStorage storage $ = _getGalaxyMemberStorage();
    return $._b3trToUpgradeToLevel[$.levelOf[tokenId] + 1];
  }

  /// @dev Clock used for flagging checkpoints. Can be overridden to implement timestamp based checkpoints (and voting), in which case {CLOCK_MODE} should be overridden as well to match.
  function clock() public view virtual returns (uint48) {
    return Time.blockNumber();
  }

  /// @dev Machine-readable description of the clock as specified in EIP-6372.
  // solhint-disable-next-line func-name-mixedcase
  function CLOCK_MODE() external view virtual returns (string memory) {
    // Check that the clock was not modified
    if (clock() != Time.blockNumber()) {
      revert ERC6372InconsistentClock();
    }
    return "mode=blocknumber&from=default";
  }

  /// @notice gets the token URI for a specific token
  /// @dev computes the token URI based on the base URI and the level of the token
  /// @param tokenId Token ID to get the URI for
  function tokenURI(uint256 tokenId) public view override(ERC721Upgradeable) returns (string memory) {
    GalaxyMemberStorage storage $ = _getGalaxyMemberStorage();
    uint256 levelOfToken = $.levelOf[tokenId];
    return levelOfToken > 0 ? string.concat(baseURI(), Strings.toString(levelOfToken), ".json") : "";
  }

  /// @notice Gets the xAllocationsGovernor contract address
  function xAllocationsGovernor() external view returns (IXAllocationVotingGovernorV2) {
    GalaxyMemberStorage storage $ = _getGalaxyMemberStorage();
    return $.xAllocationsGovernor;
  }

  /// @notice Gets the b3trGovernor contract address
  function b3trGovernor() external view returns (IB3TRGovernorV4) {
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
  function MAX_LEVEL() external view returns (uint256) {
    GalaxyMemberStorage storage $ = _getGalaxyMemberStorage();
    return $.MAX_LEVEL;
  }

  /// @notice Gets the level of the token
  function levelOf(uint256 tokenId) external view returns (uint256) {
    GalaxyMemberStorage storage $ = _getGalaxyMemberStorage();
    return $.levelOf[tokenId];
  }

  /// @notice Retrieves the current version of the contract
  /// @dev This function is used to identify the version of the contract and should be updated in each new version
  /// @return string The version of the contract
  function version() external pure virtual returns (string memory) {
    return "1";
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
    _updateHighestLevelOwned(auth, to, tokenId);

    return super._update(to, tokenId, auth);
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

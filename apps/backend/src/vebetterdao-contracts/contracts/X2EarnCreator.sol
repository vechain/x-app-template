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
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/// @title X2EarnCreator
/// @notice Contract for minting and managing NFTs for X2Earn creators of VeBetterDAO.
/// @dev This contract extends ERC721 Non-Fungible Token Standard basic implementation with upgradeable pattern, enumerable, pausable, and access control functionalities.
contract X2EarnCreator is
  Initializable,
  ERC721Upgradeable,
  ERC721PausableUpgradeable,
  ERC721EnumerableUpgradeable,
  AccessControlUpgradeable,
  UUPSUpgradeable
{
  // ---------------- Roles ----------------
  bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
  bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
  bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
  bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

  // ---------------- Errors ----------------
  /// @dev Error thrown when a transfer attempt is made, as transfers are disabled
  error TransfersDisabled();

  /// @dev Error thrown when a user already owns an NFT
  error AlreadyOwnsNFT(address owner);

  /// @dev Error thrown when a user is not authorized to perform an action
  error X2EarnCreatorUnauthorizedUser(address user);

  // ---------------- Storage ----------------
  /// @notice Storage structure for X2EarnCreator
  /// @custom:storage-location erc7201:b3tr.storage.X2EarnCreator
  struct X2EarnCreatorStorage {
    uint256 nextTokenId;
    string baseURI;
  }

  /// @notice Storage slot for X2EarnCreator
  /// @dev keccak256(abi.encode(uint256(keccak256("b3tr.storage.X2EarnCreator")) - 1)) & ~bytes32(uint256(0xff))
  bytes32 private constant X2EarnCreatorStorageLocation =
    0xaf8fa2a2e81e5e00a4ef8747fbca475174c33b675ca2c56fe05a83bfd2d8fc00;

  /// @dev Retrieves the stored `X2EarnCreator` from its designated slot
  function _getX2EarnCreatorStorage() private pure returns (X2EarnCreatorStorage storage $) {
    assembly {
      $.slot := X2EarnCreatorStorageLocation
    }
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  /// @notice Initializes the contract with role-based access control
  /// @param baseURI The base URI for the NFT metadata
  /// @param defaultAdmin Address to be assigned the default admin role
  function initialize(string calldata baseURI, address defaultAdmin) public initializer {
    __ERC721_init("X2EarnCreator", "X2C");
    __ERC721Pausable_init();
    __AccessControl_init();
    __UUPSUpgradeable_init();
    __ERC721Enumerable_init();

    X2EarnCreatorStorage storage $ = _getX2EarnCreatorStorage();

    require(bytes(baseURI).length > 0, "X2EarnCreator: baseURI is empty");
    $.baseURI = baseURI;

    require(defaultAdmin != address(0), "X2EarnCreator: zero address");

    _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);

    // make token id start from 1
    $.nextTokenId = 1;
  }

  // ---------- Modifiers ------------ //

  /// @notice Modifier to check if the user has the required role or is the DEFAULT_ADMIN_ROLE
  /// @param role - the role to check
  modifier onlyRoleOrAdmin(bytes32 role) {
    if (!hasRole(role, msg.sender) && !hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
      revert X2EarnCreatorUnauthorizedUser(msg.sender);
    }
    _;
  }

  // ---------- Setters ---------- //

  /// @notice Pauses all token transfers and minting functions
  /// @dev Only callable by accounts with the PAUSER_ROLE or the DEFAULT_ADMIN_ROLE
  function pause() public onlyRoleOrAdmin(PAUSER_ROLE) {
    _pause();
  }

  /// @notice Unpauses the contract to resume token transfers and minting
  /// @dev Only callable by accounts with the PAUSER_ROLE or the DEFAULT_ADMIN_ROLE
  function unpause() public onlyRoleOrAdmin(PAUSER_ROLE) {
    _unpause();
  }

  /// @notice Burns a specific token, removing it from circulation
  /// @param tokenId ID of the token to burn
  /// @dev Only callable by accounts with the BURNER_ROLE or the DEFAULT_ADMIN_ROLE
  function burn(uint256 tokenId) public onlyRoleOrAdmin(BURNER_ROLE) whenNotPaused {
    _burn(tokenId);
  }

  /// @notice Mints a new token to a specified address
  /// @param to Address that will receive the new token
  /// @dev Only callable by accounts with the MINTER_ROLE or the DEFAULT_ADMIN_ROLE. Ensures the address does not already own a token.
  function safeMint(address to) public onlyRoleOrAdmin(MINTER_ROLE) whenNotPaused {
    if (balanceOf(to) > 0) {
      revert AlreadyOwnsNFT(to);
    }

    X2EarnCreatorStorage storage $ = _getX2EarnCreatorStorage();
    uint256 tokenId = $.nextTokenId++;

    _safeMint(to, tokenId);
  }

  // @notice Retrieves the metadata URI for a given token ID
  /// @dev Ensures the token ID is owned, then returns the base URI as the token URI
  /// @param tokenId The ID of the token to retrieve the URI for
  /// @return The metadata URI for the specified token ID
  function tokenURI(uint256 tokenId) public view override(ERC721Upgradeable) returns (string memory) {
    _requireOwned(tokenId);

    string memory baseURI = _baseURI();
    return baseURI;
  }

  /// @notice Retrieves the base URI for the NFT metadata
  /// @return The base URI for the NFT metadata
  function baseURI() public view returns (string memory) {
    X2EarnCreatorStorage storage $ = _getX2EarnCreatorStorage();
    return $.baseURI;
  }

  /// @notice Retieves the version of the contract
  function version() public pure returns (string memory) {
    return "1";
  }

  // ---------------- Overrides for Non-Transferability ----------------

  /// @notice Prevents token transfers by reverting any call to transferFrom
  /// @dev Override to disable token transfers, making tokens non-transferable
  function transferFrom(address, address, uint256) public pure override(ERC721Upgradeable, IERC721) {
    revert TransfersDisabled();
  }

  /// @notice Prevents safe token transfers by reverting any call to safeTransferFrom
  /// @dev Override to disable safe token transfers, making tokens non-transferable
  function safeTransferFrom(address, address, uint256, bytes memory) public pure override(ERC721Upgradeable, IERC721) {
    revert TransfersDisabled();
  }

  /// @notice Prevents approvals by reverting any call to approve
  /// @dev Override to disable approval functionality
  function approve(address, uint256) public pure override(ERC721Upgradeable, IERC721) {
    revert TransfersDisabled();
  }

  /// @notice Prevents setting approval for all by reverting any call to setApprovalForAll
  /// @dev Override to disable approval functionality
  function setApprovalForAll(address, bool) public pure override(ERC721Upgradeable, IERC721) {
    revert TransfersDisabled();
  }

  /// @notice Sets the base URI for the NFT metadata
  /// @param newBaseURI The new base URI for the NFT metadata
  /// @dev Only callable by accounts with the DEFAULT_ADMIN_ROLE
  function setBaseURI(string calldata newBaseURI) public onlyRole(DEFAULT_ADMIN_ROLE) {
    X2EarnCreatorStorage storage $ = _getX2EarnCreatorStorage();
    $.baseURI = newBaseURI;
  }

  // ---------------- Internal Functions ----------------

  /// @notice Returns the base URI used for all token metadata URIs in the contract
  /// @dev This function retrieves the base URI from the contract's storage.
  function _baseURI() internal view override(ERC721Upgradeable) returns (string memory) {
    X2EarnCreatorStorage storage $ = _getX2EarnCreatorStorage();
    return $.baseURI;
  }

  // ---------------- Upgrade and Utility Overrides ----------------
  function _authorizeUpgrade(address newImplementation) internal override onlyRoleOrAdmin(UPGRADER_ROLE) {}

  function _update(
    address to,
    uint256 tokenId,
    address auth
  ) internal override(ERC721Upgradeable, ERC721PausableUpgradeable, ERC721EnumerableUpgradeable) returns (address) {
    return super._update(to, tokenId, auth);
  }

  function supportsInterface(
    bytes4 interfaceId
  ) public view override(ERC721Upgradeable, ERC721EnumerableUpgradeable, AccessControlUpgradeable) returns (bool) {
    return super.supportsInterface(interfaceId);
  }

  function _increaseBalance(
    address account,
    uint128 value
  ) internal override(ERC721Upgradeable, ERC721EnumerableUpgradeable) {
    super._increaseBalance(account, value);
  }
}

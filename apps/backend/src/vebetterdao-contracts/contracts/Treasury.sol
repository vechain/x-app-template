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
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IERC721.sol";
import "./interfaces/IVOT3.sol";
import "./interfaces/IERC1155.sol";

/// @title Treasury Contract for VeBetter DAO
/// @dev This contract handles the receiving and transferring of assets, leveraging upgradeable, pausable, and access control features.
/// @notice This contract is designed to manage all assets owned by the VeBetter DAO
contract Treasury is
  IERC721Receiver,
  IERC1155Receiver,
  AccessControlUpgradeable,
  PausableUpgradeable,
  ReentrancyGuardUpgradeable,
  UUPSUpgradeable
{
  /// @notice Role identifier for governance operations
  bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
  /// @notice Role identifier for upgrading the contract
  bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
  /// @notice Role identifier for pausing the contract
  bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
  /// @notice Address of VTHO token (Built-in Contract on Vechain Thor)
  address public constant VTHO = 0x0000000000000000000000000000456E65726779;

  /// @notice Storage structure for Treasury
  /// @dev GalaxyMemberStorage structure holds all the state variables in a single location.
  /// @custom:storage-location erc7201:b3tr.storage.Treasury
  struct TreasuryStorage {
    address B3TR;
    address VOT3;
    mapping(address => uint256) transferLimit; // Mapping of token addresses to their transfer limits
    uint256 transferLimitVET; // Transfer limit for VET
  }

  /// @notice Emitted when transfer limit for a token is updated
  event TransferLimitUpdated(address indexed token, uint256 limit);

  /// @notice Emitted when transfer limit for VET is updated
  event TransferLimitVETUpdated(uint256 limit);

  /// @dev The slot for Treasury storage in contract storage
  /// keccak256(abi.encode(uint256(keccak256("b3tr.storage.Treasury")) - 1)) & ~bytes32(uint256(0xff))
  bytes32 private constant TreasuryStorageLocation = 0xe0cc5742fa27b7db7d28941bcd9e29ed370469b1c96f6a96a9544ba871b50f00;

  /// @dev Retrieves the stored `TreasuryStorage` from its designated slot
  function _getTreasuryStorage() internal pure returns (TreasuryStorage storage $) {
    assembly {
      $.slot := TreasuryStorageLocation
    }
  }

  /// @dev Ensures that only users with governance role can perform actions when the contract is not paused
  modifier onlyGovernanceWhenNotPaused() {
    require(hasRole(GOVERNANCE_ROLE, _msgSender()), "Treasury: caller is not a governance actor");
    require(!paused(), "Treasury: contract is paused");
    _;
  }

  modifier onlyAdminOrGovernance() {
    require(
      hasRole(DEFAULT_ADMIN_ROLE, _msgSender()) || hasRole(GOVERNANCE_ROLE, _msgSender()),
      "Treasury: caller is not an admin or governance actor"
    );
    _;
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  /// @notice Initializes the contract with necessary roles and token addresses
  /// @param _b3tr Address of the B3TR token
  /// @param _vot3 Address of the VOT3 token
  /// @param _timeLock Address of the timelock contract controlling governance actions
  /// @param _admin Address of the admin responsible for initial setup
  /// @param _proxyAdmin Address of the proxy administrator for upgrade purposes
  /// @param _pauser Address of the pauser role
  /// @param _transferLimitVET Transfer limit for VET
  /// @param _transferLimitB3TR Transfer limit for B3TR
  /// @param _transferLimitVOT3 Transfer limit for VOT3
  /// @param _transferLimitVTHO Transfer limit for VTHO
  function initialize(
    address _b3tr,
    address _vot3,
    address _timeLock,
    address _admin,
    address _proxyAdmin,
    address _pauser,
    uint256 _transferLimitVET,
    uint256 _transferLimitB3TR,
    uint256 _transferLimitVOT3,
    uint256 _transferLimitVTHO
  ) external initializer {
    _validateAddresses(_b3tr, _vot3);

    __UUPSUpgradeable_init();
    __AccessControl_init();
    __Pausable_init();
    __ReentrancyGuard_init();

    _setLimits(_transferLimitVET, _transferLimitB3TR, _transferLimitVOT3, _transferLimitVTHO);

    require(_admin != address(0), "Treasury: admin address cannot be zero");
    _grantRole(DEFAULT_ADMIN_ROLE, _admin);
    _grantRole(GOVERNANCE_ROLE, _timeLock);
    _grantRole(UPGRADER_ROLE, _proxyAdmin);
    _grantRole(PAUSER_ROLE, _pauser);
  }

  function _validateAddresses(address _b3tr, address _vot3) private {
    require(_b3tr != address(0), "Treasury: B3TR address cannot be zero");
    require(_vot3 != address(0), "Treasury: VOT3 address cannot be zero");

    TreasuryStorage storage $ = _getTreasuryStorage();
    $.B3TR = _b3tr;
    $.VOT3 = _vot3;
  }

  function _setLimits(
    uint256 _transferLimitVET,
    uint256 _transferLimitB3TR,
    uint256 _transferLimitVOT3,
    uint256 _transferLimitVTHO
  ) private {
    TreasuryStorage storage $ = _getTreasuryStorage();
    $.transferLimitVET = _transferLimitVET;
    $.transferLimit[$.B3TR] = _transferLimitB3TR;
    $.transferLimit[$.VOT3] = _transferLimitVOT3;
    $.transferLimit[VTHO] = _transferLimitVTHO;
  }

  /// @notice Allows the contract to receive VET directly
  receive() external payable {}

  /// @notice Fallback function to handle incoming VET when data is sent
  fallback() external payable {}

  /// @notice Pauses the Treasury contract
  /// @dev Pausing the contract will prevent all transfers and staking operations
  /// @dev Only admin with pauser role can pause the contract
  function pause() external onlyRole(PAUSER_ROLE) {
    _pause();
  }

  /// @notice Unpauses the Treasury contract allowing normal operations
  /// @dev Only admin with pauser role can unpause the contract
  function unpause() external onlyRole(PAUSER_ROLE) {
    _unpause();
  }

  /// @notice Transfers a specified amount of VTHO tokens to a specified address
  /// @dev Only governance can transfer VTHO when the contract is not paused
  /// @param _to Recipient of the VTHO
  /// @param _value Amount of VTHO to transfer
  function transferVTHO(address _to, uint256 _value) external onlyGovernanceWhenNotPaused {
    TreasuryStorage storage $ = _getTreasuryStorage();

    require($.transferLimit[VTHO] >= _value, "Treasury: transfer limit exceeded");

    IERC20 vtho = _getERC20Contract(VTHO);

    require(vtho.balanceOf(address(this)) >= _value, "Treasury: insufficient VTHO balance");
    require(vtho.transfer(_to, _value), "Treasury: transfer failed");
  }

  /// @notice Transfers a specified amount of B3TR tokens to a specified address
  /// @dev Only governance can transfer B3TR when the contract is not paused
  /// @param _to Recipient of the B3TR
  /// @param _value Amount of B3TR to transfer
  function transferB3TR(address _to, uint256 _value) external onlyGovernanceWhenNotPaused {
    TreasuryStorage storage $ = _getTreasuryStorage();

    require($.transferLimit[$.B3TR] >= _value, "Treasury: transfer limit exceeded");

    IERC20 b3tr = _getERC20Contract(b3trAddress());
    require(b3tr.balanceOf(address(this)) >= _value, "Treasury: insufficient B3TR balance");
    require(b3tr.transfer(_to, _value), "Treasury: transfer failed");
  }

  /// @notice Transfers a specified amount of VOT3 tokens to a specified address
  /// @dev Only governance can transfer VOT3 when the contract is not paused
  /// @param _to Recipient of the VOT3
  /// @param _value Amount of VOT3 to transfer
  function transferVOT3(address _to, uint256 _value) external onlyGovernanceWhenNotPaused {
    TreasuryStorage storage $ = _getTreasuryStorage();

    require($.transferLimit[$.VOT3] >= _value, "Treasury: transfer limit exceeded");

    IERC20 vot3 = _getERC20Contract(vot3Address());
    require(vot3.balanceOf(address(this)) >= _value, "Treasury: insufficient VOT3 balance");
    require(vot3.transfer(_to, _value), "Treasury: transfer failed");
  }

  /// @notice Transfers a specified amount of VET to a specified address
  /// @dev Only governance can transfer VET when the contract is not paused
  /// @param _to Recipient of the VET
  /// @param _value Amount of VET to transfer
  function transferVET(address _to, uint256 _value) external onlyGovernanceWhenNotPaused nonReentrant {
    TreasuryStorage storage $ = _getTreasuryStorage();

    require($.transferLimitVET >= _value, "Treasury: transfer limit exceeded");

    require(address(this).balance >= _value, "Treasury: insufficient VET balance");
    (bool sent, ) = _to.call{ value: _value }("");
    require(sent, "Failed to send VET");
  }

  /// @notice Transfers any ERC20 token to a given address
  /// @dev Only governance can transfer tokens when the contract is not paused
  /// @param _token The ERC20 token to transfer
  /// @param _to Recipient of the ERC20 token
  /// @param _value Amount of the ERC20 token to transfer
  function transferTokens(address _token, address _to, uint256 _value) external onlyGovernanceWhenNotPaused {
    TreasuryStorage storage $ = _getTreasuryStorage();

    require($.transferLimit[_token] >= _value, "Treasury: transfer limit exceeded");

    IERC20 token = _getERC20Contract(_token);
    require(token.balanceOf(address(this)) >= _value, "Treasury: insufficient balance");
    require(token.transfer(_to, _value), "Treasury: transfer failed");
  }

  /// @notice Transfers an ERC721 token to a specified address
  /// @dev Only governance can transfer NFTs when the contract is not paused
  /// @param _nft The ERC721 token to transfer
  /// @param _to Recipient of the ERC721 token
  /// @param _tokenId The id of the ERC721 token to transfer
  function transferNFT(address _nft, address _to, uint256 _tokenId) external onlyGovernanceWhenNotPaused {
    IERC721 nft = IERC721(_nft);
    require(nft.ownerOf(_tokenId) == address(this), "Treasury: DAO does not own the NFT");
    nft.safeTransferFrom(address(this), _to, _tokenId);
  }

  /// @notice Transfers an ERC1155 token to a specified address
  /// @dev Only governance can transfer ERC1155 tokens when the contract is not paused
  /// @param _tokenAddress The ERC1155 token to transfer
  /// @param _to Recipient of the ERC1155 token
  /// @param _id The id of the ERC1155 token to transfer
  /// @param _value The amount of token ERC1155 token to transfer
  /// @param _data Additional data with no specified format
  function transferERC1155Tokens(
    address _tokenAddress,
    address _to,
    uint256 _id,
    uint256 _value,
    bytes calldata _data
  ) external onlyGovernanceWhenNotPaused nonReentrant {
    IERC1155 erc1155 = IERC1155(_tokenAddress);
    require(erc1155.balanceOf(address(this), _id) > 0, "Treasury: DAO does not own this ERC1155 token");
    erc1155.safeTransferFrom(address(this), _to, _id, _value, _data);
  }

  /// @notice Converts a specified amount of B3TR to VOT3
  /// @dev Only governance can convert B3TR when the contract is not paused
  /// @param _b3trAmount Amount of B3TR to convert
  function convertB3TR(uint256 _b3trAmount) external onlyGovernanceWhenNotPaused {
    IERC20 b3tr = _getERC20Contract(b3trAddress());
    IVOT3 vot3 = IVOT3(vot3Address());
    require(b3tr.balanceOf(address(this)) >= _b3trAmount, "Treasury: insufficient B3TR balance");
    require(b3tr.approve(vot3Address(), _b3trAmount), "Treasury: approval for VOT3 failed");
    vot3.convertToVOT3(_b3trAmount);
  }

  /// @notice Converts a specified amount of VOT3 to B3TR
  /// @dev Only governance can convert VOT3 when the contract is not paused
  /// @param _vot3Amount Amount of VOT3 to convert
  function convertVOT3(uint256 _vot3Amount) external onlyGovernanceWhenNotPaused {
    IVOT3 vot3 = IVOT3(vot3Address());
    require(vot3.convertedB3trOf(address(this)) >= _vot3Amount, "Treasury: insufficient B3TR converted");
    vot3.convertToB3TR(_vot3Amount);
  }

  /// ---------- Setters ---------- //

  /// @notice Sets the transfer limit for VET
  /// @param _transferLimitVET The new transfer limit for VET
  function setTransferLimitVET(uint256 _transferLimitVET) external onlyAdminOrGovernance {
    TreasuryStorage storage $ = _getTreasuryStorage();
    $.transferLimitVET = _transferLimitVET;
    emit TransferLimitVETUpdated(_transferLimitVET);
  }

  /// @notice Sets the transfer limit for any token
  /// @param _token The token to set the transfer limit for
  function setTransferLimitToken(address _token, uint256 _transferLimit) external onlyAdminOrGovernance {
    TreasuryStorage storage $ = _getTreasuryStorage();
    $.transferLimit[_token] = _transferLimit;
    emit TransferLimitUpdated(_token, _transferLimit);
  }

  // ---------- Getters ---------- //

  /// @notice Retrieves the balance of VTHO held by the contract
  function getVTHOBalance() external view returns (uint256) {
    IERC20 vtho = _getERC20Contract(VTHO);
    return vtho.balanceOf(address(this));
  }

  /// @notice Retrieves the balance of B3TR held by the contract
  function getB3TRBalance() external view returns (uint256) {
    IERC20 b3tr = _getERC20Contract(b3trAddress());
    return b3tr.balanceOf(address(this));
  }

  /// @notice Retrieves the balance of VOT3 held by the contract
  function getVOT3Balance() external view returns (uint256) {
    IERC20 vot3 = _getERC20Contract(vot3Address());
    return vot3.balanceOf(address(this));
  }

  /// @notice Retrieves the balance of VET held by the contract
  function getVETBalance() external view returns (uint256) {
    return address(this).balance;
  }

  /// @notice Retrieves the balance of any ERC20 token held by the contract
  /// @param _token The ERC20 token to check balance for
  function getTokenBalance(address _token) external view returns (uint256) {
    IERC20 token = _getERC20Contract(_token);
    return token.balanceOf(address(this));
  }

  /// @notice Retrieves the balance of any ERC721 token held by the contract
  /// @param _nft The ERC721 token to check balance for
  function getCollectionNFTBalance(address _nft) external view returns (uint256) {
    IERC721 nft = IERC721(_nft);
    return nft.balanceOf(address(this));
  }

  /// @notice Retrieves the balance of any ERC1155 token held by the contract
  /// @param _token The ERC1155 token to check balance for
  /// @param _id The id of the ERC1155 token
  function getERC1155TokenBalance(address _token, uint256 _id) external view returns (uint256) {
    IERC1155 erc1155 = IERC1155(_token);
    return erc1155.balanceOf(address(this), _id);
  }

  /// @notice Retrieves the current version of the contract
  function version() external pure virtual returns (string memory) {
    return "1";
  }

  /// @notice Retrieves the address of the B3TR token
  function b3trAddress() public view returns (address) {
    TreasuryStorage storage $ = _getTreasuryStorage();
    return $.B3TR;
  }

  /// @notice Retrieves the address of the VOT3 token
  function vot3Address() public view returns (address) {
    TreasuryStorage storage $ = _getTreasuryStorage();
    return $.VOT3;
  }

  function getTransferLimitVET() external view returns (uint256) {
    TreasuryStorage storage $ = _getTreasuryStorage();
    return $.transferLimitVET;
  }

  function getTransferLimitToken(address _token) external view returns (uint256) {
    TreasuryStorage storage $ = _getTreasuryStorage();
    return $.transferLimit[_token];
  }

  // ----------- Internal & Private ----------- //

  /// @dev Internal function to get the ERC20 contract instance
  function _getERC20Contract(address token) internal pure returns (IERC20) {
    return IERC20(token);
  }

  // ---------- Overrides ---------- //
  /// @dev See {IERC721Receiver-onERC721Received}.
  function onERC721Received(address, address, uint256, bytes calldata) external pure override returns (bytes4) {
    return this.onERC721Received.selector;
  }

  /// @dev See {IERC1155Receiver-onERC1155Received}.
  /// @return bytes4 The selector of the function
  function onERC1155Received(address, address, uint256, uint256, bytes memory) public virtual returns (bytes4) {
    return this.onERC1155Received.selector;
  }

  /// @notice See {IERC1155Receiver-onERC1155BatchReceived}.
  /// @return bytes4 The selector of the function
  function onERC1155BatchReceived(
    address,
    address,
    uint256[] memory,
    uint256[] memory,
    bytes memory
  ) public virtual returns (bytes4) {
    return this.onERC1155BatchReceived.selector;
  }

  // @dev See {UUPSUpgradeable-_authorizeUpgrade}.
  function _authorizeUpgrade(address newImplementation) internal virtual override onlyRole(UPGRADER_ROLE) {}
}

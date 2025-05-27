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
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/NoncesUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/// @title VOT3 Token Contract
/// @dev Extends ERC20 Fungible Token Standard basic implementation with upgradeability, pausability, ability for gasless transactions and governance capabilities.
/// @notice This contract governs the issuance and management of VOT3 tokens, which are the tokens used for voting in the VeBetter DAO Ecosystem.
contract VOT3 is
  ERC20Upgradeable,
  ERC20PausableUpgradeable,
  AccessControlUpgradeable,
  ERC20PermitUpgradeable,
  ERC20VotesUpgradeable,
  UUPSUpgradeable
{
  /// @notice Role hash for addresses allowed to upgrade the contract
  bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
  bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

  /// @notice Storage structure for VOT3 contract
  /// @dev VOT3Storage structure holds all the state variables in a single location.
  /// @custom:storage-location erc7201:b3tr.storage.VOT3
  struct VOT3Storage {
    IERC20 b3tr; // B3TR token contract
    mapping(address account => uint256) _convertedB3TR; // Mapping of B3TR tokens converted to VOT3 tokens
  }

  /// @dev The slot for VOT3 storage in contract storage
  // keccak256(abi.encode(uint256(keccak256("b3tr.storage.VOT3")) - 1)) & ~bytes32(uint256(0xff))
  bytes32 private constant VOT3StorageLocation = 0x8af7882bba84ab51775aa801e199e7d1dfd5f5ff08dcfbb73c614b3313e4cb00;

  /// @dev Retrieves the stored `VOT3Storage` from its designated slot
  function _getVOT3Storage() private pure returns (VOT3Storage storage $) {
    assembly {
      $.slot := VOT3StorageLocation
    }
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  /// @notice Initializes the VOT3 token
  /// @dev Sets initial values for all relevant contract properties and state variables.
  /// @param _admin Address to grant admin roles
  /// @param _upgrader Address to grant upgrader roles
  /// @param _pauser Address to grant pauser roles
  /// @param _b3tr B3TR token contract address
  function initialize(address _admin, address _upgrader, address _pauser, address _b3tr) external initializer {
    __ERC20_init("VOT3", "VOT3");
    __ERC20Pausable_init();
    __AccessControl_init();
    __ERC20Permit_init("VOT3");
    __ERC20Votes_init();
    __UUPSUpgradeable_init();
    __Nonces_init();

    VOT3Storage storage $ = _getVOT3Storage();

    require(_admin != address(0), "VOT3: Admin address cannot be 0");
    // Grant the contract deployer the default admin role and the UPGRADER_ROLE
    _grantRole(DEFAULT_ADMIN_ROLE, _admin);
    _grantRole(UPGRADER_ROLE, _upgrader);
    _grantRole(PAUSER_ROLE, _pauser);

    require(_b3tr != address(0), "VOT3: B3TR address cannot be 0");
    $.b3tr = IERC20(_b3tr);
  }

  /// @notice Pauses the VOT3 contract
  /// @dev pausing the contract will prevent minting, staking, upgrading, and transferring of tokens
  /// @dev Only callable by the admin role
  function pause() external onlyRole(PAUSER_ROLE) {
    _pause();
  }

  /// @notice Unpauses the VOT3 contract
  /// @dev Only callable by the admin role
  function unpause() external onlyRole(PAUSER_ROLE) {
    _unpause();
  }

  /// @dev Authorized upgrading of the contract implementation
  /// @dev Only callable by the upgrader role
  /// @param newImplementation Address of the new contract implementation
  function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

  /// @notice Retrieves the number of converted B3TR tokens for a specific user
  /// @param account Address of the user to check
  /// @return uint256 The amount of converted tokens
  function convertedB3trOf(address account) external view returns (uint256) {
    VOT3Storage storage $ = _getVOT3Storage();
    return $._convertedB3TR[account];
  }

  /// @notice Convert B3TR tokens in exchange for VOT3 tokens
  /// @dev Converts B3TR tokens and mints VOT3 tokens in return
  /// @param amount Amount of B3TR tokens to convert
  function convertToVOT3(uint256 amount) external {
    VOT3Storage storage $ = _getVOT3Storage();
    _mint(msg.sender, amount);
    $._convertedB3TR[msg.sender] += amount;

    require($.b3tr.transferFrom(msg.sender, address(this), amount), "Transfer failed");
  }

  /// @notice Convert VOT3 previously converted back to B3TR tokens
  /// @dev Burns VOT3 tokens and transfers B3TR tokens in return
  /// @param amount Amount of VOT3 tokens to convert
  function convertToB3TR(uint256 amount) external {
    VOT3Storage storage $ = _getVOT3Storage();

    require(balanceOf(msg.sender) >= amount, "Insufficient Vot3 Tokens");
    require($._convertedB3TR[msg.sender] >= amount, "Insufficient converted B3TR tokens");
    _burn(msg.sender, amount);
    $._convertedB3TR[msg.sender] -= amount;
    require($.b3tr.transfer(msg.sender, amount), "Transfer failed");
  }

  /// @notice Transfer VOT3 tokens to a specific address
  /// @dev Override of the ERC20 transferFrom function
  /// @param to Address to transfer to
  /// @param value Amount of VOT3 tokens to transfer
  /// @return True if transfer was successful
  function transfer(address to, uint256 value) public override(ERC20Upgradeable) returns (bool) {
    return super.transfer(to, value);
  }

  /// @notice Approve the transfer of VOT3 tokens to a specific address
  /// @dev Override of the ERC20 transferFrom function
  /// @param spender Address to approve
  /// @param value Amount of VOT3 tokens to approve
  /// @return True if approval was successful
  function approve(address spender, uint256 value) public override(ERC20Upgradeable) returns (bool) {
    return super.approve(spender, value);
  }

  /// @notice Transfer VOT3 tokens from one address to another
  /// @dev Override of the ERC20 transferFrom function
  /// @param from Address to transfer from
  /// @param to Address to transfer to
  /// @param value Amount of VOT3 tokens to transfer
  /// @return True if transfer was successful
  function transferFrom(address from, address to, uint256 value) public override(ERC20Upgradeable) returns (bool) {
    return super.transferFrom(from, to, value);
  }

  /// @dev Determines if the provided address is a contract by checking the size of the code at the address
  /// @param _addr The address to verify
  /// @return True if the address is a contract, false otherwise
  function isContract(address _addr) private view returns (bool) {
    uint32 size;
    assembly {
      size := extcodesize(_addr)
    }
    return (size > 0);
  }

  // Overrides required by Solidity

  /// @dev Updates the token balance of the sender and receiver upon transfer
  /// @dev Overrides the _update function to self-delegate if the user is neither unstaking nor has delegated previously nor burning tokens
  /// @param from Address to transfer from
  /// @param to Address to transfer to
  /// @param amount Amount of tokens to transfer
  function _update(
    address from,
    address to,
    uint256 amount
  ) internal override(ERC20Upgradeable, ERC20VotesUpgradeable, ERC20PausableUpgradeable) {
    super._update(from, to, amount);

    // self-delegate if the user is neither unstaking nor has delegated previously nor burning tokens
    if (to != address(0) && !isContract(to) && delegates(to) == address(0)) {
      _delegate(to, to);
    }
  }

  /// @dev Overridees nonnces for ERC20PermitUpgradeable and NoncesUpgradeable
  function nonces(
    address owner
  ) public view virtual override(ERC20PermitUpgradeable, NoncesUpgradeable) returns (uint256) {
    return super.nonces(owner);
  }

  /// @notice Delegates the voting power of the caller to another address
  /// @dev Can only be called when the contract is not paused
  /// @param delegatee The address to which the caller's voting power will be delegated
  function delegate(address delegatee) public override {
    require(paused() == false, "VOT3: contract is paused");

    _delegate(msg.sender, delegatee);
  }

  /// @notice Gets the B3TR token contract address
  function b3tr() public view returns (IERC20) {
    VOT3Storage storage $ = _getVOT3Storage();
    return $.b3tr;
  }

  /// @notice Calculates the current quadratic voting power of an account
  /// @dev The quadratic voting power is calculated as the square root of the number of votes the account has
  /// @param account The address to calculate the voting power for
  /// @return uint256 The current quadratic voting power
  function getQuadraticVotingPower(address account) public view returns (uint256) {
    // scaling by 1e9 so that number retuned is 1e18
    return Math.sqrt(getVotes(account)) * 1e9;
  }

  /// @notice Calculates the quadratic voting power of an account at a specific past block
  /// @dev The quadratic voting power is calculated as the square root of the number of votes the account had at the specified block
  /// @param account The address to calculate the voting power for
  /// @param timepoint The block number to get the past votes from
  /// @return uint256 The past quadratic voting power
  function getPastQuadraticVotingPower(address account, uint256 timepoint) public view returns (uint256) {
    // scaling by 1e9 so that number retuned is 1e18
    return Math.sqrt(getPastVotes(account, timepoint)) * 1e9;
  }

  /// @notice Returns the version of the contract
  /// @dev This should be updated every time a new version of implementation is deployed
  /// @return string The version of the contract
  function version() public pure virtual returns (string memory) {
    return "1";
  }
}

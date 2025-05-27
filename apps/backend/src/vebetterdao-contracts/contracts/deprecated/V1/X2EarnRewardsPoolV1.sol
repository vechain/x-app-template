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
import { IX2EarnApps } from "../../interfaces/IX2EarnApps.sol";
import { IX2EarnRewardsPoolV1 } from "./interfaces/IX2EarnRewardsPoolV1.sol";
import { IERC1155Receiver } from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

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
contract X2EarnRewardsPoolV1 is
  IX2EarnRewardsPoolV1,
  UUPSUpgradeable,
  AccessControlUpgradeable,
  ReentrancyGuardUpgradeable
{
  bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
  bytes32 public constant CONTRACTS_ADDRESS_MANAGER_ROLE = keccak256("CONTRACTS_ADDRESS_MANAGER_ROLE");

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  /// @custom:storage-location erc7201:b3tr.storage.X2EarnRewardsPool
  struct X2EarnRewardsPoolStorage {
    IB3TR b3tr;
    IX2EarnApps x2EarnApps;
    mapping(bytes32 appId => uint256) availableFunds; // Funds that the app can use to reward users
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
    IX2EarnApps _x2EarnApps
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

  // ---------- Authorizers ---------- //

  function _authorizeUpgrade(address newImplementation) internal virtual override onlyRole(UPGRADER_ROLE) {}

  // ---------- Setters ---------- //

  /**
   * @dev See {IX2EarnRewardsPool-deposit}
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
   * @dev See {IX2EarnRewardsPool-withdraw}
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
   * @dev See {IX2EarnRewardsPool-distributeReward}
   */
  function distributeReward(
    bytes32 appId,
    uint256 amount,
    address receiver,
    string memory proof
  ) external nonReentrant {
    X2EarnRewardsPoolStorage storage $ = _getX2EarnRewardsPoolStorage();

    require($.x2EarnApps.appExists(appId), "X2EarnRewardsPool: app does not exist");

    require($.x2EarnApps.isRewardDistributor(appId, msg.sender), "X2EarnRewardsPool: not a reward distributor");

    // check if the app has enough available funds to reward users
    require($.availableFunds[appId] >= amount, "X2EarnRewardsPool: app has insufficient funds");

    // check if the contract has enough funds
    require($.b3tr.balanceOf(address(this)) >= amount, "X2EarnRewardsPool: insufficient funds on contract");

    // transfer the rewards to the receiver
    $.availableFunds[appId] -= amount;
    require($.b3tr.transfer(receiver, amount), "X2EarnRewardsPool: Allocation transfer to app failed");

    // emit event
    emit RewardDistributed(amount, appId, receiver, proof, msg.sender);
  }

  /**
   * @dev Sets the X2EarnApps contract address.
   *
   * @param _x2EarnApps the new X2EarnApps contract
   */
  function setX2EarnApps(IX2EarnApps _x2EarnApps) external onlyRole(CONTRACTS_ADDRESS_MANAGER_ROLE) {
    require(address(_x2EarnApps) != address(0), "X2EarnRewardsPool: x2EarnApps is the zero address");

    X2EarnRewardsPoolStorage storage $ = _getX2EarnRewardsPoolStorage();
    $.x2EarnApps = _x2EarnApps;
  }

  // ---------- Getters ---------- //

  /**
   * @dev See {IX2EarnRewardsPool-availableFunds}
   */
  function availableFunds(bytes32 appId) external view returns (uint256) {
    X2EarnRewardsPoolStorage storage $ = _getX2EarnRewardsPoolStorage();
    return $.availableFunds[appId];
  }

  /**
   * @dev See {IX2EarnRewardsPool-version}
   */
  function version() external pure virtual returns (string memory) {
    return "1";
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
  function x2EarnApps() external view returns (IX2EarnApps) {
    X2EarnRewardsPoolStorage storage $ = _getX2EarnRewardsPoolStorage();
    return $.x2EarnApps;
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

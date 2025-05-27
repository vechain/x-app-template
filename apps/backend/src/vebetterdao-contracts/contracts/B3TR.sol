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

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";

/// @title B3TR Token Contract
/// @dev Extends ERC20 Token Standard with capping, pausing, and access control functionalities to manage B3TR tokens in the VeBetter ecosystem.
/// @notice This contract governs the issuance and management of B3TR fungible tokens within the VeBetter ecosystem, allowing for minting under a capped total supply.
contract B3TR is ERC20Capped, ERC20Pausable, AccessControl {
  bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
  bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

  /// @notice The maximum amount of B3TR tokens that can be minted
  uint256 private constant B3TR_CAP = 1000243154;

  /// @dev Initializes the contract with specified cap, token details, and admin roles
  /// @param _admin The address that will be granted the default admin role
  /// @param _defaultMinter The address that will be granted the minter role initially
  /// @param _pauser The address that will be granted the pauser role initially
  constructor(
    address _admin,
    address _defaultMinter,
    address _pauser
  ) ERC20("B3TR", "B3TR") ERC20Capped(B3TR_CAP * 1e18) {
    require(_admin != address(0), "B3TR: admin address cannot be zero");
    _grantRole(DEFAULT_ADMIN_ROLE, _admin);
    _grantRole(MINTER_ROLE, _defaultMinter);
    _grantRole(PAUSER_ROLE, _pauser);
  }

  /// @notice Pauses all token transfers and minting actions
  /// @dev Accessible only by accounts with the default admin role
  function pause() external onlyRole(PAUSER_ROLE) {
    _pause();
  }

  /// @notice Resumes all token transfers and minting actions
  /// @dev Accessible only by accounts with the default admin role
  function unpause() external onlyRole(PAUSER_ROLE) {
    _unpause();
  }

  /// @notice Mints new tokens to a specified address
  /// @dev The caller must have the MINTER_ROLE, and the total token supply after minting must not exceed the cap
  /// @param to The address that will receive the minted tokens
  /// @param amount The amount of tokens to be minted
  function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
    _mint(to, amount);
  }

  /// @notice Retrieves token details in a single call
  /// @return name The name of the token
  /// @return symbol The symbol of the token
  /// @return decimals The number of decimals the token uses
  /// @return totalSupply The total supply of the tokens
  /// @return cap The cap on the token's total supply
  function tokenDetails() external view returns (string memory, string memory, uint8, uint256, uint256) {
    return (name(), symbol(), decimals(), totalSupply(), cap());
  }

  /// @dev Internal function to update state during token transfers and burns
  /// @param from The address from which tokens are being transferred or burned
  /// @param to The address to which tokens are being transferred
  /// @param value The amount of tokens being transferred or burned
  /// @notice This function overrides ERC20Capped and ERC20Pausable to ensure proper hook chaining
  function _update(address from, address to, uint256 value) internal override(ERC20Capped, ERC20Pausable) {
    super._update(from, to, value);
  }
}

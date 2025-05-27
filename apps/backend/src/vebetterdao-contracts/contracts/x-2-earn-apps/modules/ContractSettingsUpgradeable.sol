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

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { X2EarnAppsUpgradeable } from "../X2EarnAppsUpgradeable.sol";

/**
 * @title ContractSettingsUpgradeable
 * @dev Contract module to handle settings of the X2EarnApps contract.
 * One functionlity is the set of the baseURI: each app has a URI (baseURI/App.metdataURI) that
 * can be used to retrieve the metadata of the app. Eg: ipfs:// or some other gateway.
 */
abstract contract ContractSettingsUpgradeable is Initializable, X2EarnAppsUpgradeable {
  /// @custom:storage-location erc7201:b3tr.storage.X2EarnApps.Settings
  struct ContractSettingsStorage {
    string _baseURI;
  }

  // keccak256(abi.encode(uint256(keccak256("b3tr.storage.X2EarnApps.Settings")) - 1)) & ~bytes32(uint256(0xff))
  bytes32 private constant SettingsStorageLocation = 0x83b9a7e51f394efa93107c3888716138908bbbe611dfc86afa3639a826441100;

  function _getContractSettingsStorage() internal pure returns (ContractSettingsStorage storage $) {
    assembly {
      $.slot := SettingsStorageLocation
    }
  }

  // ---------- Internal ---------- //

  /**
   * @dev Internal function to update the base URI to retrieve the metadata of the x2earn apps
   *
   * @param baseURI_ the base URI for the contract
   *
   * Emits a {BaseURIUpdated} event.
   */
  function _setBaseURI(string memory baseURI_) internal {
    ContractSettingsStorage storage $ = _getContractSettingsStorage();

    emit BaseURIUpdated($._baseURI, baseURI_);

    $._baseURI = baseURI_;
  }

  // ---------- Getters ---------- //

  /**
   * @dev See {IX2EarnApps-baseURI}.
   */
  function baseURI() public view virtual override returns (string memory) {
    ContractSettingsStorage storage $ = _getContractSettingsStorage();

    return $._baseURI;
  }
}

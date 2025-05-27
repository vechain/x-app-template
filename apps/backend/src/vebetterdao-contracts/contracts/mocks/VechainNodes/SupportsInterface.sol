// SPDX-License-Identifier: MIT

// Copyright (c) 2018 The VeChainThor developers

// Distributed under the GNU Lesser General Public License v3.0 software license, see the accompanying
// file LICENSE or <https://www.gnu.org/licenses/lgpl-3.0.html>

pragma solidity 0.8.20;

import "./utility/interfaces/IERC165.sol";


/**
 * @title SupportsInterfaceWithLookup
 * @dev Implements ERC165 using a lookup table.
 */
contract SupportsInterface is IERC165 {
    /**
    * 0x01ffc9a7 ===
    *   bytes4(keccak256('supportsInterface(bytes4)'))
    */
    bytes4 public constant InterfaceId_ERC165 = 0x01ffc9a7;
    
    /**
    * @dev a mapping of interface id to whether or not it's supported
    */
    mapping(bytes4 => bool) internal supportedInterfaces;

    /**
    * @dev A contract implementing SupportsInterfaceWithLookup
    * implement ERC165 itself
    */
    constructor()
    {
        _registerInterface(InterfaceId_ERC165);
    }

    /**
    * @dev implement supportsInterface(bytes4) using a lookup table
    */
    function supportsInterface(bytes4 _interfaceId)
      external
      view
      returns(bool)
    {
        return supportedInterfaces[_interfaceId];
    }

    /**
    * @dev private method for registering an interface
    */
    function _registerInterface(bytes4 _interfaceId)
      internal
    {
        require(_interfaceId != 0xffffffff, "invalid interfaceid");
        supportedInterfaces[_interfaceId] = true;
    }
}
// SPDX-License-Identifier: MIT

// Copyright (c) 2018 The VeChainThor developers

// Distributed under the GNU Lesser General Public License v3.0 software license, see the accompanying
// file LICENSE or <https://www.gnu.org/licenses/lgpl-3.0.html>

pragma solidity 0.8.20;


/// @title ERC165
/// @dev https://github.com/ethereum/EIPs/blob/master/EIPS/eip-165.md
interface IERC165 {

    /// @notice Query if a contract implements an interface
    /// @param _interfaceId The interface identifier, as specified in ERC-165
    /// @dev Interface identification is specified in ERC-165. This function
    ///      uses less than 30,000 gas.
    function supportsInterface(bytes4 _interfaceId)
        external
        view
        returns (bool);
}

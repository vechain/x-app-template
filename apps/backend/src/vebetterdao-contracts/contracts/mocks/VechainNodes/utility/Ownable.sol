// SPDX-License-Identifier: MIT

// Copyright (c) 2018 The VeChainThor developers

// Distributed under the GNU Lesser General Public License v3.0 software license, see the accompanying
// file LICENSE or <https://www.gnu.org/licenses/lgpl-3.0.html>

pragma solidity 0.8.20;

contract Ownable {
    address public owner;

    // Emit when ownership transfer to new owner
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /// @dev The Ownable constructor sets the original `owner` of the contract to the sender
    ///      account.
    constructor() {
        owner = msg.sender;
    }

    /// @dev Throws if called by any account other than the owner.
    modifier onlyOwner() {
        require(msg.sender == owner, "only owner");
        _;
    }

    /// @dev Allows the current owner to transfer control of the contract to a newOwner.
    /// @param newOwner The address to transfer ownership to.
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "invalid address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

}

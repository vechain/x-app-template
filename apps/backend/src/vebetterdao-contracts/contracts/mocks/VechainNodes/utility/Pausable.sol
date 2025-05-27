// SPDX-License-Identifier: MIT

// Copyright (c) 2018 The VeChainThor developers

// Distributed under the GNU Lesser General Public License v3.0 software license, see the accompanying
// file LICENSE or <https://www.gnu.org/licenses/lgpl-3.0.html>

pragma solidity 0.8.20;
import "./Ownable.sol";

/// @title Pausable
/// @dev Base contract which allows children to implement an emergency stop mechanism.
contract Pausable is Ownable {
    event Pause();
    event Unpause();

    bool public paused = false;

    modifier whenNotPaused() {
        require(!paused, "protocol has paused");
        _;
    }

    modifier whenPaused {
        require(paused, "needs protocol paused");
        _;
    }

    /// @dev called by the owner to pause, triggers stopped state
    function pause()
        public
        onlyOwner
        whenNotPaused
        returns (bool)
    {
        paused = true;
        emit Pause();
        return true;
    }

    /// @dev called by the owner to unpause, returns to normal state
    function unpause() 
        public
        onlyOwner
        whenPaused
        returns (bool)
    {
        paused = false;
        emit Unpause();
        return true;
    }
}
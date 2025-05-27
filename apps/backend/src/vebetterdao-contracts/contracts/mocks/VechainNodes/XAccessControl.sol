// SPDX-License-Identifier: MIT

// Copyright (c) 2018 The VeChainThor developers

// Distributed under the GNU Lesser General Public License v3.0 software license, see the accompanying
// file LICENSE or <https://www.gnu.org/licenses/lgpl-3.0.html>

pragma solidity 0.8.20;

import "./utility/Pausable.sol";

contract XAccessControl is Pausable {
    event ProtocolUpgrade(address _saleAuction);
    event OperatorUpdated(address _op, bool _enabled);
    event BlackListUpdated(address _person, bool _op);

    mapping(address => bool) public operators;
    mapping(address => bool) public blackList;

    modifier onlyOperator {
        require(operators[msg.sender], "permission denied");
        _;
    }

    modifier inBlackList {
        require(blackList[msg.sender], "operation blocked");
        _;
    }

    modifier notInBlackList {
        require(!blackList[msg.sender], "operation blocked");
        _;
    }

    function addOperator(address _operator) 
        external
        onlyOwner
        whenNotPaused
    {
        operators[_operator] = true;
        emit OperatorUpdated(_operator, true);
    }

    function removeOperator(address _operator)
        external
        onlyOwner
        whenNotPaused
    {
        operators[_operator] = false;
        emit OperatorUpdated(_operator, false);
    }

    function addToBlackList(address _badGuy)
        external
        onlyOwner
        whenNotPaused
    {
        blackList[_badGuy] = true;
        emit BlackListUpdated(_badGuy, true);
    }

    function removeFromBlackList(address _innocent)
        external
        onlyOwner
        whenNotPaused
    {
        blackList[_innocent] = false;
        emit BlackListUpdated(_innocent, false);
    }
}


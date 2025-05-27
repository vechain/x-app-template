// SPDX-License-Identifier: MIT

// Copyright (c) 2018 The VeChainThor developers

// Distributed under the GNU Lesser General Public License v3.0 software license, see the accompanying
// file LICENSE or <https://www.gnu.org/licenses/lgpl-3.0.html>

pragma solidity 0.8.20;

import "./XAccessControl.sol";
import "./auction/ClockAuction.sol";

abstract contract IEnergy {
    function transfer(address _to, uint256 _amount) external virtual;
}

contract ThunderFactory is XAccessControl {

    IEnergy constant Energy = IEnergy(0x0000000000000000000000000000456E65726779);

    /// @dev The address of the ClockAuction contract that handles sales of xtoken
    ClockAuction public saleAuction;
    /// @dev The interval between two transfers
    uint64 public transferCooldown = 1 days;
    /// @dev A time delay when to start monitor after the token is transfered
    uint64 public leadTime = 4 hours;

    /// @dev The XToken param struct
    struct TokenParameters {
        uint256 minBalance;
        uint64  ripeDays;
        uint64  rewardRatio;
        uint64  rewardRatioX;
    }

    enum strengthLevel {
        None,

        // Normal Token
        Strength,
        Thunder,
        Mjolnir,

        // X Token
        VeThorX,
        StrengthX,
        ThunderX,
        MjolnirX
    }

    /// @dev Mapping from strength level to token params
    mapping(uint8 => TokenParameters) internal strengthParams;
    
    /// @dev The main Token struct. Each token is represented by a copy of this structure.
    struct Token {
        uint64 createdAt;
        uint64 updatedAt;

        bool onUpgrade;
        strengthLevel level;

        uint64 lastTransferTime;
    }

    /// @dev An array containing the Token struct for all XTokens in existence.
    ///      The ID of each token is actually an index into this array and starts at 1.
    Token[] internal tokens;
    /// @dev The counter of normal tokens and xtokens
    uint64 public normalTokenCount;
    uint64 public xTokenCount;

    /// @dev Mapping from token ID to owner and its reverse mapping.
    ///      Every address can only hold one token at most.
    mapping(uint256 => address) public idToOwner;
    mapping(address => uint256) public ownerToId;

    // Mapping from token ID to approved address
    mapping (uint256 => address) internal tokenApprovals;

    event Transfer(address indexed _from, address indexed _to, uint256 indexed _tokenId);
    event Approval(address indexed _owner, address indexed _approved, uint256 indexed _tokenId);
    event NewUpgradeApply(uint256 indexed _tokenId, address indexed _applier, strengthLevel _level, uint64 _applyTime, uint64 _applyBlockno);
    event CancelUpgrade(uint256 indexed _tokenId, address indexed _owner);
    event LevelChanged(uint256 indexed _tokenId, address indexed _owner, strengthLevel _fromLevel, strengthLevel _toLevel);
    event AuctionCancelled(uint256 indexed _auctionId, uint256 indexed _tokenId);
    
    constructor() {
        // the index of valid tokens should start from 1
        tokens.push(Token(0, 0, false, strengthLevel.None, 0));
        
        // The params of normal token
        strengthParams[1] = TokenParameters(1000000 ether, 10, 0, 100);     // Strength
        strengthParams[2] = TokenParameters(5000000 ether, 20, 0, 150);     // Thunder
        strengthParams[3] = TokenParameters(15000000 ether, 30, 0, 200);    // Mjolnir
        
        // The params of X tokens
        strengthParams[4] = TokenParameters(600000 ether, 0, 25, 0);        // VeThorX
        strengthParams[5] = TokenParameters(1600000 ether, 30, 100, 100);   // StrengthX
        strengthParams[6] = TokenParameters(5600000 ether, 60, 150, 150);   // ThunderX
        strengthParams[7] = TokenParameters(15600000 ether, 90, 200, 200);  // MjolnirX
    }

    /// @dev To tell whether the address is holding an x token
    function isX(address _target)
        public
        view
        returns(bool)
    {
        // return false if given address doesn't hold a token
        return tokens[ownerToId[_target]].level >= strengthLevel.VeThorX;
    }

    /// @dev To tell whether the address is holding a normal token
    function isNormalToken(address _target)
        public
        view
        returns(bool)
    {
        // return false if given address doesn't hold a token
        return isToken(_target) && !isX(_target);
    }

    /// @dev To tell whether the address is holding a token(x or normal)
    function isToken(address _target)
        public
        view
        returns(bool)
    {
        return tokens[ownerToId[_target]].level > strengthLevel.None;
    }

    /// @dev Apply for a token or upgrade the holding token.
    ///      Note that bypass the level is forbided, it has to upgrade one by one.
    function applyUpgrade(strengthLevel _toLvl)
        external
        whenNotPaused
    {
        uint256 _tokenId = ownerToId[msg.sender];
        if (_tokenId == 0) {
            // a new token
            _tokenId = _add(msg.sender, strengthLevel.None, false);
        }

        Token storage token = tokens[_tokenId];
        require(!token.onUpgrade, "still upgrading");
        require(!saleAuction.isOnAuction(_tokenId), "cancel auction first");
        
        // Bypass check. Note that normal token couldn't upgrade to x token.
        require(
            uint8(token.level) + 1 == uint8(_toLvl)
            && _toLvl != strengthLevel.VeThorX
            && _toLvl <= strengthLevel.MjolnirX,
            "invalid _toLvl");
        // The balance of msg.sender must meet the requirement of target level's minbalance
        require(msg.sender.balance >= strengthParams[uint8(_toLvl)].minBalance, "insufficient balance");

        token.onUpgrade = true;
        token.updatedAt = uint64(block.timestamp);
        
        emit NewUpgradeApply(_tokenId, msg.sender, _toLvl, uint64(block.timestamp), uint64(block.number));
    }

    /// @dev Cancel the upgrade application.
    ///      Note that this method can be called by the token holder or admin.
    function cancelUpgrade(uint256 _tokenId)
        public
    {
        require(_exist(_tokenId), "token not exist");
        
        Token storage token = tokens[_tokenId];
        address _owner = idToOwner[_tokenId];

        require(token.onUpgrade, "not on upgrading");
        // The token holder or admin allowed.
        require(_owner == msg.sender || operators[msg.sender], "permission denied");

        if (token.level == strengthLevel.None) {
            _destroy(_tokenId);
        } else {
            token.onUpgrade = false;
            token.updatedAt = uint64(block.timestamp);
        }

        emit CancelUpgrade(_tokenId, _owner);
    }

    function getMetadata(uint256 _tokenId)
        public
        view
        returns(address, strengthLevel, bool, bool, uint64, uint64, uint64)
    {
        if (_exist(_tokenId)) {
            Token memory token = tokens[_tokenId];
            return (
                idToOwner[_tokenId],
                token.level,
                token.onUpgrade,
                saleAuction.isOnAuction(_tokenId),
                token.lastTransferTime,
                token.createdAt,
                token.updatedAt
            );
        }
    }

    function getTokenParams(strengthLevel _level)
        public
        view
        returns(uint256, uint64, uint64, uint64)
    {
        TokenParameters memory _params = strengthParams[uint8(_level)];
        return (_params.minBalance, _params.ripeDays, _params.rewardRatio, _params.rewardRatioX);
    }

    /// @dev To tell whether a token can be transfered.
    function canTransfer(uint256 _tokenId) 
        public 
        view
        returns(bool)
    {
        return
            _exist(_tokenId)
            && !tokens[_tokenId].onUpgrade
            && !blackList[idToOwner[_tokenId]] // token not in black list
            && block.timestamp > (tokens[_tokenId].lastTransferTime + transferCooldown);
    }

    /// Admin Methods

    function setTransferCooldown(uint64 _cooldown)
        external
        onlyOperator
    {
        transferCooldown = _cooldown;
    }

    function setLeadTime(uint64 _leadtime)
        external
        onlyOperator
    {
        leadTime = _leadtime;
    }

    /// @dev Upgrade a token to the passed level.
    function upgradeTo(uint256 _tokenId, strengthLevel _toLvl)
        external
        onlyOperator
    {
        require(tokens[_tokenId].level < _toLvl, "invalid level");
        require(!saleAuction.isOnAuction(_tokenId), "cancel auction first");

        tokens[_tokenId].onUpgrade = false;
        
        _levelChange(_tokenId, _toLvl);
    }

    /// @dev Downgrade a token to the passed level.
    function downgradeTo(uint256 _tokenId, strengthLevel _toLvl)
        external
        onlyOperator
    {
        require(tokens[_tokenId].level > _toLvl, "invalid level");
        require(block.timestamp > (tokens[_tokenId].lastTransferTime + leadTime), "cannot downgrade token");

        if (saleAuction.isOnAuction(_tokenId)) {
            _cancelAuction(_tokenId);
        }
        if (tokens[_tokenId].onUpgrade) {
            cancelUpgrade(_tokenId);
        }

        _levelChange(_tokenId, _toLvl);
    }

    /// @dev Adds a new token and stores it. This method should be called 
    ///      when the input data is block.timestampn to be valid and will generate a Transfer event.
    function addToken(address _addr, strengthLevel _lvl, bool _onUpgrade, uint64 _applyUpgradeTime, uint64 _applyUpgradeBlockno)
        external
        onlyOperator
    {
        require(!_exist(_addr), "you already hold a token");

        // This will assign ownership, and also emit the Transfer event.
        uint256 newTokenId = _add(_addr, _lvl, _onUpgrade);
        
        // Update token counter
        if(strengthLevel.Strength <= _lvl && _lvl <= strengthLevel.Mjolnir) normalTokenCount++;
        else if(strengthLevel.VeThorX <= _lvl && _lvl <= strengthLevel.MjolnirX) xTokenCount++;

        // For data imgaration
        if (_onUpgrade) {
            emit NewUpgradeApply(newTokenId, _addr, _lvl, _applyUpgradeTime, _applyUpgradeBlockno);
        }
    }

    /// @dev Send VTHO bonus to the token's holder
    function sendBonusTo(address _to, uint256 _amount)
        external
        onlyOperator
    {
        require(_to != address(0), "invalid address");
        require(_amount > 0, "invalid amount");
        // Transfer VTHO from this contract to _to address, it will throw when fail
        Energy.transfer(_to, _amount);
    }

    /// Internal Methods

    function _add(address _owner, strengthLevel _lvl, bool _onUpgrade)
    internal
    returns(uint256)
    {
        Token memory _token = Token(uint64(block.timestamp), uint64(block.timestamp), _onUpgrade, _lvl, uint64(block.timestamp));
        tokens.push(_token); // Push the token to the array
        uint256 _newTokenId = tokens.length - 1; // Get the index of the new token, which is the length of the array minus one

        ownerToId[_owner] = _newTokenId;
        idToOwner[_newTokenId] = _owner;

        emit Transfer(address(0), _owner, _newTokenId); // Emit a Transfer event indicating a new token creation

        return _newTokenId;
    }

    function _destroy(uint256 _tokenId)
        internal
    {
        address _owner = idToOwner[_tokenId];
        delete idToOwner[_tokenId];
        delete ownerToId[_owner];
        delete tokens[_tokenId];
        // 
        emit Transfer(_owner, address(0), _tokenId);
    }

    function _levelChange(uint256 _tokenId, strengthLevel _toLvl)
        internal
    {
        address _owner = idToOwner[_tokenId];
        Token storage token = tokens[_tokenId];

        strengthLevel _fromLvl = token.level;
        if (_toLvl == strengthLevel.None) {
            _destroy(_tokenId);
        } else {
            token.level = _toLvl;
            token.updatedAt = uint64(block.timestamp);
        }

        // Update token counter
        if(strengthLevel.Strength <= _fromLvl && _fromLvl <= strengthLevel.Mjolnir) {
            normalTokenCount--;
        } else if(strengthLevel.VeThorX <= _fromLvl && _fromLvl <= strengthLevel.MjolnirX) {
            xTokenCount--;
        }
        if(strengthLevel.Strength <= _toLvl && _toLvl <= strengthLevel.Mjolnir ) {
            normalTokenCount++;
        } else if(strengthLevel.VeThorX <= _toLvl && _toLvl <= strengthLevel.MjolnirX ) {
            xTokenCount++;
        }

        emit LevelChanged(_tokenId, _owner, _fromLvl,  _toLvl);
    }

    function _exist(uint256 _tokenId)
        internal
        view
        returns(bool)
    {
        return idToOwner[_tokenId] > address(0);
    }

    function _exist(address _owner)
        internal
        view
        returns(bool)
    {
        return ownerToId[_owner] > 0;
    }

    /// @notice Internal function to clear current approval of a given token ID
    /// @param _tokenId uint256 ID of the token to be transferred
    function _clearApproval(uint256 _tokenId)
        internal
    {
        delete tokenApprovals[_tokenId];
    }

    /// @notice Internal function to cancel the ongoing auction
    /// @param _tokenId uint256 ID of the token
    function _cancelAuction(uint256 _tokenId)
        internal
    {
        _clearApproval(_tokenId);
        (uint256 _autionId,,,,,) = saleAuction.getAuction(_tokenId);
        emit AuctionCancelled(_autionId, _tokenId);
        saleAuction.cancelAuction(_tokenId);
    }

}

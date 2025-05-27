// SPDX-License-Identifier: MIT

// Copyright (c) 2018 The VeChainThor developers

// Distributed under the GNU Lesser General Public License v3.0 software license, see the accompanying
// file LICENSE or <https://www.gnu.org/licenses/lgpl-3.0.html>

pragma solidity 0.8.20;

import "./utility/Strings.sol";
import "./utility/SafeMath.sol";

import "./SupportsInterface.sol";
import "./ThunderFactory.sol";

import "./utility/interfaces/IVIP181Basic.sol";


contract XOwnership is ThunderFactory, IVIP181Basic, SupportsInterface {

    using SafeMath for uint256;

    string public name = "VeChainThor Node Token";
    string public symbol = "VNT";

    string internal tokenMetadataBaseURI = "";

    constructor() {
        // register the supported interfaces to conform to VIP181 via ERC165
        _registerInterface(InterfaceId_VIP181);
        _registerInterface(InterfaceId_VIP181Metadata);
    }

    function tokenURI(uint256 _tokenId)
        external
        view
        returns (string memory)
    {
        return Strings.strConcat(tokenMetadataBaseURI, Strings.uint2str(_tokenId));
    }

    /// @dev Gets the balance of the specified address
    /// @param _owner address to query the balance of
    /// @return uint256 representing the amount owned by the passed address
    function balanceOf(address _owner)
        public
        override
        view
        returns (uint256)
    {
        // Everyone can only possess one token at most
        return isToken(_owner) ? 1 : 0;
    }

    /// @dev Gets the owner of the specified token ID
    /// @param _tokenId uint256 ID of the token to query the owner of
    /// @return owner address currently marked as the owner of the given token ID
    function ownerOf(uint256 _tokenId)
        public
        override
        view
        returns (address)
    {
        return idToOwner[_tokenId];
    }

    function totalSupply()
        public
        view
        returns(uint256)
    {
        return uint256(normalTokenCount + xTokenCount);
    }

    function setTokenMetadataBaseURI(string memory _newBaseURI)
        external
        onlyOwner
    {
        tokenMetadataBaseURI = _newBaseURI;
    }

    /// @dev Approves another address to transfer the given token ID
    ///      The zero address indicates there is no approved address.
    ///      There can only be one approved address per token at a given time.
    ///      Can only be called by the token owner or an approved operator.
    /// @param _to address to be approved for the given token ID
    /// @param _tokenId uint256 ID of the token to be approved
    function approve(address _to, uint256 _tokenId)
        public
        override
        whenNotPaused
    {
        address _owner = ownerOf(_tokenId);
        require(_to != _owner, "cannot approve your own token");
        require(msg.sender == _owner, "permission denied");

        _approve(_tokenId, _to);
    }

    /// @dev Gets the approved address for a token ID, or zero if no address set
    /// @param _tokenId uint256 ID of the token to query the approval of
    /// @return address currently approved for the given token ID
    function getApproved(uint256 _tokenId)
        public
        override
        view
        returns (address)
    {
        return tokenApprovals[_tokenId];
    }

    function transfer(address _to, uint256 _tokenId)
        public
        whenNotPaused
    {
        require(_to != address(0), "invalid address");
        // Can only transfer your own token.
        require(ownerOf(_tokenId) == msg.sender, "permission denied");
        // Token is not in blacklist and cooldown time
        require(canTransfer(_tokenId), "cannot transfer this token");

        if (saleAuction.isOnAuction(_tokenId)) {
            _cancelAuction(_tokenId);
        }

        _clearApprovalAndTransfer(msg.sender, _to, _tokenId);
    }

    /// @dev Transfers the ownership of a given token ID to another address
    ///      Requires the msg sender to be the owner, approved, or operator
    /// @param _from current owner of the token
    /// @param _to address to receive the ownership of the given token ID
    /// @param _tokenId uint256 ID of the token to be transferred
    function transferFrom(address _from, address _to, uint256 _tokenId)
        public
        override
        whenNotPaused
    {
        require(_to != address(0), "invalid address");
        // Check for approval and valid ownership
        require(ownerOf(_tokenId) == _from, "permission denied");
        require(isApprovedOrOwner(msg.sender, _tokenId), "permission denied");
        // Token is not in blacklist and cooldown time
        require(canTransfer(_tokenId), "cannot transfer this token");

        if (saleAuction.isOnAuction(_tokenId)) {
            _cancelAuction(_tokenId);
        }

        _clearApprovalAndTransfer(_from, _to, _tokenId);
    }

    /// Internal Functions

    /// @dev Returns whether the given spender can transfer a given token ID
    /// @param _spender address of the spender to query
    /// @param _tokenId uint256 ID of the token to be transferred
    /// @return bool whether the msg.sender is approved for the given token ID,
    ///         is an operator of the owner, or is the owner of the token
    function isApprovedOrOwner(address _spender, uint256 _tokenId)
        internal
        view
        returns (bool)
    {
        address _owner = ownerOf(_tokenId);
        return (_spender == _owner || getApproved(_tokenId) == _spender);
    }

    function _clearApprovalAndTransfer(address _from, address _to, uint256 _tokenId)
        internal
    {
        _clearApproval(_tokenId);
        _transfer(_from, _to, _tokenId);
    }

    // INTERNAL FUNCTIONS

    function _approve(uint256 _tokenId, address _to)
        internal
    {
        tokenApprovals[_tokenId] = _to;
        address _owner = ownerOf(_tokenId);
        emit Approval(_owner, _to, _tokenId);
    }

    function _transfer(address _from, address _to, uint256 _tokenId)
        internal
    {
        require(!_exist(_to), "_to already hold a token");
        require(!_isContract(_to), "_to mustn't a contract");

        // update the token info and cooldown the token
        tokens[_tokenId].updatedAt = uint64(block.timestamp);
        tokens[_tokenId].lastTransferTime = uint64(block.timestamp);

        // transfer ownership
        delete ownerToId[_from];
        idToOwner[_tokenId] = _to;
        ownerToId[_to] = _tokenId;

        emit Transfer(_from, _to, _tokenId);
    }

    function _isContract(address addr)
        internal
        view
        returns (bool)
    {
        uint size;
        /* solium-disable-next-line security/no-inline-assembly */
        assembly { size := extcodesize(addr) }
        return size > 0;
    }

}
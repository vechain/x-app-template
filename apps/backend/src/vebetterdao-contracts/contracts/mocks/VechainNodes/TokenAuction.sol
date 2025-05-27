// SPDX-License-Identifier: MIT

// Copyright (c) 2018 The VeChainThor developers

// Distributed under the GNU Lesser General Public License v3.0 software license, see the accompanying
// file LICENSE or <https://www.gnu.org/licenses/lgpl-3.0.html>

pragma solidity 0.8.20;

import "./XOwnership.sol";
import "./auction/ClockAuction.sol";
import "./utility/SafeMath.sol";

contract TokenAuction is XOwnership {

    using SafeMath for uint256;

    uint256 public auctionCount;

    event AuctionCreated(
        uint256 indexed _auctionId,
        uint256 indexed _tokenId,
        uint256 _startingPrice,
        uint256 _endingPrice,
        uint64 _duration
    );
    event AuctionSuccessful(
        uint256 indexed _auctionId,
        uint256 indexed _tokenId,
        address indexed _seller,
        address _winner,
        uint256 _finalPrice
    );
    
    event AddAuctionWhiteList(uint256 indexed _auctionId, uint256 indexed _tokenId, address indexed _candidate);
    event RemoveAuctionWhiteList(uint256 indexed _auctionId, uint256 indexed _tokenId, address indexed _candidate);

    /// @dev Sets the reference to the sale auction.
    /// @param _address - Address of sale contract.
    function setSaleAuctionAddress(address _address)
        public
        onlyOwner
    {
        require(_address != address(0), "invalid address");
        saleAuction = ClockAuction(_address);
        emit ProtocolUpgrade(_address);
    }


    /// @dev Put a token up for auction.
    function createSaleAuction(
        uint256 _tokenId,
        uint128 _startingPrice,
        uint128 _endingPrice,
        uint64 _duration
    )
        public
        whenNotPaused
    {
        require(ownerOf(_tokenId) == msg.sender, "permission denied");
        require(isToken(msg.sender), "is not a token");
        require(!tokens[_tokenId].onUpgrade, "cancel upgrading first");

        // Does some ownership trickery to create auctions in one tx.
        _approve(_tokenId, address(saleAuction));

        auctionCount = auctionCount.add(1);
        // If token is already on any auction, this will throw
        saleAuction.createAuction(
            auctionCount,
            _tokenId,
            _startingPrice,
            _endingPrice,
            _duration,
            uint64(block.timestamp),
            msg.sender
        );

        emit AuctionCreated(
            auctionCount,
            _tokenId,
            _startingPrice,
            _endingPrice,
            _duration
        );
    }

    /// @dev Put a token up for directional auction.
    function createDirectionalSaleAuction(
        uint256 _tokenId,
        uint128 _price,
        uint64 _duration,
        address _toAddress
    )
        public
        whenNotPaused
    {
        require(ownerOf(_tokenId) == msg.sender, "permission denied");
        require(isToken(msg.sender), "is not a token");
        require(!tokens[_tokenId].onUpgrade, "cancel upgrading first");

        // Does some ownership trickery to create auctions in one tx.
        _approve(_tokenId, address(saleAuction));

        auctionCount = auctionCount.add(1);
        
        // If token is already on any auction, this will throw
        saleAuction.createAuction(
            auctionCount,
            _tokenId,
            _price,
            _price,
            _duration,
            uint64(block.timestamp),
            msg.sender
        );

        emit AuctionCreated(
            auctionCount,
            _tokenId,
            _price,
            _price,
            _duration
        );

        // Set candidates
        saleAuction.addAuctionWhiteList(_tokenId, _toAddress);
        emit AddAuctionWhiteList(auctionCount, _tokenId, _toAddress);
    }

    /// @dev Bids on an open auction, completing the auction and transferring
    ///      ownership of the NFT if enough Ether is supplied.
    function bid(uint256 _tokenId)
        public
        payable
        whenNotPaused
    {
        (uint256 _autionId, address _seller,,,,) = saleAuction.getAuction(_tokenId);

        // Will throw if the bid fails
        uint256 _price = saleAuction.bid{value: msg.value}(msg.sender, _tokenId);

        emit AuctionSuccessful(_autionId, _tokenId, _seller, msg.sender, _price);
    }

    /// @dev Cancels an auction that hasn't been won yet.
    ///      This methods can be called while the protocol is paused.
    function cancelAuction(uint256 _tokenId)
        public
        whenNotPaused
    {
        require(ownerOf(_tokenId) == msg.sender, "permission denied");

        _cancelAuction(_tokenId);
    }

    /// @dev Add condidate for the auction of the passed token.
    function addAuctionWhiteList(uint256 _tokenId, address _address) 
        public
        whenNotPaused
    {
        require(ownerOf(_tokenId) == msg.sender, "permission denied");
        require(isToken(msg.sender), "is not a token");
        saleAuction.addAuctionWhiteList(_tokenId, _address);

        (uint256 _autionId,,,,,) = saleAuction.getAuction(_tokenId);

        emit AddAuctionWhiteList(_autionId, _tokenId, _address);
    }

    /// @dev Remove address from whitelist.
    function removeAuctionWhiteList(uint256 _tokenId, address _address) 
        public
        whenNotPaused
    {
        require(ownerOf(_tokenId) == msg.sender, "permission denied");
        require(isToken(msg.sender), "is not a token");
        saleAuction.removeAuctionWhiteList(_tokenId, _address);

        (uint256 _autionId,,,,,) = saleAuction.getAuction(_tokenId);

        emit RemoveAuctionWhiteList(_autionId, _tokenId, _address);
    }

}

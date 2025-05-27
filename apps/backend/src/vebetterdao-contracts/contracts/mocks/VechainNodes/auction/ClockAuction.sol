// SPDX-License-Identifier: MIT

// Copyright (c) 2018 The VeChainThor developers

// Distributed under the GNU Lesser General Public License v3.0 software license, see the accompanying
// file LICENSE or <https://www.gnu.org/licenses/lgpl-3.0.html>

pragma solidity 0.8.20;

import "./ClockAuctionBase.sol";

import "../utility/interfaces/IVIP181.sol";


contract ClockAuction is ClockAuctionBase {

    /// @dev Constructor creates a reference to the token ownership contract
    ///      and verifies the owner cut is in the valid range.
    /// @param _nftAddress - address of a deployed contract implementing
    ///                      the Nonfungible Interface.
    constructor(address _nftAddress, address _feePool) {
        require(_nftAddress != address(0), "invalid address");
        require(_feePool != address(0), "invalid address");
        VIP181 = IVIP181(_nftAddress);

        feePool = payable(_feePool);
    }

    /// @dev Creates and begins a new auction.
    /// @param _auctionId - ID of auction.
    /// @param _tokenId - ID of token to auction, sender must be owner.
    /// @param _startingPrice - Price of item (in wei) at beginning of auction.
    /// @param _endingPrice - Price of item (in wei) at end of auction.
    /// @param _duration - Length of time to move between starting
    ///                    price and ending price (in seconds).
    /// @param _startedAt - StartedAt, if not the message sender
    /// @param _seller - Seller, if not the message sender
    function createAuction(
        uint256 _auctionId,
        uint256 _tokenId,
        uint128 _startingPrice,
        uint128 _endingPrice,
        uint64 _duration,
        uint64 _startedAt,
        address _seller
    )
        external
        whenNotPaused
    {
        require(msg.sender == address(VIP181), "permission denied");
        require(!isOnAuction(_tokenId), "token is on auction");
        // the duration of any auction should between 2 hours and 7 days.
        require(_duration >= 2 hours, "at least 2 hours");
        require(_duration <= 7 days, "at most 7 days");

        // remove expired auction first if exist
        _cancelAuction(_tokenId);
        // add new auction
        _addAuction(_auctionId, _tokenId, _startingPrice, _endingPrice, _duration, _startedAt, payable(_seller));
    }

    /// @dev Bids on an open auction, completing the auction and transferring
    ///      ownership of the token if enough Ether is supplied.
    /// @param _buyer   - address of token buyer.
    /// @param _tokenId - ID of token to bid on.
    function bid(address _buyer, uint256 _tokenId)
        external
        payable
        whenNotPaused
        returns(uint256)
    {
        require(msg.sender == address(VIP181), "permission denied");
        require(isOnAuction(_tokenId), "auction not found");
        // if the candidates not empty check the _buyer in
        if(hasWhiteList(_tokenId)) {
            require(inWhiteList(_tokenId, _buyer), "blocked");
        }
    
        Auction storage auction = tokenIdToAuction[_tokenId];
        address payable _seller = payable(auction.seller);
        // _bid will throw if the bid or funds transfer fails
        uint256 _price = _bid(payable(_buyer), _tokenId, msg.value);
        
        VIP181.transferFrom(_seller, _buyer, _tokenId);
        return _price;
    }

    /// @dev Cancels an auction that hasn't been won yet.
    /// @param _tokenId - ID of token on auction
    function cancelAuction(uint256 _tokenId)
        external
        whenNotPaused
    {
        require(msg.sender == address(VIP181), "permission denied");
        require(exist(_tokenId), "auction not found");
        _cancelAuction(_tokenId);
    }

    /// @dev Returns auction info for an token on auction.
    /// @param _tokenId - ID of token on auction.
    function getAuction(uint256 _tokenId)
        public
        view
        returns (
        uint256 autionId,
        address seller,
        uint256 startingPrice,
        uint256 endingPrice,
        uint64 duration,
        uint64 startedAt
    ) {
        Auction storage auction = tokenIdToAuction[_tokenId];

        return (
            auction.auctionId,
            auction.seller,
            auction.startingPrice,
            auction.endingPrice,
            auction.duration,
            auction.startedAt
        );
    }

    /// @dev Returns true if the auction exists
    function exist(uint256 _tokenId)
        public
        view
        returns(bool)
    {
        return tokenIdToAuction[_tokenId].auctionId > 0;
    }

    /// @dev Returns true if the token is on auction.
    function isOnAuction(uint256 _tokenId)
        public
        view
        returns (bool)
    {
        Auction storage _auction = tokenIdToAuction[_tokenId];
        return _auction.startedAt > 0 && _auction.startedAt <= block.timestamp && block.timestamp < (_auction.startedAt + _auction.duration);
    }

    /// @dev Returns the current price of an auction.
    /// @param _tokenId - ID of the token price we are checking.
    function getCurrentPrice(uint256 _tokenId)
        public
        view
        returns (uint256)
    {
        if (!isOnAuction(_tokenId)) {
            return 0;
        }
        Auction storage auction = tokenIdToAuction[_tokenId];
        return _currentPrice(auction);
    }

    function hasWhiteList(uint256 _tokenId)
        public
        view
        returns (bool)
    {
        uint256 _auctionId = tokenIdToAuction[_tokenId].auctionId;
        // always return false when tokenId is not on auction.
        return auctionWhiteList[_auctionId].count > 0;
    }

    function inWhiteList(uint256 _tokenId, address _address)
        public
        view
        returns (bool)
    {
        uint256 _auctionId = tokenIdToAuction[_tokenId].auctionId;
        // always return false when tokenId is not on auction.
        return auctionWhiteList[_auctionId].whiteList[_address];
    }

    /// @dev Add condidate for the auction of the passed token.
    function addAuctionWhiteList(uint256 _tokenId, address _address) 
        external
        whenNotPaused
    {
        require(msg.sender == address(VIP181), "permission denied");
        require(isOnAuction(_tokenId), "auction not found");
        require(!inWhiteList(_tokenId, _address), "in the list");

        uint256 _auctionId = tokenIdToAuction[_tokenId].auctionId;
        uint64 _count = auctionWhiteList[_auctionId].count;
        auctionWhiteList[_auctionId].count++;

        // Overflow check
        assert(_count < auctionWhiteList[_auctionId].count);

        auctionWhiteList[_auctionId].whiteList[_address] = true;
    }

    /// @dev Remove address from whitelist.
    function removeAuctionWhiteList(uint256 _tokenId, address _address) 
        external
        whenNotPaused
    {
        require(msg.sender == address(VIP181), "permission denied");
        require(isOnAuction(_tokenId), "auction not found");
        require(inWhiteList(_tokenId, _address), "not in the list");

        uint256 _auctionId = tokenIdToAuction[_tokenId].auctionId;
        auctionWhiteList[_auctionId].count--;
        auctionWhiteList[_auctionId].whiteList[_address] = false;
    }

}

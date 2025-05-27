// SPDX-License-Identifier: MIT

// Copyright (c) 2018 The VeChainThor developers

// Distributed under the GNU Lesser General Public License v3.0 software license, see the accompanying
// file LICENSE or <https://www.gnu.org/licenses/lgpl-3.0.html>

pragma solidity 0.8.20;

import "../utility/Pausable.sol";
import "../utility/SafeMath.sol";
import "../utility/interfaces/IVIP181.sol";

contract ClockAuctionBase is Pausable { 
    using SafeMath for uint256;

    struct Auction {
        uint256 auctionId;
        address payable seller;
        uint128 startingPrice;
        uint128 endingPrice;
        uint64 duration;
        uint64 startedAt;
    }

    struct WhiteList {
        mapping(address => bool) whiteList;
        uint64 count;
    }

    // The reference of VIP181 Token
    IVIP181 public VIP181;

    // The address of storing service fee
    address payable public feePool;
    uint8 public feePercnt = 0; // 0%

    // Mapping from tokenId to auction struct
    mapping(uint256 => Auction) tokenIdToAuction;
    // Mapping from auctionId to whitelist
    mapping(uint256 => WhiteList) auctionWhiteList;

    // Events
    event FeePoolAddressUpdated(address _newFeePoolAddr);
    event FeePercentUpdated(uint8 _newPercent);

    function setFeePoolAddress(address payable _newFeePoolAddr)
        public
        onlyOwner
    {
        require(_newFeePoolAddr != address(0), "invalid address");
        feePool = _newFeePoolAddr;
        emit FeePoolAddressUpdated(_newFeePoolAddr);
    }

    function setFeePercent(uint8 _newPercent)
        public
        onlyOwner
    {
        require(_newPercent < 100, "must less than 100");
        feePercnt = _newPercent;
        emit FeePercentUpdated(_newPercent);
    }

    /// Internal Methods

    /// @dev Adds an auction to the list of open auctions. Also fires the AuctionCreated event.
    function _addAuction(
        uint256 _auctionId,
        uint256 _tokenId,
        uint128 _startingPrice,
        uint128 _endingPrice,
        uint64 _duration,
        uint64 _startedAt,
        address payable _seller
    )
        internal
    {
        Auction memory _auction = Auction(
            _auctionId,
            _seller,
            _startingPrice,
            _endingPrice,
            _duration,
            _startedAt
        );

        tokenIdToAuction[_tokenId] = _auction;
    }

    /// @dev Computes the price and transfers winnings. Does NOT transfer ownership of token.
    function _bid(address payable _buyer, uint256 _tokenId, uint256 _bidAmount)
        internal
        returns (uint256)
    {
        Auction storage auction = tokenIdToAuction[_tokenId];

        // Check that the bid is greater than or equal to the current price
        uint256 price = _currentPrice(auction);
        require(_bidAmount >= price, "purchase failed");

        address payable _seller = auction.seller;

        // Remove auction before sending the fees to the sender to avoid the reentrancy attack.
        _cancelAuction(_tokenId);

        // Transfer proceeds to seller if there are any
        if (price > 0) {
            uint256 _fee = price.mul(feePercnt) / 100;
            uint256 _price = price.sub(_fee);
            feePool.transfer(_fee);
            _seller.transfer(_price);
        }

        // Calculate any excess funds included with the bid and transfer it back to bidder.
        uint256 bidExcess = _bidAmount.sub(price);

        // Return the funds
        _buyer.transfer(bidExcess);

        return price;
    }

    /// @dev Cancels an auction unconditionally.
    ///      It will removes an auction from the list of open auctions.
    function _cancelAuction(uint256 _tokenId)
        internal
    {
        delete auctionWhiteList[tokenIdToAuction[_tokenId].auctionId];
        delete tokenIdToAuction[_tokenId];
    }

    /// @dev Returns current price of an token on auction. Broken into two
    ///      functions (this one, that computes the duration from the auction
    ///      structure, and the other that does the price computation) so we
    ///      can easily test that the price computation works correctly.
    function _currentPrice(Auction storage _auction)
        internal
        view
        returns (uint256)
    {
        uint64 secondsPassed = uint64(block.timestamp) - _auction.startedAt;

        if (secondsPassed >= _auction.duration) {
            // auction has expired then return the end price.
            return _auction.endingPrice;
        }

        // Count the times of price-change.
        // The price of auction will change per 300s
        uint256 changeTimes = (uint256(secondsPassed) - 1) / 300;
        // The total price-change times 
        uint256 totalTimes = (uint256(_auction.duration) - 1) / 300;
        // The amount of every change
        uint256 perTimesChange = (uint256(_auction.endingPrice) - uint256(_auction.startingPrice)) / totalTimes;
    
        return uint256(uint256(_auction.startingPrice) + changeTimes * perTimesChange);
    }

}
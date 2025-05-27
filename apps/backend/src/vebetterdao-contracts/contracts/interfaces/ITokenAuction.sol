// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface ITokenAuction {
  // ------------ Functions ------------ //

  function removeAuctionWhiteList(uint256 _tokenId, address _address) external;

  function supportsInterface(bytes4 _interfaceId) external view returns (bool);

  function sendBonusTo(address _to, uint256 _amount) external;

  function name() external view returns (string memory);

  function isNormalToken(address _target) external view returns (bool);

  function getApproved(uint256 _tokenId) external view returns (address);

  function approve(address _to, uint256 _tokenId) external;

  function operators(address) external view returns (bool);

  function totalSupply() external view returns (uint256);

  function isToken(address _target) external view returns (bool);

  function InterfaceId_ERC165() external view returns (bytes4);

  function setTokenMetadataBaseURI(string memory _newBaseURI) external;

  function transferFrom(address _from, address _to, uint256 _tokenId) external;

  function getTokenParams(uint8 _level) external view returns (uint256, uint64, uint64, uint64);

  function auctionCount() external view returns (uint256);

  function setLeadTime(uint64 _leadtime) external;

  function createDirectionalSaleAuction(
    uint256 _tokenId,
    uint128 _price,
    uint64 _duration,
    address _toAddress
  ) external;

  function unpause() external returns (bool);

  function addToBlackList(address _badGuy) external;

  function bid(uint256 _tokenId) external payable;

  function blackList(address) external view returns (bool);

  function removeFromBlackList(address _innocent) external;

  function canTransfer(uint256 _tokenId) external view returns (bool);

  function paused() external view returns (bool);

  function upgradeTo(uint256 _tokenId, uint8 _toLvl) external;

  function ownerOf(uint256 _tokenId) external view returns (address);

  function transferCooldown() external view returns (uint64);

  function setSaleAuctionAddress(address _address) external;

  function balanceOf(address _owner) external view returns (uint256);

  function applyUpgrade(uint8 _toLvl) external;

  function addToken(
    address _addr,
    uint8 _lvl,
    bool _onUpgrade,
    uint64 _applyUpgradeTime,
    uint64 _applyUpgradeBlockno
  ) external;

  function pause() external returns (bool);

  function leadTime() external view returns (uint64);

  function owner() external view returns (address);

  function symbol() external view returns (string memory);

  function cancelAuction(uint256 _tokenId) external;

  function addOperator(address _operator) external;

  function getMetadata(uint256 _tokenId) external view returns (address, uint8, bool, bool, uint64, uint64, uint64);

  function transfer(address _to, uint256 _tokenId) external;

  function removeOperator(address _operator) external;

  function downgradeTo(uint256 _tokenId, uint8 _toLvl) external;

  function cancelUpgrade(uint256 _tokenId) external;

  function setTransferCooldown(uint64 _cooldown) external;

  function createSaleAuction(uint256 _tokenId, uint128 _startingPrice, uint128 _endingPrice, uint64 _duration) external;

  function idToOwner(uint256) external view returns (address);

  function tokenURI(uint256 _tokenId) external view returns (string memory);

  function addAuctionWhiteList(uint256 _tokenId, address _address) external;

  function xTokenCount() external view returns (uint64);

  function saleAuction() external view returns (address);

  function ownerToId(address) external view returns (uint256);

  function transferOwnership(address newOwner) external;

  function normalTokenCount() external view returns (uint64);

  function isX(address _target) external view returns (bool);

  // ------------ Events ------------ //

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

  event Transfer(address indexed _from, address indexed _to, uint256 indexed _tokenId);

  event Approval(address indexed _owner, address indexed _approved, uint256 indexed _tokenId);

  event ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved);

  event NewUpgradeApply(
    uint256 indexed _tokenId,
    address indexed _applier,
    uint8 _level,
    uint64 _applyTime,
    uint64 _applyBlockno
  );

  event CancelUpgrade(uint256 indexed _tokenId, address indexed _owner);

  event LevelChanged(uint256 indexed _tokenId, address indexed _owner, uint8 _fromLevel, uint8 _toLevel);

  event AuctionCancelled(uint256 indexed _auctionId, uint256 indexed _tokenId);

  event ProtocolUpgrade(address _saleAuction);

  event OperatorUpdated(address _op, bool _enabled);

  event BlackListUpdated(address _person, bool _op);

  event Pause();

  event Unpause();

  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
}

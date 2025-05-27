// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface ITreasury {
  event TransferLimitUpdated(address indexed token, uint256 limit);
  event TransferLimitVETUpdated(uint256 limit);
  function pause() external;
  function unpause() external;
  function transferVTHO(address _to, uint256 _value) external;
  function transferB3TR(address _to, uint256 _value) external;
  function transferVOT3(address _to, uint256 _value) external;
  function transferVET(address _to, uint256 _value) external;
  function transferTokens(address _token, address _to, uint256 _value) external;
  function transferNFT(address _nft, address _to, uint256 _tokenId) external;
  function convertB3TR(uint256 _b3trAmount) external;
  function convertVOT3(uint256 __vot3Amount) external;
  function getVTHOBalance() external view returns (uint256);
  function getB3TRBalance() external view returns (uint256);
  function getVOT3Balance() external view returns (uint256);
  function getVETBalance() external view returns (uint256);
  function getTokenBalance(address _token) external view returns (uint256);
  function getCollectionNFTBalance(address _nft) external view returns (uint256);
  function version() external pure returns (string memory);
  function b3trAddress() external view returns (address);
  function vot3Address() external view returns (address);
}

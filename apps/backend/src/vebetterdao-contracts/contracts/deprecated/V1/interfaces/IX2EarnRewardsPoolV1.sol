// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

/**
 * @title IX2EarnRewardsPoolV1
 * @dev Interface designed to be used by a contract that allows x2Earn apps to reward users that performed sustainable actions.
 * Funds can be deposited into this contract by specifying the app id that can access the funds.
 * Admins of x2EarnApps can withdraw funds from the rewards pool, whihc are sent to the team wallet.
 */
interface IX2EarnRewardsPoolV1 {
  /**
   * @dev Event emitted when a new deposit is made into the rewards pool.
   *
   * @param amount The amount of $B3TR deposited.
   * @param appId The ID of the app for which the deposit was made.
   * @param depositor The address of the user that deposited the funds.
   */
  event NewDeposit(uint256 amount, bytes32 indexed appId, address indexed depositor);

  /**
   * @dev Event emitted when a team withdraws funds from the rewards pool.
   *
   * @param amount The amount of $B3TR withdrawn.
   * @param appId The ID of the app for which the withdrawal was made.
   * @param teamWallet The address of the team wallet that received the funds.
   * @param withdrawer The address of the user that withdrew the funds.
   * @param reason The reason for the withdrawal.
   */
  event TeamWithdrawal(
    uint256 amount,
    bytes32 indexed appId,
    address indexed teamWallet,
    address withdrawer,
    string reason
  );

  /**
   * @dev Event emitted when a reward is emitted by an app.
   *
   * @param amount The amount of $B3TR rewarded.
   * @param appId The ID of the app that emitted the reward.
   * @param receiver The address of the user that received the reward.
   * @param proof The proof of the sustainable action that was performed.
   * @param distributor The address of the user that distributed the reward.
   */
  event RewardDistributed(
    uint256 amount,
    bytes32 indexed appId,
    address indexed receiver,
    string proof,
    address indexed distributor
  );

  /**
   * @dev Retrieves the current version of the contract.
   *
   * @return The version of the contract.
   */
  function version() external pure returns (string memory);

  /**
   * @dev Function used by x2earn apps to deposit funds into the rewards pool.
   *
   * @param amount The amount of $B3TR to deposit.
   * @param appId The ID of the app.
   */
  function deposit(uint256 amount, bytes32 appId) external returns (bool);

  /**
   * @dev Function used by x2earn apps to withdraw funds from the rewards pool.
   *
   * @param amount The amount of $B3TR to withdraw.
   * @param appId The ID of the app.
   * @param reason The reason for the withdrawal.
   */
  function withdraw(uint256 amount, bytes32 appId, string memory reason) external;

  /**
   * @dev Gets the amount of funds available for an app to reward users.
   *
   * @param appId The ID of the app.
   */
  function availableFunds(bytes32 appId) external view returns (uint256);

  /**
   * @dev Function used by x2earn apps to reward users that performed sustainable actions.
   *
   * @param appId the app id that is emitting the reward
   * @param amount the amount of B3TR token the user is rewarded with
   * @param receiver the address of the user that performed the sustainable action and is rewarded
   * @param proof a JSON file uploaded on IPFS by the app that adds information on the type of action that was performed
   */
  function distributeReward(bytes32 appId, uint256 amount, address receiver, string memory proof) external;
}

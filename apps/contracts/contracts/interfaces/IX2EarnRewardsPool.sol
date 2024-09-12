// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

/**
 * @title IX2EarnRewardsPool
 * @dev Interface designed to be used by a contract that allows x2Earn apps to reward users that performed sustainable actions.
 * Funds can be deposited into this contract by specifying the app id that can access the funds.
 * Admins of x2EarnApps can withdraw funds from the rewards pool, whihc are sent to the team wallet.
 */
interface IX2EarnRewardsPool {
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
    event TeamWithdrawal(uint256 amount, bytes32 indexed appId, address indexed teamWallet, address withdrawer, string reason);

    /**
     * @dev Event emitted when a reward is emitted by an app.
     *
     * @param amount The amount of $B3TR rewarded.
     * @param appId The ID of the app that emitted the reward.
     * @param receiver The address of the user that received the reward.
     * @param proof The proof of the sustainable action that was performed.
     * @param distributor The address of the user that distributed the reward.
     */
    event RewardDistributed(uint256 amount, bytes32 indexed appId, address indexed receiver, string proof, address indexed distributor);

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
     * @param proof deprecated argument, pass an empty string instead
     */
    function distributeReward(bytes32 appId, uint256 amount, address receiver, string memory proof) external;

    /**
     * @dev Function used by x2earn apps to reward users that performed sustainable actions.
     * @notice This function is depracted in favor of distributeRewardWithProof.
     *
     * @param appId the app id that is emitting the reward
     * @param amount the amount of B3TR token the user is rewarded with
     * @param receiver the address of the user that performed the sustainable action and is rewarded
     * @param proof the JSON string that contains the proof and impact of the sustainable action
     */
    function distributeRewardDeprecated(bytes32 appId, uint256 amount, address receiver, string memory proof) external;

    /**
     * @dev Function used by x2earn apps to reward users that performed sustainable actions.
     *
     * @param appId the app id that is emitting the reward
     * @param amount the amount of B3TR token the user is rewarded with
     * @param receiver the address of the user that performed the sustainable action and is rewarded
     * @param proofTypes the types of the proof of the sustainable action
     * @param proofValues the values of the proof of the sustainable action
     * @param impactCodes the codes of the impacts of the sustainable action
     * @param impactValues the values of the impacts of the sustainable action
     * @param description the description of the sustainable action
     */
    function distributeRewardWithProof(
        bytes32 appId,
        uint256 amount,
        address receiver,
        string[] memory proofTypes, // link, image, video, text, etc.
        string[] memory proofValues, // "https://...", "Qm...", etc.,
        string[] memory impactCodes, // carbon, water, etc.
        uint256[] memory impactValues, // 100, 200, etc.,
        string memory description
    ) external;

    /**
     * @dev Builds the JSON proof string that will be stored
     * on chain regarding the proofs, impacts and description of the sustainable action.
     *
     * @param proofTypes the types of the proof of the sustainable action
     * @param proofValues the values of the proof of the sustainable action
     * @param impactCodes the codes of the impacts of the sustainable action
     * @param impactValues the values of the impacts of the sustainable action
     * @param description the description of the sustainable action
     */
    function buildProof(
        string[] memory proofTypes, // link, photo, video, text, etc.
        string[] memory proofValues, // "https://...", "Qm...", etc.,
        string[] memory impactCodes, // carbon, water, etc.
        uint256[] memory impactValues, // 100, 200, etc.,
        string memory description
    ) external returns (string memory);
}

// SPDX-License-Identifier: MIT

//                                      #######
//                                 ################
//                               ####################
//                             ###########   #########
//                            #########      #########
//          #######          #########       #########
//          #########       #########      ##########
//           ##########     ########     ####################
//            ##########   #########  #########################
//              ################### ############################
//               #################  ##########          ########
//                 ##############      ###              ########
//                  ############                       #########
//                    ##########                     ##########
//                     ########                    ###########
//                       ###                    ############
//                                          ##############
//                                    #################
//                                   ##############
//                                   #########

// This contract is provided as a template for VeBetterDAO and should not be used as the definitive version. Ensure proper review and testing before deployment.

pragma solidity ^0.8.19;

import '@openzeppelin/contracts/access/AccessControl.sol';
import './interfaces/IToken.sol';

/**
 * @title EcoEarn Contract
 * @dev This contract manages a reward system based on cycles. Participants can make valid submissions to earn rewards.
 */
contract EcoEarn is AccessControl {
    IToken public token;

    // Mapping from cycle to total rewards
    mapping(uint256 => uint256) public rewards;

    // Mapping from cycle to remaining rewards
    mapping(uint256 => uint256) public rewardsLeft;

    // Mapping from cycle to participant's valid submissions count
    mapping(uint256 => mapping(address => uint256)) public submissions;

    // Mapping from cycle to total submissions count
    mapping(uint256 => uint256) public totalSubmissions;

    uint256 public maxSubmissionsPerCycle;

    // Duration of a cycle in blocks
    uint256 public cycleDuration;

    // Block number when the last cycle was started
    uint256 public lastCycleStartBlock;

    // Next cycle number
    uint256 public nextCycle;

    // Events
    event CycleStarted(uint256 cycleStartBlock);
    event CycleDurationUpdated(uint256 newDuration);
    event Submission(address indexed participant, uint256 amount);
    event ClaimedAllocation(uint256 indexed cycle, uint256 amount);

    /**
     * @dev Constructor for the EcoEarn contract
     * @param _admin Address of the admin
     * @param _token Address of the token contract
     * @param _cycleDuration Duration of each cycle in blocks
     * @param _maxSubmissionsPerCycle Maximum submissions allowed per cycle
     */
    constructor(address _admin, address _token, uint256 _cycleDuration, uint256 _maxSubmissionsPerCycle) {
        token = IToken(_token);
        maxSubmissionsPerCycle = _maxSubmissionsPerCycle;
        cycleDuration = _cycleDuration;
        nextCycle = 1;
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
    }

    /**
     * @dev Function to trigger a new cycle
     */
    function triggerCycle() public onlyRole(DEFAULT_ADMIN_ROLE) {
        lastCycleStartBlock = block.number; // Update the start block to the current block
        nextCycle++;
        emit CycleStarted(lastCycleStartBlock);
    }

    /**
     * @dev Registers a valid submission
     * @param participant Address of the participant
     * @param amount Amount of rewards to be given for the submission
     */
    function registerValidSubmission(address participant, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(amount > 0, 'EcoEarn: Amount must be greater than 0');
        require(submissions[getCurrentCycle()][participant] < maxSubmissionsPerCycle, 'EcoEarn: Max submissions per user reached');
        require(rewardsLeft[getCurrentCycle()] >= amount, 'EcoEarn: Not enough rewards left');
        require(block.number < getNextCycleBlock(), 'EcoEarn: Cycle is over');

        // Register the submission
        submissions[getCurrentCycle()][participant]++;
        // Increment the total submissions count
        totalSubmissions[getCurrentCycle()]++;
        // Decrease the rewards left
        rewardsLeft[getCurrentCycle()] -= amount;

        // Transfer the reward to the participant
        require(token.transfer(participant, amount));

        emit Submission(participant, amount);
    }

    /**
     * @dev Claims allocation for the next cycle
     * @param amount Amount of tokens to be allocated
     */
    function claimAllocation(uint256 amount) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(amount <= token.balanceOf(msg.sender), 'EcoEarn: Insufficient balance');
        rewards[nextCycle] = amount;
        rewardsLeft[nextCycle] = amount;
        require(token.transferFrom(msg.sender, address(this), amount));
        emit ClaimedAllocation(nextCycle, amount);
    }

    /**
     * @dev Withdraws remaining rewards of a specific cycle
     * @param cycle The cycle number to withdraw rewards from
     */
    function withdrawRewards(uint256 cycle) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(rewards[cycle] > 0, 'EcoEarn: No rewards to withdraw');
        require(cycle < getCurrentCycle(), 'EcoEarn: Cycle is not over');
        uint256 amount = rewardsLeft[cycle];
        rewardsLeft[cycle] = 0;
        require(token.transfer(msg.sender, amount));
    }

    // ---------------- SETTERS ---------------- //

    /**
     * @dev Sets the maximum submissions allowed per cycle
     * @param _maxSubmissionsPerCycle New maximum submissions per cycle
     */
    function setMaxSubmissionsPerCycle(uint256 _maxSubmissionsPerCycle) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_maxSubmissionsPerCycle > 0, 'EcoEarn: Max submissions per cycle must be greater than 0');
        maxSubmissionsPerCycle = _maxSubmissionsPerCycle;
    }

    /**
     * @dev Sets the token address
     * @param _token New token contract address
     */
    function setToken(address _token) external onlyRole(DEFAULT_ADMIN_ROLE) {
        token = IToken(_token);
    }

    /**
     * @dev Sets the next cycle number
     * @param _nextCycle New next cycle number
     */
    function setNextCycle(uint256 _nextCycle) external onlyRole(DEFAULT_ADMIN_ROLE) {
        nextCycle = _nextCycle;
    }

    // ---------------- GETTERS ---------------- //

    /**
     * @dev Returns the current cycle number
     * @return Current cycle number
     */
    function getCurrentCycle() public view returns (uint256) {
        return nextCycle - 1;
    }

    /**
     * @dev Returns the block number for the next cycle
     * @return Block number when the next cycle starts
     */
    function getNextCycleBlock() public view returns (uint256) {
        return lastCycleStartBlock + cycleDuration;
    }

    /**
     * @dev Checks if the participant has reached the maximum submissions for the current cycle
     * @param participant Address of the participant
     * @return True if the participant has reached the maximum submissions, otherwise false
     */
    function isUserMaxSubmissionsReached(address participant) public view returns (bool) {
        return submissions[getCurrentCycle()][participant] >= maxSubmissionsPerCycle;
    }
}

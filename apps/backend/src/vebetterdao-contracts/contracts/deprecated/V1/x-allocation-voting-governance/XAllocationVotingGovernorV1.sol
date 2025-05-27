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

pragma solidity 0.8.20;

import { ERC165Upgradeable } from "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { ContextUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import { IXAllocationVotingGovernorV1, IERC6372 } from "../interfaces/IXAllocationVotingGovernorV1.sol";
import { IXAllocationPoolV1 } from "../interfaces/IXAllocationPoolV1.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { IX2EarnAppsV1 } from "../interfaces/IX2EarnAppsV1.sol";
import { IEmissionsV1 } from "../interfaces/IEmissionsV1.sol";
import { IVoterRewardsV1 } from "../interfaces/IVoterRewardsV1.sol";

/**
 * @title XAllocationVotingGovernorV1
 * @dev Core of the voting system of allocation rounds, designed to be extended through various modules.
 *
 * This contract is abstract and requires several functions to be implemented in various modules:
 * - A counting module must implement {quorum}, {_quorumReached}, {_voteSucceeded}, and {_countVote}
 * - A voting module must implement {_getVotes}, {clock}, and {CLOCK_MODE}
 * - A settings module must implement {votingPeriod}
 * - An external contracts module must implement {x2EarnApps}, {emissions} and {voterRewards}
 * - A rounds storage module must implement {_startNewRound}, {roundSnapshot}, {roundDeadline}, and {currentRoundId}
 * - A rounds finalization module must implement {finalize}
 * - A earnings settings module must implement {_snapshotRoundEarningsCap}
 */
abstract contract XAllocationVotingGovernorV1 is
  Initializable,
  ContextUpgradeable,
  ERC165Upgradeable,
  IXAllocationVotingGovernorV1
{
  bytes32 private constant ALL_ROUND_STATES_BITMAP = bytes32((2 ** (uint8(type(RoundState).max) + 1)) - 1);

  /// @custom:storage-location erc7201:b3tr.storage.XAllocationVotingGovernor
  struct XAllocationVotingGovernorStorage {
    string _name;
  }

  // keccak256(abi.encode(uint256(keccak256("b3tr.storage.XAllocationVotingGovernor")) - 1)) & ~bytes32(uint256(0xff))
  bytes32 private constant XAllocationVotingGovernorStorageLocation =
    0x7fb63bcd433c69110ad961bfbe38aef51814cbb9e11af6fe21011ae43fb4be00;

  function _getXAllocationVotingGovernorStorage() internal pure returns (XAllocationVotingGovernorStorage storage $) {
    assembly {
      $.slot := XAllocationVotingGovernorStorageLocation
    }
  }

  /**
   * @dev Sets the value for {name}
   */
  function __XAllocationVotingGovernor_init(string memory name_) internal onlyInitializing {
    __XAllocationVotingGovernor_init_unchained(name_);
  }

  function __XAllocationVotingGovernor_init_unchained(string memory name_) internal onlyInitializing {
    XAllocationVotingGovernorStorage storage $ = _getXAllocationVotingGovernorStorage();
    $._name = name_;
  }

  // ---------- Setters ---------- //

  /**
   * @dev Starts a new round of voting to allocate funds to x-2-earn applications.
   */
  function startNewRound() public virtual returns (uint256) {
    address proposer = _msgSender();

    // check that there isn't an already ongoing round
    // but only do it after we have at least 1 round otherwise it will fail with `GovernorNonexistentRound`
    uint256 currentRound = currentRoundId();
    if (currentRound > 0) {
      require(!isActive(currentRound), "XAllocationVotingGovernor: there can be only one round per time");
    }

    return _startNewRound(proposer);
  }

  /**
   * @dev Cast a vote for a set of x-2-earn applications.
   */
  function castVote(uint256 roundId, bytes32[] memory appIds, uint256[] memory voteWeights) public virtual {
    _validateStateBitmap(roundId, _encodeStateBitmap(RoundState.Active));

    require(appIds.length == voteWeights.length, "XAllocationVotingGovernor: apps and weights length mismatch");
    require(appIds.length > 0, "XAllocationVotingGovernor: no apps to vote for");

    address voter = _msgSender();

    _countVote(roundId, voter, appIds, voteWeights);
  }

  // ---------- Internal and Private ---------- //

  /**
   * @dev Check that the current state of a round matches the requirements described by the `allowedStates` bitmap.
   * This bitmap should be built using `_encodeStateBitmap`.
   *
   * If requirements are not met, reverts with a {GovernorUnexpectedRoundState} error.
   */
  function _validateStateBitmap(uint256 roundId, bytes32 allowedStates) private view returns (RoundState) {
    RoundState currentState = state(roundId);
    if (_encodeStateBitmap(currentState) & allowedStates == bytes32(0)) {
      revert GovernorUnexpectedRoundState(roundId, currentState, allowedStates);
    }
    return currentState;
  }

  // ---------- Getters ---------- //

  function supportsInterface(
    bytes4 interfaceId
  ) public view virtual override(IERC165, ERC165Upgradeable) returns (bool) {
    return interfaceId == type(IXAllocationVotingGovernorV1).interfaceId || super.supportsInterface(interfaceId);
  }

  /**
   * @dev Returns the name of the governor.
   */
  function name() public view virtual returns (string memory) {
    XAllocationVotingGovernorStorage storage $ = _getXAllocationVotingGovernorStorage();
    return $._name;
  }

  /**
   * @dev Returns the version of the governor.
   */
  function version() public view virtual returns (string memory) {
    return "1";
  }

  /**
   * @dev Checks if the specified round is in active state or not.
   */
  function isActive(uint256 roundId) public view virtual override returns (bool) {
    return state(roundId) == RoundState.Active;
  }

  /**
   * @dev Returns the current state of a round.
   */
  function state(uint256 roundId) public view virtual returns (RoundState) {
    uint256 snapshot = roundSnapshot(roundId);

    if (snapshot == 0) {
      revert GovernorNonexistentRound(roundId);
    }

    uint256 currentTimepoint = clock();

    uint256 deadline = roundDeadline(roundId);

    if (deadline >= currentTimepoint) {
      return RoundState.Active;
    } else if (!_voteSucceeded(roundId)) {
      return RoundState.Failed;
    } else {
      return RoundState.Succeeded;
    }
  }

  /**
   * @dev Checks if the quorum has been reached for a given round.
   */
  function quorumReached(uint256 roundId) public view returns (bool) {
    return _quorumReached(roundId);
  }

  /**
   * @dev Returns the available votes votes for a given account at a given timepoint.
   */
  function getVotes(address account, uint256 timepoint) public view virtual returns (uint256) {
    return _getVotes(account, timepoint, "");
  }

  /**
   * @dev Checks if the given appId can be voted for in the given round.
   */
  function isEligibleForVote(bytes32 appId, uint256 roundId) public view virtual returns (bool) {
    return x2EarnApps().isEligible(appId, roundSnapshot(roundId));
  }

  /**
   * @dev Encodes a `RoundState` into a `bytes32` representation where each bit enabled corresponds to
   * the underlying position in the `RoundState` enum. For example:
   *
   * 0x000...10000
   *   ^^^^^^------ ...
   *          ^---- Succeeded
   *           ^--- Failed
   *            ^-- Active
   */
  function _encodeStateBitmap(RoundState roundState) internal pure returns (bytes32) {
    return bytes32(1 << uint8(roundState));
  }

  // ---------- Virtual ---------- //

  /**
   * @dev Internal function to store a vote in storage.
   */
  function _countVote(
    uint256 roundId,
    address account,
    bytes32[] memory appIds,
    uint256[] memory voteWeights
  ) internal virtual;

  /**
   * @dev Internal function to save the app shares cap and base allocation percentage for a round.
   */
  function _snapshotRoundEarningsCap(uint256 roundId) internal virtual;

  /**
   * @dev Internal function to check if the quorum has been reached for a given round.
   */
  function _quorumReached(uint256 roundId) internal view virtual returns (bool);

  /**
   * @dev Internal function to check if the vote has succeeded for a given round.
   */
  function _voteSucceeded(uint256 roundId) internal view virtual returns (bool);

  /**
   * @dev Internal function that starts a new round of voting to allocate funds to x-2-earn applications.
   */
  function _startNewRound(address proposer) internal virtual returns (uint256);

  /**
   * @dev Internal function to get the available votes for a given account at a given timepoint.
   */
  function _getVotes(address account, uint256 timepoint, bytes memory params) internal view virtual returns (uint256);

  /**
   * @dev Function to store the last succeeded round once a round ends.
   */
  function finalizeRound(uint256 roundId) public virtual;

  /**
   * @dev Clock used for flagging checkpoints. Can be overridden to implement timestamp based checkpoints (and voting), in which case {CLOCK_MODE} should be overridden as well to match.
   */
  function clock() public view virtual returns (uint48);

  /**
   * @dev Machine-readable description of the clock as specified in EIP-6372.
   */
  function CLOCK_MODE() public view virtual returns (string memory);

  /**
   * @dev Returns the voting duration.
   */
  function votingPeriod() public view virtual returns (uint256);

  /**
   * @dev Returns the quorum for a given timepoint.
   */
  function quorum(uint256 timepoint) public view virtual returns (uint256);

  /**
   * @dev Returns the block number when the round starts.
   */
  function roundSnapshot(uint256 roundId) public view virtual returns (uint256);

  /**
   * @dev Returns the block number when the round ends.
   */
  function roundDeadline(uint256 roundId) public view virtual returns (uint256);

  /**
   * @dev Returns the latest round id.
   */
  function currentRoundId() public view virtual returns (uint256);

  /**
   * @dev Returns the X2EarnApps contract.
   */
  function x2EarnApps() public view virtual returns (IX2EarnAppsV1);

  /**
   * @dev Returns the Emissions contract.
   */
  function emissions() public view virtual returns (IEmissionsV1);

  /**
   * @dev Returns the VoterRewards contract.
   */
  function voterRewards() public view virtual returns (IVoterRewardsV1);
}

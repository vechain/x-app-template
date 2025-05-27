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

import { VotesUpgradeable } from "./VotesUpgradeable.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { Checkpoints } from "@openzeppelin/contracts/utils/structs/Checkpoints.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @title VotesQuorumFractionUpgradeable
 * @dev Extension of {XAllocationVotingGovernor} for voting weight extraction from an {ERC20Votes} token and a quorum expressed as a
 * fraction of the total supply.
 */
abstract contract VotesQuorumFractionUpgradeable is Initializable, VotesUpgradeable {
  using Checkpoints for Checkpoints.Trace208;

  /// @custom:storage-location erc7201:b3tr.storage.XAllocationVotingGovernor.VotesQuorumFraction
  struct VotesQuorumFractionStorage {
    Checkpoints.Trace208 _quorumNumeratorHistory;
  }

  // keccak256(abi.encode(uint256(keccak256("b3tr.storage.XAllocationVotingGovernor.VotesQuorumFraction")) - 1)) & ~bytes32(uint256(0xff))
  bytes32 private constant VotesQuorumFractionStorageLocation =
    0x49d99284d013647f52e2a267fd5944583bd36be17443e784ec3e86bbd4c32400;

  function _getVotesQuorumFractionStorage() private pure returns (VotesQuorumFractionStorage storage $) {
    assembly {
      $.slot := VotesQuorumFractionStorageLocation
    }
  }

  event QuorumNumeratorUpdated(uint256 oldQuorumNumerator, uint256 newQuorumNumerator);

  /**
   * @dev The quorum set is not a valid fraction.
   */
  error GovernorInvalidQuorumFraction(uint256 quorumNumerator, uint256 quorumDenominator);

  /**
   * @dev Initialize quorum as a fraction of the token's total supply.
   *
   * The fraction is specified as `numerator / denominator`. By default the denominator is 100, so quorum is
   * specified as a percent: a numerator of 10 corresponds to quorum being 10% of total supply. The denominator can be
   * customized by overriding {quorumDenominator}.
   */
  function __VotesQuorumFraction_init(uint256 quorumNumeratorValue) internal onlyInitializing {
    __VotesQuorumFraction_init_unchained(quorumNumeratorValue);
  }

  function __VotesQuorumFraction_init_unchained(uint256 quorumNumeratorValue) internal onlyInitializing {
    _updateQuorumNumerator(quorumNumeratorValue);
  }

  /**
   * @dev Returns the current quorum numerator. See {quorumDenominator}.
   */
  function quorumNumerator() public view virtual returns (uint256) {
    VotesQuorumFractionStorage storage $ = _getVotesQuorumFractionStorage();
    return $._quorumNumeratorHistory.latest();
  }

  /**
   * @dev Returns the quorum numerator at a specific timepoint. See {quorumDenominator}.
   */
  function quorumNumerator(uint256 timepoint) public view virtual returns (uint256) {
    VotesQuorumFractionStorage storage $ = _getVotesQuorumFractionStorage();

    uint256 length = $._quorumNumeratorHistory._checkpoints.length;

    // Optimistic search, check the latest checkpoint
    Checkpoints.Checkpoint208 storage latest = $._quorumNumeratorHistory._checkpoints[length - 1];
    uint48 latestKey = latest._key;
    uint208 latestValue = latest._value;
    if (latestKey <= timepoint) {
      return latestValue;
    }

    // Otherwise, do the binary search
    return $._quorumNumeratorHistory.upperLookupRecent(SafeCast.toUint48(timepoint));
  }

  /**
   * @dev Returns the quorum denominator. Defaults to 100, but may be overridden.
   */
  function quorumDenominator() public view virtual returns (uint256) {
    return 100;
  }

  /**
   * @dev Returns the quorum for a timepoint, in terms of number of votes: `supply * numerator / denominator`.
   */
  function quorum(uint256 timepoint) public view virtual override returns (uint256) {
    return (token().getPastTotalSupply(timepoint) * quorumNumerator(timepoint)) / quorumDenominator();
  }

  /**
   * @dev Changes the quorum numerator.
   *
   * Emits a {QuorumNumeratorUpdated} event.
   *
   * Requirements:
   *
   * - New numerator must be smaller or equal to the denominator.
   */
  function updateQuorumNumerator(uint256 newQuorumNumerator) public virtual {
    _updateQuorumNumerator(newQuorumNumerator);
  }

  /**
   * @dev Changes the quorum numerator.
   *
   * Emits a {QuorumNumeratorUpdated} event.
   *
   * Requirements:
   *
   * - New numerator must be smaller or equal to the denominator.
   */
  function _updateQuorumNumerator(uint256 newQuorumNumerator) internal virtual {
    uint256 denominator = quorumDenominator();
    if (newQuorumNumerator > denominator) {
      revert GovernorInvalidQuorumFraction(newQuorumNumerator, denominator);
    }

    uint256 oldQuorumNumerator = quorumNumerator();

    VotesQuorumFractionStorage storage $ = _getVotesQuorumFractionStorage();
    $._quorumNumeratorHistory.push(clock(), SafeCast.toUint208(newQuorumNumerator));

    emit QuorumNumeratorUpdated(oldQuorumNumerator, newQuorumNumerator);
  }
}

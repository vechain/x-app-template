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

import { XAllocationVotingGovernor } from "../XAllocationVotingGovernor.sol";
import { IVotes } from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import { IERC5805 } from "@openzeppelin/contracts/interfaces/IERC5805.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { Time } from "@openzeppelin/contracts/utils/types/Time.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @title VotesUpgradeable
 * @dev Extension of {XAllocationVotingGovernor} for voting weight extraction from an {ERC20Votes} token, or since v4.5 an {ERC721Votes}
 * token.
 */
abstract contract VotesUpgradeable is Initializable, XAllocationVotingGovernor {
  /// @custom:storage-location erc7201:b3tr.storage.XAllocationVotingGovernor.VotesUpgradeable
  struct VotesStorage {
    IERC5805 _token;
  }

  // keccak256(abi.encode(uint256(keccak256("b3tr.storage.XAllocationVotingGovernor.VotesUpgradeable")) - 1)) & ~bytes32(uint256(0xff))
  bytes32 private constant VotesStorageLocation = 0x6eb1bf0a160cdf1b5e63f5e5c6b310f6c2542cd9e2a47ff1bc977c526dfab500;

  function _getVotesStorage() private pure returns (VotesStorage storage $) {
    assembly {
      $.slot := VotesStorageLocation
    }
  }

  function __Votes_init(IVotes tokenAddress) internal onlyInitializing {
    __Votes_init_unchained(tokenAddress);
  }

  function __Votes_init_unchained(IVotes tokenAddress) internal onlyInitializing {
    VotesStorage storage $ = _getVotesStorage();
    $._token = IERC5805(address(tokenAddress));
  }

  /**
   * @dev The token that voting power is sourced from.
   */
  function token() public view virtual returns (IERC5805) {
    VotesStorage storage $ = _getVotesStorage();
    return $._token;
  }

  /**
   * @dev Clock (as specified in EIP-6372) is set to match the token's clock. Fallback to block numbers if the token
   * does not implement EIP-6372.
   */
  function clock() public view virtual override returns (uint48) {
    try token().clock() returns (uint48 timepoint) {
      return timepoint;
    } catch {
      return Time.blockNumber();
    }
  }

  /**
   * @dev Machine-readable description of the clock as specified in EIP-6372.
   */
  // solhint-disable-next-line func-name-mixedcase
  function CLOCK_MODE() public view virtual override returns (string memory) {
    try token().CLOCK_MODE() returns (string memory clockmode) {
      return clockmode;
    } catch {
      return "mode=blocknumber&from=default";
    }
  }

  /**
   * Read the voting weight from the token's built in snapshot mechanism (see {Governor-_getVotes}).
   */
  function _getVotes(
    address account,
    uint256 timepoint,
    bytes memory /*params*/
  ) internal view virtual override returns (uint256) {
    return token().getPastVotes(account, timepoint);
  }
}

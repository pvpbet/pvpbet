// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Record} from "../lib/Record.sol";

interface IBetActionDecide {
  event Decided(address indexed decider, uint256 amount);

  /**
   * @dev Deciders to decide.
   */
  function decide(uint256 amount) external;

  /**
   * @dev Deciders to decide through the vote contract.
   *
   * Can only be called by the vote contract.
   */
  function decide(address decider, uint256 amount) external;

  /**
   * @dev Returns the vote minimum value.
   *
   * If it is below this value, it will be considered a dust attack.
   */
  function voteMinValue() external view returns (uint256);

  /**
   * @dev Returns the total decided amount.
   */
  function decidedAmount() external view returns (uint256);

  /**
   * @dev Returns the decided amount of the decider.
   */
  function decidedAmount(address decider) external view returns (uint256);

  /**
   * @dev Returns the records of the decision.
   */
  function decidedRecords() external view returns (Record[] memory);

  /**
   * @dev Confiscates the decided votes into the bet contract.
   *
   * Can only be called by the bet contract.
   */
  function confiscateDecidedVotes() external;

  /**
   * @dev Confiscates the decided votes into the bet contract.
   * @param limit The number of accounts processed at a time.
   *
   * Can only be called by the bet contract.
   */
  function confiscateDecidedVotes(uint256 limit) external;

  /**
   * @dev Unfixes the decided votes to the deciders.
   *
   * Can only be called by the bet contract.
   */
  function unfixDecidedVotes() external;

  /**
   * @dev Unfixes the decided votes to the deciders.
   * @param limit The number of accounts processed at a time.
   *
   * Can only be called by the bet contract.
   */
  function unfixDecidedVotes(uint256 limit) external;

  /**
   * @dev Returns true if the decided votes has been released.
   */
  function decidedVotesReleased() external view returns (bool);
}

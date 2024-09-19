// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Record} from "../lib/Record.sol";

interface IBetActionWager {
  event Wagered(address indexed player, uint256 amount);

  /**
   * @dev Players to wager.
   */
  function wager(uint256 amount) external;

  /**
   * @dev Players to wager through the chip contract.
   *
   * Can only be called by the chip contract.
   */
  function wager(address player, uint256 amount) external;

  /**
   * @dev Returns the total wagered amount.
   */
  function wageredAmount() external view returns (uint256);

  /**
   * @dev Returns the wagered amount of the player.
   */
  function wageredAmount(address player) external view returns (uint256);

  /**
   * @dev Returns the records of the wager.
   */
  function wageredRecords() external view returns (Record[] memory);

  /**
   * @dev Collect the wagered chips into the bet contract.
   *
   * Can only be called by the bet contract.
   */
  function collectWageredChips() external;

  /**
   * @dev Refund the wagered chips to the players.
   *
   * Can only be called by the bet contract.
   */
  function refundWageredChips() external;

  /**
   * @dev Returns true if the wagered chips has been released.
   */
  function wageredChipsReleased() external view returns (bool);
}

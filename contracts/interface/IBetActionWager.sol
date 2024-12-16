// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Record} from "../lib/Record.sol";

interface IBetActionWager {
  event Wagered(address indexed player, uint256 amount);

  /**
   * @dev Players to wager.
   * @param amount The amount of bet chips to wager.
   */
  function wager(uint256 amount) external;

  /**
   * @dev Players to wager.
   * @param amount The amount of bet chips to wager.
   * @param nonce The nonce of the permit2.
   * @param deadline The deadline of the permit2.
   * @param signature The signature of the permit2.
   */
  function wager(uint256 amount, uint256 nonce, uint256 deadline, bytes calldata signature) external;

  /**
   * @dev Players to wager through the chip contract.
   * @param player The address of the player.
   * @param amount The amount of bet chips to wager.
   *
   * Can only be called by the chip contract.
   */
  function wager(address player, uint256 amount) external;

  /**
   * @dev Players to wager through the chip contract.
   * @param player The address of the player.
   * @param amount The amount of bet chips to wager.
   * @param nonce The nonce of the permit2.
   * @param deadline The deadline of the permit2.
   * @param signature The signature of the permit2.
   *
   * Can only be called by the proxy contract.
   */
  function wager(address player, uint256 amount, uint256 nonce, uint256 deadline, bytes calldata signature) external;

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
   * @dev Returns the records of the wager.
   */
  function wageredRecords(uint256 offset, uint256 limit) external view returns (Record[] memory);

  /**
   * @dev Returns the count of the records of the wager.
   */
  function wageredRecordCount() external view returns (uint256);

  /**
   * @dev Collects the wagered chips into the bet contract.
   *
   * Can only be called by the bet contract.
   */
  function collectWageredChips() external;

  /**
   * @dev Refunds the wagered chips to the players.
   *
   * Can only be called by the bet contract.
   */
  function refundWageredChips() external;

  /**
   * @dev Refunds the wagered chips to the players.
   * @param limit The number of accounts processed at a time.
   *
   * Can only be called by the bet contract.
   */
  function refundWageredChips(uint256 limit) external;

  /**
   * @dev Returns true if the wagered chips has been released.
   */
  function wageredChipsReleased() external view returns (bool);
}

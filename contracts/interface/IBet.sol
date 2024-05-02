// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IBet {
  struct BetDetails {
    string title;
    string description;
    string iconURL;
    string forumURL;
    string[] options;
  }

  enum Status {
    WAGERING,     // 0 During the wagering period, waiting for the players to wager.
    DECIDING,     // 1 During the deciding period, waiting for the deciders to decide.
    ANNOUNCEMENT, // 2 During the announcement period, the winning option has been decided, and waiting for the disputers to dispute.
    ARBITRATING,  // 3 During the arbitrating period, waiting for the arbitrators to arbitrate.
    CONFIRMED,    // 4 The winning option has been confirmed, and preparations are being made to distribute the rewards.
    CANCELLED,    // 5 The bet has been canceled, and preparations are being made to refund the full amount.
    CLOSED        // 6 The bet has been closed, indicating it has been released.
  }

  /**
   * @dev Returns true if the contract is a bet.
   */
  function isBet() external pure returns (bool);

  /**
   * @dev Returns the bet contract address.
   */
  function bet() external view returns (address);

  /**
   * @dev Returns the chip token contract address.
   */
  function chip() external view returns (address);

  /**
   * @dev Returns the chip minimum value.
   *
   * If it is below this value, it will be considered a dust attack.
   */
  function chipMinValue() external view returns (uint256);

  /**
   * @dev Returns the vote token contract address.
   */
  function vote() external view returns (address);

  /**
   * @dev Returns the vote minimum value.
   *
   * If it is below this value, it will be considered a dust attack.
   */
  function voteMinValue() external view returns (uint256);

  /**
   * @dev Returns the bet creator address.
   */
  function creator() external view returns (address);

  /**
   * @dev Returns the bet details
   */
  function details() external view returns (BetDetails memory);

  /**
   * @dev Returns the bet options
   */
  function options() external view returns (address[] memory);

  /**
   * @dev Returns the wagering period deadline.
   */
  function wageringPeriodDeadline() external view returns (uint256);

  /**
   * @dev Returns the deciding period deadline.
   */
  function decidingPeriodDeadline() external view returns (uint256);

  /**
   * @dev Returns the unconfirmed winning option.
   */
  function unconfirmedWinningOption() external view returns (address);

  /**
   * @dev Returns the confirmed winning option.
   */
  function confirmedWinningOption() external view returns (address);

  /**
   * @dev Returns the wagered total amount.
   */
  function wageredTotalAmount() external view returns (uint256);

  /**
   * @dev Returns the minimum wagered total amount.
   */
  function minWageredTotalAmount() external view returns (uint256);

  /**
	 * @dev Returns the status of the bet.
	 */
  function status() external view returns (Status);

  /**
   * @dev Returns the status deadline.
   */
  function statusDeadline() external view returns (uint256);

  /**
   * @dev Release all funds based on results.
   */
  function release() external;

  /**
   * @dev Returns true if the bet has been released.
   */
  function released() external view returns (bool);
}

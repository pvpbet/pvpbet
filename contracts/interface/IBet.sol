// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IBet {
  struct BetConfig {
    uint256 minWageredTotalAmountETH;
    uint256 minWageredTotalQuantityERC20;
    uint256 minDecidedTotalQuantity;
    uint256 minArbitratedTotalQuantity;
    uint256 announcementPeriodDuration;
    uint256 arbitratingPeriodDuration;
    uint256 singleOptionMaxAmountRatio;
    uint256 confirmDisputeAmountRatio;
    uint256 protocolRewardRatio;
    uint256 creatorRewardRatio;
    uint256 deciderRewardRatio;
  }

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
  function isBet() external view returns (bool);

  /**
   * @dev Returns the bet config
   */
  function config() external view returns (BetConfig memory);

  /**
   * @dev Returns the bet details
   */
  function details() external view returns (BetDetails memory);

  /**
   * @dev Returns the bet options
   */
  function options() external view returns (address[] memory);

  /**
   * @dev Returns the deadline of the wagering period.
   */
  function wageringPeriodDeadline() external view returns (uint256);

  /**
   * @dev Returns the deadline of the deciding period.
   */
  function decidingPeriodDeadline() external view returns (uint256);

  /**
   * @dev Returns the start time of the arbitration period.
   */
  function arbitratingPeriodStartTime() external view returns (uint256);

  /**
   * @dev Returns the unconfirmed winning option.
   */
  function unconfirmedWinningOption() external view returns (address);

  /**
   * @dev Returns the confirmed winning option.
   */
  function confirmedWinningOption() external view returns (address);

  /**
   * @dev Returns the address of the bet creator.
   */
  function creator() external view returns (address);

  /**
   * @dev Returns the contract address of the chip token.
   */
  function chip() external view returns (address);

  /**
   * @dev Returns the contract address of the vote token.
   */
  function vote() external view returns (address);

  /**
   * @dev Returns the chip minimum value.
   *
   * If it is below this value, it will be considered a dust attack.
   */
  function chipMinValue() external view returns (uint256);

  /**
   * @dev Returns the vote minimum value.
   *
   * If it is below this value, it will be considered a dust attack.
   */
  function voteMinValue() external view returns (uint256);

  /**
   * @dev Returns the minimum wagered total amount.
   */
  function minWageredTotalAmount() external view returns (uint256);

  /**
   * @dev Returns the minimum decided total amount.
   */
  function minDecidedTotalAmount() external view returns (uint256);

  /**
   * @dev Returns the minimum disputed total amount.
   */
  function minDisputedTotalAmount() external view returns (uint256);

  /**
   * @dev Returns the minimum arbitrated total amount.
   */
  function minArbitratedTotalAmount() external view returns (uint256);

  /**
   * @dev Returns the wagered total amount.
   */
  function wageredTotalAmount() external view returns (uint256);

  /**
   * @dev Returns the decided total amount.
   */
  function decidedTotalAmount() external view returns (uint256);

  /**
   * @dev Returns the disputed total amount.
   */
  function disputedTotalAmount() external view returns (uint256);

  /**
   * @dev Returns the arbitrated total amount.
   */
  function arbitratedTotalAmount() external view returns (uint256);

  /**
	 * @dev Returns the status of the bet.
	 */
  function status() external view returns (Status);

  /**
   * @dev Returns the status deadline.
   */
  function statusDeadline() external view returns (uint256);

  /**
   * @dev Updates the status of the bet.
   */
  function statusUpdate() external;

  /**
   * @dev Releases all funds based on results.
   */
  function release() external;

  /**
   * @dev Returns true if the bet has been released.
   */
  function released() external view returns (bool);
}

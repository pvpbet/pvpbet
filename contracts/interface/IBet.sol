// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IBet {
  event Released(address indexed sender, uint256 count);
  event Penalized(address indexed sender, uint256 count);

  struct BetConfig {
    uint256 chipMinValue;
    uint256 voteMinValue;
    uint256 minWageredTotalAmount;
    uint256 verificationRatio;
    uint256 announcementPeriodDuration;
    uint256 arbitratingPeriodDuration;
    uint256 singleOptionMaxAmountRatio;
    uint256 confirmDisputeAmountRatio;
    uint256 protocolRewardRatio;
    uint256 creatorRewardRatio;
    uint256 verifierRewardRatio;
    uint256 countPerRelease;
    uint256 countPerPenalize;
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
    VERIFYING,    // 1 During the verifying period, waiting for the verifiers to verify.
    ANNOUNCEMENT, // 2 During the announcement period, the winning option has been verified, and waiting for the disputers to dispute.
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
   * @dev Returns the deadline of the verifying period.
   */
  function verifyingPeriodDeadline() external view returns (uint256);

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
   * @dev Returns the minimum verified total amount.
   */
  function minVerifiedTotalAmount() external view returns (uint256);

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
   * @dev Returns the verified total amount.
   */
  function verifiedTotalAmount() external view returns (uint256);

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
   * @dev Updates the status of the bet.
   */
  function statusUpdate() external returns (Status);

  /**
   * @dev Returns the status deadline.
   */
  function statusDeadline() external view returns (uint256);

  /**
   * @dev Releases all funds based on results.
   */
  function release() external;

  /**
   * @dev Partial release, used when the required gas for release is too large.
   */
  function release(uint256 limit) external;

  /**
   * @dev Returns the progress of the partial release.
   */
  function releasedProgress() external view returns (uint256 done, uint256 total);

  /**
   * @dev Returns true if the bet has been released.
   */
  function released() external view returns (bool);

  /**
   * @dev Penalizes based on results.
   */
  function penalize() external;

  /**
   * @dev Partial penalize, used when the required gas for penalize is too large.
   */
  function penalize(uint256 limit) external;

  /**
   * @dev Returns the progress of the partial penalize.
   */
  function penalizedProgress() external view returns (uint256 done, uint256 total);

  /**
   * @dev Returns true if the bet has been penalized.
   */
  function penalized() external view returns (bool);
}

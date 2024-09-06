// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {StakedRecord, UnlockWaitingPeriod} from "../lib/StakedRecord.sol";
import {UnstakedRecord} from "../lib/UnstakedRecord.sol";

interface IGovTokenStaking {
  event Staked(address indexed account, UnlockWaitingPeriod, uint256 amount);
  event Unstaked(address indexed account, UnlockWaitingPeriod, uint256 amount);
  event Withdrawn(address indexed account, UnlockWaitingPeriod, uint256 amount);

  /**
   * @dev Returns the stake minimum value.
   *
   * If it is below this value, it will be considered a dust attack.
   */
  function stakeMinValue() external view returns (uint256);

  /**
   * @dev Stake a specified amount of governance token and mint staking certificate.
   *
   * You must specify a unlock waiting period, which indicates the time required from unstake to unlock.
   * The unlock waiting period varies, representing different staking benefits or rights.
   */
  function stake(UnlockWaitingPeriod, uint256 amount) external;

  /**
   * @dev Unstake all governance token and burn staking certificate.
   *
   * An unstaked record will be generated and will enter the unlock waiting period.
   * You will need to wait for this period to pass before it can be withdrawn.
   */
  function unstake(UnlockWaitingPeriod) external;

  /**
   * @dev Unstake a specified amount of governance token and burn staking certificate.
   */
  function unstake(UnlockWaitingPeriod, uint256 amount) external;

  /**
   * @dev Restake the record corresponding to the index in the unstaked list.
   */
  function restake(uint256 index) external;

  /**
   * @dev Increase unlock waiting period.
   *
   * Modify the stake record with `UnlockWaitingPeriod.WEEK` to `UnlockWaitingPeriod.WEEK12`.
   */
  function increaseUnlockWaitingPeriod() external;

  /**
   * @dev Increase unlock waiting period for the specified staked amount.
   */
  function increaseUnlockWaitingPeriod(uint256 amount) external;

  /**
   * @dev Withdraw unlocked governance tokens.
   */
  function withdraw() external;

  /**
   * @dev Deduct the staked amount and transfer the governance token to the custodian.
   *
   * Can only be called by the vote token contract.
   */
  function deductStakedAmountAndTransfer(address account, uint256 amount, address custodian) external;

  /**
   * @dev Returns whether the account is staked.
   */
  function isStaked(address account) external view returns (bool);

  /**
  * @dev Returns the total staked amount.
   */
  function stakedAmount() external view returns (uint256);

  /**
   * @dev Returns the total staked amount by the unlock waiting period.
   */
  function stakedAmount(UnlockWaitingPeriod) external view returns (uint256);

  /**
   * @dev Returns the staked amount of the account.
   */
  function stakedAmount(address account) external view returns (uint256);

  /**
   * @dev Returns the staked amount of the account by the unlock waiting period.
   */
  function stakedAmount(address account, UnlockWaitingPeriod) external view returns (uint256);

  /**
   * @dev Returns the total staked weight.
   */
  function stakedWeight() external view returns (uint256);

  /**
   * @dev Returns the staked weight of the account.
   */
  function stakedWeight(address account) external view returns (uint256);

  /**
   * @dev Returns the staked record of the account by the unlock waiting period.
   */
  function stakedRecord(address account, UnlockWaitingPeriod) external view returns (StakedRecord memory);

  /**
   * @dev Returns the total number of staked records.
   */
  function stakedRecordCount() external view returns (uint256);

  /**
   * @dev Returns the total number of staked records by the unlock waiting period.
   */
  function stakedRecordCount(UnlockWaitingPeriod) external view returns (uint256);

  /**
   * @dev Returns the staked records.
   */
  function stakedRecords() external view returns (StakedRecord[] memory);

  /**
   * @dev Returns the unstaked records of the account.
   */
  function unstakedRecords(address account) external view returns (UnstakedRecord[] memory);

  /**
   * @dev Returns the unstaked records of the account by the unlock waiting period.
   */
  function unstakedRecords(address account, UnlockWaitingPeriod) external view returns (UnstakedRecord[] memory);
}

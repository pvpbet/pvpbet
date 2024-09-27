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
   * @dev Stakes a specified amount of governance tokens and mints a staking certificate.
   * @param unlockWaitingPeriod The time period to wait for unlocking after unstaking.
   * @param amount The amount of governance tokens to stake.
   *
   * You must specify an unlock waiting period, which indicates the time required from unstaking to unlocking.
   * The unlock waiting period varies, offering different staking benefits or rights.
   */
  function stake(UnlockWaitingPeriod unlockWaitingPeriod, uint256 amount) external;

  /**
   * @dev Unstakes all governance tokens and burns the staking certificate.
   * @param unlockWaitingPeriod The waiting period for unlocking after unstaking.
   *
   * An unstaked record will be generated and will enter the unlock waiting period.
   * You must wait for this period to pass before the tokens can be withdrawn.
   */
  function unstake(UnlockWaitingPeriod unlockWaitingPeriod) external;

  /**
   * @dev Unstakes a specified amount of governance tokens and burns the staking certificate.
   * @param unlockWaitingPeriod The waiting period for unlocking after unstaking.
   * @param amount The amount of governance tokens to unstake.
   */
  function unstake(UnlockWaitingPeriod unlockWaitingPeriod, uint256 amount) external;

  /**
   * @dev Restakes the record corresponding to the index in the unstaked list.
   * @param index The index of the unstaked record to restake.
   */
  function restake(uint256 index) external;

  /**
   * @dev Extends the unlock waiting period for the staking record.
   * @param from The current unlock waiting period.
   * @param to The new unlock waiting period.
   */
  function extendUnlockWaitingPeriod(UnlockWaitingPeriod from, UnlockWaitingPeriod to) external;

  /**
   * @dev Extends the unlock waiting period for the staking record of a specified amount.
   * @param from The current unlock waiting period.
   * @param to The new unlock waiting period.
   * @param amount The amount of tokens for which the unlock waiting period will be extended.
   */
  function extendUnlockWaitingPeriod(UnlockWaitingPeriod from, UnlockWaitingPeriod to, uint256 amount) external;

  /**
   * @dev Withdraws unlocked governance tokens.
   */
  function withdraw() external;

  /**
   * @dev Deducts the staked amount from the specified account and transfers the governance token to the custodian.
   * @param account The address of the account from which the staked amount will be deducted.
   * @param amount The amount of staked tokens to deduct.
   * @param custodian The address of the custodian to receive the tokens.
   *
   * Can only be called by the vote token contract.
   */
  function deductStakedAmountAndTransfer(address account, uint256 amount, address custodian) external;

  /**
   * @dev Deducts the staked amounts from multiple accounts and transfers the governance tokens to the custodian.
   * @param accounts The addresses of the accounts from which the staked amounts will be deducted.
   * @param amounts The respective amounts of staked tokens to deduct from each account.
   * @param custodian The address of the custodian to receive the tokens.
   *
   * Can only be called by the vote token contract.
   */
  function batchDeductStakedAmountAndTransfer(address[] calldata accounts, uint256[] calldata amounts, address custodian) external;

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

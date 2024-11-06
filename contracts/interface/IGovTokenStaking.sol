// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {UnstakedRecord} from "../lib/UnstakedRecord.sol";

interface IGovTokenStaking {
  enum UnlockWaitingPeriod {
    NONE,
    WEEK,
    WEEK12
  }

  event RewardTokenSet(address[] tokens);
  event Claimed(address indexed account, address indexed token, uint256 amount);
  event Distributed(address indexed sender, address indexed token, uint256 amount);
  event Staked(address indexed account, UnlockWaitingPeriod, uint256 amount);
  event Unstaked(address indexed account, UnlockWaitingPeriod, uint256 amount);
  event Withdrawn(address indexed account, UnlockWaitingPeriod, uint256 amount);

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
   * @dev Stakes a specified amount of governance tokens and mints a staking certificate.
   * @param unlockWaitingPeriod The time period to wait for unlocking after unstaking.
   * @param amount The amount of governance tokens to stake.
   * @param nonce The nonce of the permit2.
   * @param deadline The deadline of the permit2.
   * @param signature The signature of the permit2.
   *
   * You must specify an unlock waiting period, which indicates the time required from unstaking to unlocking.
   * The unlock waiting period varies, offering different staking benefits or rights.
   */
  function stake(
    UnlockWaitingPeriod unlockWaitingPeriod,
    uint256 amount,
    uint256 nonce,
    uint256 deadline,
    bytes calldata signature
  ) external;

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
   * Can only be called by the voting escrow contract.
   */
  function deductStakedAmountAndTransfer(address account, uint256 amount, address custodian) external;

  /**
   * @dev Deducts the staked amounts from multiple accounts and transfers the governance tokens to the custodian.
   * @param accounts The addresses of the accounts from which the staked amounts will be deducted.
   * @param amounts The respective amounts of staked tokens to deduct from each account.
   * @param custodian The address of the custodian to receive the tokens.
   *
   * Can only be called by the voting escrow contract.
   */
  function batchDeductStakedAmountAndTransfer(address[] calldata accounts, uint256[] calldata amounts, address custodian) external;

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
   * @dev Returns the unstaked records of the account.
   */
  function unstakedRecords(address account) external view returns (UnstakedRecord[] memory);

  /**
   * @dev Returns the unstaked records of the account by the unlock waiting period.
   */
  function unstakedRecords(address account, UnlockWaitingPeriod) external view returns (UnstakedRecord[] memory);

  /**
   * @dev Returns the reward tokens.
   */
  function rewardTokens() external view returns (address[] memory);

  /**
   * @dev Sets the reward tokens.
   */
  function setRewardTokens(address[] calldata tokens) external;

  /**
   * @dev Distribute a specified amount of ETH.
   */
  function distribute() external payable;

  /**
   * @dev Distribute a specified amount of ERC20 token.
   */
  function distribute(address token, uint256 amount) external;

  /**
   * @dev Returns the claimed ETH rewards of the account.
   */
  function claimedRewards(address account) external view returns (uint256);

  /**
   * @dev Returns the claimed ERC20 token rewards of the account.
   */
  function claimedRewards(address account, address token) external view returns (uint256);

  /**
   * @dev Returns the unclaimed ETH rewards of the account.
   */
  function unclaimedRewards(address account) external view returns (uint256);

  /**
   * @dev Returns the unclaimed ERC20 token rewards of the account.
   */
  function unclaimedRewards(address account, address token) external view returns (uint256);

  /**
   * @dev Claim the ETH rewards.
   */
  function claim() external;

  /**
   * @dev Claim the ERC20 token rewards.
   */
  function claim(address token) external;
}

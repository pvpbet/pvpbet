// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IBetChip {
  event Deposited(address indexed sender, uint256 amount);
  event Withdrawn(address indexed sender, uint256 amount);

  /**
   * @dev Batch transfer.
   */
  function transferBatch(address[] memory tos, uint256[] memory values) external returns (bool);

  /**
   * @dev Returns the contract address of the currency token.
   */
  function currency() external view returns (address);

  /**
   * @dev Deposit a specified amount of currency and receive an equivalent amount of chip tokens.
   * @param amount Must be greater than `0`.
   */
  function deposit(uint256 amount) external;

  /**
   * @dev Withdraw a specified amount of currency and reclaim an equivalent amount of chip tokens.
   * @param amount Must be greater than `0`.
   */
  function withdraw(uint256 amount) external;
}

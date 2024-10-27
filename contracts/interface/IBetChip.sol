// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IBetChip {
  event Deposited(address indexed sender, uint256 value);
  event Withdrawn(address indexed sender, uint256 value);

  /**
   * @dev Returns true if the contract is a bet chip.
   */
  function isBetChip() external view returns (bool);

  /**
   * @dev Batch transfer.
   */
  function transferBatch(address[] memory tos, uint256[] memory values) external returns (bool);

  /**
   * @dev Returns the address of the wrapped token.
   */
  function token() external view returns (address);

  /**
   * @dev Deposits a specified `value` amount of tokens and receive an equivalent amount of chip-wrapped tokens.
   * @param value Must be greater than `0`.
   */
  function deposit(uint256 value) external;

  /**
   * @dev Withdraws a specified `value` amount of tokens and reclaim an equivalent amount of chip-wrapped tokens.
   * @param value Must be greater than `0`.
   */
  function withdraw(uint256 value) external;
}

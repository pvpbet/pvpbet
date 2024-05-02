// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IWithdrawable {
  event Withdrawal(address indexed sender, uint256 amount);
  event WithdrawalERC20(address indexed sender, address indexed token, uint256 amount);

  /**
   * @dev Withdraw all ETH.
   * Can only be called by the authorized.
   */
  function withdraw() external;

  /**
   * @dev Withdraw a specified amount of ETH.
   * Can only be called by the authorized.
   */
  function withdraw(uint256 amount) external;

  /**
   * @dev Withdraw all ERC20 tokens.
   * Can only be called by the authorized.
   */
  function withdrawERC20(address token) external;

  /**
   * @dev Withdraw a specified amount of ERC20 tokens.
   * Can only be called by the authorized.
   */
  function withdrawERC20(address token, uint256 amount) external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IRewardDistributable {
  event Claimed(address indexed account, address indexed token, uint256 amount);
  event Distributed(address indexed sender, address indexed token, uint256 amount);

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

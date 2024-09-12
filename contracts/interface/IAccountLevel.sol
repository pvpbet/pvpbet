// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IAccountLevel {
  event LevelUpdated(address indexed account, uint256 level);

  /**
   * @dev Returns the level of account.
   */
  function level(address account) external view returns (uint256);

  /**
   * @dev Level up the account.
   *
   * Can only be called by bet contract.
   */
  function levelUp(address account) external;

  /**
   * @dev Level down the account.
   *
   * Can only be called by the bet contract.
   */
  function levelDown(address account) external;
}

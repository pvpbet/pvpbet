// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IAccountLevel {
  event LevelUpdated(address indexed account, uint256 level);
  event LevelUpdatedBatch(address[] accounts, uint256[] levels);

  /**
   * @dev Returns the level of the specified account.
   * @param account The address of the account whose level is being queried.
   */
  function level(address account) external view returns (uint256);

  /**
   * @dev Level up the specified account.
   * @param account The address of the account to level up.
   *
   * Can only be called by the bet contract.
   */
  function levelUp(address account) external;

  /**
   * @dev Level up multiple accounts.
   * @param accounts The addresses of the accounts to level up.
   *
   * Can only be called by the bet contract.
   */
  function levelUpBatch(address[] calldata accounts) external;

  /**
   * @dev Level down the specified account.
   * @param account The address of the account to level down.
   *
   * Can only be called by the bet contract.
   */
  function levelDown(address account) external;

  /**
   * @dev Level down multiple accounts.
   * @param accounts The addresses of the accounts to level down.
   *
   * Can only be called by the bet contract.
   */
  function levelDownBatch(address[] calldata accounts) external;
}

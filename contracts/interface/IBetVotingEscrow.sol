// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IBetVotingEscrow {
  event Fixed(address indexed spender, address indexed account, uint256 value);
  event Unfixed(address indexed spender, address indexed account, uint256 value);
  event UnfixedBatch(address indexed spender, address[] indexed accounts, uint256[] values);
  event Confiscated(address indexed spender, address indexed account, uint256 value);
  event ConfiscatedBatch(address indexed spender, address[] indexed accounts, uint256[] values);

  /**
   * @dev Mints votes to the specified account.
   * @param account The address of the account to receive the minted votes.
   * @param value The number of votes to mint.
   *
   * Can only be called by the governance token staking contract.
   */
  function mint(address account, uint256 value) external;

  /**
   * @dev Burns votes from the specified account.
   * @param account The address of the account from which the votes will be burned.
   * @param value The number of votes to burn.
   *
   * Can only be called by the governance token staking contract.
   */
  function burn(address account, uint256 value) external;

  /**
   * @dev Returns the vote balance of the specified account.
   * @param account The address of the account whose vote balance is being queried.
   * @param hasFixed If true, includes fixed votes in the balance.
   * @return The total vote balance of the account.
   */
  function balanceOf(address account, bool hasFixed) external view returns (uint256);

  /**
   * @dev Returns whether the specified account is able to participate in decision.
   * @param account The address of the account being checked.
   */
  function isAbleToDecide(address account) external view returns (bool);

  /**
   * @dev Returns whether the specified account is able to participate in arbitration.
   * @param account The address of the account being checked.
   */
  function isAbleToArbitrate(address account) external view returns (bool);

  /**
   * @dev Fixes the votes of the specified account.
   * @param account The address of the account whose votes will be fixed.
   * @param value The number of votes to fix.
   */
  function fix(address account, uint256 value) external;

  /**
   * @dev Unfixes the votes of the specified account.
   * @param account The address of the account whose votes will be unfixed.
   * @param value The number of votes to unfix.
   */
  function unfix(address account, uint256 value) external;

  /**
   * @dev Unfixes the votes of multiple accounts.
   * @param accounts The addresses of the accounts whose votes will be unfixed.
   * @param values The respective number of votes to unfix from each account.
   */
  function unfixBatch(address[] calldata accounts, uint256[] calldata values) external;

  /**
   * @dev Confiscates the votes of the specified account.
   * @param account The address of the account whose votes will be confiscated.
   * @param value The number of votes to confiscate.
   * @param custodian The address of the custodian.
   */
  function confiscate(address account, uint256 value, address custodian) external;

  /**
   * @dev Confiscates the votes of multiple accounts.
   * @param accounts The addresses of the accounts whose votes will be confiscated.
   * @param values The respective number of votes to confiscate from each account.
   * @param custodian The address of the custodian.
   */
  function confiscateBatch(address[] calldata accounts, uint256[] calldata values, address custodian) external;
}

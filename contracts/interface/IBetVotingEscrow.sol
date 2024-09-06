// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IBetVotingEscrow {
  event Fixed(address indexed account, address indexed spender, uint256 value);
  event Unfixed(address indexed account, address indexed spender, uint256 value);
  event Confiscated(address indexed account, address indexed spender, uint256 value);

  /**
   * @dev Mint the votes to the account.
   *
   * Can only be called by the governance token staking contract.
   */
  function mint(address account, uint256 value) external;

  /**
   * @dev Burn the votes from the account.
   *
   * Can only be called by the governance token staking contract.
   */
  function burn(address account, uint256 value) external;

  /**
   * @dev Returns the vote balance of the account.
   * @param hasFixed If true, includes the fixed votes.
   */
  function balanceOf(address account, bool hasFixed) external view returns (uint256);

  /**
   * @dev Returns whether the account is able to decide.
   */
  function isAbleToDecide(address account) external view returns (bool);

  /**
   * @dev Returns whether the account is able to arbitrate.
   */
  function isAbleToArbitrate(address account) external view returns (bool);

  /**
   * @dev Fix the votes of the account.
   */
  function fix(address account, uint256 value) external;

  /**
   * @dev Unfix the votes of the account.
   */
  function unfix(address account, uint256 value) external;

  /**
   * @dev Confiscate the votes of the account.
   * @param custodian The custodian address.
   *
   * `custodian` can transfer the votes to anyone.
   */
  function confiscate(address account, uint256 value, address custodian) external;
}

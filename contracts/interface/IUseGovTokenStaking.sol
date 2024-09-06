// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IUseGovTokenStaking {
  event SetGovTokenStaking(address govTokenStaking);

  /**
   * @dev Returns the governance token staking contract address.
   */
  function govTokenStaking() external view returns (address);

  /**
   * @dev Set the governance token staking contract address.
   */
  function setGovTokenStaking(address newGovTokenStaking) external;
}

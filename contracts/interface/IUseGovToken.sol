// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IUseGovToken {
  event SetGovToken(address govToken);

  /**
   * @dev Returns the governance token contract address.
   */
  function govToken() external view returns (address);

  /**
   * @dev Set the governance token contract address.
   */
  function setGovToken(address newGovToken) external;
}

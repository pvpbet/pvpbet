// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IUseGovToken {
  event GovTokenSet(address govToken);

  /**
   * @dev Returns the contract address of the governance token.
   */
  function govToken() external view returns (address);

  /**
   * @dev Sets the contract address of the governance token.
   */
  function setGovToken(address newGovToken) external;
}

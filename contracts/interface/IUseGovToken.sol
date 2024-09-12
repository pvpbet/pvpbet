// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IUseGovToken {
  event GovTokenSet(address govToken);

  /**
   * @dev Returns contract address of the governance token.
   */
  function govToken() external view returns (address);

  /**
   * @dev Set contract address of the governance token.
   */
  function setGovToken(address newGovToken) external;
}

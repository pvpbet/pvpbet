// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IMetadata {
  /**
   * @dev Returns the name of the contract.
   */
  function name() external view returns (string memory);

  /**
   * @dev Returns the version of the contract.
   */
  function version() external view returns (string memory);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IUseChipToken {
  event SetChipToken(address chipToken);

  /**
   * @dev Returns the chip token contract address.
   */
  function chipToken() external view returns (address);

  /**
   * @dev Set the chip token contract address.
   */
  function setChipToken(address newChip) external;
}

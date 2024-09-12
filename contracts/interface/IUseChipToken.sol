// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IUseChipToken {
  event ChipTokenSet(address chipToken);

  /**
   * @dev Returns contract address of the chip token.
   */
  function chipToken() external view returns (address);

  /**
   * @dev Set contract address of the chip token.
   */
  function setChipToken(address newChip) external;
}

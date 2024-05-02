// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IBetOption {
  /**
   * @dev Returns true if the contract is a bet option.
   */
  function isBetOption() external pure returns (bool);

  /**
   * @dev Returns the bet contract address.
   */
  function bet() external view returns (address);

  /**
   * @dev Returns the chip token contract address.
   */
  function chip() external view returns (address);

  /**
   * @dev Returns the chip minimum value.
   *
   * If it is below this value, it will be considered a dust attack.
   */
  function chipMinValue() external view returns (uint256);

  /**
   * @dev Returns the vote token contract address.
   */
  function vote() external view returns (address);

  /**
   * @dev Returns the vote minimum value.
   *
   * If it is below this value, it will be considered a dust attack.
   */
  function voteMinValue() external view returns (uint256);

  /**
   * @dev Returns the description of the option.
   */
  function description() external view returns (string memory);
}

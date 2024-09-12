// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IBetOption {
  /**
   * @dev Returns true if the contract is a bet option.
   */
  function isBetOption() external pure returns (bool);

  /**
   * @dev Returns contract address of the bet.
   */
  function bet() external view returns (address);

  /**
   * @dev Returns contract address of the chip token.
   */
  function chip() external view returns (address);

  /**
   * @dev Returns the chip minimum value.
   *
   * If it is below this value, it will be considered a dust attack.
   */
  function chipMinValue() external view returns (uint256);

  /**
   * @dev Returns contract address of the vote token.
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

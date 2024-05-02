// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IBetOptionFactory {
  /**
	 * @dev Create a bet option.
	 */
  function createBetOption(
    address bet,
    string calldata description
  ) external returns (address);
}

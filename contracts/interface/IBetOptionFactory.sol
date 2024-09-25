// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IBetOptionFactory {
  /**
	 * @dev Create a bet option.
	 */
  function createBetOption(
    string calldata description,
    address bet
  ) external returns (address);
}

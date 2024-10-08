// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IBetChipFactory {
  /**
	 * @dev Creates a bet chip.
	 */
  function createBetChip(address token) external returns (address);
}

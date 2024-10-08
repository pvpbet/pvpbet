// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IBetChipManager {
  event BetChipFactorySet(address betChipFactory);
  event BetChipCreated(address indexed chip);

  /**
   * @dev Returns the contract address of the bet chip factory.
   */
  function betChipFactory() external view returns (address);

  /**
  * @dev Sets the contract address of the bet chip factory.
   */
  function setBetChipFactory(address newBetChipFactory) external;

  /**
	 * @dev Creates a bet chip.
	 */
  function createBetChip(address token) external returns (address);

  /**
   * @dev Returns true if the address is a bet chip.
   */
  function isBetChip(address chip) external view returns (bool);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IUseBetManager {
  event BetManagerSet(address betManager);

  /**
   * @dev Returns the contract address of the bet manager.
   */
  function betManager() external view returns (address);

  /**
   * @dev Set the contract address of the bet manager.
   */
  function setBetManager(address newBetManager) external;
}

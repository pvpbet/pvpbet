// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IUseBetManager {
  event BetManagerSet(address betManager);

  /**
   * @dev Returns contract address of the bet manager.
   */
  function betManager() external view returns (address);

  /**
   * @dev Set contract address of the bet manager.
   */
  function setBetManager(address newBetManager) external;
}

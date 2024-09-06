// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IUseBetManager {
  event SetBetManager(address betManager);

  /**
   * @dev Returns the bet manager contract address.
   */
  function betManager() external view returns (address);

  /**
   * @dev Set the bet manager contract address.
   */
  function setBetManager(address newBetManager) external;
}

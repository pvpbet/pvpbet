// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IBet} from "./IBet.sol";

interface IBetManager {
  event BetFactorySet(address betFactory);
  event BetOptionFactorySet(address betOptionFactory);
  event CreationFeeSet(uint256 fee);
  event BetCreated(address indexed bet, address indexed creator);

  /**
   * @dev Returns contract address of the bet factory.
   */
  function betFactory() external view returns (address);

  /**
  * @dev Set contract address of the bet factory.
   */
  function setBetFactory(address newBetFactory) external;

  /**
   * @dev Returns contract address of the bet option factory.
   */
  function betOptionFactory() external view returns (address);

  /**
  * @dev Set contract address of the bet option factory.
   */
  function setBetOptionFactory(address newBetOptionFactory) external;

  /**
   * @dev Returns the fee charged for creating a bet.
   */
  function creationFee() external view returns (uint256);

  /**
   * @dev Set the fee charged for creating a bet.
   */
  function setCreationFee(uint256 fee) external;

  /**
	 * @dev Create a bet using ETH as chips.
	 */
  function createBet(
    IBet.BetDetails calldata details,
    uint256 wageringPeriodDuration,
    uint256 decidingPeriodDuration
  ) external returns (address);

  /**
	 * @dev Create a bet using ERC20 tokens as chips.
	 */
  function createBet(
    IBet.BetDetails calldata details,
    uint256 wageringPeriodDuration,
    uint256 decidingPeriodDuration,
    bool useChipERC20
  ) external returns (address);

  /**
   * @dev The bet notifies that it has been closed.
   *
   * Can only be called by the bet contract.
   */
  function close() external;

  /**
   * @dev Release all bets with the status "CANCELLED".
   */
  function clear() external;

  /**
   * @dev Returns true if the address is a bet contract.
   */
  function isBet(address bet) external view returns (bool);

  /**
   * @dev Returns the contract address for the bet’s index.
   *
   * Index counts from 1.
   */
  function betIndex(address bet) external view returns (uint256);

  /**
   * @dev Returns the bet contract address at the index.
   *
   * Index counts from 1.
   */
  function betAt(uint256 index) external view returns (address);

  /**
   * @dev Returns the total number of bet contracts.
   */
  function betCount() external view returns (uint256);

  /**
   * @dev Returns the bet contracts.
   */
  function bets(uint256 offset, uint256 limit) external view returns (address[] memory);

  /**
   * @dev Returns the bet contracts by status.
   */
  function bets(uint256 offset, uint256 limit, IBet.Status[] memory status) external view returns (address[] memory);

  /**
   * @dev Returns the contract address for the active bet’s index.
   *
   * Index counts from 1.
   */
  function activeBetIndex(address bet) external view returns (uint256);

  /**
   * @dev Returns the active bet contract address at the index.
   *
   * Index counts from 1.
   */
  function activeBetAt(uint256 index) external view returns (address);

  /**
   * @dev Returns the total number of active bet contracts.
   */
  function activeBetCount() external view returns (uint256);

  /**
   * @dev Returns the active bet contracts.
   */
  function activeBets(uint256 offset, uint256 limit) external view returns (address[] memory);

  /**
   * @dev Returns the active bet contracts by status.
   */
  function activeBets(uint256 offset, uint256 limit, IBet.Status[] memory status) external view returns (address[] memory);
}

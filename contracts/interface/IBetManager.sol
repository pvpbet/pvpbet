// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IBet} from "./IBet.sol";

interface IBetManager {
  event BetConfiguratorSet(address betConfigurator);
  event BetFactorySet(address betFactory);
  event BetOptionFactorySet(address betOptionFactory);
  event CreationFeeSet(uint256 fee);
  event BetCreated(address indexed bet, address indexed creator);

  /**
   * @dev Returns the contract address of the bet configurator.
   */
  function betConfigurator() external view returns (address);

  /**
  * @dev Set the contract address of the bet configurator.
   */
  function setBetConfigurator(address newBetConfigurator) external;

  /**
   * @dev Returns the contract address of the bet factory.
   */
  function betFactory() external view returns (address);

  /**
  * @dev Set the contract address of the bet factory.
   */
  function setBetFactory(address newBetFactory) external;

  /**
   * @dev Returns the contract address of the bet option factory.
   */
  function betOptionFactory() external view returns (address);

  /**
  * @dev Set the contract address of the bet option factory.
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
   * @dev Returns true if the address is a bet contract.
   */
  function isBet(address bet) external view returns (bool);
}

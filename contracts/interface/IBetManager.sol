// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IBet} from "./IBet.sol";

interface IBetManager {
  event BetChipManagerSet(address betChipManager);
  event BetConfiguratorSet(address betConfigurator);
  event BetFactorySet(address betFactory);
  event BetOptionFactorySet(address betOptionFactory);
  event CreationFeeSet(uint256 fee);
  event BetCreated(
    address indexed bet,
    address indexed chip,
    address indexed creator,
    uint256 timestamp,
    string version
  );

  /**
   * @dev Returns the contract address of the bet chip manager.
   */
  function betChipManager() external view returns (address);

  /**
  * @dev Sets the contract address of the bet chip manager.
   */
  function setBetChipManager(address newBetChipManager) external;

  /**
   * @dev Returns the contract address of the bet configurator.
   */
  function betConfigurator() external view returns (address);

  /**
  * @dev Sets the contract address of the bet configurator.
   */
  function setBetConfigurator(address newBetConfigurator) external;

  /**
   * @dev Returns the contract address of the bet factory.
   */
  function betFactory() external view returns (address);

  /**
  * @dev Sets the contract address of the bet factory.
   */
  function setBetFactory(address newBetFactory) external;

  /**
   * @dev Returns the contract address of the bet option factory.
   */
  function betOptionFactory() external view returns (address);

  /**
  * @dev Sets the contract address of the bet option factory.
   */
  function setBetOptionFactory(address newBetOptionFactory) external;

  /**
   * @dev Returns the fee charged for creating a bet.
   */
  function creationFee() external view returns (uint256);

  /**
   * @dev Sets the fee charged for creating a bet.
   */
  function setCreationFee(uint256 fee) external;

  /**
	 * @dev Creates a bet using ETH as chips.
	 * @param details The details of the bet.
	 * @param wageringPeriodDuration The duration of the wagering period.
	 * @param verifyingPeriodDuration The duration of the verifying period.
	 */
  function createBet(
    IBet.BetDetails calldata details,
    uint256 wageringPeriodDuration,
    uint256 verifyingPeriodDuration
  ) external returns (address);

  /**
	 * @dev Creates a bet using ETH as chips.
	 * @param details The details of the bet.
	 * @param wageringPeriodDuration The duration of the wagering period.
	 * @param verifyingPeriodDuration The duration of the verifying period.
	 * @param nonce The nonce of the permit2.
   * @param deadline The deadline of the permit2.
   * @param signature The signature of the permit2.
	 */
  function createBet(
    IBet.BetDetails calldata details,
    uint256 wageringPeriodDuration,
    uint256 verifyingPeriodDuration,
    uint256 nonce,
    uint256 deadline,
    bytes calldata signature
  ) external returns (address);

  /**
	 * @dev Creates a bet using ERC20 tokens as chips.
	 * @param details The details of the bet.
	 * @param wageringPeriodDuration The duration of the wagering period.
	 * @param verifyingPeriodDuration The duration of the verifying period.
	 * @param chip The address of the ERC20 token contract.
	 */
  function createBet(
    IBet.BetDetails calldata details,
    uint256 wageringPeriodDuration,
    uint256 verifyingPeriodDuration,
    address chip
  ) external returns (address);

  /**
	 * @dev Creates a bet using ERC20 tokens as chips.
	 * @param details The details of the bet.
	 * @param wageringPeriodDuration The duration of the wagering period.
	 * @param verifyingPeriodDuration The duration of the verifying period.
	 * @param chip The address of the ERC20 token contract.
	 * @param nonce The nonce of the permit2.
   * @param deadline The deadline of the permit2.
   * @param signature The signature of the permit2.
	 */
  function createBet(
    IBet.BetDetails calldata details,
    uint256 wageringPeriodDuration,
    uint256 verifyingPeriodDuration,
    address chip,
    uint256 nonce,
    uint256 deadline,
    bytes calldata signature
  ) external returns (address);

  /**
   * @dev Returns true if the address is a bet contract.
   */
  function isBet(address bet) external view returns (bool);

  /**
   * @dev Returns the version of the bet contract.
   */
  function betVersion() external view returns (string memory);

  /**
   * @dev Returns the version of the bet option contract.
   */
  function betOptionVersion() external view returns (string memory);
}

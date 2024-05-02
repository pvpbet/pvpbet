// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IBetChip {
  event SetCurrenciesAndRates(address[] currencies, uint256[] rates);
  event Mint(address indexed account, uint256 quantity, address currency, uint256 amount);
  event Burn(address indexed account, uint256 quantity, address[] currenies, uint256[] amounts);

  /**
   * @dev Returns currencies and rates.
   *
   * address[] currencies
   * [
   *   0x0,     // ETH
   *   0xX...,  // WETH Contract Address
   *   0xY...,  // DAI Contract Address
   *   0xZ...,  // USDC Contract Address
   * ]
   * uint256[] rates
   * [
   *   3_600 * 3_000, // 1ETH = 3_000DAI = 10_800_000TIME (ETH has 18 decimals, TIME has 18 decimals)
   *   3_600 * 3_000, // 1WETH = 3_000DAI = 10_800_000TIME (WETH has 18 decimals, TIME has 18 decimals)
   *   3_600, // 1DAI = 3_600TIME (DAI has 18 decimals, TIME has 18 decimals)
   *   3_600 * 10 ** 12, // 1USDC = 3_600TIME (USDC has 6 decimals, TIME has 18 decimals)
   * ]
   */
  function currenciesAndRates() external view returns (address[] memory, uint256[] memory);

  /**
   * @dev Set currencies and rates.
   *
   * Can only be called by the owner.
   *
   * `newCurrencies` and `newRates` must have the same length.
   */
  function setCurrenciesAndRates(address[] calldata newCurrencies, uint256[] calldata newRates) external;

  /**
   * @dev Buy a specified quantity of chip tokens.
   * @param currency Must be a valid currency.
   * @param quantity Must be greater than `0`.
   *
   * `quantity` = 1 token / (10 ** decimals)
   */
  function buy(address currency, uint256 quantity) external payable;

  /**
   * @dev Sell a specified quantity of chip tokens.
   * @param currency Must be a valid currency.
   * @param quantity Must be greater than `0`.
   *
   * `quantity` = 1 token / (10 ** decimals)
   */
  function sell(address currency, uint256 quantity) external;

  /**
   * @dev Deposit a specified amount of currency for buying tokens.
   * @param currency Must be a valid currency.
   * @param amount Must be greater than `0`.
   */
  function deposit(address currency, uint256 amount) external payable;

  /**
   * @dev Withdraw a specified amount of currency from selling tokens.
   * @param currency Must be a valid currency.
   * @param amount Must be greater than `0`.
   */
  function withdraw(address currency, uint256 amount) external;

  /**
   * @dev Gets the currency amount corresponding to the chip token quantity.
   * @param currency Must be a valid currency.
   * @param quantity Must be greater than `0`.
   *
   * `quantity` = 1 token / (10 ** decimals)
   * `amount` = `quantity` / currency rate
   *
   * The returned amount must be greater than `0`.
   */
  function getTokenAmount(address currency, uint256 quantity) external view returns (uint256 amount);

  /**
   * @dev Gets the chip token quantity corresponding to the currency amount.
   * @param currency Must be a valid currency.
   * @param amount Must be greater than `0`.
   *
   * `amount` = 1 currency token / (10 ** decimals)
   * `quantity` = `amount` * currency rate
   *
   * The returned quantity could be `0`.
   */
  function getTokenQuantity(address currency, uint256 amount) external view returns (uint256 quantity);
}

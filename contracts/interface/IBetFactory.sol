// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IBet} from "./IBet.sol";

interface IBetFactory {
  /**
	 * @dev Create a bet.
	 */
  function createBet(
    IBet.BetConfig calldata config,
    IBet.BetDetails calldata details,
    uint256 wageringPeriodDuration,
    uint256 decidingPeriodDuration,
    address creator,
    address chip,
    address vote,
    address betManager,
    address betOptionFactory
  ) external returns (address);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IBet} from "./IBet.sol";

interface IBetFactory {
  /**
	 * @dev Creates a bet.
	 */
  function createBet(
    IBet.BetConfig calldata config,
    IBet.BetDetails calldata details,
    uint256 wageringPeriodDuration,
    uint256 verifyingPeriodDuration,
    address creator,
    address chip,
    address vote,
    address govToken,
    address betManager,
    address betOptionFactory
  ) external returns (address);
}

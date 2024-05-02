// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IBet} from "./IBet.sol";

interface IBetFactory {
  /**
	 * @dev Create a bet.
	 */
  function createBet(
    address betManager,
    address betOptionFactory,
    address chip,
    address vote,
    address creator,
    IBet.BetDetails calldata details,
    uint256 wageringPeriodDuration,
    uint256 decidingPeriodDuration
  ) external returns (address);
}

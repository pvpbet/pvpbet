// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IBet} from "./IBet.sol";

interface IBetFactory {
  /**
	 * @dev Create a bet.
	 */
  function createBet(
    address betOptionFactory,
    address betManager,
    address chip,
    address vote,
    address creator,
    uint256 wageringPeriodDuration,
    uint256 decidingPeriodDuration,
    IBet.BetDetails calldata details
  ) external returns (address);
}

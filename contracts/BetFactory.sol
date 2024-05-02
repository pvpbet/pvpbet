// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IBetFactory} from "./interface/IBetFactory.sol";
import {Bet} from "./Bet.sol";

contract BetFactory is IBetFactory {
  function createBet(
    address betManager,
    address betOptionFactory,
    address chip,
    address vote,
    address creator,
    Bet.BetDetails calldata details,
    uint256 wageringPeriodDuration,
    uint256 decidingPeriodDuration
  ) external returns (address) {
    return address(
      new Bet(
        betManager,
        betOptionFactory,
        chip,
        vote,
        creator,
        details,
        wageringPeriodDuration,
        decidingPeriodDuration
      )
    );
  }
}
